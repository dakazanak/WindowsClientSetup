function Test-OSVersion {
    $script:osStatusMessages = @()
    $os = [System.Environment]::OSVersion.Platform

    if ($PSVersionTable.PSEdition -eq 'Core') {
        $isWin = $PSVersionTable.Platform -eq 'Win32NT' -or [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
    } else {
        $isWin = $os -eq 'Win32NT'
    }

    if (-not $isWin) {
        Write-Host "Betriebssystem: $(if ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unbekannt' })" -ForegroundColor Yellow
        Write-Host "Dieses Tool läuft nur unter Windows." -ForegroundColor Red
        return $false
    }

    $winVersion = [System.Environment]::OSVersion.Version
    $build = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).CurrentBuild

    $script:osStatusMessages += @{ Text = "Betriebssystem: Windows $($winVersion.Major).$($winVersion.Minor) (Build $build)"; Color = '#28A745' }

    if ($winVersion.Major -lt 10) {
        Write-Host "Nicht unterstützte Windows-Version." -ForegroundColor Red
        return $false
    }

    if ($winVersion.Major -eq 10 -and $build -lt 22000) {
        Write-Host "Windows 10 erkannt. winget ist möglicherweise nicht vorinstalliert." -ForegroundColor Yellow
        return $false
    }

    $script:osStatusMessages += @{ Text = "Windows 11 erkannt."; Color = '#28A745' }
    return $true
}
