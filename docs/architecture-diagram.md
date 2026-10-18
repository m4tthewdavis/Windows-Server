# How the pieces interact

Diagrams are Mermaid, so GitHub renders them inline.

## 1. Runtime: machines and services

```mermaid
flowchart TB
    NET([Internet])
    subgraph HOST["Hyper-V host"]
        NAT["NAT 'LabNat'<br/>vEthernet LabSwitch 10.10.10.1"]
        VHDX[("Backup copies<br/>(copy E: off the VM)")]
    end
    NET <--> NAT

    subgraph DC["DC01 10.10.10.10"]
        ADDS["AD DS<br/>users, groups, OUs"]
        DNS["DNS<br/>lab.test + reverse zone"]
        DHCP["DHCP<br/>10.10.10.100-200"]
        GPO["Group Policy<br/>(SYSVOL)"]
        WSB1["Windows Server Backup<br/>System State + BMR"]
    end

    subgraph FS["FS01 10.10.10.20"]
        SHARES["SMB shares<br/>Departments / Public / Home$"]
        NTFS["NTFS ACLs<br/>SH-Dept-RW / RO"]
        FSRM["FSRM<br/>quotas + file screens"]
        VSS["Shadow copies<br/>(Previous Versions)"]
        WSB2["Windows Server Backup<br/>D: data + System State"]
    end

    CL["CLIENT01<br/>Windows 11"]

    NAT --- DC
    NAT --- FS
    NAT --- CL

    ADDS <-->|"integrated zone,<br/>SRV records"| DNS
    DHCP -->|"registers A/PTR<br/>(svc-dhcp)"| DNS
    DHCP -.->|"authorized in"| ADDS
    ADDS --> GPO

    CL -->|"1 lease: IP, router, DNS"| DHCP
    CL -->|"2 resolve DC, FS01"| DNS
    CL -->|"3 Kerberos logon"| ADDS
    CL -->|"4 apply policy"| GPO
    CL -->|"5 SMB, encrypted"| SHARES

    FS -->|"domain-joined,<br/>group lookups"| ADDS
    SHARES --> NTFS
    NTFS --- FSRM
    SHARES --- VSS

    WSB1 --> E1[("DC01 E:")]
    WSB2 --> E2[("FS01 E:")]
    E1 -.-> VHDX
    E2 -.-> VHDX
```

## 2. Permissions model (AGDLP)

```mermaid
flowchart LR
    U["User<br/>alice.nguyen"] --> GG["GG-Finance<br/>(global group)"]
    GG --> DL["SH-Finance-RW<br/>(domain-local group)"]
    DL --> ACL["NTFS ACL: Modify on<br/>D:\Shares\Departments\Finance"]
    U --> ALL["GG-AllStaff"] --> PUB["NTFS ACL on Public"]
    U --> HOMEACL["Own ACL on<br/>Home$\alice.nguyen"]
```

## 3. User provisioning flow (`New-LabUser.ps1`)

```mermaid
flowchart TD
    CSV[("new-hires.csv")] --> V{"Row valid and<br/>dept known?"}
    V -- no --> L1["Log ERROR, continue batch"]
    V -- yes --> E{"Already exists<br/>in dept OU?"}
    E -- yes --> L2["Log SKIP"]
    E -- no --> S["Unique sAMAccountName<br/>first.last, first.last2 ..."]
    S --> P["Random password<br/>(crypto RNG)"]
    P --> A["New-ADUser in<br/>OU=Dept,OU=Users,OU=Corp"]
    A --> G["Add to GG-Dept and GG-AllStaff"]
    G --> H["Create \\\\FS01\\Home$\\sam<br/>protected ACL"]
    H --> Q["FSRM auto-applies 5 GB quota"]
    H --> R["Password report CSV<br/>(operator-only ACL) + log"]
```

## 4. Build order and dependencies

```mermaid
flowchart TD
    A["01 New-LabHost.ps1<br/>(host)"] --> B["Install Windows<br/>Publish-LabScripts.ps1<br/>Initialize-Server.ps1"]
    B --> C["01-Install-ADDS.ps1<br/>(DC01)"]
    C --> D["Initialize-BackupDisk.ps1<br/>(DC01)"]
    D --> O["04-New-OUStructure.ps1<br/>OUs, groups, svc-dhcp, Recycle Bin"]
    O --> N["02-Configure-DNS.ps1"]
    N --> H["03-Configure-DHCP.ps1<br/>needs svc-dhcp"]
    O --> P["05-Configure-GroupPolicy.ps1<br/>needs OUs and E:"]
    O --> J["01-Join-Domain.ps1<br/>(FS01)"]
    J --> F["02-Configure-FileShares.ps1<br/>needs SH-* groups"]
    P --> K["01-Configure-Backup.ps1<br/>(DC01 and FS01)"]
    F --> K
    F --> U["New-LabUser.ps1<br/>needs groups and Home$"]
    K --> R["02-Restore-Lab.ps1<br/>drills"]
    U --> T["Test-Lab.ps1"]
    R --> T
```
