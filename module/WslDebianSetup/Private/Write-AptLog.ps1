function Write-AptLog {
    param(
        [string]$Level,
        [string]$PackageName,
        [string]$Message
    )
    Write-Log -Level $Level -Message "$PackageName : $Message"
}