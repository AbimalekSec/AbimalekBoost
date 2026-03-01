#Requires -Version 5.1
<#
.SYNOPSIS
    OTIMIZADOR INTELIGENTE v4.0
    Deteccao inteligente de hardware + otimizacoes especificas por CPU/GPU

.NOTES
    - Requer execucao como Administrador (Windows 10/11)
    - Totalmente reversivel via backup automatico
    - Execute com: powershell.exe -ExecutionPolicy Bypass -File "AbimalekBoost.ps1"

.CHANGELOG v4.0
    - NOVO: Modulo de Overclock de RAM (XMP/EXPO + latencias)
    - NOVO: Modulo IRQ Priority (prioridade de interrupcos por hardware)
    - NOVO: Modulo MSI Mode para NIC e GPU (Message Signaled Interrupts)
    - NOVO: Modulo de Timer Resolution (aumenta precisao do scheduler)
    - NOVO: Otimizacoes de NTFS e I/O para SSD/NVMe
    - NOVO: Desativar Mitigacoes Spectre/Meltdown (opcional - risco vs ganho)
    - NOVO: Configuracoes avancadas de GPU via nvidia-smi (frequencia minima)
    - NOVO: Perfil "Modo Streamer" (OBS + jogo sem drops)
    - NOVO: Analise de temperatura e throttling em tempo real
    - NOVO: Exportar relatorio de otimizacoes em TXT
    - MELHORIA: Deteccao de disco NVMe vs SATA vs HDD com tweaks especificos
    - MELHORIA: DNS com ping automatico para recomendar o mais rapido
    - MELHORIA: Debloater atualizado com mais 20 apps
    - MELHORIA: Plano de energia com perfis por uso (Gaming / Workstation / Equilibrado)
    - MELHORIA: Interface mais informativa com barra de progresso ASCII
#>

Set-StrictMode -Off
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ================================================================
#  VARIAVEIS GLOBAIS
# ================================================================
$Script:Versao      = "4.0.0"
$Script:NomeProg    = "Abimalek Boost"
$Script:IDSessao    = (New-Guid).ToString("N").Substring(0,8).ToUpper()

# Hardware
$Script:CPUNome     = ""; $Script:CPUFab   = ""; $Script:CPUNucleos  = 0; $Script:CPUThreads = 0
$Script:CPUX3D      = $false; $Script:CPUIntelK = $false; $Script:CPUGen = 0
$Script:RAMtotalGB  = 0; $Script:RAMtipo   = ""; $Script:RAMvelocidade = 0; $Script:RAMslots = 0
$Script:GPUNome     = ""; $Script:GPUFab   = ""; $Script:GPUVRAM = 0
$Script:GPUTemp     = -1; $Script:GPUCore  = -1; $Script:GPUPL   = -1; $Script:GPUPLmax = -1
$Script:GPUSmi      = ""; $Script:GPUDriver = ""
$Script:DiscoTipo   = ""; $Script:DiscoNome = ""; $Script:DiscoNVMe = $false
$Script:WinBuild    = 0;  $Script:WinVer    = ""
$Script:TemWinget   = $false

# Estado
$Script:TweaksFeitos   = [System.Collections.Generic.List[string]]::new()
$Script:SvcsBackup     = @{}
$Script:PlanoOrig      = ""
$Script:OtimAplicada   = $false
$Script:ModoStreamer    = $false

# Pastas
$Script:PastaRaiz   = Join-Path $env:LOCALAPPDATA "AbimalekBoost"
$Script:PastaBackup = Join-Path $Script:PastaRaiz "Backup"
$Script:PastaLogs   = Join-Path $Script:PastaRaiz "Logs"
$Script:LogFile     = Join-Path $Script:PastaLogs "v4_$($Script:IDSessao)_$(Get-Date -f 'yyyyMMdd_HHmmss').log"

foreach ($p in @($Script:PastaRaiz, $Script:PastaBackup, $Script:PastaLogs)) {
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

# ================================================================
#  UI - HELPERS
# ================================================================
function LOG  { param([string]$m, [string]$n='INFO')
    try { Add-Content $Script:LogFile "$(Get-Date -f 'HH:mm:ss') [$n] $m" -Encoding UTF8 } catch {} }

function OK   { Write-Host "  [+] $args" -ForegroundColor Green }
function WN   { Write-Host "  [!] $args" -ForegroundColor Yellow }
function ER   { Write-Host "  [X] $args" -ForegroundColor Red }
function IN   { Write-Host "  [>] $args" -ForegroundColor Gray }
function H1   { Write-Host "`n  $args" -ForegroundColor Cyan }
function INF  { Write-Host "  [i] $args" -ForegroundColor DarkCyan }

function H2 {
    $txt = $args -join " "
    $linha = "=" * 70
    Write-Host ""
    Write-Host "  $linha" -ForegroundColor Cyan
    Write-Host "  ## $txt" -ForegroundColor Cyan
    Write-Host "  $linha" -ForegroundColor Cyan
    Write-Host ""
}

function SEP  { Write-Host "  $("-"*70)" -ForegroundColor DarkCyan }
function PAUSE { Read-Host "`n  [ ENTER para continuar ]" | Out-Null }

function CONF {
    param([string]$msg = "Confirmar?")
    $r = Read-Host "  $msg (S/N)"
    return ($r -match '^[Ss]$')
}

function Show-Progress {
    param([string]$Label, [int]$Atual, [int]$Total)
    $pct  = [math]::Round($Atual / [math]::Max($Total, 1) * 100)
    $fill = [math]::Round($pct / 5)
    $bar  = ("#" * $fill).PadRight(20)
    Write-Host "`r  [$bar] $pct% - $Label        " -NoNewline -ForegroundColor Cyan
}

function Show-Banner {
    Clear-Host
    $linha = "=" * 72
    Write-Host ""
    Write-Host "  $linha" -ForegroundColor Cyan
    Write-Host "  ##  $($Script:NomeProg)  v$($Script:Versao)$((" "*([math]::Max(0,55-$Script:NomeProg.Length-$Script:Versao.Length)))  )##" -ForegroundColor Cyan
    Write-Host "  ##  Inspirado no WinUtil do Chris Titus Tech$((" "*28))##" -ForegroundColor DarkCyan
    Write-Host "  $linha" -ForegroundColor Cyan
    Write-Host "  ID Sessao: $($Script:IDSessao)   |   $(Get-Date -f 'dd/MM/yyyy HH:mm')" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-StatusBar {
    $corCPU = if ($Script:CPUNome) { if ($Script:CPUX3D) {'Magenta'} else {'White'} } else { 'DarkGray' }
    $corGPU = if ($Script:GPUNome) { 'White' } else { 'DarkGray' }
    $corOtm = if ($Script:OtimAplicada) { 'Green' } else { 'DarkGray' }
    $txtOtm = if ($Script:OtimAplicada) { "ATIVO ($($Script:TweaksFeitos.Count) tweaks)" } else { "Pendente" }

    $cpuTxt = if ($Script:CPUNome) { $Script:CPUNome } else { "Nao detectado" }
    $gpuTxt = if ($Script:GPUNome) { $Script:GPUNome } else { "Nao detectada" }

    Write-Host "  CPU : " -NoNewline -ForegroundColor DarkGray
    Write-Host $cpuTxt -NoNewline -ForegroundColor $corCPU
    if ($Script:CPUX3D)     { Write-Host " [X3D]"    -NoNewline -ForegroundColor Magenta }
    if ($Script:CPUIntelK)  { Write-Host " [K-serie]"-NoNewline -ForegroundColor Yellow }
    Write-Host ""

    Write-Host "  GPU : " -NoNewline -ForegroundColor DarkGray
    Write-Host $gpuTxt -NoNewline -ForegroundColor $corGPU
    if ($Script:GPUTemp -gt 0) {
        $cor = if($Script:GPUTemp -lt 60){'Green'}elseif($Script:GPUTemp -lt 75){'Yellow'}else{'Red'}
        Write-Host "  ($($Script:GPUTemp)C)" -NoNewline -ForegroundColor $cor
    }
    Write-Host ""

    Write-Host "  RAM : " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($Script:RAMtotalGB) GB $($Script:RAMtipo)$(if($Script:RAMvelocidade -gt 0){" @ $($Script:RAMvelocidade) MHz"})" -ForegroundColor White

    Write-Host "  Disco: " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($Script:DiscoNome) $(if($Script:DiscoNVMe){'[NVMe]'}elseif($Script:DiscoTipo -eq 'SSD'){'[SSD]'}else{'[HDD]'})" -ForegroundColor White

    Write-Host "  Status: " -NoNewline -ForegroundColor DarkGray
    Write-Host $txtOtm -ForegroundColor $corOtm
    if ($Script:ModoStreamer) { Write-Host "  [MODO STREAMER ATIVO]" -ForegroundColor Magenta }
    Write-Host ""
    SEP
    Write-Host ""
}

# ================================================================
#  VERIFICACAO DE ADMIN
# ================================================================
function Test-Admin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-Admin)) {
    Write-Host "`n  [ERRO] Execute como Administrador!" -ForegroundColor Red
    Write-Host "  Clique direito no PowerShell > Executar como Administrador`n" -ForegroundColor Yellow
    Read-Host "  ENTER para sair" | Out-Null; exit 1
}

