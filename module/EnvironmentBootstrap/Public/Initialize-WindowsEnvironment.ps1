function Initialize-WindowsEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )

    Test-PS7Installed -ScriptPath $ScriptPath
    Test-YamlModule
    Write-Host "Alle Voraussetzungen erfüllt." -ForegroundColor Green
}
