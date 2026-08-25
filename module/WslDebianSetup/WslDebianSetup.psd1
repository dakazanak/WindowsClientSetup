@{
    RootModule           = 'WslDebianSetup.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'a3f8c7d2-9e4b-4a1c-b6d5-f8e3a2c1b0d9'
    Author               = 'WindowsClientSetup'
    Description          = 'Installiert apt-Pakete in einer WSL-Debian-Instanz via Konsole mit Checkbox-Auswahl.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @('Start-WslDebianSetup')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
}