# Single source of truth for the lab. Every script reads this file.
# No secrets live here: passwords are always prompted for or generated at run time.
@{
    Domain = @{
        Name        = 'lab.test'      # .test is reserved (RFC 2606) so it never collides with real DNS
        NetBios     = 'LAB'
        BaseOU      = 'Corp'          # OU=Corp,DC=lab,DC=test
        Departments = @('IT', 'HR', 'Finance', 'Sales')
    }

    Network = @{
        SwitchName   = 'LabSwitch'    # Hyper-V Internal switch + host NAT
        Subnet       = '10.10.10.0'
        PrefixLength = 24
        Gateway      = '10.10.10.1'   # Hyper-V host vEthernet adapter (NAT)
        Forwarders   = @('1.1.1.1', '8.8.8.8')
    }

    Servers = @{
        DC01 = @{ IP = '10.10.10.10'; MemoryGB = 4; Cpu = 2; OsDiskGB = 60; ExtraDisksGB = @(60) }          # extra: backup volume
        FS01 = @{ IP = '10.10.10.20'; MemoryGB = 4; Cpu = 2; OsDiskGB = 60; ExtraDisksGB = @(100, 100) }    # extra: data + backup
    }
    Client = @{ Name = 'CLIENT01'; MemoryGB = 4; Cpu = 2; DiskGB = 64 }   # Windows 11, DHCP

    Dhcp = @{
        ScopeName  = 'LabLAN'
        ScopeId    = '10.10.10.0'
        StartRange = '10.10.10.100'
        EndRange   = '10.10.10.200'
        SubnetMask = '255.255.255.0'
        LeaseDays  = 8
    }

    FileServer = @{
        DataDrive   = 'D:'
        BackupDrive = 'E:'
        ShareRoot   = 'D:\Shares'     # Departments\<dept>, Public, Home
        HomeQuotaGB = 5
    }

    Backup = @{
        DcBackupVolume = 'E:'
        FsBackupVolume = 'E:'
        Schedule       = '21:00'
        GpoBackupPath  = 'E:\GpoBackups'
    }

    Provisioning = @{
        HomeUncRoot     = '\\FS01\Home$'
        OutputPath      = 'C:\LabProvisioning\Output'
        LogPath         = 'C:\LabProvisioning\Logs'
        PasswordLength  = 16
        DefaultGroupFmt = 'GG-{0}'    # global group per department
    }
}
