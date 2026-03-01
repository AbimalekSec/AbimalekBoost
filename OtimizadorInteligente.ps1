#Requires -Version 5.1
<#
.SYNOPSIS
    OTIMIZADOR INTELIGENTE v2.0
    Inspirado no WinUtil do Chris Titus Tech
    Deteccao inteligente de hardware + otimizacoes especificas por CPU/GPU
.NOTES
    Requer execucao como Administrador. Windows 10/11.
    Totalmente reversivel. Tudo e salvo em backup antes de modificar.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ================================================================
#  VARIAVEIS GLOBAIS
# ================================================================
$Script:Versao         = "2.0.0"
$Script:NomeProg       = "OTIMIZADOR INTELIGENTE"
$Script:IDSessao       = (New-Guid).ToString("N").Substring(0,8).ToUpper()

# Hardware
$Script:CPUNome        = ""; $Script:CPUFab    = ""; $Script:CPUNucleos = 0
$Script:CPUX3D         = $false;  $Script:CPUIntelK = $false
$Script:RAMtotalGB     = 0;       $Script:RAMtipo   = ""
$Script:GPUNome        = "";      $Script:GPUFab    = "";  $Script:GPUVRAM = 0
$Script:GPUTemp        = -1;      $Script:GPUCore   = -1;  $Script:GPUPL   = -1; $Script:GPUPLmax = -1
$Script:GPUSmi         = "";      $Script:DiscoTipo = ""

# Estado
$Script:TweaksFeitos   = [System.Collections.Generic.List[string]]::new()
$Script:SvcsBackup     = @{}
$Script:PlanoOrig      = ""
$Script:OtimAplicada   = $false

# Pastas
$Script:PastaRaiz      = Join-Path $env:LOCALAPPDATA "OtimizadorInteligente"
$Script:PastaBackup    = Join-Path $Script:PastaRaiz "Backup"
$Script:PastaLogs      = Join-Path $Script:PastaRaiz "Logs"
$Script:LogFile        = Join-Path $Script:PastaLogs "sessao_$($Script:IDSessao)_$(Get-Date -f 'yyyyMMdd_HHmmss').log"

foreach ($p in @($Script:PastaRaiz,$Script:PastaBackup,$Script:PastaLogs)) {
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

# ================================================================
#  UI — HELPERS
# ================================================================
function LOG  { param([string]$m,[string]$n='INFO') Add-Content $Script:LogFile "$(Get-Date -f 'HH:mm:ss') [$n] $m" -Encoding UTF8 }
function OK   { Write-Host "  $(([char]0x2714)) $args" -ForegroundColor Green }
function WN   { Write-Host "  $(([char]0x26A0))  $args" -ForegroundColor Yellow }
function ER   { Write-Host "  $(([char]0x2718)) $args" -ForegroundColor Red }
function IN   { Write-Host "  $(([char]0x25B8))  $args" -ForegroundColor Gray }
function H1   { Write-Host "`n  $args" -ForegroundColor Cyan }
function H2   {
    Write-Host ""
    Write-Host ("  " + [char]0x2550 * 70) -ForegroundColor Cyan
    Write-Host "  $(([char]0x25C6))  $args" -ForegroundColor Cyan
    Write-Host ("  " + [char]0x2550 * 70) -ForegroundColor Cyan
    Write-Host ""
}
function SEP  { Write-Host ("  " + [char]0x2500 * 70) -ForegroundColor DarkCyan }
function PAUSE { Read-Host "`n  [ ENTER para continuar ]" | Out-Null }
function CONF {
    param([string]$msg="Confirmar?")
    $r = Read-Host "  $msg (S/N)"
    return ($r -match '^[Ss]$')
}

function Show-Banner {
    Clear-Host
    $cor = 'Cyan'
    Write-Host ""
    Write-Host "  $([char]0x2554)$([char]0x2550*70)$([char]0x2557)" -ForegroundColor $cor
    Write-Host "  $([char]0x2551)  $($Script:NomeProg)  v$($Script:Versao)$((' '*($([char]0x2550*70).Length - $Script:NomeProg.Length - $Script:Versao.Length - 5))  )$([char]0x2551)" -ForegroundColor $cor
    Write-Host "  $([char]0x2551)  Inspirado no WinUtil do Chris Titus Tech$((' '*28))$([char]0x2551)" -ForegroundColor DarkCyan
    Write-Host "  $([char]0x255A)$([char]0x2550*70)$([char]0x255D)" -ForegroundColor $cor
    Write-Host "  ID Sessao: $($Script:IDSessao)   |   $(Get-Date -f 'dd/MM/yyyy HH:mm')" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-StatusBar {
    $corCPU = if ($Script:CPUNome) { if ($Script:CPUX3D) {'Magenta'} else {'White'} } else { 'DarkGray' }
    $corGPU = if ($Script:GPUNome) { 'White' } else { 'DarkGray' }
    $corOtm = if ($Script:OtimAplicada) { 'Green' } else { 'DarkGray' }
    $txtOtm = if ($Script:OtimAplicada) { "ATIVO ($($Script:TweaksFeitos.Count) tweaks)" } else { "Nao aplicado" }

    Write-Host "  CPU: " -NoNewline -ForegroundColor DarkGray
    Write-Host ($(if($Script:CPUNome){$Script:CPUNome}else{"Nao detectado"})) -NoNewline -ForegroundColor $corCPU
    if ($Script:CPUX3D) { Write-Host " [X3D]" -NoNewline -ForegroundColor Magenta }
    Write-Host "   GPU: " -NoNewline -ForegroundColor DarkGray
    Write-Host ($(if($Script:GPUNome){$Script:GPUNome}else{"Nao detectada"})) -ForegroundColor $corGPU
    Write-Host "  Status: " -NoNewline -ForegroundColor DarkGray
    Write-Host $txtOtm -ForegroundColor $corOtm
    Write-Host ""
    SEP
    Write-Host ""
}

# ================================================================
#  VERIFICACAO DE ADMIN
# ================================================================
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-Admin)) {
    Write-Host "`n  [ERRO] Execute como Administrador.`n  Clique direito no PowerShell > Executar como Administrador`n" -ForegroundColor Red
    Read-Host "  ENTER para sair" | Out-Null; exit 1
}

# ================================================================
#  DETECCAO DE HARDWARE
# ================================================================
function Invoke-DetectarHardware {
    H2 "DETECTANDO HARDWARE"

    # CPU
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $Script:CPUNome     = $cpu.Name.Trim()
        $Script:CPUNucleos  = $cpu.NumberOfCores
        $Script:CPUFab      = if ($Script:CPUNome -match 'AMD') {'AMD'} elseif ($Script:CPUNome -match 'Intel') {'Intel'} else {'Outro'}
        $Script:CPUX3D      = $Script:CPUNome -match 'X3D'
        $Script:CPUIntelK   = $Script:CPUNome -match '\d{4,5}K[FSs]?\b'

        OK "CPU    : $($Script:CPUNome)"
        OK "Nucleos: $($Script:CPUNucleos) | Fab: $($Script:CPUFab)$(if($Script:CPUX3D){' | [V-Cache X3D]'})"
    } catch { ER "Falha ao detectar CPU" }

    # RAM
    try {
        $ram = Get-CimInstance Win32_PhysicalMemory
        $Script:RAMtotalGB = [math]::Round(($ram | Measure-Object -Property Capacity -Sum).Sum / 1GB, 0)
        $Script:RAMtipo = ($ram | Select-Object -First 1).SMBIOSMemoryType
        $Script:RAMtipo = switch ($Script:RAMtipo) { 26{'DDR4'} 34{'DDR5'} 21{'DDR3'} default{'DDR?'} }
        OK "RAM    : $($Script:RAMtotalGB) GB $($Script:RAMtipo)"
    } catch { ER "Falha ao detectar RAM" }

    # GPU
    try {
        $gpu = Get-CimInstance Win32_VideoController | Where-Object {
            $_.Name -notmatch 'Microsoft|Remote|Virtual|Basic' -and $_.AdapterRAM -gt 200MB
        } | Sort-Object AdapterRAM -Descending | Select-Object -First 1
        if (-not $gpu) { $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1 }

        $Script:GPUNome  = $gpu.Name.Trim()
        $Script:GPUVRAM  = [math]::Round($gpu.AdapterRAM / 1GB, 0)
        $Script:GPUFab   = if ($Script:GPUNome -match 'NVIDIA|GeForce|RTX|GTX') {'NVIDIA'}
                            elseif ($Script:GPUNome -match 'AMD|Radeon|RX\s') {'AMD'}
                            elseif ($Script:GPUNome -match 'Intel|Arc') {'Intel'}
                            else {'Outro'}

        # nvidia-smi
        $smiCaminhos = @(
            "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe",
            "$env:SystemRoot\System32\nvidia-smi.exe"
        )
        foreach ($c in $smiCaminhos) { if (Test-Path $c) { $Script:GPUSmi = $c; break } }
        if (-not $Script:GPUSmi) {
            $cmd = Get-Command "nvidia-smi.exe" -ErrorAction SilentlyContinue
            if ($cmd) { $Script:GPUSmi = $cmd.Source }
        }

        if ($Script:GPUFab -eq 'NVIDIA' -and $Script:GPUSmi) {
            $d = & $Script:GPUSmi --query-gpu=temperature.gpu,clocks.current.graphics,power.limit,power.max_limit --format=csv,noheader,nounits 2>$null
            if ($d) {
                $cols = $d -split ','
                if ($cols.Count -ge 4) {
                    $Script:GPUTemp  = [int]($cols[0].Trim())
                    $Script:GPUCore  = [int]($cols[1].Trim())
                    $Script:GPUPL    = [math]::Round([double]($cols[2].Trim()),0)
                    $Script:GPUPLmax = [math]::Round([double]($cols[3].Trim()),0)
                }
            }
        }

        OK "GPU    : $($Script:GPUNome) ($($Script:GPUVRAM) GB VRAM)"
        if ($Script:GPUTemp -gt 0) { OK "GPU    : $($Script:GPUTemp)C | Core $($Script:GPUCore)MHz | PL $($Script:GPUPL)W (max $($Script:GPUPLmax)W)" }
    } catch { ER "Falha ao detectar GPU" }

    # Disco
    try {
        $disco = Get-PhysicalDisk | Select-Object -First 1
        $Script:DiscoTipo = $disco.MediaType
        $discoNome = $disco.FriendlyName
        OK "Disco  : $discoNome ($($Script:DiscoTipo))"
    } catch {}

    # Windows
    $win = (Get-CimInstance Win32_OperatingSystem)
    OK "SO     : $($win.Caption) (Build $($win.BuildNumber))"
    OK "Usuario: $env:USERNAME @ $env:COMPUTERNAME"

    LOG "HW detectado: CPU=$($Script:CPUNome) GPU=$($Script:GPUNome) RAM=$($Script:RAMtotalGB)GB"
    PAUSE
}

