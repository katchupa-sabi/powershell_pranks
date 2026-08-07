# Desativa o UAC (User Account Control) no Windows
$Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance"
New-Item -Path $Path -Force | Out-Null
New-ItemProperty -Path $Path -Name "Enabled" -PropertyType DWord -Value 0 -Force | Out-Null
Start-Sleep -Seconds 5
New-ItemProperty -Path HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system -Name EnableLUA -PropertyType DWord -Value 0 -Force
#Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 0" -WindowStyle Hidden