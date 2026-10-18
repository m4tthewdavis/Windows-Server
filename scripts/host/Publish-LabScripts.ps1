#Requires -RunAsAdministrator
#Requires -Modules Hyper-V
<#
.SYNOPSIS
    Copies the repo's config + scripts into a VM at C:\Lab using PowerShell Direct (no network needed).
.EXAMPLE
    .\Publish-LabScripts.ps1 -VMName DC01
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$VMName,
    [pscredential]$Credential = (Get-Credential -Message "Local/domain admin of $VMName")
)
$ErrorActionPreference = 'Stop'
$repo = Resolve-Path "$PSScriptRoot\..\.."
$session = New-PSSession -VMName $VMName -Credential $Credential
try {
    Invoke-Command -Session $session { Remove-Item C:\Lab -Recurse -Force -ErrorAction SilentlyContinue; New-Item C:\Lab -ItemType Directory | Out-Null }
    foreach ($dir in 'config', 'scripts', 'data') {
        Copy-Item -Path (Join-Path $repo $dir) -Destination C:\Lab -ToSession $session -Recurse -Force
    }
    Write-Host "Published to $VMName`:C:\Lab"
}
finally { Remove-PSSession $session }
