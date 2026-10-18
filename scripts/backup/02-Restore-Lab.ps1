#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Restore helpers. Modes: List | File | DeletedUser | Gpo.
.EXAMPLE
    .\02-Restore-Lab.ps1 -Mode List
    .\02-Restore-Lab.ps1 -Mode File -Source 'D:\Shares\Departments\Finance\Budget.xlsx' -RestoreTo 'D:\Restore'
    .\02-Restore-Lab.ps1 -Mode DeletedUser -Identity jane.doe
    .\02-Restore-Lab.ps1 -Mode Gpo -Identity 'LAB-Workstation-Baseline'
.NOTES
    A full AD system state restore needs Directory Services Restore Mode and is walked through in docs/08.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('List', 'File', 'DeletedUser', 'Gpo')][string]$Mode,
    [string]$Source,
    [string]$RestoreTo = 'D:\Restore',
    [string]$Identity,
    [string]$Version                # e.g. 10/18/2026-21:00 from -Mode List; defaults to the newest
)
$ErrorActionPreference = 'Stop'
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"

switch ($Mode) {
    'List' {
        wbadmin get versions
    }
    'File' {
        if (-not $Source) { throw '-Source is required for File mode.' }
        if (-not $Version) {
            $latest = Get-WBBackupSet | Sort-Object BackupTime -Descending | Select-Object -First 1
            $Version = $latest.VersionId
        }
        New-Item $RestoreTo -ItemType Directory -Force | Out-Null
        if ($PSCmdlet.ShouldProcess($Source, "Restore from version $Version to $RestoreTo")) {
            # Restores to an alternate location so the live file is never overwritten blindly
            wbadmin start recovery -version:$Version -itemType:File -items:$Source `
                -recoveryTarget:$RestoreTo -overwrite:Skip -quiet
        }
    }
    'DeletedUser' {
        if (-not $Identity) { throw '-Identity (sAMAccountName) is required.' }
        $obj = Get-ADObject -Filter "samAccountName -eq '$Identity'" -IncludeDeletedObjects -Properties lastKnownParent |
            Sort-Object whenChanged -Descending | Select-Object -First 1
        if (-not $obj -or -not $obj.Deleted) { throw "No deleted object found for $Identity." }
        if ($PSCmdlet.ShouldProcess($obj.DistinguishedName, 'Restore-ADObject')) {
            Restore-ADObject -Identity $obj.ObjectGUID    # group memberships and attributes return with it
            Write-Host "Restored $Identity to $($obj.lastKnownParent). Re-enable and reset password if needed."
        }
    }
    'Gpo' {
        if (-not $Identity) { throw '-Identity (GPO name) is required.' }
        if ($PSCmdlet.ShouldProcess($Identity, 'Restore-GPO')) {
            Restore-GPO -Name $Identity -Path $Lab.Backup.GpoBackupPath
        }
    }
}
