# 08 – Backup and restore

Tool: **Windows Server Backup** (WSB). Targets are the dedicated `E:` volumes. Backups only protect you if restores are tested – do the drills below.

## 8.1 Configure backups (run on DC01 *and* FS01)
```powershell
C:\Lab\scripts\backup\01-Configure-Backup.ps1 -WhatIf
C:\Lab\scripts\backup\01-Configure-Backup.ps1      # sets 21:00 nightly policy and runs a first backup
```
| Server | Contents |
|--------|----------|
| DC01 | System State (AD DB, SYSVOL, registry) + bare-metal recovery |
| FS01 | `D:` data volume + System State |

GPO exports were already written to `E:\GpoBackups` (doc 06). Re-run `Backup-GPO -All` after policy changes (or schedule it).
Copy `E:\` off the VM (e.g. to the host via `Copy-VMFile` or a share) to survive loss of the VHDX.

## 8.2 Restore drills

### A. Single file / folder (FS01)
Users can self-serve via **Previous Versions** (shadow copies). For backup restores:
```powershell
.\02-Restore-Lab.ps1 -Mode List
.\02-Restore-Lab.ps1 -Mode File -Source 'D:\Shares\Departments\Finance\Budget.xlsx' -RestoreTo D:\Restore
```
Restores to an alternate location by default; copy back after reviewing.

### B. Deleted AD object (AD Recycle Bin – no downtime)
```powershell
Remove-ADUser alice.nguyen -Confirm:$false          # simulate the accident
.\02-Restore-Lab.ps1 -Mode DeletedUser -Identity alice.nguyen
```
Group memberships and attributes come back. Works within the deleted-object lifetime (default 180 days).

### C. Deleted/corrupted GPO
```powershell
.\02-Restore-Lab.ps1 -Mode Gpo -Identity LAB-Workstation-Baseline
```

### D. Full AD restore from System State (single-DC disaster)
Use only when the AD database is lost or corrupt and there is no other DC.
1. Reboot into **Directory Services Restore Mode**: `bcdedit /set safeboot dsrepair` then `shutdown /r /t 0` (log in as `.\Administrator` with the **DSRM password**).
2. List versions and restore:
   ```powershell
   wbadmin get versions
   wbadmin start systemstaterecovery -version:<MM/DD/YYYY-HH:MM> -backupTarget:E: -quiet
   ```
3. For an **authoritative** restore of a single OU/object (e.g. mass deletion with multiple DCs), before rebooting:
   ```
   ntdsutil "activate instance ntds" "authoritative restore" "restore subtree OU=Sales,OU=Users,OU=Corp,DC=lab,DC=test" q q
   ```
4. Leave DSRM: `bcdedit /deletevalue safeboot`, reboot. Validate with `dcdiag`, `repadmin /replsummary`, and `Test-Lab.ps1`.

With multiple DCs, a non-authoritative restore followed by replication is the norm. In this single-DC lab, either way, test it on a checkpointed VM first.

### E. Bare metal
Boot the Server ISO → Repair → Troubleshoot → System Image Recovery, pointing at the attached backup VHDX.

## Verify
```powershell
Get-WBSummary; Get-WBBackupSet | ft VersionId, BackupTime, BackupTarget
Get-WBJob -Previous 1
```
Record each drill's date, RTO and outcome in a table so you can show it works.
