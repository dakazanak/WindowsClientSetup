function Initialize-Logging {
    param(
        [Parameter(Mandatory)]
        [string]$LogDirectory
    )

    if (-not (Test-Path $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }

    $script:LogFile = Join-Path $LogDirectory 'winget.log'
    Write-Log -Level 'START' -Message "=== Session gestartet $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
}
