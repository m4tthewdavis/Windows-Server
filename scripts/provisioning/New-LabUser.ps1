#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Bulk-provisions users from a CSV: AD account, OU placement, group membership, home folder, ACLs, quota, report.
.DESCRIPTION
    For each CSV row (FirstName, LastName, Department, Title, Manager, Phone):
      1. Validates the row (department must exist in config/lab.psd1; names non-empty)
      2. Builds a unique sAMAccountName (first.last, then first.last2 ...) and UPN
      3. Creates the account in OU=<Dept>,OU=Users,OU=Corp with a random password, change-at-logon
      4. Adds the user to GG-<Dept> and GG-AllStaff
      5. Creates \\FS01\Home$\<sam>, sets the HomeDirectory/HomeDrive and grants only the user + admins
      6. Appends an audit log line and writes a one-time password report
    Safe to re-run: users that already exist (same name + department) are skipped.
    Supports -WhatIf so a CSV can be dry-run first.
.EXAMPLE
    .\New-LabUser.ps1 -CsvPath C:\Lab\data\new-hires.sample.csv -WhatIf
    .\New-LabUser.ps1 -CsvPath C:\Lab\data\new-hires.sample.csv
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path $_ -PathType Leaf })][string]$CsvPath,
    [string]$HomeDrive = 'H:'
)
$ErrorActionPreference = 'Stop'
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"
$prov = $Lab.Provisioning
$domain = Get-ADDomain
$base = "OU=$($Lab.Domain.BaseOU),$($domain.DistinguishedName)"
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

foreach ($p in $prov.OutputPath, $prov.LogPath) { New-Item $p -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $prov.LogPath "provision-$stamp.log"
function Write-Log([string]$Level, [string]$Message) {
    $line = '{0:u} [{1}] {2}' -f (Get-Date), $Level, $Message
    Add-Content -Path $logFile -Value $line
    if ($Level -eq 'ERROR') { Write-Warning $Message } else { Write-Verbose $Message }
}

# Cryptographically random password that always satisfies complexity (upper/lower/digit/symbol)
function New-RandomPassword([int]$Length) {
    $sets = 'ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!@#$%^&*-_=+'
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    function Pick([string]$chars) {
        $b = [byte[]]::new(4); $rng.GetBytes($b)
        $chars[[int]([BitConverter]::ToUInt32($b, 0) % $chars.Length)]
    }
    $chars = foreach ($s in $sets) { Pick $s }                       # one of each class
    $chars += 1..($Length - $sets.Count) | ForEach-Object { Pick ($sets -join '') }
    # Fisher-Yates shuffle with the same RNG
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $b = [byte[]]::new(4); $rng.GetBytes($b)
        $j = [int]([BitConverter]::ToUInt32($b, 0) % ($i + 1))
        $chars[$i], $chars[$j] = $chars[$j], $chars[$i]
    }
    -join $chars
}

function Get-UniqueSam([string]$First, [string]$Last) {
    $clean = { param($s) ($s.ToLower() -replace '[^a-z0-9]', '') }
    $stem = '{0}.{1}' -f (& $clean $First), (& $clean $Last)
    if ($stem.Length -gt 18) { $stem = $stem.Substring(0, 18) }     # leave room for a numeric suffix (20-char limit)
    $sam = $stem; $n = 1
    while (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        $n++; $sam = "$stem$n"
    }
    $sam
}

$rows = Import-Csv $CsvPath
$required = 'FirstName', 'LastName', 'Department'
$report = [System.Collections.Generic.List[object]]::new()
$summary = @{ Created = 0; Skipped = 0; Failed = 0 }

