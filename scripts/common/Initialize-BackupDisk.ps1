#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Initializes the first RAW disk as the backup volume (default E:). Needed on DC01 before GPO/backup steps.
    (FS01 does this inside 02-Configure-FileShares.ps1.)
#>
[CmdletBinding(SupportsShouldProcess)]
param([string]$DriveLetter = 'E', [string]$Label = 'Backup')
$ErrorActionPreference = 'Stop'
if (Test-Path "${DriveLetter}:\") { Write-Host "${DriveLetter}: already present"; return }
$disk = Get-Disk | Where-Object PartitionStyle -eq 'RAW' | Sort-Object Number | Select-Object -First 1
if (-not $disk) { throw 'No RAW disk found.' }
if ($PSCmdlet.ShouldProcess("Disk $($disk.Number)", "Format as ${DriveLetter}:")) {
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT
    New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $DriveLetter |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel $Label -Confirm:$false | Out-Null
}
