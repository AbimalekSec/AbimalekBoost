<div align="center">

```
 █████╗ ██████╗ ██╗███╗   ███╗ █████╗ ██╗     ███████╗██╗  ██╗
██╔══██╗██╔══██╗██║████╗ ████║██╔══██╗██║     ██╔════╝██║ ██╔╝
███████║██████╔╝██║██╔████╔██║███████║██║     █████╗  █████╔╝ 
██╔══██║██╔══██╗██║██║╚██╔╝██║██╔══██║██║     ██╔══╝  ██╔═██╗ 
██║  ██║██████╔╝██║██║ ╚═╝ ██║██║  ██║███████╗███████╗██║  ██╗
╚═╝  ╚═╝╚═════╝ ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝
                    BOOST  v6.0
```

**Motor de IA Heurística para Windows 10/11**

*Detecta hardware · Analisa gargalos · Decide o que otimizar · Mede o resultado*

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4?logo=windows)](https://www.microsoft.com/windows)
[![Version](https://img.shields.io/badge/Versão-6.0.0-00FF88)](#)
[![Tweaks](https://img.shields.io/badge/Tweaks-120-FF6B35)](#módulos)
[![License](https://img.shields.io/badge/Licença-MIT-yellow)](#licença)

</div>

---

## Execução rápida

```powershell
irm "https://raw.githubusercontent.com/AbimalekSec/AbimalekBoost/refs/heads/main/AbimalekBoost.ps1" | iex
```

> **Requer PowerShell como Administrador.** Clique com botão direito no PowerShell → *Executar como administrador*.

---

## O que é

AbimalekBoost é um otimizador avançado de desempenho para Windows 10 e 11, executado **100% em memória** via PowerShell — sem instalação, sem servidor externo, sem IA paga.

A versão 6.0 introduz o **Motor de IA Heurística**: em vez de aplicar um conjunto fixo de tweaks, o script analisa o hardware real da máquina, detecta gargalos, decide quais otimizações fazem sentido para aquele sistema específico e mede o resultado com score comparativo antes/depois.

**Não é um script de tweaks estático. É um motor de decisão.**

---

## Como funciona — 4 fases

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  [FASE 1] COLETA              [FASE 2] DECISÃO                  │
│  ───────────────────           ─────────────────────            │
│  CPU uso%                      Detecta gargalos:                │
│  RAM uso% + livre              · CPU-bound                      │
│  Disk Queue Length             · RAM-limitada                   │
│  Ping ×5 + jitter              · IO-limitado                    │
│  Timer resolution              · Rede-instável                  │
│  TCP autotuning                · GPU-bound                      │
│  Core parking                  Seleciona regras                 │
│  Plano de energia              por perfil e condição            │
│  Top 8 processos               Ordena por prioridade            │
│                                                                  │
│  [FASE 3] APLICAÇÃO           [FASE 4] SCORE + APRENDIZADO      │
│  ──────────────────            ───────────────────────────      │
│  Ponto de restauração          Score Geral      (0–100)         │
│  Backup de registro            Score Latência   (0–100)         │
│  Aplica por prioridade         Score Responsiv. (0–100)         │
│  Erro por regra isolado        Score Gamer      (0–100)         │
│                                Salva em JSON local              │
│                                Interface WPF antes/depois       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Perfis de otimização

| Perfil | Para quem | O que inclui |
|--------|-----------|--------------|
| 🟢 **Seguro** | Primeiro uso, uso geral | Plano de energia, Timer, Nagle OFF, TCP, Telemetria, NTFS |
| 🟡 **Gamer** | Gaming competitivo, uso diário | + Mouse 1:1, IRQ, MMCSS, QoS gaming, Background apps, RAM clear |
| 🔵 **Streamer** | Gaming + OBS simultâneo | + Prioridade OBS, afinidade de CPU, rede para streaming |
| 🔴 **Extremo** | PC dedicado a gaming | + Spectre/Meltdown OFF, C-States OFF, Memory Compression OFF |

> ⚠️ **Perfil Extremo** desativa mitigações de segurança do CPU. Use apenas em PCs dedicados a gaming sem dados sensíveis.

---

## Módulos

| Módulo | Tweaks | Risco | O que faz |
|--------|:------:|:-----:|-----------|
| Plano de Energia | 8 | 🟢 Baixo | Ultimate Performance, core parking, turbo boost, SpeedStep, C-States, PCIe ASPM |
| Privacidade / Telemetria | 7 | 🟢 Baixo | Desativa coleta de dados, feedback, CEIP, localização, anúncios, Activity History |
| Game Bar / Game Mode | 5 | 🟢 Baixo | Game Bar, Game Mode, HAGS (Hardware GPU Scheduling), DVR, overlay |
| Otimização de Rede | 11 | 🟢 Baixo | TCP stack, Nagle OFF, QoS, buffer, autotuning, DNS, timestamps, checksum offload |
| Serviços Desnecessários | 7 | 🟢 Baixo | Para e desativa serviços que consomem CPU/RAM sem benefício para gaming |
| Visual e Performance | 7 | 🟢 Baixo | Animações, transparência, efeitos visuais, widgets, menu contexto Win11 |
| NTFS e I/O | 8 | 🟢 Baixo | LastAccess OFF, 8.3 names OFF, MFT zone, write cache, TRIM |
| Timer Resolution | 5 | 🟡 Médio | Scheduler preciso, platform tick, dynamic tick, BCD (adaptativo Win10/Win11) |
| MSI Mode | 2 | 🟡 Médio | Message Signaled Interrupts para GPU e NIC — reduz latência de interrupção |
| Tweaks de CPU | 7 | 🟡 Médio | Affinity, SpeedStep, QoS por processo, C-States, prioridade foreground |
| Tweaks de Memória | 5 | 🟡 Médio | Large Pages, prefetch avançado, Working Set clear, pagefile, compressão |
| Tweaks de GPU | 6 | 🟡 Médio | TDR Delay, PhysX CPU, shader cache, CUDA, driver threading, DX12 |
| Tweaks de Áudio | 4 | 🟢 Baixo | WASAPI exclusive, buffer mínimo, DPC latency, MMCSS de áudio |
| 💥 Nuclear Microsoft | 9 | 🟡 Médio | Remove OneDrive, Copilot, Teams, Recall, Cortana, Edge autostart, Search, Widgets |
| Processos CPU/RAM | 10 | 🟡 Médio | Kill processos pesados, Xbox services, Print Spooler, Working Set clear, startup |
| Input Lag | 11 | 🟡 Médio | Mouse 1:1, IRQ priority, USB power, QoS jogos, MMCSS, DWM overlay, teclado |
| Group Policy Pack | 16 | 🟡 Médio | 16 políticas via registro — funciona no **Windows Home** sem gpedit |

**Total: 120 tweaks em 17 módulos.**

---

## Sistema de Score

O score é calculado com métricas reais coletadas antes e depois de otimizar:

```
Score Geral = (Latência × 30%) + (Responsividade × 35%) + (Gamer × 35%)
```

| Dimensão | O que penaliza o score |
|----------|------------------------|
| **Latência** | Ping alto, jitter, Nagle ativo, TCP não otimizado, timer resolution ruim |
| **Responsividade** | CPU > 60%, RAM > 70%, Disk Queue > 1.0, paginação ativa, core parking ligado |
| **Gamer** | Plano errado, SysMain ativo em HDD, serviços em excesso, MMCSS padrão |

Hardware premium gera bônus no Score Gamer: CPU X3D `+5` · DDR5 `+5` · NVMe `+5` · GPU ≥ 8 GB `+5`

---

## Regras do Motor de IA

O motor seleciona otimizações com base em **condições medidas em tempo real**:

| Regra | Condição de ativação | Prioridade |
|-------|---------------------|:----------:|
| Plano Ultimate Performance | Plano atual ≠ Ultimate | 🔴 Crítico |
| Core Parking OFF | Core parking ativo detectado | 🔴 Crítico |
| Timer Resolution | Timer medido > 3ms | 🔴 Crítico |
| Nagle Algorithm OFF | Nagle ativo na interface de rede | 🔴 Crítico |
| MMCSS Gaming | Configuração padrão ausente | 🟠 Alto |
| Network Throttle OFF | Throttle de rede ativo | 🟠 Alto |
| SysMain OFF | Disco = HDD **ou** RAM ≤ 8 GB | 🟠 Alto |
| Power Throttling OFF | Sempre (Win throttle em background) | 🟠 Alto |
| Mouse Aceleração OFF | Sempre | 🟠 Alto |
| TCP Stack | Sempre (TTL, MaxUserPort, scaling) | 🟠 Alto |
| Background Apps OFF | CPU > 30% **ou** RAM > 60% | 🟡 Médio |
| Telemetria OFF | DiagTrack ativo | 🟡 Médio |
| Windows Error Reporting OFF | Sempre | 🟡 Médio |
| IRQ Priority Input | Mouse/teclado com baixa IRQ | 🟡 Médio |
| NTFS Performance | Sempre (LastAccess + 8.3 names) | 🟡 Médio |
| RAM Working Set Clear | RAM uso > 65% | 🟡 Médio |
| QoS Gaming | Sempre (CS2, Valorant, Apex, etc.) | 🟡 Médio |
| OBS Prioridade | Perfil = Streamer | 🟠 Alto |
| Spectre/Meltdown OFF | Perfil = Extremo | ⚫ Extremo |
| C-States OFF | Perfil = Extremo | ⚫ Extremo |

---

## Win10 vs Win11 — diferenças automáticas

O script detecta a versão do Windows na inicialização (`build ≥ 22000 = Win11`) e aplica tweaks diferentes para cada uma:

| Tweak | Windows 10 | Windows 11 |
|-------|-----------|-----------|
| `Win32PrioritySeparation` | `0x26` — quantum curto com boost | `2` — sem stutter no scheduler moderno |
| `useplatformtick` (BCD) | `YES` — melhora timer no Win10 | Removido — causa stutter no Win11 22H2+ |
| `disabledynamictick` | `YES` | `YES` |
| Copilot / Recall / Widgets | Ignorado — não existe no Win10 | Aplicado normalmente |
| Auto HDR / VRR | Ignorado — exclusivo Win11 | Desativado para menor overhead |
| SysMain | Desativa só em HDD ou RAM ≤ 8 GB | Desativa só em HDD ou RAM ≤ 8 GB |

---

## Ferramentas extras

**🎮 Simulação de impacto por jogo**
Estima ganho de FPS e input lag antes de otimizar, com análise de hardware específica para cada engine:
- **FiveM** — gargalo: CPU single-core + RAM bandwidth
- **CS2** — gargalo: latência de rede + mouse input lag + timer
- **Valorant** — gargalo: CPU scheduler + network + VRAM

**📊 Monitor de Hardware em tempo real**
CPU, RAM, temperatura de GPU e disco em loop no terminal, atualizado a cada 2 segundos.

**🖥️ Analisador de GPU / Overclock**
Lê temperatura, clock core, power limit e VRAM via `nvidia-smi`. Sugere perfil de OC baseado nos dados.

**🎙️ Modo Streamer**
Prioridade `AboveNormal` para OBS, afinidade de CPU dividida entre jogo e encoder, MMCSS ajustado para encoding sem drops.

**⚡ Otimizações X3D V-Cache**
Para AMD 5800X3D, 7800X3D, 9800X3D: desativa PBO, ajusta Curve Optimizer, força scheduler a usar núcleos com V-Cache primeiro.

**🧹 Debloater**
Remove apps pré-instalados do Windows com checklist de seleção.

**📦 Instalador via Winget**
Instala Chrome, Discord, Steam, OBS, 7-Zip e outros pelo repositório oficial da Microsoft.

**🔧 Reparar Windows**
Executa `SFC /scannow` e `DISM /RestoreHealth` com log de resultado.

---

## Segurança e reversibilidade

Toda sessão cria **3 camadas de proteção** antes de qualquer alteração:

```
1. Ponto de Restauração do Sistema
   └── criado via Checkpoint-Computer antes da primeira alteração

2. Backup de Registro
   └── exportado em .reg com timestamp
   └── %LOCALAPPDATA%\AbimalekBoost\Backup\reg_ia_YYYYMMDD_HHMMSS.reg

3. Log de Sessão
   └── cada tweak registrado com resultado
   └── %LOCALAPPDATA%\AbimalekBoost\Logs\
```

Para reverter tudo: menu **Restaurar**.
Para rollback granular: **Motor de IA → Rollback de Registro** → selecione o backup por data.

---

## Aprendizado local

O sistema mantém histórico de sessões em JSON local — **zero dados enviados para servidores**:

```
%LOCALAPPDATA%\AbimalekBoost\ia_historico.json
```

Cada sessão registra: data, perfil, hardware, score antes/depois, ganho, ping, RAM e tweaks aplicados. Na próxima execução, o motor exibe ganho médio histórico e recomenda o perfil mais eficiente para aquele hardware.

---

## Navegação no menu

```
Menu Principal
├── [1] Otimização do Sistema     tweaks granulares por módulo (checklist)
├── [2] Motor de IA v6.0          análise inteligente completa
├── [3] Ferramentas               debloater, instalador, monitor, reparar
├── [A] Aplicar Tudo              modo rápido com padrões recomendados
├── [R] Restaurar                 reverter todas as otimizações
└── [I] Informações do Hardware   exibe detecção completa

Motor de IA
├── [1] Executar com seleção de perfil
├── [2] Perfil Seguro
├── [3] Perfil Gamer
├── [4] Perfil Streamer
├── [5] Perfil Extremo
├── [S] Simulação por jogo  (FiveM / CS2 / Valorant)
├── [H] Histórico de aprendizado
└── [R] Rollback de registro IA

Checklist de tweaks (em qualquer módulo)
├── [número]  marcar/desmarcar tweak individual
├── [A]       marcar todos
├── [N]       desmarcar todos
├── [ENTER]   aplicar os marcados
└── [V]       voltar sem aplicar
```

> Tweaks de risco **ALTO** aparecem desmarcados por padrão. Tweaks **MÉDIO** e **BAIXO** vêm marcados.

---

## Avisos

> 🔄 **Reinicie após aplicar.** Tweaks de BCD e registro de kernel só entram em vigor no próximo boot.

> 🔑 **Execute como Administrador.** Sem privilégio elevado os tweaks falham silenciosamente.

> 🛡️ **Antivírus pode bloquear.** Adicione `raw.githubusercontent.com` como exceção se necessário.

> 📖 **Leia a descrição de cada tweak.** O checklist mostra nome, descrição e risco antes de aplicar.

---

## Changelog

### v6.0 — Motor de IA Heurística
- Motor de IA com 20 regras condicionais por hardware/gargalo
- Score 4D: Geral, Latência, Responsividade e Gamer (0–100)
- Perfis: Seguro, Gamer, Streamer, Extremo
- Coleta de métricas em tempo real (CPU, RAM, Disk Queue, Ping, Timer)
- Aprendizado local em JSON — histórico de sessões sem servidor externo
- Interface WPF com comparativo antes/depois e delta colorido
- Simulação de impacto para FiveM, CS2 e Valorant
- Ponto de restauração + backup de registro automático por sessão
- Detecção automática Win10 vs Win11 com tweaks adaptativos
- `Win32PrioritySeparation` adaptativo: `0x26` no Win10, `2` no Win11
- `useplatformtick`: YES no Win10, removido no Win11 (evita stutter)
- Tweaks Win11-only ignorados automaticamente no Win10
- `SysMain` condicional: desativa só em HDD ou RAM ≤ 8 GB
- Checklist: tweaks de risco ALTO desmarcados por padrão

### v5.1 — Novos módulos de performance
- Nuclear Microsoft: OneDrive, Copilot, Teams, Recall, Cortana, Edge, Search, Widgets
- Processos CPU/RAM: kill de processos pesados, Xbox, Print Spooler, Working Set clear
- Input Lag: mouse 1:1, IRQ priority, USB power, QoS, DWM overlay, MMCSS
- Group Policy Pack: 16 políticas via registro (funciona no Windows Home)

### v5.0 — IA Advisor + Checklist granular
- Sistema de checklist tweak por tweak em todos os módulos
- Módulos: CPU avançado, Memória, GPU, Áudio
- Tweaks de Spectre/Meltdown, paginação, Large Pages

---

## Licença

MIT — use, modifique e distribua livremente com atribuição.

---

<div align="center">
<b>AbimalekBoost v6.0</b> · Motor de IA Heurística · Windows 10/11<br>
4.679 linhas · 120 tweaks · 17 módulos · 0 servidores externos
</div>
