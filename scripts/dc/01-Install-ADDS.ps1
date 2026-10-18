#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs AD DS + DNS and promotes DC01 to the first domain controller of a new forest.
.NOTES
    Prompts for the DSRM (Directory Services Restore Mode) password. Store it in a vault: you need it
    for system state restores (docs/08). The server reboots automatically at the end.
#>
[CmdletBinding(SupportsShouldProcess)]
param([securestring]$SafeModePassword = (Read-Host -AsSecureString 'DSRM (safe mode) password'))

$ErrorActionPreference = 'Stop'
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"

if ($env:COMPUTERNAME -ne 'DC01') { throw 'Run this on DC01.' }

Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools | Out-Null

if ($PSCmdlet.ShouldProcess($Lab.Domain.Name, 'Create AD forest')) {
    Install-ADDSForest `
        -DomainName $Lab.Domain.Name `
        -DomainNetbiosName $Lab.Domain.NetBios `
        -ForestMode WinThreshold -DomainMode WinThreshold `
        -InstallDns `
        -DatabasePath 'C:\Windows\NTDS' -LogPath 'C:\Windows\NTDS' -SysvolPath 'C:\Windows\SYSVOL' `
        -SafeModeAdministratorPassword $SafeModePassword `
        -NoRebootOnCompletion:$false -Force
}
# Windows Server 2025 introduces a new functional level (Win2025), but WinThreshold keeps
# the lab compatible with older test DCs. Raise it later with Set-ADForestMode if desired.
