# 03 – Active Directory

## 3.1 Promote DC01 (new forest)

On DC01:
```powershell
C:\Lab\scripts\dc\01-Install-ADDS.ps1 -WhatIf
C:\Lab\scripts\dc\01-Install-ADDS.ps1        # prompts for the DSRM password; server reboots
```
It installs `AD-Domain-Services` + `DNS` and runs `Install-ADDSForest` for `lab.test` (NetBIOS `LAB`), with database, logs and SYSVOL on the default paths.
**Record the DSRM password** – it is required for the restore procedure in doc 08.

After reboot sign in as `LAB\Administrator`.

## 3.2 Backup volume (DC01)

Initialize DC01's second disk as `E:` (used for GPO exports and backups):
```powershell
C:\Lab\scripts\common\Initialize-BackupDisk.ps1
```

## 3.3 OU tree, groups, delegation, Recycle Bin

```powershell
C:\Lab\scripts\dc\04-New-OUStructure.ps1 -WhatIf
C:\Lab\scripts\dc\04-New-OUStructure.ps1     # prompts for the svc-dhcp password
```
Creates:
* `OU=Corp` with `Users\{IT,HR,Finance,Sales}`, `Computers\{Servers,Workstations}`, `Groups`, `ServiceAccounts`, `Disabled`. All OUs are protected from accidental deletion.
* Groups `GG-<Dept>`, `SH-<Dept>-RW`, `SH-<Dept>-RO`, `GG-AllStaff`, `GG-Helpdesk` (AGDLP model).
* Delegation: `GG-Helpdesk` may reset passwords/unlock accounts in `OU=Users` only.
* `svc-dhcp` service account (for DHCP DNS registration).
* **AD Recycle Bin** enabled (irreversible, enables object-level restore – doc 08).

## Verify

```powershell
Get-ADDomain | Format-List DNSRoot, NetBIOSName, DomainMode
Get-ADDomainController | Format-List Name, IPv4Address, IsGlobalCatalog
dcdiag /q
Get-ADOrganizationalUnit -Filter * | Select Name, DistinguishedName
```
Checkpoint: `ad-built`.

## 3.4 Join the other machines

* FS01: `C:\Lab\scripts\fileserver\01-Join-Domain.ps1` (doc 07).
* CLIENT01: after DHCP (doc 05) it can join with `Add-Computer -DomainName lab.test -OUPath 'OU=Workstations,OU=Computers,OU=Corp,DC=lab,DC=test'`.
