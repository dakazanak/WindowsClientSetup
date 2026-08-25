$versionFile = Join-Path $PSScriptRoot '..\..\VERSION'
if (Test-Path $versionFile) {
    $script:ModuleVersion = (Get-Content $versionFile -Raw).Trim()
} else {
    $script:ModuleVersion = '0.0.0'
}

$bootstrapManifest = Join-Path $PSScriptRoot '..\EnvironmentBootstrap\EnvironmentBootstrap.psd1'
Import-Module $bootstrapManifest -Force -Global

foreach ($folder in 'Private', 'Public') {
    $folderPath = Join-Path $PSScriptRoot $folder
    if (Test-Path $folderPath) {
        Get-ChildItem -Path $folderPath -Filter '*.ps1' | ForEach-Object {
            . $_.FullName
        }
    }
}

Export-ModuleMember -Function 'Start-WslDebianSetup'