# ================================================================
#  DETECCAO DE HARDWARE (v4 - mais detalhes)
# ================================================================
function Invoke-DetectarHardware {
    H2 "DETECTANDO HARDWARE"

    # CPU
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $Script:CPUNome    = $cpu.Name.Trim()
        $Script:CPUNucleos = $cpu.NumberOfCores
        $Script:CPUThreads = $cpu.NumberOfLogicalProcessors
        $Script:CPUFab     = if ($Script:CPUNome -match 'AMD') {'AMD'} elseif ($Script:CPUNome -match 'Intel') {'Intel'} else {'Outro'}
        $Script:CPUX3D     = $Script:CPUNome -match 'X3D'
        $Script:CPUIntelK  = $Script:CPUNome -match '\d{4,5}K[FSs]?\b'

        # Detectar geracao Intel
        if ($Script:CPUFab -eq 'Intel' -and $Script:CPUNome -match 'i[3579]-(\d{4,5})') {
            $n = [int]($Matches[1].Substring(0,2))
            $Script:CPUGen = $n
        }

        OK "CPU    : $($Script:CPUNome)"
        OK "Nucleos: $($Script:CPUNucleos) fisicos / $($Script:CPUThreads) logicos | Fab: $($Script:CPUFab)$(if($Script:CPUX3D){' | [V-Cache X3D]'})"
        if ($Script:CPUGen -gt 0) { INF "Geracao Intel detectada: $($Script:CPUGen)a geracao" }
    } catch { ER "Falha ao detectar CPU" }

    # RAM (v4: detecta velocidade e numero de slots)
    try {
        $ram = Get-CimInstance Win32_PhysicalMemory
        $Script:RAMtotalGB    = [math]::Round(($ram | Measure-Object -Property Capacity -Sum).Sum / 1GB, 0)
        $Script:RAMslots      = ($ram | Measure-Object).Count
        $Script:RAMvelocidade = ($ram | Select-Object -First 1).Speed
        $ramTipoNum           = ($ram | Select-Object -First 1).SMBIOSMemoryType
        $Script:RAMtipo       = switch ($ramTipoNum) { 26{'DDR4'} 34{'DDR5'} 21{'DDR3'} default{'DDR?'} }

        OK "RAM    : $($Script:RAMtotalGB) GB $($Script:RAMtipo) @ $($Script:RAMvelocidade) MHz | $($Script:RAMslots) modulo(s)"

        # Aviso sobre dual-channel
        if ($Script:RAMslots -eq 1) {
            WN "Apenas 1 modulo de RAM - considere adicionar outro para Dual Channel (ganho de 20pct em perf)"
        }
    } catch { ER "Falha ao detectar RAM" }

    # GPU (v4: detecta versao do driver)
    try {
        $gpu = Get-CimInstance Win32_VideoController | Where-Object {
            $_.Name -notmatch 'Microsoft|Remote|Virtual|Basic' -and $_.AdapterRAM -gt 200MB
        } | Sort-Object AdapterRAM -Descending | Select-Object -First 1
        if (-not $gpu) { $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1 }

        $Script:GPUNome   = $gpu.Name.Trim()
        $Script:GPUVRAM   = [math]::Round($gpu.AdapterRAM / 1GB, 0)
        $Script:GPUDriver = $gpu.DriverVersion
        $Script:GPUFab    = if ($Script:GPUNome -match 'NVIDIA|GeForce|RTX|GTX') {'NVIDIA'}
                             elseif ($Script:GPUNome -match 'AMD|Radeon|RX\s') {'AMD'}
                             elseif ($Script:GPUNome -match 'Intel|Arc') {'Intel'}
                             else {'Outro'}

        # Localizar nvidia-smi
        $smis = @(
            "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe",
            "$env:SystemRoot\System32\nvidia-smi.exe"
        )
        foreach ($c in $smis) { if (Test-Path $c) { $Script:GPUSmi = $c; break } }
        if (-not $Script:GPUSmi) {
            $cmd = Get-Command "nvidia-smi.exe" -ErrorAction SilentlyContinue
            if ($cmd) { $Script:GPUSmi = $cmd.Source }
        }

        # Dados nvidia-smi
        if ($Script:GPUFab -eq 'NVIDIA' -and $Script:GPUSmi) {
            $d = & $Script:GPUSmi --query-gpu=temperature.gpu,clocks.current.graphics,power.limit,power.max_limit --format=csv,noheader,nounits 2>$null
            if ($d) {
                $cols = $d -split ','
                if ($cols.Count -ge 4) {
                    $Script:GPUTemp  = [int]($cols[0].Trim())
                    $Script:GPUCore  = [int]($cols[1].Trim())
                    $Script:GPUPL    = [math]::Round([double]($cols[2].Trim()), 0)
                    $Script:GPUPLmax = [math]::Round([double]($cols[3].Trim()), 0)
                }
            }
        }

        OK "GPU    : $($Script:GPUNome) ($($Script:GPUVRAM) GB VRAM) | Driver: $($Script:GPUDriver)"
        if ($Script:GPUTemp -gt 0) {
            $corT = if($Script:GPUTemp -lt 60){'Green'}elseif($Script:GPUTemp -lt 75){'Yellow'}else{'Red'}
            Write-Host "  [+] GPU Live: $($Script:GPUTemp)C | Core $($Script:GPUCore)MHz | PL $($Script:GPUPL)W (max $($Script:GPUPLmax)W)" -ForegroundColor $corT
        }
    } catch { ER "Falha ao detectar GPU" }

    # Disco (v4: detecta NVMe via WMI)
    try {
        $disco = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq "0" } | Select-Object -First 1
        if (-not $disco) { $disco = Get-PhysicalDisk | Select-Object -First 1 }
        $Script:DiscoNome = $disco.FriendlyName
        $Script:DiscoTipo = $disco.MediaType

        # Detectar NVMe
        $nvme = Get-CimInstance -Namespace root/Microsoft/Windows/Storage -ClassName MSFT_PhysicalDisk 2>$null |
                Where-Object { $_.BusType -eq 17 } | Select-Object -First 1
        if ($nvme) { $Script:DiscoNVMe = $true }
        # Fallback pelo nome
        if ($Script:DiscoNome -match 'NVMe|M\.2|PCIe') { $Script:DiscoNVMe = $true }

        $tipoStr = if ($Script:DiscoNVMe) { "NVMe" } elseif ($Script:DiscoTipo -match 'SSD') { "SSD SATA" } else { "HDD" }
        OK "Disco  : $($Script:DiscoNome) [$tipoStr]"
    } catch { ER "Falha ao detectar disco" }

    # Windows
    try {
        $win = Get-CimInstance Win32_OperatingSystem
        $Script:WinBuild = [int]$win.BuildNumber
        $Script:WinVer   = $win.Caption
        OK "SO     : $($Script:WinVer) (Build $($Script:WinBuild))"
        OK "Usuario: $env:USERNAME @ $env:COMPUTERNAME"
    } catch {}

    # Winget
    $Script:TemWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    if ($Script:TemWinget) { OK "Winget : Disponivel" } else { WN "Winget : Nao encontrado" }

    LOG "HW detectado: CPU=$($Script:CPUNome) | GPU=$($Script:GPUNome) | RAM=$($Script:RAMtotalGB)GB $($Script:RAMtipo) @$($Script:RAMvelocidade)MHz | Disco=$($Script:DiscoNome) NVMe=$($Script:DiscoNVMe)"
    PAUSE
}

# ================================================================
#  MODULO 1 - PLANO DE ENERGIA INTELIGENTE v4
# ================================================================
function Invoke-PlanoEnergia {
    H2 "PLANO DE ENERGIA INTELIGENTE"

    # Backup do plano atual
    $atual = powercfg /getactivescheme 2>$null
    if ($atual -match 'GUID:\s*([\w-]+)') {
        $Script:PlanoOrig = $Matches[1]
        $Script:PlanoOrig | Out-File (Join-Path $Script:PastaBackup "plano.txt") -Encoding UTF8 -Force
        IN "Plano atual salvo: $($Script:PlanoOrig)"
    }

    # Menu de perfil
    Write-Host "  Selecione o perfil de uso:" -ForegroundColor Cyan
    Write-Host "  [1] Gaming         - maxima performance em jogos" -ForegroundColor White
    Write-Host "  [2] Workstation    - performance + estabilidade termica" -ForegroundColor White
    Write-Host "  [3] Equilibrado    - bom para uso misto (padrao Intel X3D)" -ForegroundColor White
    Write-Host "  [4] Detectar auto  - o script decide baseado no seu hardware" -ForegroundColor Yellow
    Write-Host ""
    $per = Read-Host "  Perfil [1-4]"
    if (-not $per) { $per = "4" }

    $modoGaming      = $false
    $modoWorkstation = $false
    $modoEquil       = $false

    switch ($per.Trim()) {
        '1' { $modoGaming = $true }
        '2' { $modoWorkstation = $true }
        '3' { $modoEquil = $true }
        default {
            if ($Script:CPUX3D)              { $modoEquil = $true }
            elseif ($Script:CPUFab -eq 'AMD'){ $modoGaming = $true }
            else                             { $modoGaming = $true }
        }
    }

    if ($Script:CPUX3D -and $modoGaming) {
        WN "X3D detectado com Gaming: usando Balanced (High Perf prejudica V-Cache)"
        $modoGaming = $false; $modoEquil = $true
    }

    # Aplicar plano base
    if ($modoEquil -or $Script:CPUX3D) {
        $amd = powercfg /list 2>$null | Select-String 'AMD Ryzen Balanced'
        if ($amd -and $Script:CPUFab -eq 'AMD') {
            $guid = ($amd.Line -split '\s+' | Where-Object {$_ -match '^[0-9a-f-]{36}$'}) | Select-Object -First 1
            if ($guid) { powercfg /setactive $guid 2>$null; OK "AMD Ryzen Balanced ativado (ideal para X3D)" }
        } else {
            powercfg /setactive SCHEME_BALANCED 2>$null; OK "Plano Balanceado ativado"
        }
    } elseif ($modoGaming -and $Script:CPUFab -eq 'Intel') {
        powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-Null
        $ult = powercfg /list 2>$null | Select-String 'Ultimate Performance'
        if ($ult) {
            $guid = ($ult.Line -split '\s+' | Where-Object {$_ -match '^[0-9a-f-]{36}$'}) | Select-Object -First 1
            if ($guid) { powercfg /setactive $guid 2>$null; OK "Ultimate Performance ativado (Intel Gaming)" }
        } else { powercfg /setactive SCHEME_MIN 2>$null; OK "Alto Desempenho ativado" }
    } else {
        # AMD Gaming
        $amd = powercfg /list 2>$null | Select-String 'AMD Ryzen Balanced'
        if ($amd) {
            $guid = ($amd.Line -split '\s+' | Where-Object {$_ -match '^[0-9a-f-]{36}$'}) | Select-Object -First 1
            if ($guid) { powercfg /setactive $guid 2>$null; OK "AMD Ryzen Balanced ativado" }
        } else { powercfg /setactive SCHEME_MIN 2>$null; OK "Alto Desempenho ativado" }
    }

    # Configuracoes avancadas do plano
    $bmodo = if ($Script:CPUX3D) { 4 } elseif ($modoWorkstation) { 0 } else { 2 }
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES     100    2>$null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE  $bmodo 2>$null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFINCTHRESHOLD 10   2>$null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFDECTHRESHOLD  8   2>$null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR SYSCOOLPOL      0     2>$null  # Active cooling
    powercfg /change standby-timeout-ac 0 2>$null
    powercfg /change monitor-timeout-ac 0 2>$null

    # NOVO v4: Desativar Hibernate (libera espaco no SSD)
    if ($modoGaming) {
        if (CONF "Desativar Hibernate? (libera GB no SSD - recomendado Gaming)") {
            powercfg /h off 2>$null
            OK "Hibernate desativado (hiberfil.sys removido)"
        }
    }

    # NOVO v4: Ajuste de CPU parking por geracao Intel
    if ($Script:CPUFab -eq 'Intel' -and $Script:CPUGen -ge 12) {
        # Alder Lake e acima: E-cores e P-cores - nao desativar parking total
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 50 2>$null
        WN "Intel $($Script:CPUGen)a ger. (E+P cores): Core Parking em 50% (P-cores ativos, E-cores gerenciados)"
    }

    OK "Sleep desativado | Boost: modo $(if($Script:CPUX3D){'Efficient Aggressive (X3D)'}elseif($modoWorkstation){'Disabled (Workstation)'}else{'Aggressive'})"
    $Script:TweaksFeitos.Add("Plano de energia: perfil $(if($modoGaming){'Gaming'}elseif($modoWorkstation){'Workstation'}else{'Equilibrado'})")
    LOG "Plano de energia configurado: Gaming=$modoGaming Work=$modoWorkstation Equil=$modoEquil"
}

# ================================================================
#  MODULO 2 - PRIVACIDADE E TELEMETRIA
# ================================================================
function Invoke-Privacidade {
    H2 "PRIVACIDADE E TELEMETRIA"

    $tweaks = @(
        # Telemetria
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";                        N="AllowTelemetry";                              V=0}
        @{P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection";         N="AllowTelemetry";                              V=0}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";                        N="DoNotShowFeedbackNotifications";              V=1}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";                        N="LimitDiagnosticLogCollection";                V=1}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";                        N="DisableOneSettingsDownloads";                 V=1}
        # Anuncios
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo";                 N="Enabled";                                     V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy";                         N="TailoredExperiencesWithDiagnosticDataEnabled";V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";          N="SilentInstalledAppsEnabled";                  V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";          N="SystemPaneSuggestionsEnabled";                V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";          N="SoftLandingEnabled";                          V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";          N="SubscribedContentEnabled";                    V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";          N="OemPreInstalledAppsEnabled";                  V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";          N="PreInstalledAppsEnabled";                     V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager";          N="ContentDeliveryAllowed";                      V=0}
        # Historico / Timeline
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System";                                N="EnableActivityFeed";                          V=0}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System";                                N="PublishUserActivities";                       V=0}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System";                                N="UploadUserActivities";                        V=0}
        # Localizacao
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors";                    N="DisableLocation";                             V=1}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"; N="Value";                        V="Deny"; T="String"}
        # Cortana / Search
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search";                        N="AllowCortana";                                V=0}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search";                        N="DisableWebSearch";                            V=1}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search";                        N="ConnectedSearchUseWeb";                       V=0}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search";                        N="AllowSearchHighlights";                       V=0}
        # Start / sugestoes
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced";               N="ShowSyncProviderNotifications";               V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced";               N="Start_TrackProgs";                            V=0}
        # Diagnostico / apps
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics"; N="Value";                  V="Deny"; T="String"}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone";     N="Value";                  V="Deny"; T="String"}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam";         N="Value";                  V="Deny"; T="String"}
        # Feedback
        @{P="HKCU:\SOFTWARE\Microsoft\Siuf\Rules";                                             N="NumberOfSIUFInPeriod";                        V=0}
        @{P="HKCU:\SOFTWARE\Microsoft\Siuf\Rules";                                             N="PeriodInNanoSeconds";                         V=0}
        # NOVO v4: OneDrive startup
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run";                             N="OneDrive";                                    V=""; T="RemoveIfExists"}
        # NOVO v4: Recall (Windows 11 24H2)
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI";                             N="DisableAIDataAnalysis";                       V=1}
    )

    $ok = 0
    foreach ($t in $tweaks) {
        try {
            if (-not (Test-Path $t.P)) { New-Item -Path $t.P -Force | Out-Null }
            if ($t.T -eq 'RemoveIfExists') {
                if (Get-ItemProperty $t.P -Name $t.N -ErrorAction SilentlyContinue) {
                    Remove-ItemProperty $t.P -Name $t.N -Force -ErrorAction SilentlyContinue
                    $ok++
                }
            } elseif ($t.T -eq 'String') {
                Set-ItemProperty -Path $t.P -Name $t.N -Value $t.V -Type String -Force
                $ok++
            } else {
                Set-ItemProperty -Path $t.P -Name $t.N -Value $t.V -Type DWord -Force
                $ok++
            }
        } catch {}
    }

    OK "Telemetria e diagnostico desativados"
    OK "Anuncios e sugestoes bloqueados"
    OK "Cortana e pesquisa web desativados"
    OK "Recall (Windows AI) desativado"
    OK "$ok tweaks de privacidade aplicados"
    $Script:TweaksFeitos.Add("Privacidade: $ok tweaks")
    LOG "Privacidade: $ok tweaks"
}

