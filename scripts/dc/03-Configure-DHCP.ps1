#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs DHCP on DC01, authorizes it in AD, creates the LAN scope and options, and lets DHCP register DNS.
.PARAMETER DnsUpdateCredential
    A low-privilege account used by DHCP to write DNS records (avoids the "DHCP runs as DC" ownership problem).
#>
[CmdletBinding(SupportsShouldProcess)]
param([pscredential]$DnsUpdateCredential = (Get-Credential -Message 'DHCP DNS-update account (e.g. LAB\svc-dhcp)'))

$ErrorActionPreference = 'Stop'
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"
$d = $Lab.Dhcp
$dc = $Lab.Servers.DC01.IP
$fqdn = "DC01.$($Lab.Domain.Name)"

Install-WindowsFeature DHCP -IncludeManagementTools | Out-Null

if ($PSCmdlet.ShouldProcess($fqdn, 'Configure DHCP')) {
    # Creates DHCP Administrators / DHCP Users local groups and silences the Server Manager flag
    Add-DhcpServerSecurityGroup
    Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12' -Name ConfigurationState -Value 2 -ErrorAction SilentlyContinue
    Restart-Service DHCPServer

    if (-not (Get-DhcpServerInDC | Where-Object DnsName -eq $fqdn)) {
        Add-DhcpServerInDC -DnsName $fqdn -IPAddress $dc
    }

    if (-not (Get-DhcpServerv4Scope -ScopeId $d.ScopeId -ErrorAction SilentlyContinue)) {
        Add-DhcpServerv4Scope -Name $d.ScopeName -StartRange $d.StartRange -EndRange $d.EndRange `
            -SubnetMask $d.SubnetMask -LeaseDuration ([timespan]::FromDays($d.LeaseDays)) -State Active
    }
    Set-DhcpServerv4OptionValue -ScopeId $d.ScopeId -Router $Lab.Network.Gateway `
        -DnsServer $dc -DnsDomain $Lab.Domain.Name

    # DHCP registers A + PTR for clients, always, and cleans up on lease expiry
    Set-DhcpServerv4DnsSetting -ComputerName $fqdn -DynamicUpdates Always -DeleteDnsRROnLeaseExpiry $true
    Set-DhcpServerDnsCredential -Credential $DnsUpdateCredential -ComputerName $fqdn

    # Example reservation: keeps the client's address stable. Replace the MAC with the VM's real one.
    # Add-DhcpServerv4Reservation -ScopeId $d.ScopeId -IPAddress 10.10.10.101 -ClientId 00-15-5D-00-00-01 -Name CLIENT01
}

Get-DhcpServerv4Scope | Format-Table ScopeId, Name, StartRange, EndRange, State -AutoSize
Get-DhcpServerv4OptionValue -ScopeId $d.ScopeId | Format-Table Name, Value -AutoSize
