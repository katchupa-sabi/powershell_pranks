$conteudo = @'
$RegPath = "HKCU:\Software\Policies\Microsoft\Windows\System"
$ValueName = "DisableCMD"

if (!(Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}

try {
    $CurrentValue = (Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction Stop).DisableCMD
}
catch {
    $CurrentValue = 0
}

Write-Host "Estado atual do CMD:" -NoNewline

switch ($CurrentValue) {
    0 { Write-Host " HABILITADO" }
    1 { Write-Host " DESABILITADO (scripts permitidos)" }
    2 { Write-Host " DESABILITADO (completamente bloqueado)" }
    default { Write-Host " DESCONHECIDO ($CurrentValue)" }
}

if ($CurrentValue -eq 0) {
    Set-ItemProperty -Path $RegPath -Name $ValueName -Value 1 -Type DWord -Force
    $msg = "CMD foi DESABILITADO."
}
else {
    Set-ItemProperty -Path $RegPath -Name $ValueName -Value 0 -Type DWord -Force
    $msg = "CMD foi HABILITADO."
}

Write-Host $msg
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

exit