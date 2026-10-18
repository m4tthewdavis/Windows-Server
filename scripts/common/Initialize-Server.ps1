#Requires -RunAsAdministrator
<#
.SYNOPSIS
    First-boot configuration for a lab server: static IP, DNS client, computer name, time zone.
.EXAMPLE
    C:\Lab\scripts\common\Initialize-Server.ps1 -Name DC01      # reboots when the rename is applied
#>
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$Name)

$ErrorActionPreference = 'Stop'
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"
$srv = $Lab.Servers[$Name]
if (-not $srv) { throw "$Name is not defined in config/lab.psd1" }
$net = $Lab.Network

$nic = Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | Select-Object -First 1
if (-not $nic) { throw 'No connected network adapter found.' }

# DC01 points at itself for DNS (after promotion); everyone else points at the DC.
$dnsIp = $Lab.Servers.DC01.IP

if ($PSCmdlet.ShouldProcess($nic.Name, "Set IP $($srv.IP)")) {
    Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object PrefixOrigin -ne 'WellKnown' | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix '0.0.0.0/0' -Confirm:$false -ErrorAction SilentlyContinue
    New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress $srv.IP -PrefixLength $net.PrefixLength -DefaultGateway $net.Gateway | Out-Null
    Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $dnsIp
}

Set-TimeZone -Id 'UTC'

if ($env:COMPUTERNAME -ne $Name -and $PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Rename to $Name")) {
    Rename-Computer -NewName $Name -Force
    Write-Host 'Renamed - rebooting in 10 seconds.'
    Start-Sleep 10
    Restart-Computer -Force
}
