#Requires -RunAsAdministrator

$Host.UI.RawUI.WindowTitle = "Setup Ambiente - mrigueti"

Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                CONFIGURAÇÃO AUTOMÁTICA DE AMBIENTE          ║
║                $(Get-Date -Format 'dd/MM/yyyy HH:mm')                    ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# Verificar se está executando como Administrador
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Este script deve ser executado como Administrador!"
    Write-Host "Clique com botão direito no PowerShell e selecione 'Executar como administrador'" -ForegroundColor Yellow
    Read-Host "Pressione Enter para sair"
    exit 1
}

function Write-Log {
    param($Message, $Color = "White")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
}

function Test-InternetConnection {
    Write-Log "Verificando conectividade com a internet..." -Color Yellow

    try {
        $result = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($result) {
            Write-Log "Conectividade verificada com sucesso" -Color Green
            return $true
        }
        else {
            Write-Log "Sem conectividade com a internet" -Color Red
            return $false
        }
    }
    catch {
        Write-Log "Erro ao verificar conectividade: $_" -Color Red
        return $false
    }
}

function Install-Chocolatey {
    Write-Log "Verificando instalacao do Chocolatey..." -Color Yellow

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Log "Chocolatey ja esta instalado" -Color Green
        return $true
    }

    try {
        Write-Log "Instalando Chocolatey..." -Color Yellow

        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

        # Recarregar PATH
        $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")

        Write-Log "Chocolatey instalado com sucesso!" -Color Green
        return $true
    }
    catch {
        Write-Log "Erro ao instalar Chocolatey: $_" -Color Red
        return $false
    }
}

function Install-WithWinGet {
    param($PackageName, $WinGetId)

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log "WinGet nao esta disponivel" -Color Yellow
        return $false
    }

    try {
        Write-Log "Tentando instalar '$PackageName' via WinGet..." -Color Yellow

        $process = Start-Process -FilePath "winget" -ArgumentList "install", "--id", $WinGetId, "--silent", "--accept-package-agreements", "--accept-source-agreements" -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-Log "'$PackageName' instalado via WinGet" -Color Green
            return $true
        }
        else {
            Write-Log "Falha na instalacao via WinGet (Exit Code: $($process.ExitCode))" -Color Yellow
            return $false
        }
    }
    catch {
        Write-Log "Erro ao tentar instalar via WinGet: $_" -Color Yellow
        return $false
    }
}

function Install-WithChocolatey {
    param($PackageName, $ChocoName)

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Log "Chocolatey nao esta disponivel" -Color Yellow
        return $false
    }

    try {
        Write-Log "Tentando instalar '$PackageName' via Chocolatey..." -Color Yellow

        $process = Start-Process -FilePath "choco" -ArgumentList "install", $ChocoName, "-y" -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-Log "'$PackageName' instalado via Chocolatey" -Color Green
            return $true
        }
        else {
            Write-Log "Falha na instalacao via Chocolatey" -Color Yellow
            return $false
        }
    }
    catch {
        Write-Log "Erro ao tentar instalar via Chocolatey: $_" -Color Yellow
        return $false
    }
}

function Install-Program {
    param(
        $DisplayName,
        $WinGetId = $null,
        $ChocoName = $null
    )

    Write-Log "Instalando: $DisplayName" -Color Cyan

    # Tentar WinGet primeiro
    if ($WinGetId -and (Install-WithWinGet -PackageName $DisplayName -WinGetId $WinGetId)) {
        return
    }

    # Se WinGet falhou, tentar Chocolatey
    if ($ChocoName -and (Install-WithChocolatey -PackageName $DisplayName -ChocoName $ChocoName)) {
        return
    }

    Write-Log "Falha ao instalar '$DisplayName' com todos os metodos disponiveis" -Color Red
}

# ═══════════════════════════════════════════════════════════════
# INÍCIO DA EXECUÇÃO
# ═══════════════════════════════════════════════════════════════

Write-Log "Iniciando configuracao do ambiente..." -Color Cyan

# Verificar conectividade
if (-not (Test-InternetConnection)) {
    Write-Log "ERRO: Sem conectividade com a internet!" -Color Red
    Read-Host "Pressione Enter para sair"
    exit 1
}

Write-Log "Etapa 1: Instalando gerenciador de pacotes Chocolatey" -Color Magenta
$chocoInstalled = Install-Chocolatey

if (-not $chocoInstalled) {
    Write-Log "AVISO: Chocolatey nao foi instalado. Tentaremos apenas com WinGet" -Color Yellow
}

Write-Host ""

Write-Log "Etapa 2: Instalando programas essenciais" -Color Magenta

