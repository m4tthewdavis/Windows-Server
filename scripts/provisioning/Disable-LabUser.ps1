#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Offboarding: disable the account, strip group memberships, move to OU=Disabled, stamp the description.
.DESCRIPTION
    The home folder is retained (not deleted) so data can be reviewed or restored; delete it manually after
    the retention period. Supports -WhatIf.
.EXAMPLE
    .\Disable-LabUser.ps1 -Identity alice.nguyen -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param([Parameter(Mandatory, ValueFromPipeline)][string[]]$Identity)
begin {
    $ErrorActionPreference = 'Stop'
    $Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"
    $disabledOU = "OU=Disabled,OU=$($Lab.Domain.BaseOU),$((Get-ADDomain).DistinguishedName)"
}
process {
    foreach ($id in $Identity) {
        $user = Get-ADUser -Identity $id -Properties MemberOf, Description
        if ($PSCmdlet.ShouldProcess($user.SamAccountName, 'Disable, remove groups, move to Disabled')) {
            Disable-ADAccount -Identity $user
            foreach ($g in $user.MemberOf) { Remove-ADGroupMember -Identity $g -Members $user -Confirm:$false }
            Set-ADUser -Identity $user -Description "Disabled $(Get-Date -f yyyy-MM-dd) by $env:USERNAME (was: $($user.Description))"
            Move-ADObject -Identity $user.DistinguishedName -TargetPath $disabledOU
            Write-Host "Offboarded $($user.SamAccountName)"
        }
    }
}
