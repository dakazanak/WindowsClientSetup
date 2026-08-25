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

Add-Type -Name Window -Namespace Console -MemberDefinition '[DllImport("Kernel32.dll")]public static extern IntPtr GetConsoleWindow();[DllImport("User32.dll")]public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);'
$null = [Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0)

Import-Module (Join-Path $repoRoot 'module\WslDebianSetup\WslDebianSetup.psd1') -Force

Start-WslDebianSetup -DataPath $repoRoot