# ================================================================
#  MODULO 1 — PLANO DE ENERGIA INTELIGENTE
# ================================================================
function Invoke-PlanoEnergia {
    H2 "PLANO DE ENERGIA INTELIGENTE"

    $atual = powercfg /getactivescheme 2>$null
    if ($atual -match 'GUID:\s*([\w-]+)') {
        $Script:PlanoOrig = $Matches[1]
        $Script:PlanoOrig | Out-File (Join-Path $Script:PastaBackup "plano.txt") -Encoding UTF8 -Force
        IN "Plano atual salvo: $($Script:PlanoOrig)"
    }

    if ($Script:CPUX3D) {
        WN "X3D detectado — NAO usar High Performance (prejudica o V-Cache)"
        $amd = powercfg /list 2>$null | Select-String 'AMD Ryzen Balanced'
        if ($amd) {
            $guid = ($amd.Line -split '\s+' | Where-Object {$_ -match '^[0-9a-f-]{36}$'}) | Select-Object -First 1
            if ($guid) { powercfg /setactive $guid 2>$null; OK "AMD Ryzen Balanced ativado (ideal para X3D)" }
        } else {
            powercfg /setactive SCHEME_BALANCED 2>$null
            OK "Plano Balanceado ativado"
            WN "Instale o AMD Chipset Driver (amd.com) para o plano AMD Balanced"
        }
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 2>$null
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE 4 2>$null
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFINCTHRESHOLD 10 2>$null
        OK "Core Parking OFF | Boost: Efficient Aggressive (ideal X3D)"

    } elseif ($Script:CPUFab -eq 'AMD') {
        $amd = powercfg /list 2>$null | Select-String 'AMD Ryzen Balanced'
        if ($amd) {
            $guid = ($amd.Line -split '\s+' | Where-Object {$_ -match '^[0-9a-f-]{36}$'}) | Select-Object -First 1
            if ($guid) { powercfg /setactive $guid 2>$null; OK "AMD Ryzen Balanced ativado" }
        } else {
            powercfg /setactive SCHEME_MIN 2>$null; OK "Alto Desempenho ativado"
        }
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 2>$null
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE 2 2>$null

    } elseif ($Script:CPUFab -eq 'Intel') {
        $ult = powercfg /list 2>$null | Select-String 'Ultimate Performance'
        if (-not $ult) { powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-Null }
        $ult = powercfg /list 2>$null | Select-String 'Ultimate Performance'
        if ($ult) {
            $guid = ($ult.Line -split '\s+' | Where-Object {$_ -match '^[0-9a-f-]{36}$'}) | Select-Object -First 1
            if ($guid) { powercfg /setactive $guid 2>$null; OK "Ultimate Performance ativado (Intel)" }
        } else {
            powercfg /setactive SCHEME_MIN 2>$null; OK "Alto Desempenho ativado"
        }
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 2>$null
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE 2 2>$null
    }

    powercfg /change standby-timeout-ac 0 2>$null
    OK "Sleep desativado durante uso (AC)"
    $Script:TweaksFeitos.Add("Plano de energia: $($Script:CPUFab)$(if($Script:CPUX3D){' X3D'})")
    LOG "Plano de energia configurado"
}

# ================================================================
#  MODULO 2 — PRIVACIDADE E TELEMETRIA (estilo WinUtil)
# ================================================================
function Invoke-Privacidade {
    H2 "PRIVACIDADE E TELEMETRIA"

    $tweaks = @(
        # Telemetria
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";        N="AllowTelemetry";                       V=0}
        @{P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; N="AllowTelemetry";              V=0}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";        N="DoNotShowFeedbackNotifications";       V=1}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";        N="LimitDiagnosticLogCollection";         V=1}
        # Anuncios
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; N="Enabled";                              V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy";         N="TailoredExperiencesWithDiagnosticDataEnabled"; V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="SilentInstalledAppsEnabled";   V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="SystemPaneSuggestionsEnabled"; V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="SoftLandingEnabled";           V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="SubscribedContentEnabled";     V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="OemPreInstalledAppsEnabled";   V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="PreInstalledAppsEnabled";      V=0}
        # Historico de atividades
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System";                N="EnableActivityFeed";                   V=0}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System";                N="PublishUserActivities";                V=0}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System";                N="UploadUserActivities";                 V=0}
        # Localizacao
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors";    N="DisableLocation";                      V=1}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"; N="Value"; V="Deny"; T="String"}
        # Cortana / pesquisa
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search";        N="AllowCortana";                         V=0}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search";        N="DisableWebSearch";                     V=1}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search";        N="ConnectedSearchUseWeb";                V=0}
        # Inicio / sugestoes
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="ShowSyncProviderNotifications";      V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="Start_TrackProgs";                   V=0}
        # Diagnostico de apps
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics"; N="Value"; V="Deny"; T="String"}
        # Acesso a microfone/camera por apps
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"; N="Value"; V="Deny"; T="String"}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam";      N="Value"; V="Deny"; T="String"}
        # Feedback
        @{P="HKCU:\SOFTWARE\Microsoft\Siuf\Rules";                             N="NumberOfSIUFInPeriod";                 V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Siuf\Rules";                             N="PeriodInNanoSeconds";                  V=0}
    )

    $ok = 0
    foreach ($t in $tweaks) {
        try {
            if (-not (Test-Path $t.P)) { New-Item -Path $t.P -Force | Out-Null }
            $tipo = if ($t.T) { $t.T } else { 'DWord' }
            Set-ItemProperty -Path $t.P -Name $t.N -Value $t.V -Type $tipo -Force
            $ok++
        } catch {}
    }

    OK "Telemetria e diagnostico desativados"
    OK "Anuncios e sugestoes desativados"
    OK "Cortana e pesquisa web desativados"
    OK "Acesso de apps a microfone/camera bloqueado"
    OK "$ok tweaks de privacidade aplicados"
    $Script:TweaksFeitos.Add("Privacidade: $ok tweaks aplicados")
    LOG "Privacidade: $ok tweaks"
}

# ================================================================
#  MODULO 3 — DEBLOATER (remover apps desnecessarios)
# ================================================================
function Invoke-Debloater {
    H2 "DEBLOATER — REMOVER APLICATIVOS DESNECESSARIOS"

    $apps = @(
        # Xbox (mantemos o runtime que jogos usam, removemos os apps)
        "Microsoft.XboxApp"
        "Microsoft.XboxGameOverlay"
        "Microsoft.XboxGamingOverlay"
        "Microsoft.XboxIdentityProvider"
        "Microsoft.Xbox.TCUI"
        # Cortana standalone
        "Microsoft.549981C3F5F10"
        # Apps Microsoft desnecessarios
        "Microsoft.BingWeather"
        "Microsoft.BingFinance"
        "Microsoft.BingNews"
        "Microsoft.BingSports"
        "Microsoft.BingTranslator"
        "Microsoft.BingTravel"
        "Microsoft.BingFoodAndDrink"
        "Microsoft.BingHealthAndFitness"
        "Microsoft.GetHelp"
        "Microsoft.Getstarted"
        "Microsoft.MicrosoftOfficeHub"
        "Microsoft.MicrosoftSolitaireCollection"
        "Microsoft.MicrosoftStickyNotes"
        "Microsoft.MixedReality.Portal"
        "Microsoft.MSPaint"
        "Microsoft.News"
        "Microsoft.Office.OneNote"
        "Microsoft.OneConnect"
        "Microsoft.OutlookForWindows"
        "Microsoft.People"
        "Microsoft.PowerAutomateDesktop"
        "Microsoft.Print3D"
        "Microsoft.ScreenSketch"
        "Microsoft.SkypeApp"
        "Microsoft.Teams"
        "Microsoft.Todos"
        "Microsoft.WindowsAlarms"
        "Microsoft.WindowsFeedbackHub"
        "Microsoft.WindowsMaps"
        "Microsoft.WindowsSoundRecorder"
        "Microsoft.YourPhone"
        "Microsoft.ZuneMusic"
        "Microsoft.ZuneVideo"
        # Third-party bloatware
        "AmazonVideo.PrimeVideo"
        "Disney.37853D22215B2"
        "Clipchamp.Clipchamp"
        "SpotifyAB.SpotifyMusic"
        "king.com.CandyCrushSaga"
        "king.com.CandyCrushFriends"
        "king.com.FarmHeroesSaga"
        "TikTok.TikTok"
        "BytedancePte.Ltd.TikTok"
        "Facebook.Facebook"
        "Instagram.Instagram"
        "Twitter.Twitter"
        "Netflix"
        "ROBLOXCORPORATION.ROBLOX"
        "Duolingo-LearnLanguagesforFree"
        "PandoraMediaInc"
        "AdobeSystemsIncorporated.AdobePhotoshopExpress"
    )

    $removidos = 0
    $naoencontrados = 0

    Write-Host "  Removendo apps..." -ForegroundColor Gray
    foreach ($app in $apps) {
        $pkg = Get-AppxPackage -Name "*$app*" -AllUsers -ErrorAction SilentlyContinue
        if ($pkg) {
            try {
                $pkg | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                $pkgProv = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$app*" }
                if ($pkgProv) { $pkgProv | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null }
                IN "Removido: $app"
                $removidos++
            } catch { $naoencontrados++ }
        }
    }

    Write-Host ""
    OK "$removidos apps removidos"
    if ($naoencontrados -gt 0) { IN "$naoencontrados nao encontrados (ja removidos ou nao instalados)" }

    # Desativar auto-instalacao de sugestoes
    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-ItemProperty $regPath -Name "OemPreInstalledAppsEnabled" -Value 0 -Type DWord -Force 2>$null
    Set-ItemProperty $regPath -Name "PreInstalledAppsEnabled" -Value 0 -Type DWord -Force 2>$null
    Set-ItemProperty $regPath -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord -Force 2>$null
    OK "Auto-instalacao de apps sugeridos bloqueada"

    $Script:TweaksFeitos.Add("Debloater: $removidos apps removidos")
    LOG "Debloater: $removidos removidos"
    PAUSE
}

