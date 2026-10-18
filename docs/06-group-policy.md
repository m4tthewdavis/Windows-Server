# 06 – Group Policy

Run after the OU tree exists (doc 03).

```powershell
C:\Lab\scripts\dc\05-Configure-GroupPolicy.ps1 -WhatIf
C:\Lab\scripts\dc\05-Configure-GroupPolicy.ps1
```

## Domain password and lockout policy (Default Domain Policy)

Min length 12, complexity on, history 24, max age 90 d, min age 1 d, lockout after 5 attempts for 30 min.

## GPOs created and linked

| GPO | Linked to | Settings |
|-----|-----------|----------|
| LAB-Workstation-Baseline | Computers\Workstations | Interactive idle lock 900 s (`InactivityTimeoutSecs`), AutoRun disabled |
| LAB-Server-Baseline | Computers\Servers | Security event log 1 GB, SMB server signing required |
| LAB-Finance-NoRemovableStorage | Users\Finance | User policy `Deny_All` for removable storage |

All GPOs are exported to `E:\GpoBackups` with `Backup-GPO` for restore (doc 08).

## Manual step: drive mapping (Group Policy Preferences)

1. `gpmc.msc` → edit `LAB-Workstation-Baseline` (or a new user GPO linked to `Users`).
2. User Configuration → Preferences → Windows Settings → Drive Maps → New Mapped Drive.
3. `H:` → `\\FS01\Home$\%username%`; `P:` → `\\FS01\Public`. Use **Item-level targeting** → Security Group `LAB\GG-Finance` etc. for department shares (`\\FS01\Departments\<Dept>`).

(Automating Drives.xml by hand-writing SYSVOL XML is fragile, so it is left as a GUI step.)

## Verify

On CLIENT01 (domain-joined, in `Workstations` OU), signed in as a lab user:
```powershell
gpupdate /force
gpresult /r /scope computer
Get-GPResultantSetOfPolicy -ReportType Html -Path C:\rsop.html     # or: gpresult /h C:\rsop.html
```
On DC01: `Get-GPOReport -All -ReportType Html -Path C:\gpo.html`; `Get-GPInheritance -Target 'OU=Workstations,OU=Computers,OU=Corp,DC=lab,DC=test'`.
