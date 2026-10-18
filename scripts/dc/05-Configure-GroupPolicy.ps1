#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory, GroupPolicy
<#
.SYNOPSIS
    Domain password/lockout policy plus baseline GPOs, linked to the right OUs, with a GPO backup.
.NOTES
    Drive-map preferences are easier in the GPMC GUI; see docs/06 for that one manual step.
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"
$domain = Get-ADDomain
$base = "OU=$($Lab.Domain.BaseOU),$($domain.DistinguishedName)"

if ($PSCmdlet.ShouldProcess($domain.DNSRoot, 'Set default domain password policy')) {
    Set-ADDefaultDomainPasswordPolicy -Identity $domain.DNSRoot `
        -MinPasswordLength 12 -ComplexityEnabled $true -PasswordHistoryCount 24 `
        -MaxPasswordAge 90.00:00:00 -MinPasswordAge 1.00:00:00 `
        -LockoutThreshold 5 -LockoutDuration 00:30:00 -LockoutObservationWindow 00:30:00
}

function Ensure-Gpo([string]$Name, [string]$Comment, [string]$TargetOU) {
    $gpo = Get-GPO -Name $Name -ErrorAction SilentlyContinue
    if (-not $gpo) { $gpo = New-GPO -Name $Name -Comment $Comment }
    if ((Get-GPInheritance -Target $TargetOU).GpoLinks.DisplayName -notcontains $Name) {
        New-GPLink -Name $Name -Target $TargetOU -LinkEnabled Yes | Out-Null
    }
    $gpo
}

if ($PSCmdlet.ShouldProcess('GPOs', 'Create and link')) {
    # --- Workstations: lock the session after 15 min idle, disable AutoRun ---
    $ws = Ensure-Gpo 'LAB-Workstation-Baseline' 'Idle lock, AutoRun off' "OU=Workstations,OU=Computers,$base"
    Set-GPRegistryValue -Name $ws.DisplayName -Key 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
        -ValueName InactivityTimeoutSecs -Type DWord -Value 900 | Out-Null
    Set-GPRegistryValue -Name $ws.DisplayName -Key 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' `
        -ValueName NoDriveTypeAutoRun -Type DWord -Value 255 | Out-Null

    # --- Servers: keep logs long enough to investigate, SMB signing required ---
    $sv = Ensure-Gpo 'LAB-Server-Baseline' 'Event log size, SMB signing' "OU=Servers,OU=Computers,$base"
    Set-GPRegistryValue -Name $sv.DisplayName -Key 'HKLM\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security' `
        -ValueName MaxSize -Type DWord -Value 1048576 | Out-Null          # KB = 1 GB
    Set-GPRegistryValue -Name $sv.DisplayName -Key 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' `
        -ValueName RequireSecuritySignature -Type DWord -Value 1 | Out-Null

    # --- Finance users: no removable storage (data-leak control) ---
    $fin = Ensure-Gpo 'LAB-Finance-NoRemovableStorage' 'Deny all removable storage' "OU=Finance,OU=Users,$base"
    Set-GPRegistryValue -Name $fin.DisplayName -Key 'HKCU\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices' `
        -ValueName Deny_All -Type DWord -Value 1 | Out-Null
}

# Back every GPO up so it can be restored (docs/08)
$gpoBackup = $Lab.Backup.GpoBackupPath
if ($PSCmdlet.ShouldProcess($gpoBackup, 'Backup-GPO -All')) {
    New-Item $gpoBackup -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    Backup-GPO -All -Path $gpoBackup -Comment "Lab baseline $(Get-Date -f yyyy-MM-dd)" | Out-Null
}
Get-GPO -All | Format-Table DisplayName, GpoStatus, ModificationTime -AutoSize