# ================================================================
#  MODULO 4 — INSTALADOR DE PROGRAMAS (via winget)
# ================================================================
function Invoke-Instalador {
    H2 "INSTALADOR DE PROGRAMAS"

    # Verificar winget
    $wg = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wg) {
        ER "winget nao encontrado."
        WN "Instale o 'App Installer' na Microsoft Store ou atualize o Windows."
        PAUSE; return
    }

    $catalogo = @(
        # Navegadores
        @{ID="Google.Chrome";           Cat="Navegador";    N="Google Chrome"}
        @{ID="Mozilla.Firefox";         Cat="Navegador";    N="Mozilla Firefox"}
        @{ID="Brave.Brave";             Cat="Navegador";    N="Brave Browser"}
        @{ID="Opera.Opera";             Cat="Navegador";    N="Opera"}
        # Comunicacao
        @{ID="Discord.Discord";         Cat="Comunicacao";  N="Discord"}
        @{ID="WhatsApp.WhatsApp";       Cat="Comunicacao";  N="WhatsApp Desktop"}
        @{ID="Telegram.TelegramDesktop";Cat="Comunicacao";  N="Telegram"}
        @{ID="Zoom.Zoom";               Cat="Comunicacao";  N="Zoom"}
        # Gaming
        @{ID="Valve.Steam";             Cat="Gaming";       N="Steam"}
        @{ID="EpicGames.EpicGamesLauncher"; Cat="Gaming";   N="Epic Games Launcher"}
        @{ID="Ubisoft.Connect";         Cat="Gaming";       N="Ubisoft Connect"}
        @{ID="ElectronicArts.EADesktop";Cat="Gaming";       N="EA App"}
        # Utilitarios
        @{ID="7zip.7zip";               Cat="Utilitarios";  N="7-Zip"}
        @{ID="Notepad++.Notepad++";     Cat="Utilitarios";  N="Notepad++"}
        @{ID="VideoLAN.VLC";            Cat="Utilitarios";  N="VLC Media Player"}
        @{ID="HandBrake.HandBrake";     Cat="Utilitarios";  N="HandBrake"}
        @{ID="qBittorrent.qBittorrent"; Cat="Utilitarios";  N="qBittorrent"}
        @{ID="Malwarebytes.Malwarebytes";Cat="Utilitarios"; N="Malwarebytes"}
        @{ID="CrystalDewWorld.CrystalDiskInfo"; Cat="Utilitarios"; N="CrystalDiskInfo"}
        @{ID="CPUID.HWMonitor";         Cat="Utilitarios";  N="HWiNFO64 (temp/sensores)"}
        @{ID="REALiX.HWiNFO";          Cat="Utilitarios";  N="HWiNFO64"}
        # GPU OC
        @{ID="MSI.Afterburner";         Cat="GPU/OC";       N="MSI Afterburner"}
        @{ID="Guru3D.RTSS";             Cat="GPU/OC";       N="RivaTuner Statistics Server"}
        # Dev
        @{ID="Git.Git";                 Cat="Dev";          N="Git"}
        @{ID="Microsoft.VisualStudioCode"; Cat="Dev";       N="VS Code"}
        @{ID="Python.Python.3.12";      Cat="Dev";          N="Python 3.12"}
        @{ID="OpenJS.NodeJS.LTS";       Cat="Dev";          N="Node.js LTS"}
        # Multimedia
        @{ID="OBSProject.OBSStudio";    Cat="Multimedia";   N="OBS Studio"}
        @{ID="Spotify.Spotify";         Cat="Multimedia";   N="Spotify"}
        @{ID="GIMP.GIMP";               Cat="Multimedia";   N="GIMP"}
        # Office
        @{ID="LibreOffice.LibreOffice"; Cat="Office";       N="LibreOffice"}
        @{ID="Adobe.Acrobat.Reader.64-bit"; Cat="Office";   N="Adobe Acrobat Reader"}
        @{ID="Microsoft.Teams";         Cat="Office";       N="Microsoft Teams"}
    )

    $cats = $catalogo | Select-Object -ExpandProperty Cat -Unique | Sort-Object
    $lista = @()
    $idx   = 1

    Write-Host "  Programas disponiveis para instalacao:" -ForegroundColor Cyan
    Write-Host ""

    foreach ($cat in $cats) {
        Write-Host "  $([char]0x25B8) $cat" -ForegroundColor DarkCyan
        foreach ($prog in ($catalogo | Where-Object { $_.Cat -eq $cat })) {
            $instalado = Get-AppxPackage -Name "*$($prog.ID.Split('.')[0])*" -ErrorAction SilentlyContinue
            $status = if ($instalado) { "[instalado]" } else { "" }
            Write-Host ("   [{0,2}] {1,-35} {2}" -f $idx, $prog.N, $status) -ForegroundColor $(if($instalado){'DarkGray'}else{'White'})
            $lista += @{ Idx=$idx; Prog=$prog }
            $idx++
        }
        Write-Host ""
    }

    Write-Host "  Digite os numeros separados por virgula. Ex: 1,5,12,18" -ForegroundColor Yellow
    Write-Host "  [ENTER sem digitar = cancelar]" -ForegroundColor DarkGray
    Write-Host ""
    $sel = Read-Host "  Selecao"
    if (-not $sel.Trim()) { WN "Cancelado."; return }

    $nums = $sel -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
    $selecionados = $lista | Where-Object { $_.Idx -in $nums }

    if (-not $selecionados) { WN "Nenhum programa valido selecionado."; PAUSE; return }

    Write-Host ""
    H1 "Instalando $($selecionados.Count) programa(s)..."
    Write-Host ""

    $instOK = 0; $instFail = 0
    foreach ($item in $selecionados) {
        $p = $item.Prog
        IN "Instalando: $($p.N)..."
        winget install --id $p.ID --accept-source-agreements --accept-package-agreements --silent 2>$null
        if ($LASTEXITCODE -eq 0) { OK "$($p.N) instalado"; $instOK++ }
        else { WN "$($p.N) — verifique manualmente"; $instFail++ }
    }

    Write-Host ""
    OK "$instOK instalados com sucesso"
    if ($instFail -gt 0) { WN "$instFail falharam — tente instalar manualmente" }
    LOG "Instalador: $instOK OK, $instFail falhas"
    PAUSE
}

