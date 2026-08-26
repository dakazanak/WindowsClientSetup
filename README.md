# WindowsClientSetup

Grafische Werkzeuge zur automatisierten Einrichtung und Verwaltung von Entwicklungsumgebungen.

## Enthaltene Tools

### Windows Client Setup

PowerShell/WPF-Oberfläche zur Installation, Aktualisierung und Deinstallation von Windows-Anwendungen per **winget**.

- Switch-Toggles als Statusindikatoren pro Paket
- Installieren / Update / Deinstallieren pro Zeile
- Cross-Launch zum WSL Debian Setup
- Admin-/User-Scope je nach Paket
- Winget-Output-Logging pro Installation
- Session-Transkript in `logs/session.log`

**Start:** `.\Start-WindowsClientForge.ps1`

### WSL Debian Setup

PowerShell/WPF-Oberfläche zur Verwaltung von apt-Paketen und zusätzlichen Tools in einer WSL-Debian-Instanz.

- Switch-Toggles als Statusindikatoren pro Paket
- Installieren / Update / Deinstallieren pro Zeile
- Cross-Launch zum Windows Client Setup
- sudo-Passwortverwaltung (Session-Speicher, kein Logging)
- apt- und Binary-Erkennung (dpkg + `command -v`)
- Setup-/Uninstall-Commands für externe Paketquellen (GitHub CLI, Terraform, Azure CLI, pipx, uv, yq)
- apt upgrade per Dialog
- Session-Transkript in `logs/session.log`
- Apt-Output-Logging pro Aktion in `logs/apt-<name>-<aktion>-<timestamp>.log`

**Start:** `.\Setup-WslDebian.ps1`

## Voraussetzungen

- **PowerShell 7+**
- **winget** (für Windows Client Setup)
- **WSL mit Debian** (für WSL Debian Setup)
- Administrator-Rechte für vollen Funktionsumfang des Windows-Tools

## Projektstruktur

```
config/
  packages.yaml              # Windows winget-Paketdefinitionen
  wsl-debian-packages.yaml   # Debian apt-/Binary-Paketdefinitionen
module/
  WindowsClientSetup/        # Windows Tool (winget)
  WslDebianSetup/            # Debian Tool (apt)
  EnvironmentBootstrap/      # Gemeinsame PowerShell-Umgebungschecks
logs/                        # Logging (Session, apt, winget)
```

## Version

Siehe `VERSION`-Datei und Tags.