#Requires -RunAsAdministrator
#Requires -Modules DnsServer
<#
.SYNOPSIS
    DNS hardening and zones: forwarders, reverse zone, secure dynamic updates, scavenging, static records.
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"
$zone = $Lab.Domain.Name
$octets = $Lab.Network.Subnet.Split('.')
$reverseZone = "$($octets[2]).$($octets[1]).$($octets[0]).in-addr.arpa"   # /24 only

if ($PSCmdlet.ShouldProcess('DNS', 'Configure')) {
    Set-DnsServerForwarder -IPAddress $Lab.Network.Forwarders -PassThru | Out-Null

    if (-not (Get-DnsServerZone -Name $reverseZone -ErrorAction SilentlyContinue)) {
        Add-DnsServerPrimaryZone -NetworkId "$($Lab.Network.Subnet)/$($Lab.Network.PrefixLength)" -ReplicationScope Domain
    }
    Set-DnsServerPrimaryZone -Name $zone        -DynamicUpdate Secure
    Set-DnsServerPrimaryZone -Name $reverseZone -DynamicUpdate Secure

    # Scavenge stale dynamic records (DHCP clients come and go)
    Set-DnsServerScavenging -ScavengingState $true -ScavengingInterval 7.00:00:00 `
        -RefreshInterval 7.00:00:00 -NoRefreshInterval 7.00:00:00 -ApplyOnAllZones
    Set-DnsServerZoneAging -Name $zone        -Aging $true
    Set-DnsServerZoneAging -Name $reverseZone -Aging $true

    # Static A + PTR for infrastructure that must not move
    foreach ($name in $Lab.Servers.Keys) {
        $ip = $Lab.Servers[$name].IP
        if (-not (Get-DnsServerResourceRecord -ZoneName $zone -Name $name -RRType A -ErrorAction SilentlyContinue)) {
            Add-DnsServerResourceRecordA -ZoneName $zone -Name $name -IPv4Address $ip -CreatePtr
        }
    }
    Add-DnsServerResourceRecordCName -ZoneName $zone -Name 'files' -HostNameAlias "FS01.$zone" -ErrorAction SilentlyContinue
}

Get-DnsServerZone | Format-Table ZoneName, ZoneType, DynamicUpdate, IsReverseLookupZone -AutoSize
