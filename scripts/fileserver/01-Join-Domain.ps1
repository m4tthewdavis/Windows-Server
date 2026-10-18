#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Joins this member server to the lab domain and places it in OU=Servers. Reboots.
#>
[CmdletBinding(SupportsShouldProcess)]
param([pscredential]$Credential = (Get-Credential -Message 'Domain admin (LAB\Administrator)'))
$ErrorActionPreference = 'Stop'
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"
$dn = (($Lab.Domain.Name.Split('.') | ForEach-Object { "DC=$_" }) -join ',')
$ou = "OU=Servers,OU=Computers,OU=$($Lab.Domain.BaseOU),$dn"
if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Join $($Lab.Domain.Name)")) {
    Add-Computer -DomainName $Lab.Domain.Name -OUPath $ou -Credential $Credential -Restart
}
