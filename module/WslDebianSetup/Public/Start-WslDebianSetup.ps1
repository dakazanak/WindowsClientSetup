function Start-WslDebianSetup {
    [CmdletBinding()]
    param(
        [string]$DataPath = (Get-Location).Path
    )

    $packagesYamlPath = Join-Path $DataPath 'config\wsl-debian-packages.yaml'
    $guiXamlPath = Join-Path $PSScriptRoot '..\Resources\GUI.xaml'
    $windowStatePath = Join-Path $DataPath 'window-state.json'

    if (-not (Test-Path $packagesYamlPath)) {
        Write-Host "FEHLER: $packagesYamlPath nicht gefunden." -ForegroundColor Red
        Read-Host "Drücke Enter zum Beenden"
        exit 1
    }

    Test-YamlModule

    $wslCheck = wsl -d Debian -- echo "ready" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FEHLER: WSL-Debian ist nicht verfügbar." -ForegroundColor Red
        Read-Host "Drücke Enter zum Beenden"
        exit 1
    }

    Initialize-Logging -LogDirectory (Join-Path $DataPath 'logs')
    $logsDir = Join-Path $DataPath 'logs'
    Write-Log -Level 'INFO' -Message "WSL-Debian verfuegbar. Starte GUI..."

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

    $guiXaml = Get-Content -Path $guiXamlPath -Raw
    [xml]$xaml = $guiXaml
    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    if (Test-Path $windowStatePath) {
        $windowState = Get-Content $windowStatePath -Raw | ConvertFrom-Json
        if ($windowState.Width)  { $window.Width = $windowState.Width }
        if ($windowState.Height) { $window.Height = $windowState.Height }
        if ($windowState.Left)   { $window.Left = $windowState.Left }
        if ($windowState.Top)    { $window.Top = $windowState.Top }
    }

    $packagesYaml = Get-Content -Path $packagesYamlPath -Raw | ConvertFrom-Yaml -Ordered

    $tabMain = $window.FindName('tabMain')
    $txtStatus = $window.FindName('txtStatus')
    $mnuInstallSelected = $window.FindName('mnuInstallSelected')
    $mnuStartWindowsSetup = $window.FindName('mnuStartWindowsSetup')
    $mnuSetPassword = $window.FindName('mnuSetPassword')
    $mnuBeenden = $window.FindName('mnuBeenden')
    $mnuVersion = $window.FindName('mnuVersion')
    $txtPasswordHint = $window.FindName('txtPasswordHint')

    function Add-StatusLine {
        param([string]$Text, [string]$Color = '#333333', [string]$Level = 'INFO')
        $run = [System.Windows.Documents.Run]::new($Text)
        $para = [System.Windows.Documents.Paragraph]::new($run)
        $para.Margin = [Windows.Thickness]'0'
        $para.Foreground = $Color
        $txtStatus.Document.Blocks.Add($para)
        $txtStatus.ScrollToEnd()
        Write-Log -Level $Level -Message $Text
    }

    Add-StatusLine -Text "WSL-Debian verfuegbar." -Color '#28A745'
    Add-StatusLine -Text "Suche installierte Pakete und Updates ..." -Color '#005A9E'

    $allPackageItems = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($tabKey in $packagesYaml.Keys) {
        $tabItem = [Windows.Controls.TabItem]@{ Header = $tabKey }
        $scrollViewer = [Windows.Controls.ScrollViewer]@{ VerticalScrollBarVisibility = 'Auto' }
        $stackPanel = [Windows.Controls.StackPanel]@{ Margin = [Windows.Thickness]'10' }

        foreach ($group in $packagesYaml.$tabKey) {
            $groupBox = [Windows.Controls.GroupBox]@{ Header = $group.group }
            $groupBox.Style = $window.Resources[([Windows.Controls.GroupBox].FullName)]
            $groupStack = [Windows.Controls.StackPanel]::new()

            foreach ($pkg in $group.packages) {
                $row = [Windows.Controls.StackPanel]@{ Orientation = 'Horizontal'; Margin = [Windows.Thickness]'0,2,0,2' }

                $checkBox = [Windows.Controls.CheckBox]@{
                    Content = $pkg.name
                    Style = $window.Resources['SwitchCheckBox']
                    IsChecked = $false
                    VerticalAlignment = 'Center'
                    Width = 320
                    IsEnabled = $false
                }

                $pkgData = @{
                    Name = $pkg.name
                    Description = $pkg.description
                    Sudo = if ($pkg.sudo -eq $false) { $false } else { $true }
                    CheckBox = $checkBox
                    IsInstalled = $false
                    IsUpgradable = $false
                    SetupCommands = $group.setup_commands
                    UninstallCommands = $group.uninstall_commands
                    IsAptPackage = $true
                }

                $installBtn = [Windows.Controls.Button]@{
                    Content = 'Installieren'
                    Width = 90; Height = 26
                    Margin = [Windows.Thickness]'10,0,0,0'
                    VerticalAlignment = 'Center'
                    Tag = @{ Data = $pkgData; Action = 'Install' }
                }
                $updateBtn = [Windows.Controls.Button]@{
                    Content = 'Update'
                    Width = 90; Height = 26
                    Margin = [Windows.Thickness]'6,0,0,0'
                    VerticalAlignment = 'Center'
                    IsEnabled = $false
                    Tag = @{ Data = $pkgData; Action = 'Update' }
                }
                $uninstallBtn = [Windows.Controls.Button]@{
                    Content = 'Deinstallieren'
                    Width = 100; Height = 26
                    Margin = [Windows.Thickness]'6,0,0,0'
                    VerticalAlignment = 'Center'
                    IsEnabled = $false
                    Tag = @{ Data = $pkgData; Action = 'Uninstall' }
                }

                $pkgData.InstallButton = $installBtn
                $pkgData.UpdateButton = $updateBtn
                $pkgData.UninstallButton = $uninstallBtn

                $clickHandler = {
                    param($sender, $e)
                    $tag = $sender.Tag
                    $sender.IsEnabled = $false
                    $sender.Content = '...'
                    $script:installQueue.Enqueue(@{ Data = $tag.Data; Action = $tag.Action })
                }
                $installBtn.Add_Click($clickHandler)
                $updateBtn.Add_Click($clickHandler)
                $uninstallBtn.Add_Click($clickHandler)

                $row.AddChild($checkBox) | Out-Null
                $row.AddChild($installBtn) | Out-Null
                $row.AddChild($updateBtn) | Out-Null
                $row.AddChild($uninstallBtn) | Out-Null
                $groupStack.AddChild($row) | Out-Null
                $allPackageItems.Add($pkgData)
            }
            $groupBox.Content = $groupStack
            $stackPanel.AddChild($groupBox) | Out-Null
        }
        $scrollViewer.Content = $stackPanel
        $tabItem.Content = $scrollViewer
        [void]$tabMain.Items.Add($tabItem)
    }

    $installedRaw = wsl -d Debian -- bash -c "dpkg --get-selections 2>/dev/null | grep -E '[[:space:]]+install$' | cut -f1"
    $binaryRaw = wsl -d Debian -- bash -l -c "command -v uv >/dev/null 2>&1 && echo uv; command -v yq >/dev/null 2>&1 && echo yq"

    $installedSet = @{}
    foreach ($p in ($installedRaw -split "`n")) { $installedSet[$p.Trim()] = $true }
    $binarySet = @{}
    foreach ($p in ($binaryRaw -split "`n")) { if ($p.Trim()) { $binarySet[$p.Trim()] = $true } }

    Add-StatusLine -Text "$($installedSet.Count) installierte Pakete erkannt." -Color '#333333'

    $binaryOnlySet = @{ 'uv' = $true; 'yq' = $true }

    foreach ($pkg in $allPackageItems) {
        $isInstalled = $installedSet.ContainsKey($pkg.Name) -or $binarySet.ContainsKey($pkg.Name)
        $pkg.IsInstalled = $isInstalled
        $pkg.IsAptPackage = -not $binaryOnlySet.ContainsKey($pkg.Name)
        if ($isInstalled) {
            $pkg.CheckBox.IsChecked = $true
            $pkg.CheckBox.Content = "$($pkg.Name) (installiert)"
            $pkg.InstallButton.IsEnabled = $false
            $pkg.UninstallButton.IsEnabled = $true
        }
    }

    Start-Job -Name "WslUpgradable" -ScriptBlock {
        wsl -d Debian -- bash -c "apt list --upgradable 2>/dev/null | tail -n +2 | cut -d/ -f1"
    } | Out-Null

    $script:installQueue = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new())
    $script:setupCommandsDone = @{}
    $script:uninstallCommandsDone = @{}
    $script:sudoPassword = $null

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(300)

    $timer.Add_Tick({
        $upgradeJob = Get-Job -Name "WslUpgradable" -ErrorAction SilentlyContinue
        if ($upgradeJob -and $upgradeJob.State -eq 'Completed') {
            $upgradableRaw = Receive-Job -Name "WslUpgradable"
            Remove-Job -Name "WslUpgradable"

            $upgradableSet = @{}
            foreach ($p in ($upgradableRaw -split "`n")) { $upgradableSet[$p.Trim()] = $true }

            Add-StatusLine -Text "$($upgradableSet.Count) Updates verfuegbar." -Color '#333333'

            foreach ($pkg in $allPackageItems) {
                $pkg.IsUpgradable = $upgradableSet.ContainsKey($pkg.Name)
                $pkg.UpdateButton.IsEnabled = $pkg.IsInstalled -and $pkg.IsUpgradable
            }
            Add-StatusLine -Text "Bereit." -Color '#333333'
        }

        $job = Get-Job -Name "AptJob" -ErrorAction SilentlyContinue
        if ($job -and $job.State -eq 'Completed' -and $script:aptTargetData) {
            $res = Receive-Job -Name "AptJob"
            Remove-Job -Name "AptJob"

            $btn = switch ($res.Action) {
                'Update'    { $script:aptTargetData.UpdateButton }
                'Uninstall' { $script:aptTargetData.UninstallButton }
                default     { $script:aptTargetData.InstallButton }
            }

            if ($res.ExitCode -eq 0) {
                Write-AptLog -Level 'SUCCESS' -PackageName $res.PackageName -Message "$($res.Action) erfolgreich"
                switch ($res.Action) {
                    'Uninstall' {
                        $script:aptTargetData.IsInstalled = $false
                        $script:aptTargetData.CheckBox.IsChecked = $false
                        $script:aptTargetData.CheckBox.Content = $script:aptTargetData.Name
                        $script:aptTargetData.UninstallButton.Content = 'Deinstallieren'
                        $script:aptTargetData.UninstallButton.IsEnabled = $false
                        $script:aptTargetData.InstallButton.IsEnabled = $true
                        $script:aptTargetData.UpdateButton.IsEnabled = $false
                        Add-StatusLine -Text "$($script:aptTargetData.Name) erfolgreich deinstalliert" -Color '#28A745'
                    }
                    'Update' {
                        $script:aptTargetData.CheckBox.IsChecked = $true
                        $script:aptTargetData.CheckBox.Content = "$($script:aptTargetData.Name) (installiert)"
                        $script:aptTargetData.UpdateButton.Content = 'OK'
                        Add-StatusLine -Text "$($script:aptTargetData.Name) erfolgreich aktualisiert" -Color '#28A745'
                    }
                    default {
                        $script:aptTargetData.IsInstalled = $true
                        $script:aptTargetData.CheckBox.IsChecked = $true
                        $script:aptTargetData.CheckBox.Content = "$($script:aptTargetData.Name) (installiert)"
                        $script:aptTargetData.InstallButton.Content = 'OK'
                        $script:aptTargetData.UninstallButton.IsEnabled = $true
                        Add-StatusLine -Text "$($script:aptTargetData.Name) erfolgreich installiert" -Color '#28A745'
                    }
                }
            } else {
                Write-AptLog -Level 'ERROR' -PackageName $res.PackageName -Message "$($res.Action) fehlgeschlagen"
                if ($btn) {
                    $btn.Content = 'Fehler'
                    $btn.IsEnabled = $true
                }
                Add-StatusLine -Text "Fehler bei $($script:aptTargetData.Name)" -Color '#DC3545'
            }
            $script:isRunning = $false
            return
        }

        if ($script:isRunning) { return }
        $entry = $null
        try { $entry = $script:installQueue.Dequeue() } catch { return }

        $script:isRunning = $true
        $script:aptTargetData = $entry.Data
        $action = $entry.Action
        $pw = $script:sudoPassword

        if ($action -eq 'Uninstall' -and $script:aptTargetData.UninstallCommands -and -not $script:uninstallCommandsDone[$script:aptTargetData.Name]) {
            $script:uninstallCommandsDone[$script:aptTargetData.Name] = $true
            foreach ($unCmd in $script:aptTargetData.UninstallCommands) {
                Add-StatusLine -Text "Uninstall-Setup: $unCmd" -Color '#555555'
                if ($pw) {
                    $pwB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pw))
                    wsl -d Debian -- bash -c "echo $pwB64 | base64 -d | sudo -S bash -c '$unCmd' 2>&1" | Out-Null
                } else {
                    wsl -d Debian -- bash -c $unCmd 2>&1 | Out-Null
                }
            }
        }

        if ($action -eq 'Install' -and $script:aptTargetData.SetupCommands -and -not $script:setupCommandsDone[$script:aptTargetData.Name]) {
            $script:setupCommandsDone[$script:aptTargetData.Name] = $true
            foreach ($setupCmd in $script:aptTargetData.SetupCommands) {
                Add-StatusLine -Text "Setup: $setupCmd" -Color '#555555'
                if ($pw) {
                    $pwB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pw))
                    wsl -d Debian -- bash -c "echo $pwB64 | base64 -d | sudo -S bash -c '$setupCmd' 2>&1" | Out-Null
                } else {
                    wsl -d Debian -- bash -c $setupCmd 2>&1 | Out-Null
                }
            }
        }

        $startText = switch ($action) {
            'Update'    { "Aktualisiere $($script:aptTargetData.Name) ..." }
            'Uninstall' { "Deinstalliere $($script:aptTargetData.Name) ..." }
            default     { "Installiere $($script:aptTargetData.Name) ..." }
        }
        Add-StatusLine -Text $startText -Color '#005A9E'

        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $script:aptLogFile = Join-Path $logsDir "apt-$($script:aptTargetData.Name -replace '[\.\\/]','-')-$action-$timestamp.log"
        '' | Set-Content $script:aptLogFile -Force
        Write-AptLog -Level 'INFO' -PackageName $script:aptTargetData.Name -Message "$action gestartet"

        $needsApt = $true
        if ($action -eq 'Uninstall' -and -not $script:aptTargetData.IsAptPackage) { $needsApt = $false }
        if ($action -eq 'Install' -and -not $script:aptTargetData.IsAptPackage) { $needsApt = $false }

        $pwEncoded = if ($pw) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pw)) } else { '' }

        if ($needsApt) {
            Start-Job -Name "AptJob" -ScriptBlock {
                param($Name, $Action, $PwEncoded, $LogPath)
                $aptCmd = switch ($Action) {
                    'Update'    { "apt-get install --only-upgrade -y $Name" }
                    'Uninstall' { "apt-get remove -y $Name" }
                    default     { "apt-get install -y $Name" }
                }
                $output = if ($PwEncoded) {
                    wsl -d Debian -- bash -c "echo $PwEncoded | base64 -d | sudo -S $aptCmd 2>&1"
                } else {
                    wsl -d Debian -- bash -c "sudo $aptCmd 2>&1"
                }
                $output | Out-File -FilePath $LogPath -Append -Encoding UTF8
                @{ ExitCode = $LASTEXITCODE; PackageName = $Name; Action = $Action; LogPath = $LogPath }
            } -ArgumentList $script:aptTargetData.Name, $action, $pwEncoded, $script:aptLogFile | Out-Null
        } else {
            Start-Job -Name "AptJob" -ScriptBlock {
                param($Name, $Action, $LogPath)
                "Kein apt-Paket, ueberspringe apt $Action" | Out-File -FilePath $LogPath -Append -Encoding UTF8
                @{ ExitCode = 0; PackageName = $Name; Action = $Action; LogPath = $LogPath }
            } -ArgumentList $script:aptTargetData.Name, $action, $script:aptLogFile | Out-Null
        }
    })

    $script:isRunning = $false
    $timer.Start()

    function Save-WindowConfig {
        @{
            Width  = $window.Width
            Height = $window.Height
            Left   = $window.Left
            Top    = $window.Top
        } | ConvertTo-Json | Set-Content -Path $windowStatePath -Force
    }

    function Invoke-InstallSelected {
        $toInstall = @($allPackageItems | Where-Object { -not $_.IsInstalled })
        if ($toInstall.Count -eq 0) {
            Add-StatusLine -Text "Alle Pakete bereits installiert." -Color '#FFA500'
            return
        }
        foreach ($pkg in $toInstall) {
            $pkg.InstallButton.IsEnabled = $false
            $pkg.InstallButton.Content = '...'
            $script:installQueue.Enqueue(@{ Data = $pkg; Action = 'Install' })
        }
        Add-StatusLine -Text "$($toInstall.Count) Paket(e) zur Installation eingereiht." -Color '#005A9E'
    }

    function Show-PasswordDialog {
        $pwWindow = [Windows.Window]@{
            Title = 'sudo-Passwort'
            Width = 350; Height = 160
            WindowStartupLocation = 'CenterOwner'
            Owner = $window
            ResizeMode = 'NoResize'
            WindowStyle = 'ToolWindow'
        }
        $pwGrid = [Windows.Controls.Grid]@{ Margin = [Windows.Thickness]'10' }
        $pwGrid.RowDefinitions.Add([Windows.Controls.RowDefinition]@{ Height = [Windows.GridLength]'Auto' })
        $pwGrid.RowDefinitions.Add([Windows.Controls.RowDefinition]@{ Height = [Windows.GridLength]'Auto' })
        $pwGrid.RowDefinitions.Add([Windows.Controls.RowDefinition]@{ Height = [Windows.GridLength]'Auto' })
        $pwLabel = [Windows.Controls.TextBlock]@{ Text = 'Debian sudo-Passwort:'; Margin = [Windows.Thickness]'0,0,0,8'; FontWeight = 'SemiBold' }
        $pwGrid.AddChild($pwLabel)
        $pwBox = [Windows.Controls.PasswordBox]@{ Password = if ($script:sudoPassword) { $script:sudoPassword } else { '' }; Margin = [Windows.Thickness]'0,0,0,10' }
        $pwBox.SetValue([Windows.Controls.Grid]::RowProperty, 1)
        $pwGrid.AddChild($pwBox)
        $pwBtnPanel = [Windows.Controls.StackPanel]@{ Orientation = 'Horizontal'; HorizontalAlignment = 'Right' }
        $pwBtnPanel.SetValue([Windows.Controls.Grid]::RowProperty, 2)
        $pwOkBtn = [Windows.Controls.Button]@{ Content = 'OK'; Width = 80; Height = 26; Margin = [Windows.Thickness]'0,0,10,0'; IsDefault = $true }
        $pwCancelBtn = [Windows.Controls.Button]@{ Content = 'Abbrechen'; Width = 80; Height = 26; IsCancel = $true }
        $pwOkBtn.Add_Click({ $pwWindow.DialogResult = $true; $pwWindow.Close() })
        $pwCancelBtn.Add_Click({ $pwWindow.DialogResult = $false; $pwWindow.Close() })
        $pwBtnPanel.AddChild($pwOkBtn)
        $pwBtnPanel.AddChild($pwCancelBtn)
        $pwGrid.AddChild($pwBtnPanel)
        $pwWindow.Content = $pwGrid
        $pwBox.Focus()
        $pwBox.SelectAll()
        if ($pwWindow.ShowDialog()) {
            $script:sudoPassword = [System.Net.NetworkCredential]::new('', $pwBox.SecurePassword).Password
            $txtPasswordHint.Visibility = 'Collapsed'
            Update-ButtonStates
            Add-StatusLine -Text "sudo-Passwort gespeichert." -Color '#28A745'
        }
    }

    function Update-ButtonStates {
        $hasPw = [bool]$script:sudoPassword
        foreach ($pkg in $allPackageItems) {
            if ($pkg.Sudo -and -not $hasPw) {
                $pkg.CheckBox.Foreground = '#DC3545'
                $pkg.InstallButton.IsEnabled = $false
                $pkg.UpdateButton.IsEnabled = $false
                $pkg.UninstallButton.IsEnabled = $false
            } else {
                $pkg.CheckBox.Foreground = '#333333'
                if (-not $pkg.IsInstalled) { $pkg.InstallButton.IsEnabled = $true }
                if ($pkg.IsUpgradable -and $pkg.IsInstalled) { $pkg.UpdateButton.IsEnabled = $true }
                if ($pkg.IsInstalled) { $pkg.UninstallButton.IsEnabled = $true }
            }
        }
    }

    Update-ButtonStates

    $moduleVersion = $script:ModuleVersion

    $mnuVersion.Add_Click({
        [Windows.MessageBox]::Show("WslDebianSetup v$moduleVersion", "Version", 'OK', 'Information') | Out-Null
    })

    $mnuSetPassword.Add_Click({ Show-PasswordDialog })

    $mnuStartWindowsSetup.Add_Click({
        $winLauncher = Join-Path $DataPath 'Start-WindowsClientForge.ps1'
        if (Test-Path $winLauncher) {
            $timer.Stop()
            Get-Job -Name "AptJob", "WslUpgradable" -ErrorAction SilentlyContinue | Stop-Job | Remove-Job
            Save-WindowConfig
            Start-Process pwsh -ArgumentList '-NoProfile', '-WindowStyle', 'Hidden', '-File', "`"$winLauncher`""
            $window.Close()
        } else {
            Add-StatusLine -Text "Start-WindowsClientForge.ps1 nicht gefunden." -Color '#DC3545'
        }
    })

    $mnuInstallSelected.Add_Click({ Invoke-InstallSelected })

    $mnuBeenden.Add_Click({
        $timer.Stop()
        Get-Job -Name "AptJob", "WslUpgradable" -ErrorAction SilentlyContinue | Stop-Job | Remove-Job
        Save-WindowConfig
        $window.Close()
    })

    $window.Add_Closing({
        Write-Log -Level 'INFO' -Message "GUI geschlossen"
        $timer.Stop()
        Get-Job -Name "AptJob", "WslUpgradable" -ErrorAction SilentlyContinue | Stop-Job | Remove-Job
        Save-WindowConfig
    })

    Write-Log -Level 'INFO' -Message "GUI geoeffnet"
    $window.ShowDialog() | Out-Null
    Write-Log -Level 'END' -Message "=== Session beendet $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
}