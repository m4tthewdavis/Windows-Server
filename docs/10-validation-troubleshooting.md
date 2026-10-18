# 10 – Validation and troubleshooting

Run `C:\Lab\scripts\validation\Test-Lab.ps1` on DC01 and on FS01 after each stage; it is read-only and exits non-zero on any failure.

## End-to-end acceptance checklist

- [ ] `dcdiag` clean on DC01; FS01 and CLIENT01 joined to `lab.test`
- [ ] Forward and reverse DNS resolve; external names resolve through forwarders
- [ ] CLIENT01 receives address, router, DNS and suffix from DHCP; its A record appears in DNS
- [ ] `gpresult` on CLIENT01 lists the baseline GPOs; password policy enforced
- [ ] Provisioned user can log in, is forced to change password, sees only their department share and own home folder
- [ ] Backup ran on both servers; at least restore drills 8.2 A, B and C passed

## Common problems

| Symptom | Likely cause / fix |
|---------|--------------------|
| Domain join fails "domain not found" | Client DNS not pointing at 10.10.10.10; fix DNS before anything else |
| DHCP gives no leases | Server not authorized (`Get-DhcpServerInDC`), scope not Active, or lab switch shared with another DHCP |
| GPO not applying | Wrong OU (computer vs. user setting), `gpupdate /force`, check `gpresult /h` and SYSVOL replication |
| Can't see share contents | Not in the right `GG-` group yet – log off/on to refresh the token |
| Home folder creation fails in provisioning | FS01 offline, or operator not Domain Admin; the user is still created and the error is in the log |
| `Set-WBPolicy` fails on volume | Backup volume missing/ in use by another policy: `Get-WBPolicy`, `Remove-WBPolicy` and re-run |
| Time skew / Kerberos errors | Hyper-V time sync vs. DC; keep DC01 as authoritative: `w32tm /query /status` |

Useful: `repadmin /replsummary`, `nltest /dclist:lab.test`, `Get-WinEvent -LogName 'Directory Service' -MaxEvents 30`.