foreach ($row in $rows) {
    $display = "$($row.FirstName) $($row.LastName)".Trim()
    try {
        foreach ($f in $required) { if ([string]::IsNullOrWhiteSpace($row.$f)) { throw "Missing required field '$f'" } }
        if ($Lab.Domain.Departments -notcontains $row.Department) {
            throw "Unknown department '$($row.Department)' (valid: $($Lab.Domain.Departments -join ', '))"
        }
        $ou = "OU=$($row.Department),OU=Users,$base"

        # Idempotency: same display name in the same OU = already provisioned
        if (Get-ADUser -Filter "Name -eq '$($display -replace "'", "''")'" -SearchBase $ou -ErrorAction SilentlyContinue) {
            Write-Log 'SKIP' "$display already exists in $($row.Department)"
            $summary.Skipped++; continue
        }

        $sam = Get-UniqueSam $row.FirstName $row.LastName
        $upn = "$sam@$($domain.DNSRoot)"
        $password = New-RandomPassword $prov.PasswordLength
        $homePath = Join-Path $prov.HomeUncRoot $sam

        if ($PSCmdlet.ShouldProcess("$display ($sam)", "Create user in $($row.Department)")) {
            $params = @{
                Name = $display; GivenName = $row.FirstName; Surname = $row.LastName; DisplayName = $display
                SamAccountName = $sam; UserPrincipalName = $upn; Path = $ou
                Department = $row.Department; Title = $row.Title; OfficePhone = $row.Phone
                AccountPassword = (ConvertTo-SecureString $password -AsPlainText -Force)
                ChangePasswordAtLogon = $true; Enabled = $true
                HomeDirectory = $homePath; HomeDrive = $HomeDrive
            }
            foreach ($k in 'Title', 'OfficePhone') { if ([string]::IsNullOrWhiteSpace($params[$k])) { $params.Remove($k) } }   # empty strings are rejected by AD
            if ($row.Manager) {
                $mgr = Get-ADUser -Filter "SamAccountName -eq '$($row.Manager)'" -ErrorAction SilentlyContinue
                if ($mgr) { $params.Manager = $mgr.DistinguishedName } else { Write-Log 'WARN' "Manager '$($row.Manager)' not found for $sam" }
            }
            New-ADUser @params

            foreach ($g in ($prov.DefaultGroupFmt -f $row.Department), 'GG-AllStaff') {
                Add-ADGroupMember -Identity $g -Members $sam
            }

            # Home folder: owner + full control for the user, Administrators/SYSTEM; nothing inherited
            New-Item -ItemType Directory -Path $homePath -Force | Out-Null
            $acl = Get-Acl $homePath
            $acl.SetAccessRuleProtection($true, $false)
            $inherit = 'ContainerInherit,ObjectInherit'
            $rules = @(
                [Security.AccessControl.FileSystemAccessRule]::new("$($Lab.Domain.NetBios)\$sam", 'Modify', $inherit, 'None', 'Allow')
                [Security.AccessControl.FileSystemAccessRule]::new('BUILTIN\Administrators', 'FullControl', $inherit, 'None', 'Allow')
                [Security.AccessControl.FileSystemAccessRule]::new('NT AUTHORITY\SYSTEM', 'FullControl', $inherit, 'None', 'Allow')
            )
            $rules | ForEach-Object { $acl.AddAccessRule($_) }
            Set-Acl -Path $homePath -AclObject $acl

            Write-Log 'CREATE' "$sam ($display) dept=$($row.Department) home=$homePath"
            $report.Add([pscustomobject]@{
                SamAccountName = $sam; UserPrincipalName = $upn; DisplayName = $display
                Department = $row.Department; TemporaryPassword = $password; HomeFolder = $homePath
            })
            $summary.Created++
        }
    }
    catch {
        Write-Log 'ERROR' "$display : $($_.Exception.Message)"
        $summary.Failed++
    }
}

if ($report.Count -gt 0) {
    $out = Join-Path $prov.OutputPath "new-users-$stamp.csv"
    $report | Export-Csv $out -NoTypeInformation
    # Restrict the password report to the current user only; hand passwords over securely, then delete it.
    icacls $out /inheritance:r /grant:r "${env:USERDOMAIN}\${env:USERNAME}:(R,D)" | Out-Null
    Write-Host "Password report: $out  (delete after distribution)" -ForegroundColor Yellow
}
Write-Host ("Created: {0}  Skipped: {1}  Failed: {2}  Log: {3}" -f $summary.Created, $summary.Skipped, $summary.Failed, $logFile)
if ($summary.Failed) { exit 1 }