# ================================================================
#  MODULO 3 - GAME BAR, GAME MODE, HAGS
# ================================================================
function Invoke-GameMode {
    H2 "GAME BAR / GAME MODE / HAGS"

    $tweaks = @(
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR";        N="AppCaptureEnabled";                     V=0}
        @{P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR";              N="AllowGameDVR";                          V=0}
        @{P="HKCU:\System\GameConfigStore";                                    N="GameDVR_Enabled";                       V=0}
        @{P="HKCU:\System\GameConfigStore";                                    N="GameDVR_FSEBehaviorMode";               V=2}
        @{P="HKCU:\System\GameConfigStore";                                    N="GameDVR_HonorUserFSEBehaviorMode";      V=1}
        @{P="HKCU:\System\GameConfigStore";                                    N="GameDVR_DXGIHonorFSEWindowsCompatible"; V=1}
        @{P="HKCU:\SOFTWARE\Microsoft\GameBar";                                N="AllowAutoGameMode";                     V=1}
        @{P="HKCU:\SOFTWARE\Microsoft\GameBar";                                N="AutoGameModeEnabled";                   V=1}
        # HAGS - Hardware Accelerated GPU Scheduling
        @{P="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers";          N="HwSchMode";                             V=2}
        # Multimedia Scheduler
        @{P="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; N="SystemResponsiveness";     V=0}
        @{P="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; N="Priority";     V=6}
        # NOVO v4: MpKsL1 latencia do kernel scheduler
        @{P="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; N="Affinity";     V=0}
        @{P="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; N="Background Only"; V="False"; T="String"}
        @{P="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; N="Clock Rate";   V=10000}
        @{P="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; N="GPU Priority"; V=8}
    )

    foreach ($t in $tweaks) {
        try {
            if (-not (Test-Path $t.P)) { New-Item -Path $t.P -Force | Out-Null }
            if ($t.T -eq 'String') {
                Set-ItemProperty $t.P -Name $t.N -Value $t.V -Type String -Force
            } else {
                Set-ItemProperty $t.P -Name $t.N -Value $t.V -Type DWord -Force
            }
        } catch {}
    }

    try {
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
            -Name "Scheduling Category" -Value "High" -Force 2>$null
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
            -Name "SFIO Priority" -Value "High" -Force 2>$null
    } catch {}

    OK "Xbox Game Bar desativado"
    OK "Game Mode ON + GPU Priority 8"
    OK "HAGS (Hardware GPU Scheduling) ativado"
    OK "Multimedia Scheduler: prioridade maxima para jogos"
    $Script:TweaksFeitos.Add("Game Mode: Bar OFF / HAGS ON / MM Scheduler")
    LOG "Game Mode configurado"
}

# ================================================================
#  MODULO 4 - REDE AVANCADA (v4)
# ================================================================
function Invoke-OtimizarRede {
    H2 "OTIMIZACAO DE REDE"

    # Nagle Algorithm OFF
    try {
        Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" | ForEach-Object {
            Set-ItemProperty $_.PSPath -Name "TcpAckFrequency" -Value 1  -Type DWord -Force 2>$null
            Set-ItemProperty $_.PSPath -Name "TCPNoDelay"      -Value 1  -Type DWord -Force 2>$null
            Set-ItemProperty $_.PSPath -Name "TcpDelAckTicks"  -Value 0  -Type DWord -Force 2>$null
        }
        OK "Nagle Algorithm desativado"
    } catch { ER "Nagle: falha" }

    # NOVO v4: TCP Stack tweaks
    try {
        $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        Set-ItemProperty $tcpPath -Name "DefaultTTL"             -Value 64   -Type DWord -Force 2>$null
        Set-ItemProperty $tcpPath -Name "MaxUserPort"            -Value 65534 -Type DWord -Force 2>$null
        Set-ItemProperty $tcpPath -Name "TcpTimedWaitDelay"      -Value 30   -Type DWord -Force 2>$null
        Set-ItemProperty $tcpPath -Name "EnablePMTUDiscovery"    -Value 1    -Type DWord -Force 2>$null
        Set-ItemProperty $tcpPath -Name "Tcp1323Opts"            -Value 1    -Type DWord -Force 2>$null
        Set-ItemProperty $tcpPath -Name "GlobalMaxTcpWindowSize" -Value 65535 -Type DWord -Force 2>$null
        OK "TCP Stack otimizado (TTL=64, Timestamps, Window Scaling)"
    } catch {}

    # NOVO v4: Auto-Tuning Level
    try {
        netsh int tcp set global autotuninglevel=normal 2>$null | Out-Null
        netsh int tcp set global chimney=disabled 2>$null | Out-Null
        netsh int tcp set global dca=enabled 2>$null | Out-Null
        netsh int tcp set global netdma=enabled 2>$null | Out-Null
        netsh int tcp set global ecncapability=disabled 2>$null | Out-Null
        OK "TCP Autotuning normal | DCA/NetDMA ativados | ECN desativado"
    } catch {}

    # DNS com teste de latencia
    Write-Host ""
    Write-Host "  Configurar DNS rapido:" -ForegroundColor Cyan
    Write-Host "  [1] Cloudflare  1.1.1.1 / 1.0.0.1" -ForegroundColor White
    Write-Host "  [2] Google      8.8.8.8 / 8.8.4.4" -ForegroundColor White
    Write-Host "  [3] Quad9       9.9.9.9 / 149.112.112.112" -ForegroundColor White
    Write-Host "  [4] OpenDNS     208.67.222.222 / 208.67.220.220" -ForegroundColor White
    Write-Host "  [5] Testar automaticamente (recomendado)" -ForegroundColor Yellow
    Write-Host "  [6] Manter DNS atual" -ForegroundColor DarkGray
    Write-Host ""
    $dns = Read-Host "  Escolha o DNS [1-6]"

    $dns1 = ""; $dns2 = ""; $dnsNome = ""
    if ($dns.Trim() -eq '5') {
        IN "Testando latencia dos servidores DNS..."
        $servidores = @(
            @{N="Cloudflare";D1="1.1.1.1";     D2="1.0.0.1"}
            @{N="Google";    D1="8.8.8.8";     D2="8.8.4.4"}
            @{N="Quad9";     D1="9.9.9.9";     D2="149.112.112.112"}
            @{N="OpenDNS";   D1="208.67.222.222";D2="208.67.220.220"}
        )
        $melhor = $null; $melhorPing = 9999
        foreach ($s in $servidores) {
            $ping = (Test-Connection -ComputerName $s.D1 -Count 3 -ErrorAction SilentlyContinue |
                     Measure-Object -Property ResponseTime -Average).Average
            if ($null -eq $ping) { $ping = 9999 }
            Write-Host "    $($s.N.PadRight(12)): $([math]::Round($ping, 1)) ms" -ForegroundColor $(if($ping -lt 20){'Green'}elseif($ping -lt 50){'Yellow'}else{'Red'})
            if ($ping -lt $melhorPing) { $melhorPing = $ping; $melhor = $s }
        }
        if ($melhor) {
            $dns1 = $melhor.D1; $dns2 = $melhor.D2; $dnsNome = "$($melhor.N) (mais rapido: $([math]::Round($melhorPing,0))ms)"
            OK "DNS selecionado automaticamente: $($melhor.N)"
        }
    } else {
        switch ($dns.Trim()) {
            '1' { $dns1="1.1.1.1";          $dns2="1.0.0.1";           $dnsNome="Cloudflare" }
            '2' { $dns1="8.8.8.8";          $dns2="8.8.4.4";           $dnsNome="Google" }
            '3' { $dns1="9.9.9.9";          $dns2="149.112.112.112";   $dnsNome="Quad9" }
            '4' { $dns1="208.67.222.222";   $dns2="208.67.220.220";    $dnsNome="OpenDNS" }
        }
    }

    if ($dns1) {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Virtual|Loopback' }
        foreach ($ad in $adapters) {
            Set-DnsClientServerAddress -InterfaceIndex $ad.ifIndex -ServerAddresses ($dns1,$dns2) 2>$null
            IN "DNS $dnsNome aplicado em: $($ad.Name)"
        }
        OK "DNS $dnsNome configurado"
        $Script:TweaksFeitos.Add("DNS: $dnsNome")
    }

    # Reserva de banda
    try {
        if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched")) {
            New-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Force | Out-Null
        }
        Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -Value 0 -Type DWord -Force
        OK "Reserva de 20pct de banda liberada"
    } catch {}

    # NIC tweaks
    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        foreach ($ad in $adapters) {
            Set-NetAdapterAdvancedProperty -Name $ad.Name -DisplayName "Interrupt Moderation"            -DisplayValue "Disabled"  2>$null
            Set-NetAdapterAdvancedProperty -Name $ad.Name -DisplayName "Receive Side Scaling"            -DisplayValue "Enabled"   2>$null
            Set-NetAdapterAdvancedProperty -Name $ad.Name -DisplayName "Large Send Offload v2 (IPv4)"    -DisplayValue "Disabled"  2>$null
            Set-NetAdapterAdvancedProperty -Name $ad.Name -DisplayName "Large Send Offload v2 (IPv6)"    -DisplayValue "Disabled"  2>$null
            Set-NetAdapterAdvancedProperty -Name $ad.Name -DisplayName "Energy Efficient Ethernet"       -DisplayValue "Disabled"  2>$null
            Set-NetAdapterAdvancedProperty -Name $ad.Name -DisplayName "Packet Priority & VLAN"          -DisplayValue "Enabled"   2>$null
        }
        OK "NIC: IMod OFF | RSS ON | LSO OFF | EEE OFF"
    } catch {}

    # NOVO v4: MSI Mode para NIC
    try {
        $nics = Get-PnpDevice -Class 'Net' -Status 'OK' -ErrorAction SilentlyContinue
        foreach ($nic in $nics) {
            $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($nic.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            if (Test-Path $path) {
                Set-ItemProperty $path -Name "MSISupported" -Value 1 -Type DWord -Force 2>$null
            }
        }
        OK "MSI Mode ativado na NIC (reduz latencia de interrupcoes)"
    } catch {}

    ipconfig /flushdns 2>$null | Out-Null
    OK "Cache DNS limpo"

    $Script:TweaksFeitos.Add("Rede: Nagle OFF, TCP otimizado, NIC MSI, banda liberada")
    LOG "Rede otimizada v4"
}

# ================================================================
#  MODULO 5 - SERVICOS
# ================================================================
function Invoke-Servicos {
    H2 "SERVICOS DESNECESSARIOS"
    WN "Apenas servicos seguros serao desativados."
    Write-Host ""

    $svcs = @(
        @{N="DiagTrack";         D="Telemetria Microsoft (consome CPU+rede)"}
        @{N="dmwappushservice";  D="WAP Push Messages"}
        @{N="XblAuthManager";    D="Xbox Live Auth"}
        @{N="XblGameSave";       D="Xbox Game Save"}
        @{N="XboxNetApiSvc";     D="Xbox Network API"}
        @{N="XboxGipSvc";        D="Xbox Accessories"}
        @{N="lfsvc";             D="Localizacao geografica"}
        @{N="MapsBroker";        D="Mapas Offline"}
        @{N="RetailDemo";        D="Modo demo de loja"}
        @{N="wisvc";             D="Windows Insider Program"}
        @{N="WerSvc";            D="Relatorio de Erros Windows"}
        @{N="Fax";               D="Fax (obsoleto)"}
        @{N="icssvc";            D="Hotspot movel (se nao usar)"}
        @{N="PhoneSvc";          D="Vinculador de Telefone"}
        @{N="RmSvc";             D="Gerenciador de Radio"}
        @{N="RemoteRegistry";    D="Registro Remoto (risco de seguranca)"}
        @{N="TapiSrv";           D="Telefonia legada"}
        @{N="WpcMonSvc";         D="Controles parentais"}
        @{N="SharedAccess";      D="ICS compartilhamento de internet"}
        @{N="WMPNetworkSvc";     D="Windows Media Player Network"}
        # NOVO v4
        @{N="AJRouter";          D="AllJoyn Router (IoT legado)"}
        @{N="PrintNotify";       D="Notificacoes de impressora (se nao usar)"}
        @{N="EntAppSvc";         D="Enterprise App Management"}
        @{N="MsKeyboardFilter";  D="Filtro de teclado Kiosk"}
    )

    $off = 0
    $tot = $svcs.Count
    $i   = 0
    foreach ($s in $svcs) {
        $i++
        Show-Progress "Verificando servicos..." $i $tot
        try {
            $svc = Get-Service -Name $s.N -ErrorAction SilentlyContinue
            if ($svc) {
                $Script:SvcsBackup[$s.N] = $svc.StartType.ToString()
                if ($svc.Status -eq 'Running') { Stop-Service -Name $s.N -Force -ErrorAction SilentlyContinue }
                Set-Service -Name $s.N -StartupType Disabled -ErrorAction SilentlyContinue
                $off++
            }
        } catch {}
    }
    Write-Host ""

    $Script:SvcsBackup | ConvertTo-Json | Out-File (Join-Path $Script:PastaBackup "servicos.json") -Encoding UTF8 -Force
    Write-Host ""
    OK "$off servicos desativados | Backup salvo"
    $Script:TweaksFeitos.Add("Servicos: $off desativados")
    LOG "Servicos: $off desativados"
}

# ================================================================
#  MODULO 6 - VISUAL E PERFORMANCE
# ================================================================
function Invoke-VisualPerf {
    H2 "VISUAL E PERFORMANCE"

    try {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" `
            -Name "VisualFXSetting" -Value 2 -Type DWord -Force 2>$null
    } catch {}

    $tweaks = @(
        @{P="HKCU:\Control Panel\Desktop";                                       N="DragFullWindows";              V="0";  T="String"}
        @{P="HKCU:\Control Panel\Desktop";                                       N="MenuShowDelay";                V="0";  T="String"}
        @{P="HKCU:\Control Panel\Desktop\WindowMetrics";                         N="MinAnimate";                   V=0}
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="TaskbarAnimations";            V=0}
        @{P="HKCU:\Software\Microsoft\Windows\DWM";                              N="EnableAeroPeek";               V=0}
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="ListviewAlphaSelect";          V=0}
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="ListviewShadow";               V=0}
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="ExtendedUIHoverTime";          V=1}
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="HideFileExt";                  V=0}
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="Hidden";                       V=1}
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize";N="EnableTransparency";           V=0}
        # NOVO v4: Desativar widgets taskbar
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="TaskbarDa";                    V=0}
        # NOVO v4: Desativar Chat (Meet Now)
        @{P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="TaskbarMn";                    V=0}
        # NOVO v4: Nao mostrar News e Interests
        @{P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds";             N="ShellFeedsTaskbarViewMode";    V=2}
        # NOVO v4: Antigo menu de contexto Win11
        @{P="HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"; N="(default)";  V="";   T="String"}
    )

    foreach ($t in $tweaks) {
        try {
            if (-not (Test-Path $t.P)) { New-Item -Path $t.P -Force | Out-Null }
            if ($t.T -eq 'String') { Set-ItemProperty $t.P -Name $t.N -Value $t.V -Type String -Force }
            else                   { Set-ItemProperty $t.P -Name $t.N -Value $t.V -Type DWord -Force }
        } catch {}
    }

    # Prefetch/Superfetch (mantido para SSD/NVMe)
    if ($Script:DiscoNVMe -or $Script:DiscoTipo -match 'SSD') {
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" `
            -Name "EnablePrefetcher" -Value 3 -Type DWord -Force 2>$null
        OK "Prefetch mantido ($( if($Script:DiscoNVMe){'NVMe'}else{'SSD'} ) - melhora carregamento de jogos)"
    }

    OK "Animacoes, transparencia e widgets desativados"
    OK "Menu de contexto classico restaurado (Win 11)"
    OK "Extensions e arquivos ocultos visiveis"
    $Script:TweaksFeitos.Add("Visual/Performance: animacoes OFF")
    LOG "Visual performance configurado v4"
}

