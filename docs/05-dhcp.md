# 05 – DHCP

```powershell
C:\Lab\scripts\dc\03-Configure-DHCP.ps1      # prompts for LAB\svc-dhcp credentials
```

What it configures:
* DHCP role installed, local security groups created, and the server **authorized in AD** (an unauthorized DHCP server on a domain stays silent).
* Scope `LabLAN` 10.10.10.100–.200/24, 8-day lease. Options: router `10.10.10.1`, DNS `10.10.10.10`, domain `lab.test`.
* DHCP registers A/PTR records for clients (`Always`) and deletes them on lease expiry, using `svc-dhcp` credentials so
  records are not owned by the DC computer account.
* A commented-out reservation example (replace the MAC with `Get-VMNetworkAdapter CLIENT01`'s).

## Verify

```powershell
Get-DhcpServerInDC
Get-DhcpServerv4Scope | ft
Get-DhcpServerv4Lease -ScopeId 10.10.10.0
```
On CLIENT01 (set to DHCP): `ipconfig /renew; ipconfig /all` – expect `10.10.10.1xx`, DNS `10.10.10.10`, suffix `lab.test`.
Then `Resolve-DnsName client01.lab.test` on DC01 should return the lease.

Production note: use two servers with `Add-DhcpServerv4Failover`; here a single server is a deliberate lab simplification.
