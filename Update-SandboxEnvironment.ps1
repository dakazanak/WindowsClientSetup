$scriptPath = $MyInvocation.MyCommand.Path
if (-not $scriptPath) { $scriptPath = Join-Path $PSScriptRoot $MyInvocation.MyCommand.Name }
$repoRoot = Split-Path -Parent $scriptPath

Import-Module (Join-Path $repoRoot 'module\EnvironmentBootstrap\EnvironmentBootstrap.psd1') -Force

Initialize-SandboxEnvironment -ScriptPath $scriptPath
