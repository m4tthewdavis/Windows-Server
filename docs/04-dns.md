# 04 – DNS

DNS was installed with AD DS; AD-integrated zone `lab.test` already exists. This step hardens and completes it.

```powershell
C:\Lab\scripts\dc\02-Configure-DNS.ps1 -WhatIf
C:\Lab\scripts\dc\02-Configure-DNS.ps1
```

| Setting | Value | Why |
|---------|-------|-----|
| Forwarders | 1.1.1.1, 8.8.8.8 | External resolution via the NAT |
| Reverse zone | `10.10.10.in-addr.arpa`, AD-integrated | PTR lookups, required by some tooling |
| Dynamic updates | **Secure only** on both zones | Prevents unauthenticated record hijacking |
| Aging/scavenging | 7d no-refresh + 7d refresh, scavenge weekly | Removes stale DHCP-registered records |
| Static records | A + PTR for DC01, FS01; CNAME `files` → FS01 | Infrastructure stays resolvable |

## Verify

```powershell
Resolve-DnsName fs01.lab.test
Resolve-DnsName 10.10.10.20                      # PTR
Resolve-DnsName _ldap._tcp.dc._msdcs.lab.test -Type SRV
Resolve-DnsName www.microsoft.com                # forwarders work
Get-DnsServerZone | ft ZoneName, DynamicUpdate, IsReverseLookupZone
```
Troubleshooting: `ipconfig /registerdns`, `dcdiag /test:dns /v`, `nltest /dsgetdc:lab.test`.
