# Windows Server 2025 Virtual Lab

A reproducible, script-driven Windows Server 2025 environment on Hyper-V:
**Active Directory · DNS · DHCP · Group Policy · NTFS file shares · Backup & Restore · PowerShell user provisioning.**

Every build step is documented in [`docs/`](docs/) and automated in [`scripts/`](scripts/). Environment values
(domain, IPs, scope, drive letters) live in one file, [`config/lab.psd1`](config/lab.psd1).

## Topology

```
                Hyper-V host (Windows 11/Server, Hyper-V role)
                 vEthernet (LabSwitch) 10.10.10.1  ── NAT ──> Internet
                              │
        ┌─────────────────────┼──────────────────────┐
   DC01 10.10.10.10      FS01 10.10.10.20       CLIENT01 (DHCP .100-.200)
   AD DS · DNS · DHCP    File server · FSRM     Windows 11, domain-joined
   Group Policy · WSB    Shadow copies · WSB    receives GPOs, maps shares
```

Domain `lab.test` (NetBIOS `LAB`). `.test` is reserved by RFC 2606, so it cannot collide with real DNS.

See [how the pieces interact](docs/architecture-diagram.md) for diagrams of the services, permissions, provisioning flow and build dependencies.

## Build order

| # | Doc | Script (run where) |
|---|-----|--------------------|
| 0 | [Architecture & design decisions](docs/00-architecture.md) | – |
| 1 | [Hyper-V host & VMs](docs/01-hyperv-host.md) | `scripts/host/New-LabHost.ps1` (host) |
| 2 | [Install Windows, first-boot config](docs/02-vm-build.md) | `scripts/host/Publish-LabScripts.ps1` (host), `scripts/common/Initialize-Server.ps1` (guests) |
| 3 | [Active Directory](docs/03-active-directory.md) | `scripts/dc/01-Install-ADDS.ps1`, `scripts/common/Initialize-BackupDisk.ps1`, `04-New-OUStructure.ps1` (DC01) |
| 4 | [DNS](docs/04-dns.md) | `scripts/dc/02-Configure-DNS.ps1` (DC01) |
| 5 | [DHCP](docs/05-dhcp.md) | `scripts/dc/03-Configure-DHCP.ps1` (DC01) |
| 6 | [Group Policy](docs/06-group-policy.md) | `scripts/dc/05-Configure-GroupPolicy.ps1` (DC01) |
| 7 | [NTFS file shares](docs/07-file-shares.md) | `scripts/fileserver/01-…`, `02-…` (FS01) |
| 8 | [Backup & restore](docs/08-backup-restore.md) | `scripts/backup/01-Configure-Backup.ps1`, `02-Restore-Lab.ps1` |
| 9 | [User provisioning automation](docs/09-user-provisioning.md) | `scripts/provisioning/New-LabUser.ps1`, `Disable-LabUser.ps1` |
| 10 | [Validation & troubleshooting](docs/10-validation-troubleshooting.md) | `scripts/validation/Test-Lab.ps1` |

Note the order inside step 3: `04-New-OUStructure.ps1` must run before the GPO, DHCP service-account and file-share steps,
because they depend on the OUs and groups it creates. The numeric prefixes are per-folder; docs give the exact sequence.

## Requirements

* Windows host with Hyper-V, ≥ 16 GB RAM, ≈ 400 GB free disk, virtualization enabled in firmware.
* Windows Server 2025 ISO (the free 180-day evaluation works) and optionally a Windows 11 ISO.
* PowerShell 5.1 (Windows PowerShell) – the AD/DHCP/DNS/GPO modules ship with it.

## Safety and secrets

* No passwords are stored in the repo. DSRM and service-account passwords are prompted for; user passwords are random per user.
* The provisioning password report is written with a restricted ACL and must be deleted after hand-off.
* This is a lab. Review settings (SMB encryption, password policy, firewall) before reusing anything in production.

## Status

The scripts were authored without access to a Windows host and have **not yet been executed end to end**. Run each with `-WhatIf` first
(where supported), snapshot VMs between stages (`Checkpoint-VM`), and use `scripts/validation/Test-Lab.ps1` after each stage.