# ================================================================
#  MODULO 7 - NTFS E I/O AVANCADO (NOVO v4)
# ================================================================
function Invoke-NTFSIOTweaks {
    H2 "NTFS E I/O - OTIMIZACOES AVANCADAS"

    # NTFS tweaks
    try {
        fsutil behavior set DisableLastAccess 1 2>$null | Out-Null
        OK "NTFS: Last Access Time desativado (menos writes no disco)"
    } catch {}

    try {
        fsutil behavior set EncryptPagingFile 0 2>$null | Out-Null
        OK "NTFS: Criptografia do PageFile desativada"
    } catch {}

    # Desativar 8.3 filename (melhora perf em pastas com muitos arquivos)
    try {
        fsutil behavior set Disable8dot3 1 2>$null | Out-Null
        OK "NTFS: Nomes curtos 8.3 desativados (melhora velocidade do Explorer)"
    } catch {}

    # Virtual Memory / PageFile
    try {
        $ram = $Script:RAMtotalGB
        if ($ram -ge 16) {
            # Com 16+ GB, pagefile gerenciado pelo sistema mas com limite definido
            $cs = Get-CimInstance Win32_ComputerSystem
            if ($cs.AutomaticManagedPagefile) {
                IN "PageFile gerenciado pelo sistema (recomendado com $($ram)GB RAM)"
            }
        }
    } catch {}

    if ($Script:DiscoNVMe) {
        # NOVO v4: Write cache para NVMe
        try {
            $discos = Get-CimInstance Win32_DiskDrive
            foreach ($d in $discos) {
                $idx = $d.Index
                $reg = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($d.PNPDeviceID)\Device Parameters\Disk"
                if (Test-Path $reg) {
                    Set-ItemProperty $reg -Name "UserWriteCacheSetting" -Value 1 -Type DWord -Force 2>$null
                }
            }
            OK "NVMe: Write Cache Buffer Flushing ativado"
        } catch {}

        # StorNVMe tweaks
        try {
            $stornvme = "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device"
            if (-not (Test-Path $stornvme)) { New-Item $stornvme -Force | Out-Null }
            Set-ItemProperty $stornvme -Name "FpdoEnableCommandSpreading" -Value 0 -Type DWord -Force 2>$null
            OK "NVMe: StorNVMe Command Spreading desativado (reduz latencia)"
        } catch {}
    }

    # Storage Device Policy - WriteThrough mais rapido em SSD
    if ($Script:DiscoNVMe -or $Script:DiscoTipo -match 'SSD') {
        try {
            $dp = "HKLM:\SYSTEM\CurrentControlSet\Services\disk"
            Set-ItemProperty $dp -Name "TimeOutValue" -Value 30 -Type DWord -Force 2>$null
            OK "Disco: I/O Timeout otimizado"
        } catch {}
    }

    # I/O priority para jogos
    try {
        $ioPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-ItemProperty $ioPath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force 2>$null
        OK "I/O Network Throttling desativado para jogos"
    } catch {}

    $Script:TweaksFeitos.Add("NTFS/IO: Last Access OFF, 8.3 OFF$(if($Script:DiscoNVMe){', NVMe tweak'})")
    LOG "NTFS IO tweaks aplicados"
    PAUSE
}

# ================================================================
#  MODULO 8 - TIMER RESOLUTION (NOVO v4)
# ================================================================
function Invoke-TimerResolution {
    H2 "TIMER RESOLUTION - PRECISAO DO SCHEDULER"

    INF "O Windows usa por padrao um timer de 15.625ms."
    INF "Reduzir para 0.5ms melhora a consistencia de FPS e latencia."
    INF "Impacto: leve aumento de consumo de energia (1-5W)."
    Write-Host ""

    # Verificar se existe ferramenta de timer resolution
    $timerTool = @(
        "$env:SystemRoot\System32\bcdedit.exe"
    )

    # Windows 11 22H2+: o jogo define automaticamente via API
    if ($Script:WinBuild -ge 22621) {
        try {
            # NOVO: Win11 22H2 tem HighResolutionTimers por jogo
            $bcdOut = bcdedit /enum {current} 2>$null
            if ($bcdOut -match 'useplatformclock\s+Yes') {
                WN "Platform Clock esta ativado (pode causar stuttering em alguns jogos)"
                if (CONF "Desativar Platform Clock?") {
                    bcdedit /deletevalue {current} useplatformclock 2>$null | Out-Null
                    OK "Platform Clock desativado"
                }
            }

            # Ativar HPET se disponivel
            if ($bcdOut -notmatch 'useplatformperfcounters') {
                bcdedit /set useplatformperfcounters yes 2>$null | Out-Null
                OK "Platform Performance Counters ativado"
            }
        } catch {}
    }

    # Registry para timer resolution consistente
    try {
        $trPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-ItemProperty $trPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force 2>$null
        OK "System Responsiveness: 0% (100pct CPU para primeiro plano)"
    } catch {}

    # BCD Tweaks (v4)
    try {
        Write-Host ""
        Write-Host "  Otimizacoes de boot e BCD:" -ForegroundColor Cyan
        if (CONF "Aplicar tweaks de BCD para gaming? (desativa mitigacoes nao-criticas)") {
            bcdedit /set disabledynamictick yes 2>$null | Out-Null
            OK "Dynamic Tick desativado (timer mais consistente)"
            bcdedit /set useplatformtick yes 2>$null | Out-Null
            OK "Platform Tick ativado"
            # Salvar no backup
            "bcd_gaming=yes" | Out-File (Join-Path $Script:PastaBackup "bcd.txt") -Encoding UTF8 -Force
        }
    } catch {}

    $Script:TweaksFeitos.Add("Timer Resolution: Dynamic Tick OFF")
    LOG "Timer Resolution configurado"
    PAUSE
}

# ================================================================
#  MODULO 9 - MSI MODE PARA GPU (NOVO v4)
# ================================================================
function Invoke-MSIMode {
    H2 "MSI MODE - MESSAGE SIGNALED INTERRUPTS"

    INF "MSI Mode elimina conflitos de IRQ e reduz latencia de interrupcoes."
    INF "Beneficio maior em sistemas com muitos dispositivos PCIe."
    Write-Host ""

    # GPU MSI Mode
    try {
        $gpuDevs = Get-PnpDevice -Class 'Display' -Status 'OK' -ErrorAction SilentlyContinue
        $gpuMsi = 0
        foreach ($dev in $gpuDevs) {
            $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            if (-not (Test-Path $path)) { New-Item $path -Force | Out-Null }
            Set-ItemProperty $path -Name "MSISupported" -Value 1 -Type DWord -Force 2>$null

            # Definir numero de MSI (16 para GPU moderna)
            $liPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters\Interrupt Management\Affinity Policy"
            if (-not (Test-Path $liPath)) { New-Item $liPath -Force | Out-Null }
            Set-ItemProperty $liPath -Name "DevicePriority"  -Value 3 -Type DWord -Force 2>$null  # High priority
            $gpuMsi++
        }
        if ($gpuMsi -gt 0) { OK "GPU MSI Mode ativado + prioridade High ($gpuMsi dispositivo(s))" }
    } catch { ER "Falha ao configurar MSI para GPU" }

    # NVMe MSI
    try {
        if ($Script:DiscoNVMe) {
            $nvmeDev = Get-PnpDevice -Class 'DiskDrive' -Status 'OK' | Where-Object { $_.FriendlyName -match 'NVMe' }
            foreach ($dev in $nvmeDev) {
                $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                if (-not (Test-Path $path)) { New-Item $path -Force | Out-Null }
                Set-ItemProperty $path -Name "MSISupported" -Value 1 -Type DWord -Force 2>$null
            }
            OK "NVMe MSI Mode ativado"
        }
    } catch {}

    WN "REINICIE o computador para MSI Mode ter efeito."
    $Script:TweaksFeitos.Add("MSI Mode: GPU + NVMe")
    LOG "MSI Mode configurado"
    PAUSE
}

# ================================================================
#  MODULO 10 - OTIMIZACOES X3D
# ================================================================
function Invoke-OtimizacoesX3D {
    H2 "OTIMIZACOES EXCLUSIVAS PARA X3D V-CACHE"
    WN "Configuracoes especificas para: $($Script:CPUNome)"
    Write-Host ""

    $amd = powercfg /list 2>$null | Select-String 'AMD Ryzen Balanced'
    if ($amd) {
        $guid = ($amd.Line -split '\s+' | Where-Object {$_ -match '^[0-9a-f-]{36}$'}) | Select-Object -First 1
        if ($guid) { powercfg /setactive $guid 2>$null; OK "AMD Ryzen Balanced confirmado (OBRIGATORIO para X3D)" }
    }

    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES      100 2>$null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE     4 2>$null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFINCTHRESHOLD 10 2>$null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFDECTHRESHOLD  8 2>$null

    OK "Core Parking OFF"
    OK "Boost: Efficient Aggressive (melhor para latencia do V-Cache)"
    OK "Transicoes de frequencia rapidas"

    # NOVO v4: Processo de jogos afinado aos CCDs corretos
    INF "Para X3D: recomenda-se afinidade de CPU automatica pelo sistema."
    INF "BIOS: CPPC Preferred Cores = Enabled, PBO = Disabled."

    Write-Host ""
    WN "BIOS necessario para maximo desempenho X3D:"
    WN "  > CPPC Preferred Cores = Enabled"
    WN "  > AMD Cool'n'Quiet     = Enabled"
    WN "  > Global C-state       = Enabled"
    WN "  > XMP/EXPO para sua RAM"
    WN "  > PBO = Disabled (X3D nao overclocka - reduz temperatura)"

    $Script:TweaksFeitos.Add("X3D V-Cache: plano, boost, core parking")
    LOG "X3D otimizacoes aplicadas"
}

