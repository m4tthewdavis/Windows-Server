# 02 – Install Windows and first-boot configuration

## Install the OS

1. `Start-VM DC01, FS01` then connect with `vmconnect localhost DC01`.
2. Setup: choose **Windows Server 2025 Standard (Desktop Experience)**, custom install onto the 60 GB disk.
3. Set a local Administrator password when prompted (use a lab-only password; record it in a vault).
4. Repeat for FS01. After setup, eject the ISO: `Get-VMDvdDrive -VMName DC01 | Set-VMDvdDrive -Path $null`.
5. Take a checkpoint: `Checkpoint-VM DC01 -SnapshotName 'clean-os'`.

## Push the scripts into the guests (PowerShell Direct – no network needed)

On the host:
```powershell
.\scripts\host\Publish-LabScripts.ps1 -VMName DC01      # prompts for the local Administrator credential
.\scripts\host\Publish-LabScripts.ps1 -VMName FS01
```
Files land in `C:\Lab` inside each VM.

## Static IP, name, time zone

Inside each VM (elevated PowerShell):
```powershell
Set-ExecutionPolicy -Scope Process Bypass
C:\Lab\scripts\common\Initialize-Server.ps1 -Name DC01 -WhatIf   # preview
C:\Lab\scripts\common\Initialize-Server.ps1 -Name DC01           # reboots after rename
```
Do the same on FS01 with `-Name FS01`. After the reboot the PowerShell Direct session needs re-publishing only if you changed the repo.

## Verify

```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -like '10.10.10.*'
Test-Connection 10.10.10.1      # host gateway
Test-Connection 1.1.1.1         # NAT to internet
```
Windows Update both servers now, then checkpoint `os-patched`.
