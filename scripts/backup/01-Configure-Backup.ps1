#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs Windows Server Backup and sets a nightly policy: DC01 = system state + bare metal; FS01 = data volume.
.DESCRIPTION
    Targets the dedicated backup VHDX volume (E:) added by New-LabHost.ps1. A volume target is not formatted
    or hidden, so files stay browsable. Also takes a first backup immediately. Run on each server.
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"
$time = $Lab.Backup.Schedule
Install-WindowsFeature Windows-Server-Backup | Out-Null

$isDc = (Get-CimInstance Win32_ComputerSystem).DomainRole -ge 4
$target = if ($isDc) { $Lab.Backup.DcBackupVolume } else { $Lab.Backup.FsBackupVolume }
if (-not (Test-Path "$target\")) { throw "Backup volume $target not found - run FS01 disk setup / initialize the disk first." }

if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Create backup policy')) {
    $policy = New-WBPolicy
    if ($isDc) {
        Add-WBSystemState -Policy $policy
        Add-WBBareMetalRecovery -Policy $policy
    } else {
        Add-WBVolume -Policy $policy -Volume (Get-WBVolume -VolumePath $Lab.FileServer.DataDrive)
        Add-WBSystemState -Policy $policy
    }
    Add-WBBackupTarget -Policy $policy -Target (New-WBBackupTarget -VolumePath $target)
    Set-WBSchedule -Policy $policy -Schedule ([datetime]::ParseExact($time, 'HH:mm', $null))
    Set-WBVssBackupOptions -Policy $policy -VssCopyBackup:$false
    Set-WBPolicy -Policy $policy -Force

    Write-Host 'Starting first backup (this can take several minutes)...'
    Start-WBBackup -Policy $policy
}
Get-WBSummary | Format-List LastSuccessfulBackupTime, NextBackupTime, LastBackupResultHR
