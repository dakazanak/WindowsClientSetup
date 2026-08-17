function Initialize-SandboxEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )

    if (-not (Test-IsWindowsSandbox)) {
        throw "Dieses Skript ist nur fuer Windows Sandbox gedacht. Abbruch."
    }

    Test-WingetInstalled
    Test-PS7Installed -ScriptPath $ScriptPath
    Test-YamlModule
    Write-Host "Alle Voraussetzungen erfüllt." -ForegroundColor Green
}
