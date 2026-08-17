@{
    RootModule           = 'EnvironmentBootstrap.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'db01271f-7d1e-4c91-b9c6-a465b367fc4c'
    Author               = 'WindowsClientSetup'
    Description          = 'Bereitet die Umgebung (Host oder Windows Sandbox) fuer WindowsClientSetup vor: prueft/installiert PowerShell 7, winget und das powershell-yaml Modul. Laeuft bewusst noch unter PowerShell 5.1, da PS7 hier erst installiert werden koennte.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Initialize-WindowsEnvironment', 'Initialize-SandboxEnvironment', 'Test-YamlModule')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
}