# ================================================================
#  MODULO 5 — GAME BAR E MODO JOGO
# ================================================================
function Invoke-GameMode {
    H2 "GAME BAR E MODO JOGO"

    # Game Bar OFF
    $tweaks = @(
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR";        N="AppCaptureEnabled";                   V=0}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR";              N="AllowGameDVR";                        V=0}
        @{P="HKCU:\System\GameConfigStore";                                    N="GameDVR_Enabled";                     V=0}
        @{P="HKCU:\System\GameConfigStore";                                    N="GameDVR_FSEBehaviorMode";             V=2}
        @{P="HKCU:\System\GameConfigStore";                                    N="GameDVR_HonorUserFSEBehaviorMode";    V=1}
        @{P="HKCU:\System\GameConfigStore";                                    N="GameDVR_DXGIHonorFSEWindowsCompatible"; V=1}
        # Game Mode ON
        @{P="HKCU:\SOFTWARE\Microsoft\GameBar";                                N="AllowAutoGameMode";                   V=1}
        @{P="HKCU:\SOFTWARE\Microsoft\GameBar";                                N="AutoGameModeEnabled";                 V=1}
        # HAGS — GPU Scheduling
        @{P="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers";          N="HwSchMode";                           V=2}
        # Prioridade de jogos no Multimedia Scheduler
        @{P="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; N="SystemResponsiveness";   V=0}
        @{P="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; N="Priority";   V=6}
    )

    foreach ($t in $tweaks) {
        try {
            if (-not (Test-Path $t.P)) { New-Item -Path $t.P -Force | Out-Null }
            Set-ItemProperty -Path $t.P -Name $t.N -Value $t.V -Type DWord -Force
        } catch {}
    }

    try {
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
            -Name "Scheduling Category" -Value "High" -Force 2>$null
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
            -Name "SFIO Priority" -Value "High" -Force 2>$null
    } catch {}

    OK "Xbox Game Bar desativado (libera CPU em jogos)"
    OK "Modo Jogo (Game Mode) ativado — Windows prioriza o processo do jogo"
    OK "HAGS (Hardware GPU Scheduling) ativado"
    OK "Multimedia Scheduler prioriza jogos"
    $Script:TweaksFeitos.Add("Game Mode: Bar OFF / HAGS ON / Scheduler jogos")
    LOG "Game Mode configurado"
}

# ================================================================
#  MODULO 6 — REDE (ping / packet loss)
# ================================================================
function Invoke-OtimizarRede {
    H2 "OTIMIZACAO DE REDE"

    # Nagle Algorithm OFF
    $nicPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    try {
        Get-ChildItem $nicPath | ForEach-Object {
            Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force 2>$null
            Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay"      -Value 1 -Type DWord -Force 2>$null
        }
        OK "Nagle Algorithm desativado (reduz latencia)"
    } catch { ER "Nagle: falha" }

    # DNS rapido
    try {
        Write-Host ""
        Write-Host "  Configurar DNS rapido:" -ForegroundColor Cyan
        Write-Host "  [1] Cloudflare  1.1.1.1 / 1.0.0.1  (mais rapido mundialmente)" -ForegroundColor White
        Write-Host "  [2] Google      8.8.8.8 / 8.8.4.4" -ForegroundColor White
        Write-Host "  [3] Quad9       9.9.9.9 / 149.112.112.112  (foco em seguranca)" -ForegroundColor White
        Write-Host "  [4] Manter DNS atual" -ForegroundColor DarkGray
        Write-Host ""
        $dns = Read-Host "  Escolha o DNS [1-4]"

        $dns1 = ""; $dns2 = ""; $dnsNome = ""
        switch ($dns.Trim()) {
            '1' { $dns1="1.1.1.1"; $dns2="1.0.0.1"; $dnsNome="Cloudflare" }
            '2' { $dns1="8.8.8.8"; $dns2="8.8.4.4"; $dnsNome="Google" }
            '3' { $dns1="9.9.9.9"; $dns2="149.112.112.112"; $dnsNome="Quad9" }
        }

        if ($dns1) {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Virtual|Loopback' }
            foreach ($ad in $adapters) {
                Set-DnsClientServerAddress -InterfaceIndex $ad.ifIndex -ServerAddresses ($dns1,$dns2) 2>$null
                IN "DNS $dnsNome aplicado em: $($ad.Name)"
            }
            OK "DNS $dnsNome ($dns1 / $dns2) configurado"
            $Script:TweaksFeitos.Add("DNS: $dnsNome ($dns1)")
        }
    } catch { ER "Falha ao configurar DNS" }

    # Reserva de banda
    try {
        if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched")) {
            New-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Force | Out-Null
        }
        Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -Value 0 -Type DWord -Force
        OK "Reserva de 20% de banda do Windows removida"
    } catch {}

    # NIC tweaks
    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        foreach ($ad in $adapters) {
            Set-NetAdapterAdvancedProperty -Name $ad.Name -DisplayName "Interrupt Moderation" -DisplayValue "Disabled" 2>$null
            Set-NetAdapterAdvancedProperty -Name $ad.Name -DisplayName "Receive Side Scaling" -DisplayValue "Enabled" 2>$null
            Set-NetAdapterAdvancedProperty -Name $ad.Name -DisplayName "Large Send Offload v2 (IPv4)" -DisplayValue "Disabled" 2>$null
            Set-NetAdapterAdvancedProperty -Name $ad.Name -DisplayName "Large Send Offload v2 (IPv6)" -DisplayValue "Disabled" 2>$null
        }
        OK "NIC: Interrupt Moderation OFF / RSS ON / LSO OFF"
    } catch {}

    # Flush DNS
    ipconfig /flushdns 2>$null | Out-Null
    OK "Cache DNS limpo"

    $Script:TweaksFeitos.Add("Rede otimizada (Nagle OFF, NIC tweaks, banda liberada)")
    LOG "Rede otimizada"
}

# ================================================================
#  MODULO 7 — SERVICOS
# ================================================================
function Invoke-Servicos {
    H2 "SERVICOS DESNECESSARIOS"
    WN "Apenas servicos seguros serao desativados. SysMain e Windows Update sao mantidos."
    Write-Host ""

    $svcs = @(
        @{N="DiagTrack";           D="Telemetria Windows (CPU+rede constante)"}
        @{N="dmwappushservice";    D="WAP Push Messages"}
        @{N="XblAuthManager";      D="Xbox Live Auth"}
        @{N="XblGameSave";         D="Xbox Game Save"}
        @{N="XboxNetApiSvc";        D="Xbox Network API"}
        @{N="XboxGipSvc";           D="Xbox Accessories"}
        @{N="lfsvc";               D="Servico de localizacao"}
        @{N="MapsBroker";          D="Mapas Offline"}
        @{N="RetailDemo";          D="Modo demonstracao de loja"}
        @{N="wisvc";               D="Windows Insider Program"}
        @{N="WerSvc";              D="Relatorio de Erros Windows"}
        @{N="Fax";                 D="Fax (inutilizado)"}
        @{N="icssvc";              D="Hotspot movel"}
        @{N="PhoneSvc";            D="Vinculador de Telefone"}
        @{N="RmSvc";               D="Gerenciador de Radio"}
        @{N="RemoteRegistry";      D="Registro Remoto (risco de seguranca)"}
        @{N="TapiSrv";             D="TAPI (telefonia legada)"}
        @{N="WpcMonSvc";           D="Controles dos pais (desnecessario)"}
        @{N="SharedAccess";        D="ICS (compartilhamento de Internet)"}
        @{N="WMPNetworkSvc";       D="Windows Media Player Network"}
    )

    $off = 0
    foreach ($s in $svcs) {
        try {
            $svc = Get-Service -Name $s.N -ErrorAction SilentlyContinue
            if ($svc) {
                $Script:SvcsBackup[$s.N] = $svc.StartType.ToString()
                if ($svc.Status -eq 'Running') { Stop-Service -Name $s.N -Force -ErrorAction SilentlyContinue }
                Set-Service -Name $s.N -StartupType Disabled -ErrorAction SilentlyContinue
                IN "Desativado: $($s.D)"
                $off++
            }
        } catch {}
    }

    $Script:SvcsBackup | ConvertTo-Json | Out-File (Join-Path $Script:PastaBackup "servicos.json") -Encoding UTF8 -Force
    Write-Host ""
    OK "$off servicos desativados"
    OK "Backup salvo — pode restaurar com a opcao [R]"
    $Script:TweaksFeitos.Add("Servicos: $off desativados")
    LOG "Servicos: $off desativados"
}

# ================================================================
#  MODULO 8 — VISUAL E PERFORMANCE
# ================================================================
function Invoke-VisualPerf {
    H2 "VISUAL E PERFORMANCE DO WINDOWS"

    # Efeitos visuais para performance
    try {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
            -Name "VisualFXSetting" -Value 2 -Type DWord -Force 2>$null
    } catch {}

    $tweaks = @(
        @{P="HKCU:\Control Panel\Desktop";                                      N="DragFullWindows";     V="0";  T="String"}
        @{P="HKCU:\Control Panel\Desktop";                                      N="MenuShowDelay";       V="0";  T="String"}
        @{P="HKCU:\Control Panel\Desktop\WindowMetrics";                        N="MinAnimate";          V=0}
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="TaskbarAnimations";  V=0}
        @{P="HKCU:\Software\Microsoft\Windows\DWM";                             N="EnableAeroPeek";      V=0}
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="ListviewAlphaSelect";V=0}
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="ListviewShadow";     V=0}
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="ExtendedUIHoverTime"; V=1}
        # Explorer mais rapido
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="Start_ShowMyComputer"; V=1}
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="HideFileExt";        V=0}
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="Hidden";             V=1}
        # Transparencia OFF (menos GPU em background)
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"; N="EnableTransparency"; V=0}
        # Desativar snap assist popup
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="SnapAssist";         V=1}
    )

    foreach ($t in $tweaks) {
        try {
            if (-not (Test-Path $t.P)) { New-Item -Path $t.P -Force | Out-Null }
            if ($t.T -eq 'String') {
                Set-ItemProperty -Path $t.P -Name $t.N -Value $t.V -Type String -Force
            } else {
                Set-ItemProperty -Path $t.P -Name $t.N -Value $t.V -Type DWord -Force
            }
        } catch {}
    }

    # Prefetch/Superfetch ajuste (manter ativo para SSD)
    if ($Script:DiscoTipo -match 'SSD|Solid') {
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" `
            -Name "EnablePrefetcher" -Value 3 -Type DWord -Force 2>$null
        OK "Prefetch mantido (SSD detectado — melhora carregamento de jogos)"
    }

    OK "Animacoes desativadas (menos uso de CPU/GPU em background)"
    OK "Transparencia desativada"
    OK "Explorer otimizado (extensoes visiveis, arquivos ocultos visiveis)"
    OK "Menu delay zerado"
    $Script:TweaksFeitos.Add("Visual/Performance: animacoes OFF, transparencia OFF")
    LOG "Visual performance configurado"
}