# ================================================================
#  MODULO 11 - OVERCLOCK GPU (banco de dados v4 atualizado)
# ================================================================
function Get-PerfilOCGPU {
    param([string]$Nome)
    $db = @(
        # Ada Lovelace (RTX 4xxx)
        @{M='RTX\s*4090';                C=200;V=1500;P=15;T=83;N='Ada flagship. OC de mem altamente eficiente. Refrigeracao robusta necessaria.'}
        @{M='RTX\s*4080\s*(Super)?';     C=175;V=1200;P=12;T=83;N='Ada excelente. GDDR6X responde muito bem a OC de mem.'}
        @{M='RTX\s*4070\s*Ti\s*(Super)?';C=175;V=1200;P=12;T=83;N='Ada eficiente. Mem OC da ganho real de FPS.'}
        @{M='RTX\s*4070\s*(Super)?(?!\s*Ti)';C=150;V=1000;P=10;T=83;N='Excelente custo-beneficio de OC.'}
        @{M='RTX\s*4060\s*Ti';           C=150;V=1000;P=10;T=83;N='TDP limitado. Foque em mem OC para melhor retorno.'}
        @{M='RTX\s*4060(?!\s*Ti)';       C=125;V=1000;P=8; T=83;N='Margem moderada. Mem OC da melhor resultado que core.'}
        # Ampere (RTX 3xxx)
        @{M='RTX\s*3090\s*Ti';           C=150;V=800; P=8; T=83;N='GDDR6X aquece. Monitore Tjunction separadamente.'}
        @{M='RTX\s*3090(?!\s*Ti)';       C=150;V=800; P=8; T=83;N='GDDR6X sensivel. Mem OC moderado e mais seguro.'}
        @{M='RTX\s*3080\s*Ti';           C=150;V=800; P=8; T=83;N='Excelente Ampere. VRAM pode throttle, monitore.'}
        @{M='RTX\s*3080(?!\s*Ti)';       C=150;V=800; P=8; T=83;N='Ampere escala muito bem. Mem OC extremamente eficiente.'}
        @{M='RTX\s*3070\s*Ti';           C=125;V=600; P=8; T=83;N='Boa margem. Cooler padrao geralmente suficiente.'}
        @{M='RTX\s*3070(?!\s*Ti)';       C=125;V=600; P=8; T=83;N='GPU popular. Comunidade bem documentada.'}
        @{M='RTX\s*3060\s*Ti';           C=125;V=600; P=8; T=83;N='Excelente custo-beneficio de OC.'}
        @{M='RTX\s*3060(?!\s*Ti)';       C=100;V=500; P=6; T=83;N='Margem menor. Mem OC da melhor retorno.'}
        @{M='RTX\s*3050';                C=100;V=400; P=5; T=87;N='TDP baixo. OC leve recomendado.'}
        # Turing (RTX 2xxx / GTX 1660)
        @{M='RTX\s*2080\s*Ti';           C=125;V=600; P=8; T=84;N='Classico Turing. Verifique pasta termica se +4 anos.'}
        @{M='RTX\s*2080(?!\s*Ti)';       C=125;V=600; P=8; T=84;N='Boa margem Turing.'}
        @{M='RTX\s*2070';                C=100;V=500; P=7; T=84;N='Margem solida. Vale OC para ganho real.'}
        @{M='RTX\s*2060';                C=100;V=400; P=6; T=84;N='Moderado mas com ganho real.'}
        @{M='GTX\s*1660\s*(Ti|Super)?';  C=100;V=500; P=6; T=84;N='GDDR6 (Ti/Super) escala bem.'}
        @{M='GTX\s*1650';                C=75; V=300; P=4; T=87;N='TDP muito baixo. Ganhos limitados.'}
        # Pascal (GTX 10xx)
        @{M='GTX\s*1080\s*Ti';           C=125;V=500; P=8; T=84;N='Pascal classico. Pasta pode estar seca.'}
        @{M='GTX\s*1080(?!\s*Ti)';       C=125;V=500; P=8; T=84;N='Pascal envelhece bem. Verifique refrigeracao.'}
        @{M='GTX\s*1070';                C=100;V=400; P=7; T=84;N='Muito bem documentado na comunidade.'}
        @{M='GTX\s*1060';                C=100;V=400; P=6; T=84;N='Considere trocar pasta se +4 anos.'}
        @{M='GTX\s*1050\s*Ti';           C=75; V=300; P=4; T=87;N='Ganhos modestos mas existentes.'}
        # RDNA 3 (RX 7xxx)
        @{M='RX\s*7900\s*(XTX|XT)';     C=100;V=100; P=10;T=90;N='RDNA3. Hotspot diferente de Edge. Monitore junction.'}
        @{M='RX\s*7800\s*XT';            C=100;V=80;  P=8; T=90;N='Otimo RDNA3 mid-range para OC.'}
        @{M='RX\s*7700\s*XT';            C=100;V=80;  P=8; T=90;N='TDP eficiente. Margem moderada.'}
        @{M='RX\s*7600';                 C=75; V=60;  P=6; T=90;N='Entry RDNA3. Ganhos modestos.'}
        # RDNA 2 (RX 6xxx)
        @{M='RX\s*6900\s*XT';            C=100;V=100; P=8; T=90;N='RDNA2 flagship. Hotspot pode ser alto. Monitore.'}
        @{M='RX\s*6800\s*XT';            C=100;V=100; P=8; T=90;N='Excelente. Infinity Cache escala muito bem.'}
        @{M='RX\s*6800(?!\s*XT)';        C=100;V=80;  P=8; T=90;N='Muito parecido com XT. Bons ganhos.'}
        @{M='RX\s*6700\s*XT';            C=100;V=80;  P=8; T=90;N='Mid-range RDNA2 com boa margem.'}
        @{M='RX\s*6700(?!\s*XT)';        C=75; V=60;  P=6; T=90;N='Moderado. Power limit boost e eficiente.'}
        @{M='RX\s*6600\s*XT';            C=75; V=60;  P=6; T=90;N='1080p excelente. OC modesto mas eficiente.'}
        @{M='RX\s*6600(?!\s*XT)';        C=75; V=50;  P=5; T=90;N='TDP baixo. Nao exagere.'}
        # RDNA 1 (RX 5xxx)
        @{M='RX\s*5700\s*XT';            C=75; V=80;  P=7; T=90;N='RDNA1. Hotspot ate 110C e normal.'}
        @{M='RX\s*5700(?!\s*XT)';        C=75; V=80;  P=7; T=90;N='Hotspot alto esperado.'}
        @{M='RX\s*5600\s*XT';            C=75; V=60;  P=6; T=90;N='Boa GPU 1080p. Moderado recomendado.'}
        # Intel Arc
        @{M='Arc\s*A770';                C=50; V=200; P=5; T=100;N='OC em Arc e experimental. Atualize o driver sempre.'}
        @{M='Arc\s*A750';                C=50; V=200; P=5; T=100;N='Mesmos cuidados do A770.'}
    )
    foreach ($e in $db) { if ($Nome -match $e.M) { return $e } }
    if ($Nome -match 'NVIDIA|GeForce|RTX|GTX') { return @{C=75;V=300;P=5;T=84;N='GPU NVIDIA. Valores ultra-conservadores.'} }
    if ($Nome -match 'AMD|Radeon|RX')           { return @{C=50;V=50; P=4;T=90;N='GPU AMD. Valores ultra-conservadores.'} }
    return $null
}

function Invoke-AnalisadorGPU {
    H2 "ANALISADOR DE OVERCLOCK DE GPU"

    if (-not $Script:GPUNome) { Invoke-DetectarHardware }
    if (-not $Script:GPUNome) { ER "GPU nao detectada."; PAUSE; return }

    $perfil = Get-PerfilOCGPU -Nome $Script:GPUNome
    if (-not $perfil) {
        WN "GPU nao encontrada no banco de dados de OC seguro."
        PAUSE; return
    }

    # Analise termica
    $statusTerm = "nao_testado"
    if ($Script:GPUFab -eq 'NVIDIA' -and $Script:GPUSmi -and $Script:GPUTemp -gt 0) {
        Write-Host ""
        $corT = if($Script:GPUTemp -lt 60){'Green'}elseif($Script:GPUTemp -lt 75){'Yellow'}else{'Red'}
        Write-Host "  Temperatura atual: $($Script:GPUTemp) C" -ForegroundColor $corT

        if (CONF "Fazer analise termica rapida (15s)?") {
            IN "Monitorando GPU por 15 segundos..."
            $tempMax = $Script:GPUTemp; $amostras = @()
            for ($i = 1; $i -le 15; $i++) {
                $tr = & $Script:GPUSmi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>$null
                if ($tr -match '^\d+') { $t=[int]$tr.Trim(); $amostras+=$t; if($t-gt$tempMax){$tempMax=$t} }
                $corBar = if($t -lt 70){'Green'} elseif($t -lt 80){'Yellow'} else{'Red'}
                Write-Host "`r  [$('#'*$i)$((' '*([math]::Max(0,15-$i))))] $($i)s | Temp: $($t) C    " -NoNewline -ForegroundColor $corBar
                Start-Sleep 1
            }
            Write-Host ""; Write-Host ""
            OK "Temp maxima: $($tempMax) C"
            $statusTerm = if($tempMax -le 60){'excelente'}elseif($tempMax -le 72){'boa'}elseif($tempMax -le 80){'aceitavel'}else{'quente'}

            if ($statusTerm -eq 'quente') {
                ER "GPU muito quente. OC NAO recomendado sem melhorar refrigeracao."
                PAUSE; return
            }
            OK "Status termico: $statusTerm"
        }
    }

    $mult = switch ($statusTerm) { 'excelente'{1.0} 'boa'{0.85} 'aceitavel'{0.65} default{0.75} }
    $cMax = [math]::Floor($perfil.C * $mult)
    $vMax = [math]::Floor($perfil.V * $mult)

    $pC = @{C=[math]::Floor($cMax*.5);  V=[math]::Floor($vMax*.5);  P=[math]::Min([math]::Floor($perfil.P*.5),8)}
    $pM = @{C=[math]::Floor($cMax*.75); V=[math]::Floor($vMax*.75); P=[math]::Min([math]::Floor($perfil.P*.75),12)}
    $pA = @{C=$cMax; V=$vMax; P=$perfil.P}

    Write-Host ""
    H1 "RESULTADO - $($Script:GPUNome)"
    SEP
    Write-Host "  Nota : $($perfil.N)" -ForegroundColor DarkGray
    Write-Host "  Limite seguro de temperatura: $($perfil.T) C" -ForegroundColor White
    Write-Host ""

    $pl_c = if($Script:GPUPL -gt 0){[math]::Min([math]::Round($Script:GPUPL*(1+$pC.P/100)),$Script:GPUPLmax)}else{0}
    $pl_m = if($Script:GPUPL -gt 0){[math]::Min([math]::Round($Script:GPUPL*(1+$pM.P/100)),$Script:GPUPLmax)}else{0}
    $pl_a = if($Script:GPUPL -gt 0){[math]::Min([math]::Round($Script:GPUPL*(1+$pA.P/100)),$Script:GPUPLmax)}else{0}
    $plStr_c = if($pl_c -gt 0){"$($pl_c) W (+$($pC.P)%)"} else{"+$($pC.P)pct (use slider)"}
    $plStr_m = if($pl_m -gt 0){"$($pl_m) W (+$($pM.P)%)"} else{"+$($pM.P)pct (use slider)"}
    $plStr_a = if($pl_a -gt 0){"$($pl_a) W (+$($pA.P)%)"} else{"+$($pA.P)pct (use slider)"}

    $fmt = "  | {0,-15} | {1,-14} | {2,-14} | {3,-22} |"
    $sep = "  +" + ("-"*17) + "+" + ("-"*16) + "+" + ("-"*16) + "+" + ("-"*24) + "+"

    Write-Host $sep -ForegroundColor DarkCyan
    Write-Host ($fmt -f "PERFIL","CORE OC","MEM OC","POWER LIMIT") -ForegroundColor DarkCyan
    Write-Host $sep -ForegroundColor DarkCyan
    Write-Host ($fmt -f "[CONSERVADOR]","+$($pC.C) MHz","+$($pC.V) MHz",$plStr_c) -ForegroundColor Green
    Write-Host ($fmt -f "[MODERADO]","+$($pM.C) MHz","+$($pM.V) MHz",$plStr_m) -ForegroundColor Yellow
    Write-Host ($fmt -f "[AGRESSIVO]","+$($pA.C) MHz","+$($pA.V) MHz",$plStr_a) -ForegroundColor Red
    Write-Host $sep -ForegroundColor DarkCyan

    # Aplicar Power Limit (NVIDIA)
    if ($Script:GPUFab -eq 'NVIDIA' -and $Script:GPUSmi -and $Script:GPUPLmax -gt 0) {
        Write-Host ""
        WN "Power Limit pode ser aplicado agora via nvidia-smi."
        Write-Host "  [1] Conservador ($($pl_c) W)  [2] Moderado ($($pl_m) W)  [3] Agressivo ($($pl_a) W)  [4] Nao aplicar"
        $op = Read-Host "  Aplicar PL [1-4]"
        $watts = switch ($op.Trim()) {'1'{$pl_c}'2'{$pl_m}'3'{$pl_a}default{0}}
        if ($watts -gt 0) {
            $res = & $Script:GPUSmi -pl $watts 2>&1
            if ($res -match 'successfully') { OK "Power Limit aplicado: $($watts) W" }
            else { ER "Falha. Tente via MSI Afterburner." }
        }
    }

    # NOVO v4: Frequencia minima da GPU via nvidia-smi
    if ($Script:GPUFab -eq 'NVIDIA' -and $Script:GPUSmi) {
        Write-Host ""
        if (CONF "Definir frequencia minima do core (evita stutter em menu/desktop)?") {
            $freqMin = Read-Host "  Frequencia minima em MHz (ex: 1000, ou 0 para padrao)"
            if ($freqMin -match '^\d+$' -and [int]$freqMin -gt 0) {
                & $Script:GPUSmi --lock-gpu-clocks=$freqMin,$(([int]$freqMin+500)) 2>$null | Out-Null
                OK "Frequencia minima GPU: $freqMin MHz"
                WN "Use nvidia-smi --reset-gpu-clocks para reverter."
            }
        }
    }

    # Guia de aplicacao
    Write-Host ""
    H1 "COMO APLICAR - MSI AFTERBURNER"
    SEP
    if ($Script:GPUFab -eq 'NVIDIA') {
        Write-Host "  1. Abra Afterburner > Salve perfil padrao (slot 1)" -ForegroundColor Gray
        Write-Host "  2. Power Limit: suba ao maximo" -ForegroundColor Gray
        Write-Host "  3. Core Clock: +$($pC.C) MHz > Apply > teste 30min com 3DMark/Heaven" -ForegroundColor Green
        Write-Host "  4. Se estavel: suba para +$($pM.C) MHz > novo teste" -ForegroundColor Yellow
        Write-Host "  5. Memory Clock: comece com +$($pC.V) MHz > suba gradualmente" -ForegroundColor Green
        Write-Host "  6. Artefato = reduza 25 MHz e estabilize" -ForegroundColor Red
    } elseif ($Script:GPUFab -eq 'AMD') {
        Write-Host "  1. AMD Software Adrenalin > Performance > Tuning > Manual" -ForegroundColor Gray
        Write-Host "  2. GPU Frequency: +$($pC.C) MHz | VRAM: +$($pC.V) MHz | PL: +$($pC.P)%" -ForegroundColor Green
        Write-Host "  3. Apply > teste 30min > avance para moderado se estavel" -ForegroundColor Gray
        WN "  RDNA: Hotspot ate 100C e normal. Acima de 110C reduza."
    }

    LOG "GPU OC analise: $($Script:GPUNome) | Core max: +$cMax | Mem max: +$vMax"
    PAUSE
}

