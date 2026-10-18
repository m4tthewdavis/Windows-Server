#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Builds the OU tree, department groups, share-permission groups and service accounts. Enables the AD Recycle Bin.
.DESCRIPTION
    Uses AGDLP: Accounts -> Global groups (GG-<Dept>) -> Domain Local groups (SH-<Dept>-RW/RO) -> Permissions.
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"
$root = (Get-ADDomain).DistinguishedName
$base = "OU=$($Lab.Domain.BaseOU),$root"

function Ensure-OU($name, $path) {
    $dn = "OU=$name,$path"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess($dn, 'Create OU')) { New-ADOrganizationalUnit -Name $name -Path $path -ProtectedFromAccidentalDeletion $true }
    }
    $dn
}

$null = Ensure-OU $Lab.Domain.BaseOU $root
$usersOU   = Ensure-OU 'Users'    $base
$compOU    = Ensure-OU 'Computers' $base
$groupsOU  = Ensure-OU 'Groups'   $base
$null      = Ensure-OU 'ServiceAccounts' $base
$null      = Ensure-OU 'Disabled' $base
$null      = Ensure-OU 'Servers'      $compOU
$null      = Ensure-OU 'Workstations' $compOU

foreach ($dept in $Lab.Domain.Departments) {
    $null = Ensure-OU $dept $usersOU
    $defs = @(
        @{ Name = ($Lab.Provisioning.DefaultGroupFmt -f $dept); Scope = 'Global';      Desc = "$dept department members" }
        @{ Name = "SH-$dept-RW"; Scope = 'DomainLocal'; Desc = "Modify on \\FS01\$dept" }
        @{ Name = "SH-$dept-RO"; Scope = 'DomainLocal'; Desc = "Read-only on \\FS01\$dept" }
    )
    foreach ($g in $defs) {
        if (-not (Get-ADGroup -Filter "Name -eq '$($g.Name)'" -ErrorAction SilentlyContinue) -and
            $PSCmdlet.ShouldProcess($g.Name, 'Create group')) {
            New-ADGroup -Name $g.Name -GroupScope $g.Scope -GroupCategory Security -Path $groupsOU -Description $g.Desc
        }
    }
    # GG-<Dept> is nested into SH-<Dept>-RW
    if ($PSCmdlet.ShouldProcess("SH-$dept-RW", "Add GG-$dept")) {
        Add-ADGroupMember -Identity "SH-$dept-RW" -Members ($Lab.Provisioning.DefaultGroupFmt -f $dept) -ErrorAction SilentlyContinue
    }
}

# Everybody-group for the Public share, plus a helpdesk group allowed to reset passwords in Users
foreach ($n in 'GG-AllStaff', 'GG-Helpdesk') {
    if (-not (Get-ADGroup -Filter "Name -eq '$n'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $n -GroupScope Global -GroupCategory Security -Path $groupsOU
    }
}
# Delegate password reset + unlock to Helpdesk on the Users OU only (least privilege)
if ($PSCmdlet.ShouldProcess($usersOU, 'Delegate password reset to GG-Helpdesk')) {
    dsacls $usersOU /I:S /G "$($Lab.Domain.NetBios)\GG-Helpdesk:CA;Reset Password;user" "$($Lab.Domain.NetBios)\GG-Helpdesk:WP;lockoutTime;user" | Out-Null
}

# DHCP DNS-update service account (used by 03-Configure-DHCP.ps1)
if (-not (Get-ADUser -Filter "SamAccountName -eq 'svc-dhcp'")) {
    $pw = Read-Host -AsSecureString 'Password for svc-dhcp'
    New-ADUser -Name 'svc-dhcp' -SamAccountName 'svc-dhcp' -Path "OU=ServiceAccounts,$base" `
        -AccountPassword $pw -PasswordNeverExpires $true -CannotChangePassword $true -Enabled $true `
        -Description 'DHCP DNS dynamic update credentials'
}

# Recycle Bin makes accidental deletions recoverable (see docs/08). Irreversible, forest-wide.
$rb = Get-ADOptionalFeature -Filter "Name -eq 'Recycle Bin Feature'"
if (-not $rb.EnabledScopes -and $PSCmdlet.ShouldProcess('Forest', 'Enable AD Recycle Bin')) {
    Enable-ADOptionalFeature 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target (Get-ADForest).Name -Confirm:$false
}
Get-ADOrganizationalUnit -Filter * -SearchBase $base | Sort-Object DistinguishedName | Format-Table Name, DistinguishedName -AutoSize
