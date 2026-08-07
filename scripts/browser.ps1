# ============================================================
# Copiar histórico dos principais browsers - Windows
# Chrome, Edge, Brave, Vivaldi, Opera, Opera GX e Firefox
# ============================================================

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$Destino = Join-Path $env:USERPROFILE "Desktop\Browser_History_$Timestamp"

New-Item -ItemType Directory -Path $Destino -Force | Out-Null

Write-Host "Destino: $Destino"
Write-Host ""

function Copy-HistoryFile {
    param (
        [string]$Source,
        [string]$Destination
    )

    if (Test-Path $Source) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null

        try {
            Copy-Item $Source -Destination $Destination -Force -ErrorAction Stop
            Write-Host "[OK] $Source"
        }
        catch {
            Write-Warning "Nao foi possivel copiar: $Source"
            Write-Warning $_.Exception.Message
        }
    }
}

# ------------------------------------------------------------
# Browsers Chromium
# ------------------------------------------------------------

$ChromiumBrowsers = @{
    "Chrome" = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data"
    "Edge"   = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data"
    "Brave"  = Join-Path $env:LOCALAPPDATA "BraveSoftware\Brave-Browser\User Data"
    "Vivaldi" = Join-Path $env:LOCALAPPDATA "Vivaldi\User Data"
}

foreach ($Browser in $ChromiumBrowsers.GetEnumerator()) {

    $BrowserName = $Browser.Key
    $BasePath = $Browser.Value

    if (-not (Test-Path $BasePath)) {
        continue
    }

    Write-Host ""
    Write-Host "=== $BrowserName ==="

    # Default, Profile 1, Profile 2, etc.
    $Profiles = Get-ChildItem $BasePath -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -eq "Default" -or
            $_.Name -match "^Profile \d+$"
        }

    foreach ($Profile in $Profiles) {

        $ProfileDestination = Join-Path $Destino "$BrowserName\$($Profile.Name)"

        $Files = @(
            "History",
            "History-journal",
            "History-wal",
            "History-shm"
        )

        foreach ($File in $Files) {
            $Source = Join-Path $Profile.FullName $File
            Copy-HistoryFile $Source $ProfileDestination
        }
    }
}

# ------------------------------------------------------------
# Opera
# ------------------------------------------------------------

$OperaBrowsers = @{
    "Opera"    = Join-Path $env:APPDATA "Opera Software\Opera Stable"
    "Opera GX" = Join-Path $env:APPDATA "Opera Software\Opera GX Stable"
}

foreach ($Browser in $OperaBrowsers.GetEnumerator()) {

    if (-not (Test-Path $Browser.Value)) {
        continue
    }

    Write-Host ""
    Write-Host "=== $($Browser.Key) ==="

    $BrowserDestination = Join-Path $Destino $Browser.Key

    foreach ($File in @(
        "History",
        "History-journal",
        "History-wal",
        "History-shm"
    )) {
        Copy-HistoryFile `
            (Join-Path $Browser.Value $File) `
            $BrowserDestination
    }
}

# ------------------------------------------------------------
# Firefox
# ------------------------------------------------------------

$FirefoxProfiles = Join-Path $env:APPDATA "Mozilla\Firefox\Profiles"

if (Test-Path $FirefoxProfiles) {

    Write-Host ""
    Write-Host "=== Firefox ==="

    Get-ChildItem $FirefoxProfiles -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {

            $Profile = $_
            $ProfileDestination = Join-Path $Destino "Firefox\$($Profile.Name)"

            # places.sqlite contém histórico + bookmarks
            foreach ($File in @(
                "places.sqlite",
                "places.sqlite-wal",
                "places.sqlite-shm"
            )) {

                Copy-HistoryFile `
                    (Join-Path $Profile.FullName $File) `
                    $ProfileDestination
            }
        }
}


Write-Output "UPLOAD:$Destino"