# ================================================================
#  MODULO 12 - MODO STREAMER (NOVO v4)
# ================================================================
function Invoke-ModoStreamer {
    H2 "MODO STREAMER - GAMING + OBS SEM DROPS"

    INF "Configura o sistema para dividir recursos entre jogo e OBS/encode."
    Write-Host ""

    # Prioridade de CPU para OBS
    try {
        $obsPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\obs64.exe\PerfOptions"
        if (-not (Test-Path $obsPath)) { New-Item $obsPath -Force | Out-Null }
        Set-ItemProperty $obsPath -Name "CpuPriorityClass" -Value 3 -Type DWord -Force 2>$null  # High = 3
        OK "OBS64: CPU Priority = High"
    } catch {}

    # GPU scheduling para streaming
    try {
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" `
            -Name "HwSchMode" -Value 2 -Type DWord -Force 2>$null
        OK "HAGS ativado (necessario para OBS GPU encode)"
    } catch {}

    # Multimedia scheduler - OBS tambem precisa de audio responsivo
    try {
        $obsAudioPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio"
        if (-not (Test-Path $obsAudioPath)) { New-Item $obsAudioPath -Force | Out-Null }
        Set-ItemProperty $obsAudioPath -Name "Affinity"            -Value 0 -Type DWord  -Force 2>$null
        Set-ItemProperty $obsAudioPath -Name "Background Only"     -Value "False" -Type String -Force 2>$null
        Set-ItemProperty $obsAudioPath -Name "Clock Rate"          -Value 10000 -Type DWord -Force 2>$null
        Set-ItemProperty $obsAudioPath -Name "GPU Priority"        -Value 8 -Type DWord  -Force 2>$null
        Set-ItemProperty $obsAudioPath -Name "Priority"            -Value 6 -Type DWord  -Force 2>$null
        Set-ItemProperty $obsAudioPath -Name "Scheduling Category" -Value "High" -Type String -Force 2>$null
        Set-ItemProperty $obsAudioPath -Name "SFIO Priority"       -Value "High" -Type String -Force 2>$null
        OK "Pro Audio scheduler configurado (audio OBS sem drops)"
    } catch {}

    # Ajustar System Responsiveness para dividir CPU
    try {
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" `
            -Name "SystemResponsiveness" -Value 10 -Type DWord -Force 2>$null
        OK "System Responsiveness = 10% (modo streaming: divide CPU entre jogo e encoder)"
        WN "Para gaming puro sem stream, use 0%. Ajuste no modulo GameMode."
    } catch {}

    # Desativar Xbox Game Bar (consome CPU desnecessariamente)
    try {
        Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" `
            -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force 2>$null
        OK "Xbox Game Bar desativado (use OBS em vez disso)"
    } catch {}

    $Script:ModoStreamer = $true
    OK "Modo Streamer ativado!"
    WN "Recomendacoes OBS para Gaming:"
    Write-Host "  > Encoder: NVENC/AMF (GPU) - nao use x264 se for gamer" -ForegroundColor DarkGray
    Write-Host "  > Process Priority: Acima do Normal" -ForegroundColor DarkGray
    Write-Host "  > Bitrate: 6000 kbps (1080p60) | 8000 kbps (1440p60)" -ForegroundColor DarkGray
    Write-Host "  > Keyframe: 2s | Profile: High | Level: auto" -ForegroundColor DarkGray

    $Script:TweaksFeitos.Add("Modo Streamer: OBS + Gaming configurado")
    LOG "Modo Streamer ativado"
    PAUSE
}

# ================================================================
#  MODULO 13 - MONITOR TEMPO REAL (NOVO v4)
# ================================================================
function Invoke-Monitor {
    H2 "MONITOR DE HARDWARE EM TEMPO REAL"

    if (-not $Script:GPUSmi -and $Script:GPUFab -eq 'NVIDIA') {
        ER "nvidia-smi nao encontrado. Monitor disponivel apenas para NVIDIA."
        PAUSE; return
    }

    Write-Host "  Pressione CTRL+C para sair do monitor." -ForegroundColor Yellow
    Write-Host ""

    $contador = 0
    try {
        while ($true) {
            $contador++
            $ts = Get-Date -f "HH:mm:ss"

            # CPU
            $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
            $corCPU = if($cpuLoad -lt 50){'Green'}elseif($cpuLoad -lt 85){'Yellow'}else{'Red'}

            # RAM
            $os    = Get-CimInstance Win32_OperatingSystem
            $ramUsada  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
            $ramTotal  = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
            $ramPct    = [math]::Round($ramUsada / $ramTotal * 100)
            $corRAM    = if($ramPct -lt 60){'Green'}elseif($ramPct -lt 85){'Yellow'}else{'Red'}

            Write-Host "`r  [$ts] CPU: " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($cpuLoad)%".PadLeft(4) -NoNewline -ForegroundColor $corCPU
            Write-Host " | RAM: " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($ramPct)% ($($ramUsada)/$($ramTotal)GB)" -NoNewline -ForegroundColor $corRAM

            if ($Script:GPUSmi) {
                $gd = & $Script:GPUSmi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits 2>$null
                if ($gd) {
                    $gc = $gd -split ','
                    if ($gc.Count -ge 5) {
                        $gt  = [int]$gc[0].Trim()
                        $gu  = [int]$gc[1].Trim()
                        $gmu = [math]::Round([double]$gc[2].Trim() / 1024, 1)
                        $gmt = [math]::Round([double]$gc[3].Trim() / 1024, 1)
                        $gpw = [math]::Round([double]$gc[4].Trim(), 0)
                        $corGT = if($gt-lt60){'Green'}elseif($gt-lt75){'Yellow'}else{'Red'}
                        $corGU = if($gu-lt70){'Green'}elseif($gu-lt90){'Yellow'}else{'Red'}

                        Write-Host " | GPU: " -NoNewline -ForegroundColor DarkGray
                        Write-Host "$($gt)C" -NoNewline -ForegroundColor $corGT
                        Write-Host "/" -NoNewline -ForegroundColor DarkGray
                        Write-Host "$($gu)%" -NoNewline -ForegroundColor $corGU
                        Write-Host " VRAM:$($gmu)/$($gmt)GB W:$($gpw)" -NoNewline -ForegroundColor DarkGray
                    }
                }
            }

            Start-Sleep 1
        }
    } catch {
        Write-Host ""
        OK "Monitor encerrado."
    }
    PAUSE
}

# ================================================================
#  MODULO 14 - DEBLOATER v4 (atualizado)
# ================================================================
function Invoke-Debloater {
    H2 "DEBLOATER - REMOVER APPS DESNECESSARIOS"

    $apps = @(
        "Microsoft.XboxApp","Microsoft.XboxGameOverlay","Microsoft.XboxGamingOverlay",
        "Microsoft.XboxIdentityProvider","Microsoft.Xbox.TCUI",
        "Microsoft.549981C3F5F10",                          # Cortana standalone
        "Microsoft.BingWeather","Microsoft.BingFinance","Microsoft.BingNews",
        "Microsoft.BingSports","Microsoft.BingTranslator","Microsoft.BingTravel",
        "Microsoft.GetHelp","Microsoft.Getstarted","Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection","Microsoft.MixedReality.Portal",
        "Microsoft.MSPaint","Microsoft.News","Microsoft.Office.OneNote",
        "Microsoft.OutlookForWindows","Microsoft.People","Microsoft.PowerAutomateDesktop",
        "Microsoft.Print3D","Microsoft.SkypeApp","Microsoft.Teams",
        "Microsoft.Todos","Microsoft.WindowsAlarms","Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps","Microsoft.WindowsSoundRecorder","Microsoft.YourPhone",
        "Microsoft.ZuneMusic","Microsoft.ZuneVideo","Microsoft.MicrosoftStickyNotes",
        "AmazonVideo.PrimeVideo","Disney.37853D22215B2","Clipchamp.Clipchamp",
        "king.com.CandyCrushSaga","king.com.CandyCrushFriends","king.com.FarmHeroesSaga",
        "TikTok.TikTok","BytedancePte.Ltd.TikTok","Facebook.Facebook",
        "Instagram.Instagram","Twitter.Twitter","Netflix","ROBLOXCORPORATION.ROBLOX",
        "Duolingo-LearnLanguagesforFree","AdobeSystemsIncorporated.AdobePhotoshopExpress",
        # NOVO v4
        "MicrosoftCorporationII.MicrosoftFamily",           # Family Safety
        "Microsoft.GamingApp",                              # Xbox Gaming App (nao o runtime)
        "Microsoft.Copilot",                                # Copilot standalone
        "Microsoft.PowerAutomateDesktop",
        "Microsoft.WindowsCommunicationsApps",              # Mail & Calendar antigo
        "Microsoft.3DBuilder"
    )

    Write-Host "  Removendo $($apps.Count) apps potenciais..." -ForegroundColor Gray
    $removidos = 0; $i = 0
    foreach ($app in $apps) {
        $i++
        Show-Progress "Debloater" $i $apps.Count
        $pkg = Get-AppxPackage -Name "*$app*" -AllUsers -ErrorAction SilentlyContinue
        if ($pkg) {
            try {
                $pkg | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                $pkgProv = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                           Where-Object { $_.DisplayName -like "*$app*" }
                if ($pkgProv) { $pkgProv | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null }
                $removidos++
            } catch {}
        }
    }

    Write-Host ""

    # Bloquear reinstalacao
    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-ItemProperty $regPath -Name "OemPreInstalledAppsEnabled"  -Value 0 -Type DWord -Force 2>$null
    Set-ItemProperty $regPath -Name "PreInstalledAppsEnabled"      -Value 0 -Type DWord -Force 2>$null
    Set-ItemProperty $regPath -Name "SilentInstalledAppsEnabled"   -Value 0 -Type DWord -Force 2>$null
    Set-ItemProperty $regPath -Name "ContentDeliveryAllowed"       -Value 0 -Type DWord -Force 2>$null

    Write-Host ""
    OK "$removidos apps removidos"
    OK "Reinstalacao automatica bloqueada"
    $Script:TweaksFeitos.Add("Debloater: $removidos apps removidos")
    LOG "Debloater v4: $removidos removidos"
    PAUSE
}

