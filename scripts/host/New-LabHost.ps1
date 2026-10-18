#Requires -RunAsAdministrator
#Requires -Modules Hyper-V
<#
.SYNOPSIS
    Builds the Hyper-V side of the lab: internal switch, NAT, and the DC01/FS01 (and optional CLIENT01) VMs.
.DESCRIPTION
    Idempotent: existing switch/NAT/VMs are left alone. VMs are Generation 2, Secure Boot on,
    boot from the supplied ISO. Windows installation itself is a documented manual step (docs/02).
.EXAMPLE
    .\New-LabHost.ps1 -ServerIso D:\ISO\WS2025.iso -ClientIso D:\ISO\Win11.iso -VmRoot D:\Hyper-V\Lab
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path $_ })][string]$ServerIso,
    [ValidateScript({ Test-Path $_ })][string]$ClientIso,
    [string]$VmRoot = 'D:\Hyper-V\Lab'
)

$ErrorActionPreference = 'Stop'
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"
$net = $Lab.Network

# --- Virtual switch + NAT so guests reach the internet through the host -----------------
if (-not (Get-VMSwitch -Name $net.SwitchName -ErrorAction SilentlyContinue)) {
    if ($PSCmdlet.ShouldProcess($net.SwitchName, 'Create internal switch')) {
        New-VMSwitch -Name $net.SwitchName -SwitchType Internal | Out-Null
    }
}
$alias = "vEthernet ($($net.SwitchName))"
if (-not (Get-NetIPAddress -InterfaceAlias $alias -IPAddress $net.Gateway -ErrorAction SilentlyContinue)) {
    if ($PSCmdlet.ShouldProcess($alias, "Assign $($net.Gateway)/$($net.PrefixLength)")) {
        New-NetIPAddress -InterfaceAlias $alias -IPAddress $net.Gateway -PrefixLength $net.PrefixLength | Out-Null
    }
}
if (-not (Get-NetNat -Name 'LabNat' -ErrorAction SilentlyContinue)) {
    if ($PSCmdlet.ShouldProcess('LabNat', 'Create NAT')) {
        New-NetNat -Name 'LabNat' -InternalIPInterfaceAddressPrefix "$($net.Subnet)/$($net.PrefixLength)" | Out-Null
    }
}

function New-LabVm {
    param(
        [string]$Name, [int]$MemoryGB, [int]$Cpu, [int]$OsDiskGB,
        [int[]]$ExtraDisksGB = @(), [string]$Iso, [switch]$Tpm
    )
    if (Get-VM -Name $Name -ErrorAction SilentlyContinue) { Write-Host "$Name exists - skipping"; return }
    if (-not $PSCmdlet.ShouldProcess($Name, 'Create VM')) { return }

    $dir = Join-Path $VmRoot $Name
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $vm = New-VM -Name $Name -Generation 2 -MemoryStartupBytes ($MemoryGB * 1GB) `
        -NewVHDPath (Join-Path $dir "$Name-os.vhdx") -NewVHDSizeBytes ($OsDiskGB * 1GB) `
        -SwitchName $net.SwitchName -Path $VmRoot
    Set-VM -VM $vm -ProcessorCount $Cpu -StaticMemory -CheckpointType Production -AutomaticCheckpointsEnabled $false
    Enable-VMIntegrationService -VM $vm -Name 'Guest Service Interface'

    $i = 1
    foreach ($gb in $ExtraDisksGB) {
        $path = Join-Path $dir "$Name-data$i.vhdx"
        New-VHD -Path $path -SizeBytes ($gb * 1GB) -Dynamic | Out-Null
        Add-VMHardDiskDrive -VM $vm -Path $path
        $i++
    }
    $dvd = Add-VMDvdDrive -VM $vm -Path $Iso -Passthru
    Set-VMFirmware -VM $vm -FirstBootDevice $dvd
    if ($Tpm) {                                   # Windows 11 requirement
        Set-VMKeyProtector -VM $vm -NewLocalKeyProtector
        Enable-VMTPM -VM $vm
    }
    Write-Host "Created $Name"
}

foreach ($name in $Lab.Servers.Keys | Sort-Object) {
    $s = $Lab.Servers[$name]
    New-LabVm -Name $name -MemoryGB $s.MemoryGB -Cpu $s.Cpu -OsDiskGB $s.OsDiskGB `
        -ExtraDisksGB $s.ExtraDisksGB -Iso $ServerIso
}
if ($ClientIso) {
    $c = $Lab.Client
    New-LabVm -Name $c.Name -MemoryGB $c.MemoryGB -Cpu $c.Cpu -OsDiskGB $c.DiskGB -Iso $ClientIso -Tpm
}

Write-Host "`nNext: start the VMs, install Windows (docs/02-vm-build.md), then run Publish-LabScripts.ps1."
