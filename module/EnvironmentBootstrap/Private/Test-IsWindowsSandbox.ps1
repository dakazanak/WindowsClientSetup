function Test-IsWindowsSandbox {
    $isSandboxUser = $env:USERNAME -eq 'WDAGUtilityAccount'
    $hasContainerSvc = Get-Process -Name 'CExecSvc' -ErrorAction SilentlyContinue
    return [bool]($isSandboxUser -and $hasContainerSvc)
}
