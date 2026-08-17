function Test-PS7Installed {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )

    $ps7 = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $ps7) {
        Write-Host "PowerShell 7 ist nicht installiert. Installiere..." -ForegroundColor Cyan
        winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { throw "PowerShell 7 Installation fehlgeschlagen." }
        Write-Host "PowerShell 7 installiert. Starte Skript mit pwsh.exe neu..." -ForegroundColor Green
        Start-Process pwsh -ArgumentList '-NoProfile', '-NoExit', '-Command', "& '$ScriptPath'"
        Start-Sleep -Seconds 5
        Stop-Process -Id $PID
        exit 0
    }

    if ($PSVersionTable.PSEdition -ne 'Core') {
        Write-Host "PowerShell 7 ist installiert, aber Skript läuft noch in PS5. Starte neu mit pwsh.exe..." -ForegroundColor Yellow
        Start-Process pwsh -ArgumentList '-NoProfile', '-NoExit', '-Command', "& '$ScriptPath'"
        Start-Sleep -Seconds 5
        Stop-Process -Id $PID
        exit 0
    }

    Write-Host "PowerShell 7 ist verfügbar." -ForegroundColor Green
}
