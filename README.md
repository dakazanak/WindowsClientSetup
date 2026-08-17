# WindowsClientSetup

Grafisches Werkzeug zur automatisierten Einrichtung eines neuen Windows Clients. Installiert Anwendungen per **winget** und konfiguriert Windows-Einstellungen über eine PowerShell/WPF-Oberfläche mit Checkbox-Auswahl.

> Erfordert **PowerShell 7+** und Administrator-Rechte für vollen Funktionsumfang.

## Direktaufruf

```powershell
irm https://raw.githubusercontent.com/dakazanak/WindowsClientSetup/master/Start-WindowsClientForge.ps1 | iex
```