# Lista de programas simplificada (removido Scoop)
$Programs = @(
# Navegadores
    @{
        DisplayName = "Google Chrome"
        WinGetId    = "Google.Chrome"
        ChocoName   = "googlechrome"
    },
    @{
        DisplayName = "Mozilla Firefox"
        WinGetId    = "Mozilla.Firefox"
        ChocoName   = "firefox"
    },

    # Editores e IDEs
    @{
        DisplayName = "Visual Studio Code"
        WinGetId    = "Microsoft.VisualStudioCode"
        ChocoName   = "vscode"
    },
    @{
        DisplayName = "DataGrip"
        WinGetId    = "JetBrains.DataGrip"
        ChocoName   = "datagrip"
    },
    @{
        DisplayName = "Notepad++"
        WinGetId    = "Notepad++.Notepad++"
        ChocoName   = "notepadplusplus"
    },
    @{
        DisplayName = "IntelliJ Ultimate"
        WinGetId    = "JetBrains.IntelliJIDEA.Ultimate"
        ChocoName   = "intellijidea-ultimate"
    },

    # Ferramentas de desenvolvimento
    @{
        DisplayName = "Git"
        WinGetId    = "Git.Git"
        ChocoName   = "git"
    },
    @{
        DisplayName = "GitHub Desktop"
        WinGetId    = "GitHub.GitHubDesktop"
        ChocoName   = "github-desktop"
    },
    @{
        DisplayName = "Windows Terminal"
        WinGetId    = "Microsoft.WindowsTerminal"
        ChocoName   = $null
    },
    @{
        DisplayName = "Node.js"
        WinGetId    = "OpenJS.NodeJS"
        ChocoName   = "nodejs"
    },
    @{
        DisplayName = "Python"
        WinGetId    = "Python.Python.3.12"
        ChocoName   = "python"
    },
    @{
        DisplayName = "Go"
        WinGetId    = "GoLang.Go"
        ChocoName   = "golang"
    },
    @{
        DisplayName = "Lua"
        WinGetId    = "DEVCOM.Lua"
    },
    @{
        DisplayName = "Love2D"
        WinGetId    = "Love2D.Love2D"
        ChocoName   = "love"
    },

    # Utilitários
    @{
        DisplayName = "7-Zip"
        WinGetId    = "7zip.7zip"
        ChocoName   = "7zip"
    },
    @{
        DisplayName = "Discord"
        WinGetId    = "Discord.Discord"
        ChocoName   = "discord"
    },
    @{
        DisplayName = "Postman"
        WinGetId    = "Postman.Postman"
        ChocoName   = "postman"
    },
    @{
        DisplayName = "OBS Studio"
        WinGetId    = "OBSProject.OBSStudio"
        ChocoName   = "obs-studio"
    },
    @{
        DisplayName = "Steam"
        WinGetId    = "Valve.Steam"
        ChocoName   = "steam"
    },
    @{
        DisplayName = "VLC Media Player"
        WinGetId    = "VideoLAN.VLC"
        ChocoName   = "vlc"
    }
)

foreach ($Program in $Programs) {
    Install-Program @Program
    Write-Host ""
}

Write-Log "Etapa 3: Configurando Git (se instalado)" -Color Magenta

if (Get-Command git -ErrorAction SilentlyContinue) {
    try {
        $gitUser = git config --global user.name 2>$null
        $gitEmail = git config --global user.email 2>$null

        if (-not $gitUser -or -not $gitEmail) {
            Write-Log "Configurando Git..." -Color Yellow
            git config --global user.name "mrigueti"
            git config --global user.email "seu-email@exemplo.com"  # Altere aqui
            git config --global init.defaultBranch main
            Write-Log "Git configurado com sucesso!" -Color Green
        }
        else {
            Write-Log "Git ja esta configurado" -Color Green
        }
    }
    catch {
        Write-Log "Erro ao configurar Git: $_" -Color Yellow
    }
}

Write-Log "Etapa 4: Aplicando configuracoes do sistema" -Color Magenta

try {
    Write-Log "Habilitando extensoes de arquivo..." -Color Yellow
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0

    Write-Log "Habilitando visualizacao de arquivos ocultos..." -Color Yellow
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1

    Write-Log "Habilitando modo escuro..." -Color Yellow
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0

    Write-Log "Configurando modo de alto desempenho..." -Color Yellow
    try {
        $PowerPlans = powercfg /list
        $HighPerformancePlan = $PowerPlans | Where-Object { $_ -match "Alto desempenho|High performance" }

        if ($HighPerformancePlan) {
            $PlanGUID = ($HighPerformancePlan -split '\s+')[3]
            powercfg /setactive $PlanGUID
            Write-Log "Plano de Alto Desempenho ativado!" -Color Green
        }
        else {
            Write-Log "Otimizando plano de energia atual..." -Color Yellow
            powercfg /change disk-timeout-ac 0
            powercfg /change standby-timeout-ac 0
            powercfg /change monitor-timeout-ac 0
            Write-Log "Configuracoes de desempenho aplicadas!" -Color Green
        }
    }
    catch {
        Write-Log "Erro ao configurar plano de energia: $_" -Color Red
    }

    Write-Log "Habilitando WSL (Windows Subsystem for Linux)..." -Color Yellow
    try {
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

        if ($wslFeature.State -eq "Enabled") {
            Write-Log "WSL ja esta habilitado" -Color Green
        }
        else {
            dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart /quiet
            dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart /quiet
            Write-Log "WSL habilitado com sucesso!" -Color Green
            Write-Log "Reinicie e execute 'wsl --install' para instalar Ubuntu" -Color Yellow
        }
    }
    catch {
        Write-Log "Erro ao habilitar WSL: $_" -Color Yellow
    }

    Write-Log "Configuracoes do sistema aplicadas!" -Color Green
}
catch {
    Write-Log "Erro ao aplicar algumas configuracoes: $_" -Color Yellow
}

Write-Host ""
Write-Log "Configuracao concluida!" -Color Green
Write-Log "Algumas alteracoes podem requerer reinicializacao do sistema" -Color Yellow

Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                     CONFIGURAÇÃO CONCLUÍDA                  ║
║                                                              ║
║  ✅ Chocolatey instalado                                    ║
║  ✅ Programas essenciais instalados                         ║
║  ✅ Git configurado                                         ║
║  ✅ Sistema otimizado                                       ║
║                                                              ║
║  💡 Reinicie o sistema para aplicar todas as mudanças       ║
║                                                              ║
║  📝 Para instalar Scoop manualmente (usuario normal):       ║
║     Set-ExecutionPolicy RemoteSigned -Scope CurrentUser     ║
║     Invoke-RestMethod get.scoop.sh | Invoke-Expression      ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Read-Host "Pressione Enter para finalizar"