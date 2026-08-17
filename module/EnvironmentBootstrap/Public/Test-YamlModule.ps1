function Test-YamlModule {
    $hasYaml = Get-Module -ListAvailable -Name powershell-yaml
    if (-not $hasYaml) {
        Write-Host "powershell-yaml Modul ist nicht installiert. Installiere..." -ForegroundColor Cyan
        try {
            Install-Module -Name powershell-yaml -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        } catch {
            throw "powershell-yaml Installation fehlgeschlagen: $_"
        }
        Write-Host "powershell-yaml installiert." -ForegroundColor Green
    } else {
        Write-Host "powershell-yaml Modul ist verfügbar." -ForegroundColor Green
    }
}