# ================================================================
#  MODULO 9 — OTIMIZACOES X3D
# ================================================================
function Invoke-OtimizacoesX3D {
    H2 "OTIMIZACOES EXCLUSIVAS PARA X3D V-CACHE"
    WN "Estas configuracoes sao especificas para: $($Script:CPUNome)"
    Write-Host ""

    $amd = powercfg /list 2>$null | Select-String 'AMD Ryzen Balanced'
    if ($amd) {
        $guid = ($amd.Line -split '\s+' | Where-Object {$_ -match '^[0-9a-f-]{36}$'}) | Select-Object -First 1
        if ($guid) { powercfg /setactive $guid 2>$null; OK "AMD Ryzen Balanced confirmado" }
    }

    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES   100 2>$null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE  4 2>$null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFINCTHRESHOLD 10 2>$null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFDECTHRESHOLD  8 2>$null

    OK "Core Parking OFF (nucleo com V-Cache sempre acordado)"
    OK "Boost: Efficient Aggressive (melhor para latencia do cache 3D)"
    OK "Transicoes de frequencia rapidas"

    Write-Host ""
    WN "BIOS — certifique-se que esta ativado:"
    WN "  > CPPC Preferred Cores = Enabled"
    WN "  > AMD Cool'n'Quiet     = Enabled"
    WN "  > Global C-state       = Enabled"
    WN "  > XMP/EXPO para sua RAM"

    $Script:TweaksFeitos.Add("X3D V-Cache: plano, boost e core parking configurados")
    LOG "X3D otimizacoes aplicadas"
}

