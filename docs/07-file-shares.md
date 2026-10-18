# 07 – NTFS file shares (FS01)

## 7.1 Join FS01 to the domain
Make sure FS01's DNS points to `10.10.10.10` (done by `Initialize-Server.ps1`).
```powershell
C:\Lab\scripts\fileserver\01-Join-Domain.ps1     # LAB\Administrator; reboots; lands in OU=Servers
```

## 7.2 Build disks, folders, ACLs, shares, quotas
```powershell
C:\Lab\scripts\fileserver\02-Configure-FileShares.ps1 -WhatIf
C:\Lab\scripts\fileserver\02-Configure-FileShares.ps1
```

| Item | Result |
|------|--------|
| Disks | RAW disk 1 → `D:` Data, disk 2 → `E:` Backup (GPT, NTFS) |
| Tree | `D:\Shares\{Departments\{IT,HR,Finance,Sales},Public,Home}` |
| NTFS | Inheritance removed; `SYSTEM`/`Administrators` Full; `SH-<Dept>-RW` Modify; `SH-<Dept>-RO` Read & Execute |
| Shares | `Departments`, `Public`, `Home$`; share perm = Change for Domain Users (NTFS is the gate); **access-based enumeration** on; **SMB encryption** on |
| FSRM | Quota template *Home 5GB* auto-applied under `Home`; file screen blocks executables/media in `Public` and `Home` |
| VSS | Shadow copies of `D:` at 07:00 and 12:00 on weekdays (Previous Versions), 15 % storage cap |

Permission model: **share permissions broad, NTFS strict** – the effective access is the most restrictive of the two.
To give someone access, add them to the `GG-`/`SH-` group – never edit ACLs per user.

## Verify

```powershell
Get-SmbShare | ? Special -eq $false
icacls D:\Shares\Departments\Finance
Get-SmbShareAccess Departments
Get-FsrmAutoQuota
```
From CLIENT01 as a Finance user: `dir \\FS01\Departments` shows only `Finance` (ABE); opening `HR` is denied; `\\FS01\Public` is writable; copying an `.exe` to Public is blocked.
