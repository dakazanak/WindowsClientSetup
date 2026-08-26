#requires -Version 7.0

<#
.SYNOPSIS
    Konsolenbasiertes Werkzeug zur Installation von apt-Paketen in WSL Debian.
.DESCRIPTION
    Duenner Launcher fuer das WslDebianSetup-Modul.
.NOTES
    Erfordert PowerShell 7+ und eine WSL-Debian-Instanz.
#>

$scriptPath = $MyInvocation.MyCommand.Path
if (-not $scriptPath) { $scriptPath = Join-Path $PSScriptRoot $MyInvocation.MyCommand.Name }
$repoRoot = Split-Path -Parent $scriptPath

Import-Module (Join-Path $repoRoot 'module\WslDebianSetup\WslDebianSetup.psd1') -Force

Start-WslDebianSetup -DataPath $repoRoot