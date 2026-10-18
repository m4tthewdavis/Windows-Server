#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Read-only health checks for the whole lab. Run on DC01 (AD/DNS/DHCP/GPO) and FS01 (shares/backup).
    Exits non-zero if any check fails, so it is CI/automation friendly.
#>
[CmdletBinding()]
param()
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"
$results = [System.Collections.Generic.List[object]]::new()
function Check([string]$Name, [scriptblock]$Test) {
    try { $ok = [bool](& $Test); $detail = '' } catch { $ok = $false; $detail = $_.Exception.Message }
    $results.Add([pscustomobject]@{ Check = $Name; Pass = $ok; Detail = $detail })
}
$role = (Get-CimInstance Win32_ComputerSystem).DomainRole
$zone = $Lab.Domain.Name

if ($role -ge 4) {
    Check 'AD DS service running'        { (Get-Service NTDS).Status -eq 'Running' }
    Check 'dcdiag (Connectivity,Advertising)' { -not ((dcdiag /test:Connectivity /test:Advertising) -match 'failed test') }
    Check 'SYSVOL/NETLOGON shared'       { (Get-SmbShare NETLOGON, SYSVOL).Count -eq 2 }
    Check 'DNS resolves domain'          { Resolve-DnsName $zone -Server 127.0.0.1 -ErrorAction Stop }
    Check 'DNS SRV _ldap record'         { Resolve-DnsName "_ldap._tcp.dc._msdcs.$zone" -Type SRV -Server 127.0.0.1 -ErrorAction Stop }
    Check 'Reverse zone exists'          { Get-DnsServerZone | Where-Object IsReverseLookupZone }
    Check 'DHCP authorized + scope active' { (Get-DhcpServerv4Scope -ScopeId $Lab.Dhcp.ScopeId).State -eq 'Active' }
    Check 'OU structure present'         { Get-ADOrganizationalUnit "OU=$($Lab.Domain.BaseOU),$((Get-ADDomain).DistinguishedName)" }
    Check 'Dept groups present'          { ($Lab.Domain.Departments | ForEach-Object { Get-ADGroup ($Lab.Provisioning.DefaultGroupFmt -f $_) }).Count -eq $Lab.Domain.Departments.Count }
    Check 'Baseline GPOs exist'          { (Get-GPO -All | Where-Object DisplayName -like 'LAB-*').Count -ge 3 }
    Check 'Recycle Bin enabled'          { (Get-ADOptionalFeature 'Recycle Bin Feature').EnabledScopes.Count -gt 0 }
    Check 'Last backup succeeded'        { (Get-WBSummary).LastBackupResultHR -eq 0 }
}
if ($env:COMPUTERNAME -eq 'FS01') {
    foreach ($s in 'Departments', 'Public', 'Home$') { Check "Share $s exists" { Get-SmbShare -Name $s } }
    Check 'Access-based enumeration on'  { (Get-SmbShare -Name Departments).FolderEnumerationMode -eq 'AccessBased' }
    Check 'FSRM quota template present'  { Get-FsrmQuotaTemplate -Name 'Home 5GB' }
    Check 'Last backup succeeded'        { (Get-WBSummary).LastBackupResultHR -eq 0 }
}
$results | Format-Table Check, Pass, Detail -AutoSize -Wrap
if ($results.Pass -contains $false) { exit 1 }
