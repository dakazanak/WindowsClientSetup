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

Export-ModuleMember -Function 'Start-WindowsClientSetup'
