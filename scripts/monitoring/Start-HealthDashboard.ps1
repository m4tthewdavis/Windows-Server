<#
.SYNOPSIS
    Serves a live server-health dashboard (CPU, memory, disks, key services, uptime) over HTTP.
    Run on any lab server (DC01, FS01). No modules or third-party packages: HttpListener + CIM only.
.DESCRIPTION
    Samples every -IntervalSeconds, keeps the last -HistoryPoints samples in memory and exposes
    GET /            the dashboard page
    GET /api/metrics { current, history } as JSON
    Listens on localhost by default. To view it from the Hyper-V host, pass -Prefix 'http://+:8080/'
    (needs admin or a urlacl) and open the firewall port yourself; there is no authentication.
.EXAMPLE
    .\Start-HealthDashboard.ps1                      # then browse to http://localhost:8080/
.EXAMPLE
    .\Start-HealthDashboard.ps1 -Prefix 'http://10.10.10.10:8080/' -IntervalSeconds 10
#>
[CmdletBinding()]
param(
    [string]$Prefix = 'http://localhost:8080/',
    [ValidateRange(1, 300)][int]$IntervalSeconds = 5,
    [ValidateRange(10, 2000)][int]$HistoryPoints = 120,
    [string[]]$Services
)
$ErrorActionPreference = 'Stop'
$Lab = Import-PowerShellDataFile "$PSScriptRoot\..\..\config\lab.psd1"
$pagePath = Join-Path $PSScriptRoot 'dashboard\index.html'

# Default service watch-list by role (DomainRole >= 4 means domain controller); override with -Services.
if (-not $Services) {
    $Services = @('LanmanServer', 'EventLog', 'W32Time')
    if ((Get-CimInstance Win32_ComputerSystem).DomainRole -ge 4) { $Services += 'NTDS', 'DNS', 'DHCPServer', 'Netlogon', 'Kdc' }
    if ($env:COMPUTERNAME -eq 'FS01') { $Services += 'SrmSvc', 'VSS' }
}

$history = [System.Collections.Generic.List[object]]::new()

function Get-Sample {
    $os   = Get-CimInstance Win32_OperatingSystem
    $cpu  = [math]::Round((Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average, 1)
    $totalMB = [math]::Round($os.TotalVisibleMemorySize / 1KB)
    $freeMB  = [math]::Round($os.FreePhysicalMemory / 1KB)

    $disks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        [ordered]@{
            drive   = $_.DeviceID
            label   = $_.VolumeName
            sizeGB  = [math]::Round($_.Size / 1GB, 1)
            freeGB  = [math]::Round($_.FreeSpace / 1GB, 1)
            usedPct = if ($_.Size) { [math]::Round(100 * ($_.Size - $_.FreeSpace) / $_.Size, 1) } else { 0 }
        }
    })

    $svc = @($Services | ForEach-Object {
        $s = Get-Service -Name $_ -ErrorAction SilentlyContinue
        if ($s) { [ordered]@{ name = $s.Name; display = $s.DisplayName; status = "$($s.Status)"; ok = ($s.Status -eq 'Running') } }
    })

    [ordered]@{
        time      = (Get-Date).ToUniversalTime().ToString('o')
        host      = $env:COMPUTERNAME
        os        = $os.Caption
        uptimeSec = [int]((Get-Date) - $os.LastBootUpTime).TotalSeconds
        cpuPct    = $cpu
        memory    = [ordered]@{ totalMB = $totalMB; usedMB = $totalMB - $freeMB; usedPct = [math]::Round(100 * ($totalMB - $freeMB) / $totalMB, 1) }
        disks     = $disks
        services  = $svc
    }
}

function Add-Sample {
    $history.Add((Get-Sample))
    if ($history.Count -gt $HistoryPoints) { $history.RemoveAt(0) }
}

function Send-Response($ctx, [int]$Status, [string]$Type, [string]$Body) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Body)
    $ctx.Response.StatusCode      = $Status
    $ctx.Response.ContentType     = $Type
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.Headers.Add('Cache-Control', 'no-store')
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.Close()
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($Prefix)
$listener.Start()
Write-Host "Health dashboard on $Prefix  (Ctrl+C to stop)"

try {
    Add-Sample
    $nextSample = (Get-Date).AddSeconds($IntervalSeconds)
    $pending = $listener.GetContextAsync()
    while ($true) {
        # Wake at least once per interval so history keeps filling with no browser attached.
        $waitMs = [math]::Max(0, [int]($nextSample - (Get-Date)).TotalMilliseconds)
        if ($pending.Wait($waitMs)) {
            $ctx = $pending.Result
            $pending = $listener.GetContextAsync()
            try {
                switch ($ctx.Request.Url.AbsolutePath) {
                    '/' {
                        Send-Response $ctx 200 'text/html; charset=utf-8' (Get-Content -Raw -Encoding UTF8 $pagePath)
                    }
                    '/api/metrics' {
                        $payload = [ordered]@{ intervalSec = $IntervalSeconds; current = $history[$history.Count - 1]; history = $history.ToArray() }
                        Send-Response $ctx 200 'application/json' (ConvertTo-Json -InputObject $payload -Depth 6 -Compress)
                    }
                    default { Send-Response $ctx 404 'text/plain' 'Not found' }
                }
            } catch {
                Write-Warning "Request failed: $($_.Exception.Message)"
                try { $ctx.Response.Abort() } catch { }
            }
        }
        if ((Get-Date) -ge $nextSample) {
            Add-Sample
            $nextSample = (Get-Date).AddSeconds($IntervalSeconds)
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
}
