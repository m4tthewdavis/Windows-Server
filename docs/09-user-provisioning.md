# 09 – Automating user provisioning with PowerShell

`scripts/provisioning/New-LabUser.ps1` turns an HR-style CSV into fully provisioned users.

## CSV format (`data/new-hires.sample.csv`)

```
FirstName,LastName,Department,Title,Manager,Phone
Alice,Nguyen,IT,Systems Administrator,,555-0101
```
`Department` must be one of `config/lab.psd1 → Domain.Departments`. `Manager` is an optional sAMAccountName.

## Run

On DC01 (as a Domain Admin; FS01 must be up for home folders):
```powershell
C:\Lab\scripts\provisioning\New-LabUser.ps1 -CsvPath C:\Lab\data\new-hires.sample.csv -WhatIf -Verbose   # dry run
C:\Lab\scripts\provisioning\New-LabUser.ps1 -CsvPath C:\Lab\data\new-hires.sample.csv
```

## What each user gets

1. **Validation** – missing fields / unknown department rows are logged and skipped (batch continues; exit code 1 if any failed).
2. **Unique identity** – `first.last`, then `first.last2`… (the sample's second "Brian Okafor" in Sales demonstrates this).
3. **AD account** in `OU=<Dept>,OU=Users,OU=Corp`, UPN, title/department/phone/manager, enabled, **must change password at first logon**.
4. **Random 16-char password** from a cryptographic RNG that always meets complexity.
5. **Groups**: `GG-<Dept>` (→ nested in `SH-<Dept>-RW` ⇒ department share access) and `GG-AllStaff` (Public).
6. **Home folder** `\\FS01\Home$\<sam>`: protected ACL (user Modify, Administrators/SYSTEM Full), `HomeDirectory`/`H:` set; FSRM applies the 5 GB quota automatically.
7. **Audit**: `C:\LabProvisioning\Logs\provision-<ts>.log`; password hand-off file `C:\LabProvisioning\Output\new-users-<ts>.csv`, readable only by the operator. **Distribute securely and delete it.**

Idempotent: re-running the same CSV skips users that already exist.

## Offboarding

```powershell
C:\Lab\scripts\provisioning\Disable-LabUser.ps1 -Identity alice.nguyen -WhatIf
```
Disables the account, removes group memberships, stamps the description, moves it to `OU=Disabled`; the home folder is kept for retention. Reversible through the backup/Recycle Bin procedures in doc 08.

## Verify

```powershell
Get-ADUser -Filter * -SearchBase 'OU=Users,OU=Corp,DC=lab,DC=test' -Properties Department, HomeDirectory | ft Name, SamAccountName, Department, HomeDirectory
Get-ADGroupMember GG-Finance
icacls \\FS01\Home$\alice.nguyen
```
Then sign in on CLIENT01 as the new user: forced password change, then `H:` and department shares appear (after the drive-map step in doc 06).

## Extending
Add departments in `config/lab.psd1` and re-run `04-New-OUStructure.ps1` + `02-Configure-FileShares.ps1`. Add attributes by extending the CSV and the `$params` splat.
