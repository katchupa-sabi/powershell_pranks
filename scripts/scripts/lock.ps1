$conteudo = @'
rundll32.exe user32.dll,LockWorkStation
exit
'@


$users = quser | Select-Object -Skip 1 | ForEach-Object {
    $parts = ($_ -replace "\s{2,}", ",").Split(",")
    if ($parts.Count -ge 6) {
        [PSCustomObject]@{
            UserName    = $parts[0].Trim()
            SessionName = $parts[1].Trim()
            ID          = $parts[2].Trim()
            State       = $parts[3].Trim()
            IdleTime    = $parts[4].Trim()
            LogonTime   = $parts[5].Trim()
        }
    }
}

$activeUser = $users | Where-Object { $_.State -eq "Active" } | Select-Object -First 1


if ($activeUser) {
    $taskName = "app_down"
    $userName = $activeUser.UserName.TrimStart('>')
    $computerName = $env:COMPUTERNAME

    
    $ficheiro = "C:\Users\$userName\AppData\Local\mute5.ps1"
    $vbsPath = "C:\Users\$userName\AppData\Local\unmute5.vbs"

    $vbsContent = @"
Set shell = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)

psPath = "$ficheiro"

shell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & psPath & """", 0, True
"@
    #if (Test-Path "$ficheiro") {
    #    Remove-Item "$ficheiro" -Force
    #}
    Set-Content -Path $ficheiro -Value $conteudo -Encoding UTF8
    Set-Content -Path $vbsPath -Value $vbsContent -Encoding ASCII

    # Criar ação da tarefa
    $action = New-ScheduledTaskAction -Execute "$vbsPath"

    # Criar trigger para rodar uma vez imediatamente
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(60)

    # Criar principal (executa como usuário atual, oculto)
    $principal = New-ScheduledTaskPrincipal -UserId "$computerName\$userName"
    # Registrar tarefa oculta
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings (New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries)

    # Rodar a tarefa
    Start-ScheduledTask -TaskName $taskName

    # Espera um pouco para garantir execução
    Start-Sleep -Seconds 3

    # Deletar tarefa
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}


# Remover o ficheiro PS1
Remove-Item "$ficheiro" -Force
Remove-Item "$vbsPath" -Force

exit