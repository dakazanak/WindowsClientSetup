function Write-WingetLog {
    param(
        [string]$Level,
        [string]$PackageId,
        [string]$Message
    )
    Write-Log -Level $Level -Message "$PackageId : $Message"
}
