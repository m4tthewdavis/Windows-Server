#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Prepares the data/backup disks on FS01, creates department/Public/Home shares with NTFS ACLs (AGDLP),
    access-based enumeration, FSRM quotas + file screens, and Shadow Copies ("Previous Versions").
.NOTES
    Run on FS01 after it has joined the domain and 04-New-OUStructure.ps1 has created the groups.
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"
$fs = $Lab.FileServer
$nb = $Lab.Domain.NetBios
$root = $fs.ShareRoot

Install-WindowsFeature FS-FileServer, FS-Resource-Manager, FS-DFS-Namespace -IncludeManagementTools | Out-Null

# --- Disks: first raw disk -> data volume, second -> backup volume --------------------------
$labels = @(@{ Letter = $fs.DataDrive.TrimEnd(':'); Label = 'Data' }, @{ Letter = $fs.BackupDrive.TrimEnd(':'); Label = 'Backup' })
$raw = @(Get-Disk | Where-Object PartitionStyle -eq 'RAW' | Sort-Object Number)
for ($i = 0; $i -lt [Math]::Min($raw.Count, 2); $i++) {
    if ($PSCmdlet.ShouldProcess("Disk $($raw[$i].Number)", "Initialize as $($labels[$i].Label)")) {
        Initialize-Disk -Number $raw[$i].Number -PartitionStyle GPT
        New-Partition -DiskNumber $raw[$i].Number -UseMaximumSize -DriveLetter $labels[$i].Letter |
            Format-Volume -FileSystem NTFS -NewFileSystemLabel $labels[$i].Label -Confirm:$false | Out-Null
    }
}

# --- Folder tree ----------------------------------------------------------------------------
$folders = @("$root\Departments", "$root\Public", "$root\Home") +
           ($Lab.Domain.Departments | ForEach-Object { "$root\Departments\$_" })
foreach ($f in $folders) { New-Item $f -ItemType Directory -Force | Out-Null }

# --- NTFS: break inheritance, then grant only what is needed --------------------------------
function Set-Ntfs {
    param([string]$Path, [string[]]$Grants)    # each grant is an icacls "identity:(flags)" string
    icacls $Path /inheritance:r | Out-Null
    foreach ($g in $Grants) { icacls $Path /grant:r $g | Out-Null }
}
$admins = @('SYSTEM:(OI)(CI)F', 'Administrators:(OI)(CI)F')

foreach ($dept in $Lab.Domain.Departments) {
    $p = "$root\Departments\$dept"
    Set-Ntfs $p ($admins + "${nb}\SH-$dept-RW:(OI)(CI)M" + "${nb}\SH-$dept-RO:(OI)(CI)RX")
}
Set-Ntfs "$root\Departments" ($admins + "${nb}\Domain Users:(RX)")      # traverse/list only, no inheritance
Set-Ntfs "$root\Public"     ($admins + "${nb}\GG-AllStaff:(OI)(CI)M")
# Home root: users can see only the container; each home folder is locked down at provisioning time
Set-Ntfs "$root\Home"       ($admins + "${nb}\Domain Users:(RD,RA)")

# --- SMB shares: share permission is broad, NTFS is the real gate; ABE hides what you can't open ----
$shares = @(
    @{ Name = 'Departments'; Path = "$root\Departments" }
    @{ Name = 'Public';      Path = "$root\Public" }
    @{ Name = 'Home$';       Path = "$root\Home" }
)
foreach ($s in $shares) {
    if (-not (Get-SmbShare -Name $s.Name -ErrorAction SilentlyContinue) -and $PSCmdlet.ShouldProcess($s.Name, 'Create share')) {
        New-SmbShare -Name $s.Name -Path $s.Path -FolderEnumerationMode AccessBased `
            -FullAccess 'Administrators' -ChangeAccess "${nb}\Domain Users" -EncryptData $true | Out-Null
    }
}

# --- FSRM: home quotas and file screening ---------------------------------------------------
if (-not (Get-FsrmQuotaTemplate -Name 'Home 5GB' -ErrorAction SilentlyContinue)) {
    New-FsrmQuotaTemplate -Name 'Home 5GB' -Size ($fs.HomeQuotaGB * 1GB) -SoftLimit:$false |
        Out-Null
}
# Auto-apply: every new folder under Home inherits the quota
if (-not (Get-FsrmAutoQuota -Path "$root\Home" -ErrorAction SilentlyContinue)) {
    New-FsrmAutoQuota -Path "$root\Home" -Template 'Home 5GB' | Out-Null
}
if (-not (Get-FsrmFileScreenTemplate -Name 'Block Executables+Media' -ErrorAction SilentlyContinue)) {
    New-FsrmFileScreenTemplate -Name 'Block Executables+Media' -Active:$true `
        -IncludeGroup @('Executable Files', 'Audio and Video Files') | Out-Null
}
foreach ($p in "$root\Public", "$root\Home") {
    if (-not (Get-FsrmFileScreen -Path $p -ErrorAction SilentlyContinue)) {
        New-FsrmFileScreen -Path $p -Template 'Block Executables+Media' | Out-Null
    }
}

# --- Shadow copies on the data volume (Previous Versions): 07:00 and 12:00 weekdays -----------
if ($PSCmdlet.ShouldProcess($fs.DataDrive, 'Enable shadow copies')) {
    vssadmin Resize ShadowStorage /For=$($fs.DataDrive) /On=$($fs.DataDrive) /MaxSize=15% | Out-Null
    foreach ($h in 7, 12) {
        $action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\vssadmin.exe' `
            -Argument "Create Shadow /For=$($fs.DataDrive)"
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Mon, Tue, Wed, Thu, Fri -At "$($h):00"
        Register-ScheduledTask -TaskName "ShadowCopy-$h" -Action $action -Trigger $trigger `
            -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
    }
}

Get-SmbShare | Where-Object Special -eq $false | Format-Table Name, Path, FolderEnumerationMode, EncryptData -AutoSize