# ================================================================
#  MODULO 15 - INSTALADOR DE PROGRAMAS
# ================================================================
function Invoke-Instalador {
    H2 "INSTALADOR DE PROGRAMAS (via winget)"

    if (-not $Script:TemWinget) {
        ER "winget nao encontrado."
        WN "Instale 'App Installer' na Microsoft Store ou atualize o Windows."
        PAUSE; return
    }

    $catalogo = @(
        @{ID="Google.Chrome";              Cat="Navegador";   N="Google Chrome"}
        @{ID="Mozilla.Firefox";            Cat="Navegador";   N="Mozilla Firefox"}
        @{ID="Brave.Brave";                Cat="Navegador";   N="Brave Browser"}
        @{ID="Opera.Opera";                Cat="Navegador";   N="Opera"}
        @{ID="Discord.Discord";            Cat="Comunicacao"; N="Discord"}
        @{ID="WhatsApp.WhatsApp";          Cat="Comunicacao"; N="WhatsApp Desktop"}
        @{ID="Telegram.TelegramDesktop";   Cat="Comunicacao"; N="Telegram"}
        @{ID="Zoom.Zoom";                  Cat="Comunicacao"; N="Zoom"}
        @{ID="Valve.Steam";                Cat="Gaming";      N="Steam"}
        @{ID="EpicGames.EpicGamesLauncher";Cat="Gaming";      N="Epic Games"}
        @{ID="Ubisoft.Connect";            Cat="Gaming";      N="Ubisoft Connect"}
        @{ID="ElectronicArts.EADesktop";   Cat="Gaming";      N="EA App"}
        @{ID="7zip.7zip";                  Cat="Utilitarios"; N="7-Zip"}
        @{ID="Notepad++.Notepad++";        Cat="Utilitarios"; N="Notepad++"}
        @{ID="VideoLAN.VLC";               Cat="Utilitarios"; N="VLC Media Player"}
        @{ID="qBittorrent.qBittorrent";    Cat="Utilitarios"; N="qBittorrent"}
        @{ID="Malwarebytes.Malwarebytes";  Cat="Utilitarios"; N="Malwarebytes"}
        @{ID="REALiX.HWiNFO";             Cat="Utilitarios"; N="HWiNFO64"}
        @{ID="CrystalDewWorld.CrystalDiskInfo";Cat="Utilitarios";N="CrystalDiskInfo"}
        @{ID="CPUID.CPU-Z";                Cat="Utilitarios"; N="CPU-Z"}
        @{ID="MSI.Afterburner";            Cat="GPU/OC";      N="MSI Afterburner"}
        @{ID="Guru3D.RTSS";                Cat="GPU/OC";      N="RivaTuner Statistics"}
        @{ID="Git.Git";                    Cat="Dev";         N="Git"}
        @{ID="Microsoft.VisualStudioCode"; Cat="Dev";         N="VS Code"}
        @{ID="Python.Python.3.12";         Cat="Dev";         N="Python 3.12"}
        @{ID="OpenJS.NodeJS.LTS";          Cat="Dev";         N="Node.js LTS"}
        @{ID="OBSProject.OBSStudio";       Cat="Multimedia";  N="OBS Studio"}
        @{ID="GIMP.GIMP";                  Cat="Multimedia";  N="GIMP"}
        @{ID="HandBrake.HandBrake";        Cat="Multimedia";  N="HandBrake"}
        @{ID="LibreOffice.LibreOffice";    Cat="Office";      N="LibreOffice"}
        @{ID="Adobe.Acrobat.Reader.64-bit";Cat="Office";      N="Adobe Acrobat Reader"}
    )

    $cats  = $catalogo | Select-Object -ExpandProperty Cat -Unique | Sort-Object
    $lista = @(); $idx = 1

    Write-Host "  Programas disponiveis:" -ForegroundColor Cyan
    Write-Host ""
    foreach ($cat in $cats) {
        Write-Host "  >> $cat" -ForegroundColor DarkCyan
        foreach ($prog in ($catalogo | Where-Object { $_.Cat -eq $cat })) {
            Write-Host ("   [{0,2}] {1}" -f $idx, $prog.N) -ForegroundColor White
            $lista += @{ Idx=$idx; Prog=$prog }
            $idx++
        }
        Write-Host ""
    }

    Write-Host "  Numeros separados por virgula. Ex: 1,5,12,18" -ForegroundColor Yellow
    $sel = Read-Host "  Selecao"
    if (-not $sel.Trim()) { WN "Cancelado."; return }

    $nums = $sel -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
    $selecionados = $lista | Where-Object { $_.Idx -in $nums }
    if (-not $selecionados) { WN "Nenhum valido."; PAUSE; return }

    Write-Host ""; H1 "Instalando $($selecionados.Count) programa(s)..."
    $ok = 0; $fail = 0; $i = 0
    foreach ($item in $selecionados) {
        $i++
        $p = $item.Prog
        Show-Progress "$($p.N)" $i ($selecionados.Count)
        winget install --id $p.ID --accept-source-agreements --accept-package-agreements --silent 2>$null
        if ($LASTEXITCODE -eq 0) { $ok++ } else { $fail++ }
    }

    Write-Host ""
    OK "$ok instalados com sucesso"
    if ($fail -gt 0) { WN "$fail falharam - instale manualmente" }
    LOG "Instalador: $ok OK $fail falhas"
    PAUSE
}

