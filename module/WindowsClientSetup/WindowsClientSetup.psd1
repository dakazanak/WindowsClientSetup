@{
    RootModule           = 'WindowsClientSetup.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '2e5fcbd9-28ff-4735-9c77-aa054ed5fa8a'
    Author               = 'WindowsClientSetup'
    Description          = 'Grafisches Werkzeug zur Einrichtung eines neuen Windows-11-Clients (winget-Installation, Update, Deinstallation). Setzt eine bereits per EnvironmentBootstrap-Modul vorbereitete Umgebung (PowerShell 7, powershell-yaml) voraus.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @('Start-WindowsClientSetup')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
}
