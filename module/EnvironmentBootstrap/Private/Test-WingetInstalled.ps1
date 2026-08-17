function Test-WingetInstalled {
    $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $hasWinget) {
        Write-Host "winget ist nicht installiert. Installiere..." -ForegroundColor Cyan

        $ProgressPreference = 'SilentlyContinue'
        $workDir = Join-Path $env:TEMP "winget-bootstrap"
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        Push-Location $workDir
        try {
            $release = Invoke-RestMethod "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
            $depAsset = $release.assets | Where-Object { $_.name -like "*Dependencies.zip" }
            $msixAsset = $release.assets | Where-Object { $_.name -like "*.msixbundle" }
            if (-not $depAsset -or -not $msixAsset) {
                throw "Fehler: Dependencies.zip oder .msixbundle nicht gefunden."
            }
            Invoke-WebRequest -Uri $depAsset.browser_download_url -OutFile "Dependencies.zip"
            Invoke-WebRequest -Uri $msixAsset.browser_download_url -OutFile "AppInstaller.msixbundle"
            Expand-Archive "Dependencies.zip" -DestinationPath "deps" -Force
            Get-ChildItem "deps\x64" -Filter "*.appx" | ForEach-Object { Add-AppxPackage $_.FullName }
            Add-AppxPackage "AppInstaller.msixbundle"
            Write-Host "winget-Version: $(winget --version)" -ForegroundColor Green
        } catch {
            throw "winget-Installation fehlgeschlagen: $_"
        } finally {
            Pop-Location
        }
    }
    Write-Host "winget ist verfügbar." -ForegroundColor Green
}