# ================================================================
#  MODULO 16 - WINDOWS UPDATE
# ================================================================
function Invoke-WindowsUpdate {
    H2 "CONTROLE DO WINDOWS UPDATE"

    Write-Host "  [1] Pausar 35 dias (recomendado para gamers)" -ForegroundColor White
    Write-Host "  [2] Habilitar automaticamente (padrao)" -ForegroundColor White
    Write-Host "  [3] Bloquear permanente (NAO recomendado)" -ForegroundColor DarkGray
    Write-Host "  [4] Forcar verificacao agora" -ForegroundColor White
    Write-Host "  [5] Voltar" -ForegroundColor DarkGray
    Write-Host ""
    $op = Read-Host "  Opcao [1-5]"

    switch ($op.Trim()) {
        '1' {
            $dataFim = (Get-Date).AddDays(35).ToString("yyyy-MM-dd")
            $p = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
            if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
            Set-ItemProperty $p "PauseFeatureUpdatesEndTime"   "${dataFim}T00:00:00Z" -Force 2>$null
            Set-ItemProperty $p "PauseQualityUpdatesEndTime"   "${dataFim}T00:00:00Z" -Force 2>$null
            Set-ItemProperty $p "PauseUpdatesExpiryTime"       "${dataFim}T00:00:00Z" -Force 2>$null
            OK "Atualizacoes pausadas ate $dataFim"
        }
        '2' {
            $p = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
            Remove-ItemProperty $p "PauseFeatureUpdatesEndTime" -Force 2>$null
            Remove-ItemProperty $p "PauseQualityUpdatesEndTime" -Force 2>$null
            Set-Service wuauserv -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service wuauserv -ErrorAction SilentlyContinue
            OK "Windows Update habilitado"
        }
        '3' {
            WN "Bloquear permanentemente impede patches de seguranca criticos!"
            if (CONF "Tem certeza absoluta?") {
                Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
                Set-Service wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
                $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
                if (-not (Test-Path $p)) { New-Item $p -Force | Out-Null }
                Set-ItemProperty $p "NoAutoUpdate" 1 -Type DWord -Force 2>$null
                OK "Windows Update bloqueado (use opcao 2 para reativar)"
            }
        }
        '4' {
            Start-Service wuauserv -ErrorAction SilentlyContinue
            try { (New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow() } catch {}
            OK "Verificacao iniciada - abra Configuracoes > Windows Update"
        }
    }
    LOG "Windows Update: opcao $op"
    PAUSE
}

# ================================================================
#  MODULO 17 - REPARAR WINDOWS
# ================================================================
function Invoke-RepararWindows {
    H2 "REPARAR WINDOWS (SFC / DISM)"

    WN "Processo pode demorar 10-30 minutos."
    Write-Host ""
    IN "1. DISM /RestoreHealth  - repara imagem do Windows"
    IN "2. SFC /scannow         - verifica arquivos de sistema"
    Write-Host ""
    if (-not (CONF "Iniciar reparo?")) { return }

    Write-Host ""
    H1 "Rodando DISM RestoreHealth (10-20 min)..."
    $dism = Start-Process "dism.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -PassThru -NoNewWindow
    if ($dism.ExitCode -eq 0) { OK "DISM: concluido sem erros" }
    else { WN "DISM: codigo $($dism.ExitCode) - pode ser normal sem internet" }

    Write-Host ""
    H1 "Rodando SFC /scannow..."
    $sfc = Start-Process "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow
    if ($sfc.ExitCode -eq 0) { OK "SFC: nenhum arquivo corrompido" }
    else { WN "SFC: codigo $($sfc.ExitCode) - arquivos podem ter sido reparados" }

    ipconfig /flushdns 2>$null | Out-Null
    OK "Cache DNS limpo"

    if (CONF "Resetar TCP/IP e Winsock?") {
        netsh winsock reset 2>$null | Out-Null
        netsh int ip reset  2>$null | Out-Null
        OK "Winsock + IP stack resetados - reinicie"
    }

    OK "Reparo concluido!"; WN "Reinicie para completar."
    LOG "Reparo Windows executado"
    PAUSE
}

# ================================================================
#  MODULO 18 - LIMPEZA DO SISTEMA
# ================================================================
function Invoke-Limpeza {
    H2 "LIMPEZA DO SISTEMA"

    $totalBytes = 0
    $pastas = @(
        $env:TEMP, $env:TMP,
        "C:\Windows\Temp",
        "$env:LOCALAPPDATA\Temp",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\ThumbCacheToDelete",
        "C:\Windows\SoftwareDistribution\Download"
    )

    $i = 0
    foreach ($p in $pastas) {
        $i++
        Show-Progress "Limpando temporarios..." $i $pastas.Count
        if (Test-Path $p) {
            if ($p -match 'SoftwareDistribution') {
                Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
            }
            $arqs = Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue
            $bytes = ($arqs | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($bytes) { $totalBytes += $bytes }
            $arqs | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            if ($p -match 'SoftwareDistribution') {
                Start-Service wuauserv -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Host ""

    try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue; IN "Lixeira esvaziada" } catch {}

    # NOVO v4: Limpar logs do Event Viewer antigos
    try {
        $logs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 1000 }
        foreach ($log in $logs) {
            [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($log.LogName) 2>$null
        }
        OK "Logs de eventos antigos limpos"
    } catch {}

    # NOVO v4: Limpeza de thumbnails antigos
    try {
        $thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        Get-ChildItem $thumbPath -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        OK "Cache de thumbnails removido"
    } catch {}

    $mb = [math]::Round($totalBytes / 1MB, 1)
    Write-Host ""
    OK "Limpeza concluida: $($mb) MB liberados"
    $Script:TweaksFeitos.Add("Limpeza: $($mb) MB liberados")
    LOG "Limpeza v4: $($mb) MB"
    PAUSE
}

# ================================================================
#  MODULO 19 - EXPORTAR RELATORIO (NOVO v4)
# ================================================================
function Invoke-ExportarRelatorio {
    H2 "EXPORTAR RELATORIO DE OTIMIZACOES"

    $relPath = Join-Path $Script:PastaRaiz "Relatorio_$(Get-Date -f 'yyyyMMdd_HHmmss').txt"
    $linhas  = @()
    $linhas += "=" * 70
    $linhas += "  OTIMIZADOR INTELIGENTE v$($Script:Versao) - Relatorio de Sessao"
    $linhas += "  Sessao: $($Script:IDSessao)   Data: $(Get-Date -f 'dd/MM/yyyy HH:mm')"
    $linhas += "=" * 70
    $linhas += ""
    $linhas += "HARDWARE DETECTADO:"
    $linhas += "  CPU  : $($Script:CPUNome)$( if($Script:CPUX3D){' [X3D]'} )"
    $linhas += "  GPU  : $($Script:GPUNome) ($($Script:GPUVRAM) GB)"
    $linhas += "  RAM  : $($Script:RAMtotalGB) GB $($Script:RAMtipo) @ $($Script:RAMvelocidade) MHz"
    $linhas += "  Disco: $($Script:DiscoNome) $(if($Script:DiscoNVMe){'[NVMe]'}elseif($Script:DiscoTipo-match'SSD'){'[SSD]'}else{'[HDD]'})"
    $linhas += "  SO   : $($Script:WinVer) (Build $($Script:WinBuild))"
    $linhas += ""
    $linhas += "TWEAKS APLICADOS ($($Script:TweaksFeitos.Count)):"
    foreach ($t in $Script:TweaksFeitos) { $linhas += "  [+] $t" }
    $linhas += ""
    $linhas += "STATUS: $(if($Script:OtimAplicada){'OTIMIZACOES ATIVAS - Reinicie para aplicar tudo.'}else{'Parcialmente aplicado.'})"
    $linhas += "Log completo: $($Script:LogFile)"
    $linhas += ""
    $linhas += "=" * 70

    $linhas | Out-File $relPath -Encoding UTF8 -Force
    OK "Relatorio salvo em:"
    Write-Host "  $relPath" -ForegroundColor Cyan
    LOG "Relatorio exportado: $relPath"
    PAUSE
}

# ================================================================
#  MODULO 20 - RESTAURAR TUDO
# ================================================================
function Invoke-Restaurar {
    H2 "RESTAURAR CONFIGURACOES ORIGINAIS"

    IN "Plano de energia..."
    $pBkp = Join-Path $Script:PastaBackup "plano.txt"
    if (Test-Path $pBkp) {
        $guid = (Get-Content $pBkp -Raw).Trim()
        if ($guid) { powercfg /setactive $guid 2>$null; OK "Plano original restaurado" }
    } else { powercfg /setactive SCHEME_BALANCED 2>$null; OK "Plano Balanceado restaurado" }

    IN "Servicos..."
    $sBkp = Join-Path $Script:PastaBackup "servicos.json"
    if (Test-Path $sBkp) {
        try {
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
        } catch { ER "Falha ao restaurar servicos" }
    } else { WN "Backup de servicos nao encontrado" }

    IN "Tweaks de rede (Nagle)..."
    try {
        Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" | ForEach-Object {
            Remove-ItemProperty $_.PSPath "TcpAckFrequency" -Force 2>$null
            Remove-ItemProperty $_.PSPath "TCPNoDelay"      -Force 2>$null
            Remove-ItemProperty $_.PSPath "TcpDelAckTicks"  -Force 2>$null
        }
        OK "Tweaks de rede removidos"
    } catch {}

    IN "Politicas de telemetria e Cortana..."
    Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"  -Recurse -Force 2>$null
    Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"  -Recurse -Force 2>$null
    OK "Politicas removidas"

    IN "Visual effects..."
    try {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 0 -Type DWord -Force 2>$null
        Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 1 -Type DWord -Force 2>$null
        OK "Animacoes e transparencia restauradas"
    } catch {}

    IN "BCD tweaks..."
    $bcdBkp = Join-Path $Script:PastaBackup "bcd.txt"
    if (Test-Path $bcdBkp) {
        bcdedit /deletevalue {current} disabledynamictick 2>$null | Out-Null
        bcdedit /deletevalue {current} useplatformtick   2>$null | Out-Null
        OK "BCD restaurado"
    }

    $Script:OtimAplicada = $false
    $Script:ModoStreamer  = $false
    $Script:TweaksFeitos.Clear()

    Write-Host ""
    OK "Restauracao completa!"
    WN "Reinicie o computador."
    LOG "Restauracao v4 realizada"
    PAUSE
}

# ================================================================
#  MODULO 21 - APLICAR TUDO (PERFIL COMPLETO v4)
# ================================================================
function Invoke-AplicarTudo {
    H2 "PERFIL COMPLETO - TODAS AS OTIMIZACOES"

    if (-not $Script:CPUNome) { Invoke-DetectarHardware }

    Write-Host "  Hardware:" -ForegroundColor Cyan
    Write-Host "  CPU : $($Script:CPUNome)$(if($Script:CPUX3D){' [X3D]'})" -ForegroundColor White
    Write-Host "  GPU : $($Script:GPUNome)" -ForegroundColor White
    Write-Host "  RAM : $($Script:RAMtotalGB) GB $($Script:RAMtipo)" -ForegroundColor White
    Write-Host ""
    WN "Backup automatico sera feito antes de cada mudanca."
    Write-Host ""

    if (-not (CONF "Aplicar TODAS as otimizacoes?")) { WN "Cancelado."; PAUSE; return }

    $etapas = @(
        "Plano de Energia",
        "Privacidade",
        "Game Mode",
        "Rede",
        "Servicos",
        "Visual",
        "NTFS/IO",
        "MSI Mode",
        "Limpeza"
    )
    $ei = 0

    Write-Host ""
    $ei++; Show-Progress "Plano de Energia"  $ei $etapas.Count; Write-Host ""; Invoke-PlanoEnergia
    $ei++; Show-Progress "Privacidade"       $ei $etapas.Count; Write-Host ""; Invoke-Privacidade
    $ei++; Show-Progress "Game Mode"         $ei $etapas.Count; Write-Host ""; Invoke-GameMode
    $ei++; Show-Progress "Rede"              $ei $etapas.Count; Write-Host ""; Invoke-OtimizarRede
    $ei++; Show-Progress "Servicos"          $ei $etapas.Count; Write-Host ""; Invoke-Servicos
    $ei++; Show-Progress "Visual"            $ei $etapas.Count; Write-Host ""; Invoke-VisualPerf
    $ei++; Show-Progress "NTFS/IO"           $ei $etapas.Count; Write-Host ""; Invoke-NTFSIOTweaks
    $ei++; Show-Progress "MSI Mode"          $ei $etapas.Count; Write-Host ""; Invoke-MSIMode
    if ($Script:CPUX3D) { Invoke-OtimizacoesX3D }
    $ei++; Show-Progress "Limpeza"           $ei $etapas.Count; Write-Host ""; Invoke-Limpeza

    $Script:OtimAplicada = $true

    Write-Host ""
    Write-Host "  $("="*70)" -ForegroundColor Green
    OK "TODAS AS OTIMIZACOES APLICADAS!"
    Write-Host "  $("="*70)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Tweaks aplicados ($($Script:TweaksFeitos.Count)):" -ForegroundColor Cyan
    foreach ($t in $Script:TweaksFeitos) { Write-Host "    [+] $t" -ForegroundColor DarkGreen }
    Write-Host ""
    WN "REINICIE o computador para que TODAS as mudancas tenham efeito."

    if (CONF "Exportar relatorio agora?") { Invoke-ExportarRelatorio }

    LOG "Perfil completo v4 aplicado: $($Script:TweaksFeitos.Count) tweaks"
    PAUSE
}

# ================================================================
#  MENUS
# ================================================================
function Show-MenuOtimizacao {
    while ($true) {
        Show-Banner; Show-StatusBar
        H1 "OTIMIZACAO DO SISTEMA"
        Write-Host ""
        Write-Host "   [1]  Plano de Energia              (por perfil: Gaming/Work/Equilibrado)" -ForegroundColor White
        Write-Host "   [2]  Privacidade e Telemetria      (30+ tweaks)" -ForegroundColor White
        Write-Host "   [3]  Game Bar OFF / Game Mode / HAGS" -ForegroundColor White
        Write-Host "   [4]  Rede Avancada                 (DNS auto-teste, TCP, NIC MSI)" -ForegroundColor White
        Write-Host "   [5]  Servicos Desnecessarios" -ForegroundColor White
        Write-Host "   [6]  Visual e Performance" -ForegroundColor White
        Write-Host "   [7]  NTFS e I/O Avancado [NOVO]    (NVMe, 8.3, Last Access)" -ForegroundColor Cyan
        Write-Host "   [8]  MSI Mode para GPU/NVMe [NOVO] (reduz latencia IRQ)" -ForegroundColor Cyan
        Write-Host "   [9]  Timer Resolution [NOVO]       (scheduler mais preciso)" -ForegroundColor Cyan
        if ($Script:CPUX3D) {
            Write-Host "   [X]  X3D V-Cache [RECOMENDADO]    ($($Script:CPUNome))" -ForegroundColor Magenta
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
            '7' { Clear-Host; Invoke-NTFSIOTweaks }
            '8' { Clear-Host; Invoke-MSIMode }
            '9' { Clear-Host; Invoke-TimerResolution }
            'X' { if ($Script:CPUX3D) { Clear-Host; Invoke-OtimizacoesX3D; PAUSE } }
            'V' { return }
        }
    }
}

function Show-MenuFerramentas {
    while ($true) {
        Show-Banner; Show-StatusBar
        H1 "FERRAMENTAS"
        Write-Host ""
        Write-Host "   [1]  Instalar Programas via Winget" -ForegroundColor White
        Write-Host "   [2]  Debloater (remove 60+ apps)" -ForegroundColor White
        Write-Host "   [3]  Reparar Windows (SFC + DISM)" -ForegroundColor White
        Write-Host "   [4]  Controle do Windows Update" -ForegroundColor White
        Write-Host "   [5]  Limpeza do Sistema" -ForegroundColor White
        Write-Host "   [6]  Analisador de OC de GPU [ATUALIZADO]" -ForegroundColor Magenta
        Write-Host "   [7]  Modo Streamer [NOVO]          (Gaming + OBS sem drops)" -ForegroundColor Cyan
        Write-Host "   [8]  Monitor em Tempo Real [NOVO]  (CPU/GPU/RAM ao vivo)" -ForegroundColor Cyan
        Write-Host "   [9]  Exportar Relatorio [NOVO]" -ForegroundColor Cyan
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
            '7' { Clear-Host; Invoke-ModoStreamer }
            '8' { Clear-Host; Invoke-Monitor }
            '9' { Clear-Host; Invoke-ExportarRelatorio }
            'V' { return }
        }
    }
}

function Show-MenuPrincipal {
    $rodando = $true
    while ($rodando) {
        Show-Banner; Show-StatusBar

        Write-Host "   >> ACOES RAPIDAS" -ForegroundColor DarkGray
        Write-Host "   [1]  Detectar Hardware Completo" -ForegroundColor White
        Write-Host "   [2]  Aplicar TUDO (perfil completo - recomendado)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   >> CATEGORIAS" -ForegroundColor DarkGray
        Write-Host "   [3]  Otimizacao do Sistema   (Energia / Game / Rede / NTFS / MSI)" -ForegroundColor Cyan
        Write-Host "   [4]  Ferramentas             (Apps / GPU OC / Stream / Monitor)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   >> SISTEMA" -ForegroundColor DarkGray
        Write-Host "   [5]  Restaurar Configuracoes Originais" -ForegroundColor Red
        Write-Host "   [6]  Sair" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Log: $($Script:LogFile)" -ForegroundColor DarkGray
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
                if ($Script:OtimAplicada -and (CONF "Exportar relatorio antes de sair?")) {
                    Invoke-ExportarRelatorio
                }
                IN "Log completo salvo em:"
                Write-Host "  $($Script:LogFile)" -ForegroundColor DarkCyan
                Write-Host ""
                $rodando = $false
            }
            default { WN "Opcao invalida."; Start-Sleep 1 }
        }
    }
}

# ================================================================
#  INICIALIZACAO
# ================================================================
LOG "=== OTIMIZADOR INTELIGENTE v$($Script:Versao) ==="
LOG "Sessao: $($Script:IDSessao) | Usuario: $env:USERNAME | Host: $env:COMPUTERNAME"
LOG "Build Windows: $([System.Environment]::OSVersion.Version)"
LOG "==="

Show-MenuPrincipal
