# Glossary

Acronyms and abbreviations used in this project.

## Core services
| Term | Meaning |
|---|---|
| AD | Active Directory, the directory of users, computers and groups |
| AD DS | Active Directory Domain Services, the Windows role that provides AD |
| DC | Domain Controller, the server that runs AD (`DC01`) |
| DNS | Domain Name System, which turns names such as `fs01.lab.test` into IP addresses |
| DHCP | Dynamic Host Configuration Protocol, which hands out IP addresses to clients |
| GPO | Group Policy Object, a bundle of settings pushed to users or computers |
| GPMC | Group Policy Management Console (`gpmc.msc`) |
| FS | File Server (`FS01`) |
| SMB | Server Message Block, the protocol behind Windows file shares |
| NTFS | New Technology File System, the Windows file system whose permissions secure the shares |
| VM | Virtual Machine |

## Directory and naming
| Term | Meaning |
|---|---|
| OU | Organizational Unit, a folder in AD used to organize objects and link policies |
| NetBIOS | Network Basic Input/Output System, here the short legacy domain name `LAB` |
| UPN | User Principal Name, the `alice.nguyen@lab.test` style logon name |
| sAMAccountName | Security Accounts Manager name, the short logon name, e.g. `alice.nguyen` |
| FQDN | Fully Qualified Domain Name, e.g. `DC01.lab.test` |
| A / PTR / SRV / CNAME | DNS record types: name to IP, IP to name, service location, alias |
| SYSVOL / NETLOGON | Shared folders on a DC that distribute policies and logon scripts |
| DSRM | Directory Services Restore Mode, the special boot mode for restoring AD |
| GG | Global Group, the group type holding user accounts, e.g. `GG-Finance` |
| SH | Share, a domain-local group used to grant permissions on a share, e.g. `SH-Finance-RW` |
| RW / RO | Read-Write / Read-Only, used in the `SH-<Dept>-RW` and `-RO` group names |
| AGDLP | Accounts, Global groups, Domain Local groups, Permissions: the permission model |
| svc- | Prefix for a service account, e.g. `svc-dhcp` |

## Storage and file server
| Term | Meaning |
|---|---|
| ACL | Access Control List, the permissions list on a file or folder |
| ABE | Access-Based Enumeration, which hides files and folders from users who can't open them |
| FSRM | File Server Resource Manager, which provides quotas and file screens |
| VSS | Volume Shadow Copy Service, which provides the "Previous Versions" snapshots |
| VHDX | Virtual Hard Disk (v2), the virtual disk file format Hyper-V uses |
| GPT | GUID Partition Table, the disk partition style |
| RAW | An uninitialized disk |

## Backup
| Term | Meaning |
|---|---|
| WSB | Windows Server Backup |
| BMR | Bare Metal Recovery, a full restore onto empty hardware |
| WB (in cmdlets) | Windows Backup, e.g. `New-WBPolicy` |
| RTO | Recovery Time Objective, how long a restore takes |
| 3-2-1 | A backup rule: 3 copies, 2 media types, 1 offsite |

## Networking and virtualization
| Term | Meaning |
|---|---|
| NAT | Network Address Translation, which lets lab VMs reach the internet through the host |
| IP | Internet Protocol (address) |
| Gen 2 | Hyper-V Generation 2 VM, which uses UEFI firmware and Secure Boot |
| TPM / vTPM | Trusted Platform Module, and its virtual version (needed for Windows 11) |
| ISO | A disk image of an installer |
| RFC 2606 | The internet standard that reserves `.test` for testing |

## Tooling and misc
| Term | Meaning |
|---|---|
| CSV | Comma-Separated Values, the format of the new-hires file |
| RNG | Random Number Generator |
| RSOP | Resultant Set of Policy, the report of which policies actually apply |
| USN | Update Sequence Number, which AD uses to track replication (hence "USN rollback" in doc 01) |
| CI | Continuous Integration, an automated build/test system |
| UNC | Universal Naming Convention, the `\\FS01\Home$` path style |
| `$` in `Home$` | A trailing dollar sign makes a share hidden from browsing |
| `-WhatIf` | A PowerShell switch that previews changes without making them |
| `.psd1` | A PowerShell data file (`lab.psd1` holds the config) |
