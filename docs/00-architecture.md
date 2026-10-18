# 00 – Architecture & design decisions

## Components

| Host | Role | OS | RAM/CPU | Disks | IP |
|------|------|----|---------|-------|----|
| Hyper-V host | Hypervisor, NAT gateway | Win 11 Pro / Server | – | – | 10.10.10.1 |
| DC01 | AD DS, DNS, DHCP, GPO management, WSB | Server 2025 (Desktop Experience) | 4 GB / 2 | 60 GB OS, 60 GB backup | 10.10.10.10 |
| FS01 | File server, FSRM, VSS, WSB | Server 2025 | 4 GB / 2 | 60 GB OS, 100 GB data (D:), 100 GB backup (E:) | 10.10.10.20 |
| CLIENT01 | Test workstation | Windows 11 | 4 GB / 2 | 64 GB | DHCP |

## Key decisions

* **Internal switch + host NAT** – isolated from the physical LAN so lab DHCP can never answer real clients, yet guests still reach the internet for updates.
* **Separate DC and file server** – file services never run on a DC (smaller attack surface, simpler restore).
* **DHCP co-located on DC01** – acceptable in a lab; in production use two DHCP servers with DHCP failover.
* **AGDLP permissions** – users → global groups (`GG-<Dept>`) → domain-local groups (`SH-<Dept>-RW/RO`) → NTFS ACLs. Access changes are group-membership changes, never ACL edits.
* **Dedicated backup VHDX per server** – Windows Server Backup needs a separate volume; copy backups off the host for a real 3-2-1 posture.
* **Config as data** – `config/lab.psd1` is the only place with names/IPs, so the lab can be rebuilt with different values.
* **Static infra, dynamic clients** – servers use static IPs (.10, .20); DHCP serves .100–.200 so the first 99 addresses are free for statics and reservations.

## Naming

* OUs: `OU=Corp` → `Users\<Dept>`, `Computers\{Servers,Workstations}`, `Groups`, `ServiceAccounts`, `Disabled`.
* Users: `first.last` (numeric suffix on collision), UPN `first.last@lab.test`.
* GPOs: `LAB-<Scope>-<Purpose>`.
