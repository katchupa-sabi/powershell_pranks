# Desativa o UAC (User Account Control) no Windows (necessario fazer restart para aplicar as alterações)

$conteudo = @'
$Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance"
New-Item -Path $Path -Force | Out-Null
New-ItemProperty -Path $Path -Name "Enabled" -PropertyType DWord -Value 0 -Force | Out-Null
'@

try {
    $loggedUser = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).UserName
}
catch {
    Write-Host "Erro ao obter o utilizador ativo."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($loggedUser)) {
    Write-Host "Nenhum utilizador interativo encontrado."
    exit 1
}

$userName = ($loggedUser -split '\\')[-1]

$taskName = "app_down"

$ficheiro = "C:\Users\$userName\AppData\Local\mute5.ps1"
$vbsPath = "C:\Users\$userName\AppData\Local\unmute5.vbs"

$userLocalPath = "C:\Users\$userName\AppData\Local"

if (!(Test-Path $userLocalPath)) {
    Write-Host "Perfil do utilizador não encontrado: $userLocalPath"
    exit 1
}

$vbsContent = @"
Set shell = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
psPath = "$ficheiro"
shell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & psPath & """", 0, True
"@

if (Test-Path $ficheiro) {
    Remove-Item -Path $ficheiro -Force -ErrorAction SilentlyContinue
}

if (Test-Path $vbsPath) {
    Remove-Item -Path $vbsPath -Force -ErrorAction SilentlyContinue
}

Set-Content -Path $ficheiro -Value $conteudo -Encoding UTF8 -Force
Set-Content -Path $vbsPath -Value $vbsContent -Encoding ASCII -Force

$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
}

$action = New-ScheduledTaskAction `
    -Execute "$env:SystemRoot\System32\wscript.exe" `
    -Argument "`"$vbsPath`""

$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddSeconds(60)

$principal = New-ScheduledTaskPrincipal `
    -UserId $loggedUser `
    -LogonType Interactive

$settings = New-ScheduledTaskSettingsSet `
    -Hidden `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Force | Out-Null

Start-ScheduledTask -TaskName $taskName

Start-Sleep -Seconds 3

Unregister-ScheduledTask `
    -TaskName $taskName `
    -Confirm:$false `
    -ErrorAction SilentlyContinue

if (Test-Path $ficheiro) {
    Remove-Item -Path $ficheiro -Force -ErrorAction SilentlyContinue
}

if (Test-Path $vbsPath) {
    Remove-Item -Path $vbsPath -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 5
New-ItemProperty -Path HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system -Name EnableLUA -PropertyType DWord -Value 0 -Force
#Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 0" -WindowStyle Hidden

exit