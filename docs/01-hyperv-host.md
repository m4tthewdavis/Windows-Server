# 01 – Hyper-V host and VMs

**Goal:** an isolated virtual network and three empty Generation 2 VMs.

## Steps

1. Enable Hyper-V (elevated PowerShell on the host), then reboot:
   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
   ```
2. Download the Windows Server 2025 ISO (Microsoft Evaluation Center) and optionally a Windows 11 ISO.
3. Clone this repo on the host and run:
   ```powershell
   .\scripts\host\New-LabHost.ps1 -ServerIso D:\ISO\WS2025.iso -ClientIso D:\ISO\Win11.iso -VmRoot D:\Hyper-V\Lab -WhatIf   # dry run
   .\scripts\host\New-LabHost.ps1 -ServerIso D:\ISO\WS2025.iso -ClientIso D:\ISO\Win11.iso -VmRoot D:\Hyper-V\Lab
   ```
   What it does: creates `LabSwitch` (Internal), gives the host adapter `10.10.10.1/24`, creates NAT `LabNat`,
   then creates `DC01`, `FS01` (and `CLIENT01` with a vTPM) with static memory, Production checkpoints, Guest Services on,
   extra data disks, and the ISO as first boot device. Re-running skips what exists.

## Verify

```powershell
Get-VMSwitch LabSwitch; Get-NetNat LabNat; Get-VM | Format-Table Name, State, MemoryAssigned
```

## Notes

* Static (not dynamic) memory is used on the DC to avoid AD database cache pressure.
* Production checkpoints are safe for file servers; **never** restore a DC from a checkpoint in a multi-DC domain (USN rollback). With a single DC it is tolerated in a lab, but backups are the proper path (doc 08).