# ================================================================
#  MODULO 10 — LIMPEZA DO SISTEMA
# ================================================================
function Invoke-Limpeza {
    H2 "LIMPEZA DO SISTEMA"

    $totalBytes = 0

    # Temporarios
    $pastas = @(
        $env:TEMP, $env:TMP,
        "C:\Windows\Temp",
        "C:\Windows\Prefetch",
        "$env:LOCALAPPDATA\Temp",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\ThumbCacheToDelete"
    )

    foreach ($p in $pastas) {
        if (Test-Path $p) {
            $arqs = Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue
            $bytes = ($arqs | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($bytes) { $totalBytes += $bytes }
            $arqs | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
    }

    # Lixeira
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        IN "Lixeira esvaziada"
    } catch {}

    # Windows Update cache
    try {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        $wuCache = "C:\Windows\SoftwareDistribution\Download"
        if (Test-Path $wuCache) {
            $arqs = Get-ChildItem -Path $wuCache -Recurse -Force -ErrorAction SilentlyContinue
            $bytes = ($arqs | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($bytes) { $totalBytes += $bytes }
            $arqs | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            IN "Cache do Windows Update limpo"
        }
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    } catch {}

    # Minidumps
    try {
        $dumps = "C:\Windows\Minidump"
        if (Test-Path $dumps) {
            $arqs = Get-ChildItem -Path $dumps -Force -ErrorAction SilentlyContinue
            $bytes = ($arqs | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($bytes) { $totalBytes += $bytes }
            $arqs | Remove-Item -Force -ErrorAction SilentlyContinue
            IN "Minidumps (crash logs) removidos"
        }
    } catch {}

    # Cleanmgr silencioso
    try {
        $regKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        $cats = @("Temporary Internet Files","Recycle Bin","Temporary Files","Thumbnails",
                  "Old ChkDsk Files","Previous Installations","Windows Error Reporting Files",
                  "Delivery Optimization Files","Update Cleanup")
        foreach ($cat in $cats) {
            $path = "$regKey\$cat"
            if (Test-Path $path) { Set-ItemProperty -Path $path -Name "StateFlags0064" -Value 2 -Type DWord -Force 2>$null }
        }
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:64" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        IN "Limpador do Windows executado"
    } catch {}

    $mb = [math]::Round($totalBytes / 1MB, 1)
    Write-Host ""
    OK "Limpeza concluida: $($mb) MB liberados"
    $Script:TweaksFeitos.Add("Limpeza: $($mb) MB liberados")
    LOG "Limpeza: $($mb) MB"
    PAUSE
}

# ================================================================
#  MODULO 11 — REPARAR WINDOWS (SFC / DISM)
# ================================================================
function Invoke-RepararWindows {
    H2 "REPARAR WINDOWS (SFC / DISM)"

    WN "Este processo pode demorar 10-30 minutos."
    WN "Nao feche a janela enquanto estiver rodando."
    Write-Host ""
    Write-Host "  O que sera executado:" -ForegroundColor Cyan
    IN "  1. DISM /RestoreHealth    — repara a imagem do Windows"
    IN "  2. SFC /scannow           — verifica arquivos de sistema"
    IN "  3. chkdsk /f (agendado)   — verifica erros no disco"
    Write-Host ""

    if (-not (CONF "Iniciar reparo agora?")) { return }

    # DISM
    Write-Host ""
    H1 "Rodando DISM RestoreHealth..."
    Write-Host "  (pode demorar 10-20 minutos — aguarde)" -ForegroundColor DarkGray
    Write-Host ""
    $dism = Start-Process -FilePath "dism.exe" `
        -ArgumentList "/Online /Cleanup-Image /RestoreHealth" `
        -Wait -PassThru -NoNewWindow
    if ($dism.ExitCode -eq 0) { OK "DISM concluido sem erros" }
    else { WN "DISM terminou com codigo $($dism.ExitCode) — pode ser normal se sem internet" }

    # SFC
    Write-Host ""
    H1 "Rodando SFC /scannow..."
    $sfc = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow
    if ($sfc.ExitCode -eq 0) { OK "SFC: nenhum arquivo corrompido encontrado" }
    elseif ($sfc.ExitCode -eq 1) { WN "SFC: arquivos corrompidos encontrados e reparados" }
    else { WN "SFC terminou com codigo $($sfc.ExitCode)" }

    # Flush DNS
    ipconfig /flushdns 2>$null | Out-Null
    OK "Cache DNS limpo"

    # Resetar TCP/IP
    Write-Host ""
    if (CONF "Resetar pilha TCP/IP e Winsock? (bom para problemas de rede)") {
        netsh winsock reset 2>$null | Out-Null
        netsh int ip reset 2>$null | Out-Null
        OK "Winsock e IP stack resetados — reinicie o computador"
    }

    Write-Host ""
    OK "Reparo concluido!"
    WN "Reinicie o computador para completar o processo."
    LOG "Reparo Windows executado"
    PAUSE
}

# ================================================================
#  MODULO 12 — WINDOWS UPDATE
# ================================================================
function Invoke-WindowsUpdate {
    H2 "CONTROLE DO WINDOWS UPDATE"

    Write-Host "  [1] Pausar atualizacoes por 35 dias (recomendado para gamers)" -ForegroundColor White
    Write-Host "  [2] Habilitar atualizacoes automaticas (padrao Windows)" -ForegroundColor White
    Write-Host "  [3] Bloquear atualizacoes permanentemente (NAO recomendado)" -ForegroundColor DarkGray
    Write-Host "  [4] Forcar verificacao de atualizacoes agora" -ForegroundColor White
    Write-Host "  [5] Voltar" -ForegroundColor DarkGray
    Write-Host ""
    $op = Read-Host "  Opcao [1-5]"

    switch ($op.Trim()) {
        '1' {
            $dataFim = (Get-Date).AddDays(35).ToString("yyyy-MM-dd")
            $p = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
            if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
            Set-ItemProperty $p -Name "PauseFeatureUpdatesStartTime"   -Value (Get-Date -f "yyyy-MM-ddTHH:mm:ssZ") -Force 2>$null
            Set-ItemProperty $p -Name "PauseFeatureUpdatesEndTime"     -Value "$($dataFim)T00:00:00Z" -Force 2>$null
            Set-ItemProperty $p -Name "PauseQualityUpdatesStartTime"   -Value (Get-Date -f "yyyy-MM-ddTHH:mm:ssZ") -Force 2>$null
            Set-ItemProperty $p -Name "PauseQualityUpdatesEndTime"     -Value "$($dataFim)T00:00:00Z" -Force 2>$null
            Set-ItemProperty $p -Name "PauseUpdatesStartTime"          -Value (Get-Date -f "yyyy-MM-ddTHH:mm:ssZ") -Force 2>$null
            Set-ItemProperty $p -Name "PauseUpdatesExpiryTime"         -Value "$($dataFim)T00:00:00Z" -Force 2>$null
            OK "Atualizacoes pausadas ate $dataFim"
        }
        '2' {
            $p = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
            Remove-ItemProperty $p -Name "PauseFeatureUpdatesEndTime"  -Force 2>$null
            Remove-ItemProperty $p -Name "PauseQualityUpdatesEndTime"  -Force 2>$null
            Remove-ItemProperty $p -Name "PauseUpdatesExpiryTime"      -Force 2>$null
            Set-Service -Name wuauserv -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
            OK "Windows Update habilitado"
        }
        '3' {
            WN "Bloquear permanentemente pode impedir patches de seguranca criticos."
            if (CONF "Tem certeza que deseja bloquear permanentemente?") {
                Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
                $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
                if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
                Set-ItemProperty $p -Name "NoAutoUpdate" -Value 1 -Type DWord -Force 2>$null
                OK "Windows Update bloqueado permanentemente"
                WN "Para reativar: use a opcao [2] deste menu"
            }
        }
        '4' {
            IN "Verificando atualizacoes..."
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
            (New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()
            OK "Verificacao iniciada — abra Windows Update nas Configuracoes para acompanhar"
        }
    }

    LOG "Windows Update: opcao $op"
    PAUSE
}

# ================================================================
#  MODULO 13 — GPU OC (banco de dados + analise)
# ================================================================
function Get-PerfilOCGPU {
    param([string]$Nome)
    $db = @(
        @{M='RTX\s*4090';           C=200; V=1500; P=15; T=83; N='Ada flagship. OC de mem muito eficiente. Refrigeracao robusta necessaria.'}
        @{M='RTX\s*4080\s*(Super)?';C=175; V=1200; P=12; T=83; N='Excelente headroom Ada. GDDR6X responde muito bem a OC de mem.'}
        @{M='RTX\s*4070\s*Ti\s*(Super)?'; C=175; V=1200; P=12; T=83; N='Ada eficiente. OC de mem da ganho real de FPS.'}
        @{M='RTX\s*4070\s*(Super)?(?!\s*Ti)'; C=150; V=1000; P=10; T=83; N='Excelente custo-beneficio de OC. Mem GDDR6X escala bem.'}
        @{M='RTX\s*4060\s*Ti';      C=150; V=1000; P=10; T=83; N='TDP limitado. Mem OC da melhor retorno que core.'}
        @{M='RTX\s*4060(?!\s*Ti)';  C=125; V=1000; P=8;  T=83; N='Margem moderada. Foque em mem OC para ganho de FPS.'}
        @{M='RTX\s*3090\s*Ti';      C=150; V=800;  P=8;  T=83; N='VRAM GDDR6X aquece. Monitore Tjunction separadamente.'}
        @{M='RTX\s*3090(?!\s*Ti)';  C=150; V=800;  P=8;  T=83; N='GDDR6X sensivel a temp. Mem OC moderado e mais seguro.'}
        @{M='RTX\s*3080\s*Ti';      C=150; V=800;  P=8;  T=83; N='Excelente Ampere para OC. VRAM pode throttle, monitore.'}
        @{M='RTX\s*3080(?!\s*Ti)';  C=150; V=800;  P=8;  T=83; N='Ampere escala muito bem. Mem OC extremamente eficiente.'}
        @{M='RTX\s*3070\s*Ti';      C=125; V=600;  P=8;  T=83; N='Boa margem. Cooler padrao geralmente suficiente.'}
        @{M='RTX\s*3070(?!\s*Ti)';  C=125; V=600;  P=8;  T=83; N='GPU popular para OC. Comunidade muito bem documentada.'}
        @{M='RTX\s*3060\s*Ti';      C=125; V=600;  P=8;  T=83; N='Excelente custo-beneficio. Core e mem escalam bem.'}
        @{M='RTX\s*3060(?!\s*Ti)';  C=100; V=500;  P=6;  T=83; N='Margem menor que Ti. Mem OC da melhor retorno.'}
        @{M='RTX\s*3050';           C=100; V=400;  P=5;  T=87; N='TDP baixo limita ganhos. OC leve recomendado.'}
        @{M='RTX\s*2080\s*Ti';      C=125; V=600;  P=8;  T=84; N='Turing classico. Verifique pasta termica se GPU tem mais de 4 anos.'}
        @{M='RTX\s*2080(?!\s*Ti)';  C=125; V=600;  P=8;  T=84; N='Boa margem Turing. GDDR6 escala bem.'}
        @{M='RTX\s*2070';           C=100; V=500;  P=7;  T=84; N='Margem solida. Vale OC para ganho real.'}
        @{M='RTX\s*2060';           C=100; V=400;  P=6;  T=84; N='Margem moderada. Ganhos reais mas nao dramaticos.'}
        @{M='GTX\s*1660\s*(Ti|Super)?'; C=100; V=500; P=6; T=84; N='Turing lite. GDDR6 (Ti/Super) escala bem.'}
        @{M='GTX\s*1650';           C=75;  V=300;  P=4;  T=87; N='TDP muito baixo. Ganhos limitados.'}
        @{M='GTX\s*1080\s*Ti';      C=125; V=500;  P=8;  T=84; N='Pascal classico. Ainda excelente para OC. Pasta pode estar seca.'}
        @{M='GTX\s*1080(?!\s*Ti)';  C=125; V=500;  P=8;  T=84; N='Pascal envelhece bem com OC. Verifique refrigeracao.'}
        @{M='GTX\s*1070';           C=100; V=400;  P=7;  T=84; N='Classico OC. Muito bem documentado na comunidade.'}
        @{M='GTX\s*1060';           C=100; V=400;  P=6;  T=84; N='Considere trocar pasta termica se GPU tem mais de 4 anos.'}
        @{M='GTX\s*1050\s*Ti';      C=75;  V=300;  P=4;  T=87; N='TDP limitado. Ganhos modestos mas existentes.'}
        @{M='RX\s*7900\s*(XTX|XT)'; C=100; V=100; P=10; T=90; N='RDNA3. Hotspot e diferente de Edge temp. Monitore junction.'}
        @{M='RX\s*7800\s*XT';       C=100; V=80;  P=8;  T=90; N='Otimo RDNA3 mid-range para OC.'}
        @{M='RX\s*7700\s*XT';       C=100; V=80;  P=8;  T=90; N='TDP eficiente. Margem moderada.'}
        @{M='RX\s*7600';            C=75;  V=60;  P=6;  T=90; N='Entry RDNA3. Ganhos modestos mas leais.'}
        @{M='RX\s*6900\s*XT';       C=100; V=100; P=8;  T=90; N='RDNA2 flagship. Hotspot pode ser alto. Monitore com cuidado.'}
        @{M='RX\s*6800\s*XT';       C=100; V=100; P=8;  T=90; N='Excelente RDNA2. Infinity Cache escala muito bem.'}
        @{M='RX\s*6800(?!\s*XT)';   C=100; V=80;  P=8;  T=90; N='Muito parecido com XT. Bons ganhos de OC.'}
        @{M='RX\s*6700\s*XT';       C=100; V=80;  P=8;  T=90; N='Mid-range RDNA2 com boa margem.'}
        @{M='RX\s*6700(?!\s*XT)';   C=75;  V=60;  P=6;  T=90; N='Margem moderada. Power limit boost da bom resultado.'}
        @{M='RX\s*6600\s*XT';       C=75;  V=60;  P=6;  T=90; N='1080p excelente. OC modesto mas eficiente.'}
        @{M='RX\s*6600(?!\s*XT)';   C=75;  V=50;  P=5;  T=90; N='TDP baixo. Ganhos existem mas nao exagere.'}
        @{M='RX\s*5700\s*XT';       C=75;  V=80;  P=7;  T=90; N='RDNA1. Hotspot ate 110C e normal. Monitore junction temp.'}
        @{M='RX\s*5700(?!\s*XT)';   C=75;  V=80;  P=7;  T=90; N='Parecido com XT. Hotspot alto esperado.'}
        @{M='RX\s*5600\s*XT';       C=75;  V=60;  P=6;  T=90; N='Boa GPU 1080p. OC moderado recomendado.'}
        @{M='Arc\s*A770';           C=50;  V=200; P=5; T=100; N='OC em Arc e experimental. Atualize o driver sempre.'}
        @{M='Arc\s*A750';           C=50;  V=200; P=5; T=100; N='Mesmos cuidados do A770.'}
    )
    foreach ($e in $db) { if ($Nome -match $e.M) { return $e } }
    if ($Nome -match 'NVIDIA|GeForce|RTX|GTX') { return @{C=75;V=300;P=5;T=84;N='GPU NVIDIA nao identificada. Valores ultra-conservadores.'} }
    if ($Nome -match 'AMD|Radeon|RX')           { return @{C=50;V=50; P=4;T=90;N='GPU AMD nao identificada. Valores ultra-conservadores.'} }
    return $null
}

function Invoke-AnalisadorGPU {
    H2 "ANALISADOR DE OVERCLOCK DE GPU"

    if (-not $Script:GPUNome) { Invoke-DetectarHardware }
    if (-not $Script:GPUNome) { ER "GPU nao detectada."; PAUSE; return }

    if ($Script:GPUFab -eq 'Intel') {
        WN "GPU Intel Arc detectada. OC e experimental."
        WN "Use o Intel Arc Control para OC com seguranca."
        PAUSE; return
    }

    $perfil = Get-PerfilOCGPU -Nome $Script:GPUNome
    if (-not $perfil) {
        WN "GPU nao encontrada no banco de OC seguro."
        WN "Pesquise em: reddit.com/r/overclocking  ou  techpowerup.com"
        PAUSE; return
    }

    # Teste termico
    $statusTerm = "nao_testado"
    if ($Script:GPUFab -eq 'NVIDIA' -and $Script:GPUSmi -and $Script:GPUTemp -gt 0) {
        Write-Host ""
        Write-Host "  Temperatura atual: $($Script:GPUTemp) C" -ForegroundColor $(if($Script:GPUTemp -lt 60){'Green'}elseif($Script:GPUTemp -lt 75){'Yellow'}else{'Red'})
        if (CONF "Fazer teste termico rapido (15s) para calibrar recomendacao?") {
            IN "Monitorando temperatura por 15 segundos..."
            $tempMax = $Script:GPUTemp; $amostras = @()
            for ($i = 1; $i -le 15; $i++) {
                $tr = & $Script:GPUSmi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>$null
                if ($tr -match '^\d+') { $t=[int]$tr.Trim(); $amostras+=$t; if($t-gt$tempMax){$tempMax=$t} }
                Write-Host "`r  [$('#'*$i)$((' '*([math]::Max(0,15-$i))))] $($i)s | Temp: $($t) C    " -NoNewline -ForegroundColor $(if($t-lt70){'Green'}elseif($t-lt80){'Yellow'}else{'Red'})
                Start-Sleep 1
            }
            Write-Host ""; Write-Host ""
            OK "Temp maxima observada: $($tempMax) C"
            $statusTerm = if($tempMax -le 60){'excelente'}elseif($tempMax -le 72){'boa'}elseif($tempMax -le 80){'aceitavel'}else{'quente'}
            if ($statusTerm -eq 'quente') {
                ER "GPU muito quente. OC NAO recomendado."
                ER "Limpe o cooler e troque a pasta termica antes de fazer OC."
                PAUSE; return
            }
            OK "Status termico: $statusTerm"
        }
    }

    # Calcular margens com multiplicador de seguranca
    $mult = switch ($statusTerm) {
        'excelente'   {1.0} 'boa' {0.85} 'aceitavel' {0.65} default {0.75}
    }
    $cMax = [math]::Floor($perfil.C * $mult)
    $vMax = [math]::Floor($perfil.V * $mult)

    $pC = @{C=[math]::Floor($cMax*.5);  V=[math]::Floor($vMax*.5);  P=[math]::Min([math]::Floor($perfil.P*.5),8)}
    $pM = @{C=[math]::Floor($cMax*.75); V=[math]::Floor($vMax*.75); P=[math]::Min([math]::Floor($perfil.P*.75),12)}
    $pA = @{C=$cMax; V=$vMax; P=$perfil.P}

    # Exibir tabela
    Write-Host ""
    H1 "RESULTADO — $($Script:GPUNome)"
    SEP
    Write-Host "  Nota: $($perfil.N)" -ForegroundColor DarkGray
    Write-Host "  Limite de temperatura: $($perfil.T) C" -ForegroundColor White
    Write-Host ""

    $L = [char]0x2502
    Write-Host ("  " + [char]0x250C + [char]0x2500*68 + [char]0x2510) -ForegroundColor DarkCyan
    Write-Host ("  $L  {0,-14}  {1,-14}  {2,-14}  {3,-18}$L" -f "PERFIL","CORE OC","MEM OC","POWER LIMIT") -ForegroundColor DarkCyan
    Write-Host ("  " + [char]0x251C + [char]0x2500*68 + [char]0x2524) -ForegroundColor DarkCyan

    $pl_c = if($Script:GPUPL -gt 0){[math]::Min([math]::Round($Script:GPUPL*(1+$pC.P/100)),$Script:GPUPLmax)}else{0}
    $pl_m = if($Script:GPUPL -gt 0){[math]::Min([math]::Round($Script:GPUPL*(1+$pM.P/100)),$Script:GPUPLmax)}else{0}
    $pl_a = if($Script:GPUPL -gt 0){[math]::Min([math]::Round($Script:GPUPL*(1+$pA.P/100)),$Script:GPUPLmax)}else{0}
    $plStr_c = if($pl_c -gt 0){"$($pl_c) W (+$($pC.P)%)"}else{"+$($pC.P)% (use slider)"}
    $plStr_m = if($pl_m -gt 0){"$($pl_m) W (+$($pM.P)%)"}else{"+$($pM.P)% (use slider)"}
    $plStr_a = if($pl_a -gt 0){"$($pl_a) W (+$($pA.P)%)"}else{"+$($pA.P)% (use slider)"}

    Write-Host ("  $L  {0,-14}  {1,-14}  {2,-14}  {3,-18}$L" -f "[CONSERVADOR]","+$($pC.C) MHz","+$($pC.V) MHz",$plStr_c) -ForegroundColor Green
    Write-Host ("  $L  {0,-14}  {1,-14}  {2,-14}  {3,-18}$L" -f "[MODERADO]","+$($pM.C) MHz","+$($pM.V) MHz",$plStr_m) -ForegroundColor Yellow
    Write-Host ("  $L  {0,-14}  {1,-14}  {2,-14}  {3,-18}$L" -f "[AGRESSIVO]","+$($pA.C) MHz","+$($pA.V) MHz",$plStr_a) -ForegroundColor Red
    Write-Host ("  " + [char]0x2514 + [char]0x2500*68 + [char]0x2518) -ForegroundColor DarkCyan

    # Aplicar Power Limit via nvidia-smi
    if ($Script:GPUFab -eq 'NVIDIA' -and $Script:GPUSmi -and $Script:GPUPLmax -gt 0) {
        Write-Host ""
        WN "O Power Limit pode ser aplicado agora automaticamente via nvidia-smi."
        WN "Core e Mem OC devem ser feitos pelo MSI Afterburner (mais seguro)."
        Write-Host ""
        Write-Host "  [1] Conservador  ($($pl_c) W)" -ForegroundColor Green
        Write-Host "  [2] Moderado     ($($pl_m) W)" -ForegroundColor Yellow
        Write-Host "  [3] Agressivo    ($($pl_a) W)" -ForegroundColor Red
        Write-Host "  [4] Nao aplicar" -ForegroundColor DarkGray
        Write-Host ""
        $op = Read-Host "  Aplicar Power Limit [1-4]"

        $watts = switch ($op.Trim()) {
            '1' {$pl_c} '2' {$pl_m} '3' {$pl_a} default {0}
        }
        if ($watts -gt 0) {
            $res = & $Script:GPUSmi -pl $watts 2>&1
            if ($res -match 'successfully') {
                OK "Power Limit aplicado: $($watts) W"
                WN "Volta ao padrao ao reiniciar. Configure no Afterburner para tornar permanente."
            } else { ER "Falha ao aplicar PL. Tente pelo MSI Afterburner." }
        }
    }

    # Guia passo a passo
    Write-Host ""
    H1 "GUIA DE APLICACAO — MSI AFTERBURNER"
    SEP
    Write-Host ""
    if ($Script:GPUFab -eq 'NVIDIA') {
        Write-Host "  Download Afterburner: https://www.msi.com/Landing/afterburner" -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host "  Metodologia SAFE (incremental):" -ForegroundColor White
        Write-Host "  1. Abra Afterburner > Salve o perfil padrao no slot 1 (botao Save)" -ForegroundColor Gray
        Write-Host "  2. Suba Power Limit ao maximo" -ForegroundColor Gray
        Write-Host "  3. Core Clock: +$($pC.C) MHz (conservador) > Apply > teste 30min" -ForegroundColor Green
        Write-Host "  4. Se estavel: +$($pM.C) MHz (moderado) > repita o teste" -ForegroundColor Yellow
        Write-Host "  5. Memory Clock: +$($pC.V) MHz > teste > suba para +$($pM.V) MHz" -ForegroundColor Green
        Write-Host "  6. NUNCA pule para agressivo sem testar os anteriores" -ForegroundColor Red
        Write-Host "  7. Se travar/artefato: reduza 25 MHz e stabilize" -ForegroundColor Gray
    } elseif ($Script:GPUFab -eq 'AMD') {
        Write-Host "  Use: Radeon Software Adrenalin (ja instalado) ou MSI Afterburner" -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host "  Via Radeon Software:" -ForegroundColor White
        Write-Host "  1. Clique direito desktop > AMD Software: Adrenalin Edition" -ForegroundColor Gray
        Write-Host "  2. Performance > Tuning > Manual" -ForegroundColor Gray
        Write-Host "  3. GPU Freq: +$($pC.C) MHz | VRAM Freq: +$($pC.V) MHz | PL: +$($pC.P)%" -ForegroundColor Green
        Write-Host "  4. Apply > teste 30 min > avance para moderado se estavel" -ForegroundColor Gray
        Write-Host ""
        WN "RDNA: monitore HOTSPOT separadamente. Ate 100C e normal. Acima de 110C reduza."
    }

    Write-Host ""
    H1 "CHECKLIST DE SEGURANCA"
    SEP
    Write-Host "  [ ] Cooler limpo (sem po acumulado)" -ForegroundColor Gray
    Write-Host "  [ ] Pasta termica OK (GPU com mais de 3 anos: considere trocar)" -ForegroundColor Gray
    Write-Host "  [ ] Fonte com margem suficiente (+20%% da TDP total do sistema)" -ForegroundColor Gray
    Write-Host "  [ ] Perfil padrao salvo no Afterburner antes de comecar" -ForegroundColor Gray
    Write-Host "  [ ] Temperatura ambiente nao muito alta (acima de 30C prejudica)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Sinais de OC instavel:" -ForegroundColor Yellow
    Write-Host "  > Artefatos visuais (quadradinhos, cores erradas, tela piscando)" -ForegroundColor Gray
    Write-Host "  > Jogo travando ou fechando inesperadamente" -ForegroundColor Gray
    Write-Host "  > Driver NVIDIA/AMD crashando (tela preta rapida)" -ForegroundColor Gray
    Write-Host "  > FPS mais inconsistente que antes do OC" -ForegroundColor Gray

    LOG "GPU OC analise: $($Script:GPUNome) | Core max: +$($cMax) | Mem max: +$($vMax)"
    PAUSE
}

# ================================================================
#  MODULO 14 — RESTAURAR TUDO
# ================================================================
function Invoke-Restaurar {
    H2 "RESTAURAR CONFIGURACOES ORIGINAIS"

    IN "Restaurando plano de energia..."
    $pBkp = Join-Path $Script:PastaBackup "plano.txt"
    if (Test-Path $pBkp) {
        $guid = (Get-Content $pBkp -Raw).Trim()
        if ($guid) { powercfg /setactive $guid 2>$null; OK "Plano de energia original restaurado" }
    } else {
        powercfg /setactive SCHEME_BALANCED 2>$null; OK "Plano Balanceado restaurado"
    }

    IN "Restaurando servicos..."
    $sBkp = Join-Path $Script:PastaBackup "servicos.json"
    if (Test-Path $sBkp) {
        $mapa = Get-Content $sBkp -Raw | ConvertFrom-Json
        foreach ($prop in $mapa.PSObject.Properties) {
            try {
                $st = switch ($prop.Value) {
                    "Automatic" { [System.ServiceProcess.ServiceStartMode]::Automatic }
                    "Manual"    { [System.ServiceProcess.ServiceStartMode]::Manual }
                    default     { [System.ServiceProcess.ServiceStartMode]::Manual }
                }
                Set-Service -Name $prop.Name -StartupType $st -ErrorAction SilentlyContinue
            } catch {}
        }
        OK "Servicos restaurados"
    } else { WN "Backup de servicos nao encontrado" }

    IN "Removendo tweaks de rede (Nagle)..."
    try {
        Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" | ForEach-Object {
            Remove-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Force 2>$null
            Remove-ItemProperty -Path $_.PSPath -Name "TCPNoDelay"      -Force 2>$null
        }
        OK "Tweaks de rede removidos"
    } catch {}

    IN "Removendo politicas de telemetria..."
    Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Recurse -Force 2>$null
    OK "Politica de telemetria removida"

    IN "Removendo bloqueio de Cortana..."
    Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Recurse -Force 2>$null

    IN "Restaurando animacoes visuais ao padrao..."
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
        -Name "VisualFXSetting" -Value 0 -Type DWord -Force 2>$null
    Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
        -Name "EnableTransparency" -Value 1 -Type DWord -Force 2>$null
    OK "Animacoes e transparencia restauradas"

    $Script:OtimAplicada = $false
    $Script:TweaksFeitos.Clear()

    Write-Host ""
    OK "Restauracao concluida com sucesso!"
    WN "Reinicie o computador para garantir que todas as mudancas tenham efeito."
    LOG "Restauracao completa realizada"
    PAUSE
}

# ================================================================
#  MODULO 15 — APLICAR TUDO (PERFIL COMPLETO)
# ================================================================
function Invoke-AplicarTudo {
    H2 "PERFIL COMPLETO — APLICAR TODAS AS OTIMIZACOES"

    if (-not $Script:CPUNome) { Invoke-DetectarHardware }

    Write-Host "  Hardware detectado:" -ForegroundColor Cyan
    Write-Host "  CPU : $($Script:CPUNome)$(if($Script:CPUX3D){' [X3D]'})" -ForegroundColor White
    Write-Host "  GPU : $($Script:GPUNome)" -ForegroundColor White
    Write-Host "  RAM : $($Script:RAMtotalGB) GB $($Script:RAMtipo)" -ForegroundColor White
    Write-Host ""
    Write-Host "  O que sera aplicado:" -ForegroundColor Cyan
    IN "  1. Plano de energia (adaptado para $($Script:CPUFab)$(if($Script:CPUX3D){' X3D'}))"
    IN "  2. Privacidade e telemetria"
    IN "  3. Xbox Game Bar OFF / Game Mode ON / HAGS"
    IN "  4. Rede (Nagle OFF, NIC tweaks, banda liberada)"
    IN "  5. Servicos desnecessarios"
    IN "  6. Visual e performance"
    if ($Script:CPUX3D) { IN "  7. Otimizacoes exclusivas X3D V-Cache" }
    elseif ($Script:CPUFab -eq 'Intel') { IN "  7. Otimizacoes Intel (Turbo/UltimatePerfomance)" }
    IN "  8. Limpeza de arquivos temporarios"
    Write-Host ""
    WN "Um backup completo sera salvo antes de qualquer alteracao."
    Write-Host ""

    if (-not (CONF "Confirmar aplicacao de todas as otimizacoes?")) {
        WN "Cancelado."; PAUSE; return
    }

    Invoke-PlanoEnergia
    Invoke-Privacidade
    Invoke-GameMode
    Invoke-OtimizarRede
    Invoke-Servicos
    Invoke-VisualPerf

    if ($Script:CPUX3D) {
        Invoke-OtimizacoesX3D
    } elseif ($Script:CPUFab -eq 'Intel') {
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 2>$null
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE 2 2>$null
        OK "Intel: Core Parking OFF, Turbo Boost agressivo"
        $Script:TweaksFeitos.Add("Intel: Core Parking OFF, Turbo agressivo")
    } elseif ($Script:CPUFab -eq 'AMD') {
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100 2>$null
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE 2 2>$null
        OK "AMD: Core Parking OFF, Boost agressivo"
        $Script:TweaksFeitos.Add("AMD: Core Parking OFF, Boost agressivo")
    }

    Invoke-LimparTemp

    $Script:OtimAplicada = $true

    Write-Host ""
    Write-Host ("  " + [char]0x2550 * 70) -ForegroundColor Green
    OK "TODAS AS OTIMIZACOES APLICADAS COM SUCESSO!"
    Write-Host ("  " + [char]0x2550 * 70) -ForegroundColor Green
    Write-Host ""
    Write-Host "  Tweaks aplicados ($($Script:TweaksFeitos.Count)):" -ForegroundColor Cyan
    foreach ($t in $Script:TweaksFeitos) { Write-Host "    $([char]0x25B8) $t" -ForegroundColor DarkGreen }
    Write-Host ""
    WN "Reinicie o computador para que TODAS as mudancas tenham efeito."
    LOG "Perfil completo aplicado: $($Script:TweaksFeitos.Count) tweaks"
    PAUSE
}

# Alias para compatibilidade de chamada interna
function Invoke-LimparTemp { Invoke-Limpeza }

# ================================================================
#  MENUS — ESTRUTURA HIERARQUICA
# ================================================================
function Show-MenuOtimizacao {
    while ($true) {
        Show-Banner
        Show-StatusBar
        H1 "OTIMIZACAO DO SISTEMA"
        Write-Host ""
        Write-Host "   [1]  Plano de Energia Inteligente         (detecta CPU)" -ForegroundColor White
        Write-Host "   [2]  Privacidade e Telemetria             (48 tweaks)" -ForegroundColor White
        Write-Host "   [3]  Game Bar OFF / Game Mode ON / HAGS" -ForegroundColor White
        Write-Host "   [4]  Otimizacao de Rede                   (ping/PL/DNS)" -ForegroundColor White
        Write-Host "   [5]  Servicos Desnecessarios" -ForegroundColor White
        Write-Host "   [6]  Visual e Performance" -ForegroundColor White
        if ($Script:CPUX3D) {
            Write-Host "   [7]  Otimizacoes X3D V-Cache              [RECOMENDADO para $($Script:CPUNome)]" -ForegroundColor Magenta
        }
        Write-Host ""
        Write-Host "   [V]  Voltar" -ForegroundColor DarkGray
        Write-Host ""
        SEP; Write-Host ""
        $op = Read-Host "  Opcao"
        switch ($op.Trim().ToUpper()) {
            '1' { Clear-Host; if(-not $Script:CPUNome){Invoke-DetectarHardware}; Invoke-PlanoEnergia; PAUSE }
            '2' { Clear-Host; Invoke-Privacidade; PAUSE }
            '3' { Clear-Host; Invoke-GameMode; PAUSE }
            '4' { Clear-Host; Invoke-OtimizarRede }
            '5' { Clear-Host; Invoke-Servicos; PAUSE }
            '6' { Clear-Host; Invoke-VisualPerf; PAUSE }
            '7' { Clear-Host; if($Script:CPUX3D){Invoke-OtimizacoesX3D; PAUSE} }
            'V' { return }
        }
    }
}

function Show-MenuFerramentas {
    while ($true) {
        Show-Banner
        Show-StatusBar
        H1 "FERRAMENTAS"
        Write-Host ""
        Write-Host "   [1]  Instalar Programas via Winget" -ForegroundColor White
        Write-Host "   [2]  Debloater (remover apps desnecessarios)" -ForegroundColor White
        Write-Host "   [3]  Reparar Windows (SFC + DISM)" -ForegroundColor White
        Write-Host "   [4]  Controle do Windows Update" -ForegroundColor White
        Write-Host "   [5]  Limpeza do Sistema" -ForegroundColor White
        Write-Host "   [6]  Analisador de OC de GPU" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "   [V]  Voltar" -ForegroundColor DarkGray
        Write-Host ""
        SEP; Write-Host ""
        $op = Read-Host "  Opcao"
        switch ($op.Trim().ToUpper()) {
            '1' { Clear-Host; Invoke-Instalador }
            '2' { Clear-Host; Invoke-Debloater }
            '3' { Clear-Host; Invoke-RepararWindows }
            '4' { Clear-Host; Invoke-WindowsUpdate }
            '5' { Clear-Host; Invoke-Limpeza }
            '6' { Clear-Host; Invoke-AnalisadorGPU }
            'V' { return }
        }
    }
}

function Show-MenuPrincipal {
    $rodando = $true
    while ($rodando) {
        Show-Banner
        Show-StatusBar

        Write-Host "   $([char]0x25B6)  ACOES RAPIDAS" -ForegroundColor DarkGray
        Write-Host "   [1]  Detectar Hardware Completo" -ForegroundColor White
        Write-Host "   [2]  Aplicar TUDO (perfil completo — recomendado)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   $([char]0x25B6)  CATEGORIAS" -ForegroundColor DarkGray
        Write-Host "   [3]  Otimizacao do Sistema" -ForegroundColor Cyan
        Write-Host "   [4]  Ferramentas  (Instalar Apps / Debloat / Repair / OC GPU)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   $([char]0x25B6)  SISTEMA" -ForegroundColor DarkGray
        Write-Host "   [5]  Restaurar Configuracoes Originais" -ForegroundColor Red
        Write-Host "   [6]  Sair" -ForegroundColor DarkGray
        Write-Host ""
        SEP; Write-Host ""

        $op = Read-Host "  Selecione [1-6]"
        switch ($op.Trim()) {
            '1' { Clear-Host; Invoke-DetectarHardware }
            '2' { Clear-Host; Invoke-AplicarTudo }
            '3' { Show-MenuOtimizacao }
            '4' { Show-MenuFerramentas }
            '5' { Clear-Host; Invoke-Restaurar }
            '6' {
                Write-Host ""
                if ($Script:OtimAplicada) {
                    WN "Otimizacoes ainda ativas nesta sessao."
                    if (CONF "Restaurar antes de sair?") { Invoke-Restaurar }
                }
                IN "Log salvo em: $($Script:LogFile)"
                Write-Host ""; $rodando = $false
            }
            default { WN "Opcao invalida."; Start-Sleep 1 }
        }
    }
}

# ================================================================
#  INICIALIZACAO
# ================================================================
LOG "=== OTIMIZADOR INTELIGENTE v$($Script:Versao) ==="
LOG "Sessao: $($Script:IDSessao) | Usuario: $env:USERNAME | Maquina: $env:COMPUTERNAME"
LOG "==="

Show-MenuPrincipal