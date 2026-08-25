function Start-WindowsClientSetup {
    <#
    .SYNOPSIS
        Grafisches Werkzeug zur Einrichtung eines neuen Windows Clients.
    .DESCRIPTION
        WPF-basierte Oberfläche zur Installation, Aktualisierung und Deinstallation
        von winget-Paketen.
    .PARAMETER ScriptPath
        Pfad des aufrufenden Launcher-Skripts (wird für den Neustart als Admin/Benutzer benötigt).
    .PARAMETER DataPath
        Verzeichnis, in dem 'config\packages.yaml', 'logs\' und 'window-state.json' liegen.
        Standardmäßig das Verzeichnis von ScriptPath.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [string]$DataPath = (Split-Path -Parent $ScriptPath)
    )

    $logsDir = Join-Path $DataPath 'logs'
    $windowStatePath = Join-Path $DataPath 'window-state.json'
    $packagesYamlPath = Join-Path $DataPath 'config\packages.yaml'
    $guiXamlPath = Join-Path $PSScriptRoot '..\Resources\GUI.xaml'

    Start-Transcript -Path (Join-Path $logsDir 'session.log') -Append | Out-Null

    if (-not (Test-OSVersion)) {
        Write-Host "Nicht unterstütztes Betriebssystem" -ForegroundColor Red
        Read-Host "Drücke Enter zum Beenden"
        Stop-Transcript | Out-Null
        exit 1
    }

    Initialize-Logging -LogDirectory $logsDir
    Write-Log -Level 'INFO' -Message "Betriebssystem-Prüfung bestanden"

    Test-YamlModule
    Write-Log -Level 'INFO' -Message "Modul-Prüfung abgeschlossen"

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

    $isAdmin = [Security.Principal.WindowsPrincipal]::new(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

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
    $statusPanel = $window.FindName('statusPanel')
    $txtStatus   = $window.FindName('txtStatus')

    function Add-StatusLine {
        param([string]$Text, [string]$Color = '#333333')
        $run = [System.Windows.Documents.Run]::new($Text)
        $para = [System.Windows.Documents.Paragraph]::new($run)
        $para.Margin = [Windows.Thickness]'0'
        $para.Foreground = $Color
        $txtStatus.Document.Blocks.Add($para)
        $txtStatus.ScrollToEnd()
    }

    foreach ($msg in $script:osStatusMessages) {
        Add-StatusLine -Text $msg.Text -Color $msg.Color
    }

    $wingetPackages = [System.Collections.Generic.List[hashtable]]::new()

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
                    Foreground = if ($pkg.elevated) { '#DC3545' } else { 'Black' }
                }
                $allowedByElevation = -not ($pkg.elevated -and -not $isAdmin)
                # winget verweigert das Deinstallieren, wenn der Admin-Status nicht exakt zum Scope passt:
                # Machine-Scope braucht Admin, User-Scope darf NICHT als Admin deinstalliert werden.
                $allowedToUninstall = if ($pkg.elevated) { $isAdmin } else { -not $isAdmin }
                $pkgData = @{ Id = $pkg.id; Name = $pkg.name; CheckBox = $checkBox; Scope = $pkg.scope; IsAdmin = $isAdmin; AllowedByElevation = $allowedByElevation; AllowedToUninstall = $allowedToUninstall }

                $installBtn = [Windows.Controls.Button]@{
                    Content = 'Installieren'
                    Width = 90
                    Height = 26
                    Margin = [Windows.Thickness]'10,0,0,0'
                    VerticalAlignment = 'Center'
                    IsEnabled = $allowedByElevation
                    Tag = @{ Data = $pkgData; Action = 'Install' }
                }

                $updateBtn = [Windows.Controls.Button]@{
                    Content = 'Update'
                    Width = 90
                    Height = 26
                    Margin = [Windows.Thickness]'6,0,0,0'
                    VerticalAlignment = 'Center'
                    IsEnabled = $false
                    Tag = @{ Data = $pkgData; Action = 'Update' }
                }

                $uninstallBtn = [Windows.Controls.Button]@{
                    Content = 'Deinstallieren'
                    Width = 100
                    Height = 26
                    Margin = [Windows.Thickness]'6,0,0,0'
                    VerticalAlignment = 'Center'
                    IsEnabled = $false
                    Tag = @{ Data = $pkgData; Action = 'Uninstall' }
                }

                $pkgData.InstallButton = $installBtn
                $pkgData.UpdateButton = $updateBtn
                $pkgData.UninstallButton = $uninstallBtn

                $row.AddChild($checkBox)
                $row.AddChild($installBtn)
                $row.AddChild($updateBtn)
                $row.AddChild($uninstallBtn)

                if ($pkg.note) {
                    $noteBtn = [Windows.Controls.Button]@{
                        Content = 'Wichtig'
                        Width = 70
                        Height = 26
                        Margin = [Windows.Thickness]'6,0,0,0'
                        VerticalAlignment = 'Center'
                        Background = '#DC3545'
                        Foreground = 'White'
                        FontWeight = 'SemiBold'
                        Tag = @{ Name = $pkg.name; Note = $pkg.note }
                    }
                    $noteBtn.Add_Click({
                        param($sender, $e)
                        $noteWindow = [Windows.Window]@{
                            Title = "Wichtiger Hinweis: $($sender.Tag.Name)"
                            Width = 480
                            Height = 300
                            WindowStartupLocation = 'CenterOwner'
                            Owner = $window
                            ResizeMode = 'CanResizeWithGrip'
                        }
                        $noteGrid = [Windows.Controls.Grid]@{ Margin = [Windows.Thickness]'10' }
                        $noteGrid.RowDefinitions.Add([Windows.Controls.RowDefinition]@{ Height = [Windows.GridLength]'*' })
                        $noteGrid.RowDefinitions.Add([Windows.Controls.RowDefinition]@{ Height = [Windows.GridLength]'Auto' })
                        $txtNote = [Windows.Controls.TextBox]@{
                            Text = $sender.Tag.Note
                            IsReadOnly = $true
                            TextWrapping = 'Wrap'
                            VerticalScrollBarVisibility = 'Auto'
                            AcceptsReturn = $true
                            FontFamily = 'Consolas'
                            FontSize = 12
                            Margin = [Windows.Thickness]'0,0,0,10'
                        }
                        $noteGrid.AddChild($txtNote)
                        $btnClose = [Windows.Controls.Button]@{
                            Content = 'Schließen'
                            Width = 100
                            Height = 30
                            HorizontalAlignment = 'Right'
                        }
                        $btnClose.SetValue([Windows.Controls.Grid]::RowProperty, 1)
                        $btnClose.Add_Click({ $noteWindow.Close() })
                        $noteGrid.AddChild($btnClose)
                        $noteWindow.Content = $noteGrid
                        $noteWindow.ShowDialog() | Out-Null
                    })
                    $row.AddChild($noteBtn)
                }

                $groupStack.AddChild($row)
                $wingetPackages.Add($pkgData)
            }
            $groupBox.Content = $groupStack
            $stackPanel.AddChild($groupBox)
        }

        $scrollViewer.Content = $stackPanel
        $tabItem.Content = $scrollViewer
        [void]$tabMain.Items.Add($tabItem)
    }

    $btnRestartAdmin = $window.FindName('btnRestartAsAdmin')
    $btnRestartUser  = $window.FindName('btnRestartAsUser')
    $btnExit         = $window.FindName('btnExit')
    $txtAdminWarn    = $window.FindName('txtAdminWarn')
    $txtAdminOk      = $window.FindName('txtAdminOk')

    if ($isAdmin) {
        $txtAdminOk.Visibility = 'Visible'
        $btnRestartUser.Visibility = 'Visible'
        Write-Log -Level 'INFO' -Message "Als Administrator gestartet"
    } else {
        $txtAdminWarn.Visibility = 'Visible'
        $btnRestartAdmin.Visibility = 'Visible'
        Write-Log -Level 'WARN' -Message "Ohne Administrator-Rechte gestartet"
    }

    function Save-WindowConfig {
        @{
            Width  = $window.Width
            Height = $window.Height
            Left   = $window.Left
            Top    = $window.Top
        } | ConvertTo-Json | Set-Content -Path $windowStatePath -Force
    }

    $btnRestartAdmin.Add_Click({
        Write-Log -Level 'INFO' -Message "Neustart als Administrator angefordert"
        Stop-Transcript | Out-Null
        Save-WindowConfig
        Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile', '-File', "`"$ScriptPath`""
        $window.Close()
    })

    $btnRestartUser.Add_Click({
        Write-Log -Level 'INFO' -Message "Neustart als Benutzer angefordert"
        Stop-Transcript | Out-Null
        Save-WindowConfig
        # Ein elevierter Prozess kann sich nicht selbst de-elevieren; Start-Process wuerde die
        # Adminrechte vererben. Der Umweg ueber Shell.Application laesst explorer.exe (laeuft immer
        # mit dem normalen Benutzertoken) den neuen Prozess starten, wodurch dieser nicht elevated ist.
        $shell = New-Object -ComObject Shell.Application
        $shell.ShellExecute('pwsh.exe', "-NoProfile -File `"$ScriptPath`"", $DataPath, 'open', 1)
        $window.Close()
    })

    $btnExit.Add_Click({
        Write-Log -Level 'INFO' -Message "Beenden geklickt"
        Stop-Transcript | Out-Null
        Save-WindowConfig
        $window.Close()
    })

    Add-StatusLine -Text "Suche nach installierten Apps ..." -Color '#005A9E'
    $installedIds = @{}
    try {
        $wingetOutput = winget list --accept-source-agreements 2>$null
        foreach ($line in $wingetOutput) {
            if ($line -match '\S') {
                foreach ($pkg in $wingetPackages) {
                    if ($line -match [regex]::Escape($pkg.Id)) {
                        $installedIds[$pkg.Id.ToLower()] = $true
                    }
                }
            }
        }
    } catch {}
    Add-StatusLine -Text "$($installedIds.Count) installierte Apps erkannt." -Color '#333333'
    Write-Log -Level 'INFO' -Message "winget list Scan abgeschlossen: $($installedIds.Count) Pakete erkannt"

    Add-StatusLine -Text "Suche nach verfügbaren Updates ..." -Color '#005A9E'
    $updatableIds = @{}
    $updatableNames = [System.Collections.Generic.List[string]]::new()
    try {
        $wingetUpgradeOutput = winget upgrade --include-unknown --accept-source-agreements 2>$null
        foreach ($line in $wingetUpgradeOutput) {
            if ($line -match '\S') {
                foreach ($pkg in $wingetPackages) {
                    if (-not $updatableIds.ContainsKey($pkg.Id.ToLower()) -and $line -match [regex]::Escape($pkg.Id)) {
                        $updatableIds[$pkg.Id.ToLower()] = $true
                        $updatableNames.Add($pkg.Name)
                    }
                }
            }
        }
    } catch {}
    Add-StatusLine -Text "$($updatableIds.Count) Updates verfügbar." -Color '#333333'
    if ($updatableNames.Count -gt 0) {
        Add-StatusLine -Text ($updatableNames -join ', ') -Color '#333333'
    }
    Write-Log -Level 'INFO' -Message "winget upgrade Scan abgeschlossen: $($updatableIds.Count) Updates verfügbar ($($updatableNames -join ', '))"

    foreach ($pkg in $wingetPackages) {
        $isInstalled = $installedIds.ContainsKey($pkg.Id.ToLower())
        if ($isInstalled) {
            $pkg.CheckBox.IsChecked = $true
            $pkg.CheckBox.Content = "$($pkg.Name) (installiert)"
            $pkg.InstallButton.IsEnabled = $false
        }
        $pkg.UpdateButton.IsEnabled = $pkg.AllowedByElevation -and $updatableIds.ContainsKey($pkg.Id.ToLower())
        $pkg.UninstallButton.IsEnabled = $pkg.AllowedToUninstall -and $isInstalled

        $clickHandler = {
            param($sender, $e)
            $tag = $sender.Tag
            $sender.IsEnabled = $false
            $sender.Content = '...'
            $script:installQueue.Enqueue(@{
                Data = $tag.Data
                Action = $tag.Action
            })
        }
        $pkg.InstallButton.Add_Click($clickHandler)
        $pkg.UpdateButton.Add_Click($clickHandler)
        $pkg.UninstallButton.Add_Click($clickHandler)
    }

    $script:installQueue = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new())

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)

    $timer.Add_Tick({
        if ($script:isRunning) {
            if ($script:wingetLogFile -and (Test-Path $script:wingetLogFile)) {
                $lines = @(Get-Content $script:wingetLogFile -ErrorAction SilentlyContinue)
                if ($lines.Count -gt $script:loggedLineCount) {
                    foreach ($line in $lines[$script:loggedLineCount..($lines.Count - 1)]) {
                        if ($line -match '\S') {
                            Add-StatusLine -Text $line -Color '#555555'
                        }
                    }
                    $script:loggedLineCount = $lines.Count
                }
            }
            $job = Get-Job -Name "WingetJob" -ErrorAction SilentlyContinue
            if ($job -and $job.State -eq 'Completed') {
                $res = Receive-Job -Name "WingetJob"
                Remove-Job -Name "WingetJob"
                $script:wingetLogFile = $null
                $entry = $script:currentEntry
                $data = $entry.Data

                if ($res.ExitCode -eq 0) {
                    switch ($entry.Action) {
                        'Uninstall' {
                            $data.CheckBox.IsChecked = $false
                            $data.CheckBox.Content = $data.Name
                            $data.UninstallButton.Content = 'Deinstallieren'
                            $data.UninstallButton.IsEnabled = $false
                            $data.InstallButton.IsEnabled = $data.AllowedByElevation
                            $data.UpdateButton.IsEnabled = $false
                            Add-StatusLine -Text "$($data.Name) erfolgreich deinstalliert" -Color '#28A745'
                        }
                        'Update' {
                            $data.CheckBox.IsChecked = $true
                            $data.CheckBox.Content = "$($data.Name) (installiert)"
                            $data.UpdateButton.Content = 'OK'
                            Add-StatusLine -Text "$($data.Name) erfolgreich aktualisiert" -Color '#28A745'
                        }
                        default {
                            $data.CheckBox.IsChecked = $true
                            $data.CheckBox.Content = "$($data.Name) (installiert)"
                            $data.InstallButton.Content = 'OK'
                            $data.UninstallButton.IsEnabled = $data.AllowedToUninstall
                            Add-StatusLine -Text "$($data.Name) erfolgreich installiert" -Color '#28A745'
                        }
                    }
                    Write-WingetLog -Level 'OK' -PackageId $data.Id -Message "Erfolgreich"
                } else {
                    $btn = switch ($entry.Action) {
                        'Update'    { $data.UpdateButton }
                        'Uninstall' { $data.UninstallButton }
                        default     { $data.InstallButton }
                    }
                    $btn.Content = 'Fehler'
                    $btn.IsEnabled = $true
                    Add-StatusLine -Text "Fehler bei $($data.Name)" -Color '#DC3545'
                    Write-WingetLog -Level 'ERROR' -PackageId $data.Id -Message ($res.Output -join "`n")
                }

                $script:isRunning = $false
            }
            return
        }

        $entry = $null
        try { $entry = $script:installQueue.Dequeue() } catch { return }

        $script:isRunning = $true
        $script:currentEntry = $entry
        $data = $entry.Data
        $script:loggedLineCount = 0
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $script:wingetLogFile = Join-Path $logsDir "winget-$($data.Id -replace '[\.\\]','-')-$($entry.Action)-$timestamp.log"
        $startText = switch ($entry.Action) {
            'Update'    { "Aktualisiere $($data.Name) ..." }
            'Uninstall' { "Deinstalliere $($data.Name) ..." }
            default     { "Installiere $($data.Name) ..." }
        }
        Add-StatusLine -Text $startText -Color '#005A9E'
        '' | Set-Content $script:wingetLogFile -Force
        Write-WingetLog -Level 'INFO' -PackageId $data.Id -Message "$($entry.Action) gestartet"

        Start-Job -Name "WingetJob" -ScriptBlock {
            param($Id, $Scope, $IsAdmin, $LogPath, $Action)
            $OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8
            $verb = switch ($Action) {
                'Update'    { 'upgrade' }
                'Uninstall' { 'uninstall' }
                default     { 'install' }
            }
            $wingetArgs = @($verb,'--id',$Id,'--silent','--accept-source-agreements','--verbose-logs')
            switch ($Action) {
                'Update' {
                    $wingetArgs += '--accept-package-agreements'
                    $wingetArgs += '--include-unknown'
                }
                'Uninstall' {
                    # winget lehnt Uninstall ab, wenn --scope nicht exakt zum internen Scope-Tag des
                    # installierten Pakets passt - daher hier bewusst keinen Scope erzwingen.
                }
                default {
                    $wingetArgs += '--accept-package-agreements'
                    $wingetArgs += '--source'
                    $wingetArgs += 'winget'
                    if (-not $IsAdmin) {
                        $wingetArgs += '--scope'
                        $wingetArgs += 'user'
                    } elseif ($Scope -and $Scope -ne 'none') {
                        $wingetArgs += '--scope'
                        $wingetArgs += $Scope
                    }
                }
            }
            & winget $wingetArgs 2>&1 | Tee-Object -FilePath $LogPath | Out-Null
            @{ ExitCode = $LASTEXITCODE; Output = @() }
        } -ArgumentList $data.Id, $data.Scope, $data.IsAdmin, $script:wingetLogFile, $entry.Action
    })

    $script:isRunning = $false
    $script:wingetLogFile = $null
    $timer.Start()

    $window.Add_Closing({
        Write-Log -Level 'INFO' -Message "GUI geschlossen"
        Save-WindowConfig
        $timer.Stop()
        Get-Job -Name "WingetJob" -ErrorAction SilentlyContinue | Stop-Job | Remove-Job
    })

    Write-Log -Level 'INFO' -Message "GUI geöffnet"
    $window.ShowDialog() | Out-Null
    Write-Log -Level 'END' -Message "=== Session beendet $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
}
