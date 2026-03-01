# ⚡ Abimalek Boost

> Script PowerShell all-in-one para otimização de desempenho no Windows 10/11, com detecção automática de hardware e perfis inteligentes por CPU/GPU.

---

## 📋 Índice

- [Sobre](#-sobre)
- [Requisitos](#-requisitos)
- [Como usar](#-como-usar)
- [Funcionalidades](#-funcionalidades)
- [O que é permanente](#-o-que-é-permanente)
- [Restauração](#-restauração)
- [Aviso legal](#-aviso-legal)

---

## 🧠 Sobre

O **Otimizador Inteligente** é um script PowerShell focado em extrair o máximo de desempenho do seu sistema Windows, com foco em **gaming**, **streaming** e **workstation**. Ele detecta automaticamente seu hardware (CPU, GPU, RAM, disco) e aplica configurações específicas para cada combinação.

Tudo é reversível — um backup completo é salvo antes de qualquer modificação.

---

## 📦 Requisitos

- Windows 10 ou Windows 11
- PowerShell 5.1 ou superior (já incluso no Windows)
- **Executar como Administrador** (obrigatório)
- Para instalação de programas: `winget` disponível (App Installer da Microsoft Store)
- Para monitoramento e OC de GPU NVIDIA: `nvidia-smi` (incluso nos drivers NVIDIA)

---

## 🚀 Como usar

1. Baixe o arquivo `AbimalekBoos.ps1`
2. Clique com o botão direito no PowerShell → **Executar como Administrador**
3. Cole o comando abaixo e pressione Enter:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\caminho\AbimalekBoost.ps1"
```

> **Dica:** Para evitar erros de encoding, não renomeie o arquivo para nomes com acentos.

---

## ✅ Funcionalidades

### 🔍 Detecção de Hardware Automática
- CPU: nome, fabricante (AMD/Intel), núcleos físicos e lógicos, geração Intel, detecção de V-Cache X3D e série K
- GPU: nome, VRAM, fabricante, versão do driver, temperatura e clock em tempo real (NVIDIA via nvidia-smi)
- RAM: total, tipo (DDR3/4/5), velocidade em MHz, número de módulos e aviso de single-channel
- Disco: nome, tipo (NVMe / SSD SATA / HDD) com detecção automática via WMI
- Windows: versão e build number
- winget: verifica disponibilidade automaticamente

---

### ⚡ Módulo 1 — Plano de Energia Inteligente
Configura o plano de energia ideal baseado no hardware ou no perfil escolhido:

| Perfil | Indicado para |
|---|---|
| Gaming | Máxima performance, Ultimate Performance (Intel) ou AMD Ryzen Balanced |
| Workstation | Performance + estabilidade térmica |
| Equilibrado | Uso misto, padrão para CPUs AMD X3D |
| Auto | O script decide baseado no hardware detectado |

- Core Parking desativado (núcleos sempre disponíveis)
- Boost agressivo ou Efficient Aggressive (X3D)
- Sleep e monitor timeout desativados
- Suporte a Intel 12ª geração+ (Alder Lake e acima) com gerenciamento correto de E-cores e P-cores
- Opção de desativar Hibernate (libera GBs no SSD)

---

### 🔒 Módulo 2 — Privacidade e Telemetria
30+ tweaks de registro aplicados:

- Telemetria e diagnóstico da Microsoft desativados
- Anúncios personalizados bloqueados
- Cortana e pesquisa web na barra de tarefas desativados
- Sugestões e apps silenciosos bloqueados
- Histórico de atividades (Timeline) desativado
- Localização geográfica bloqueada para apps
- Acesso de apps a microfone e câmera bloqueado
- Windows Recall (IA) desativado (Windows 11 24H2)
- OneDrive removido do startup
- Feedback e relatórios de erros desativados

---

### 🎮 Módulo 3 — Game Bar / Game Mode / HAGS
- Xbox Game Bar desativado (libera CPU durante jogos)
- Game Mode ativado (Windows prioriza o processo do jogo)
- HAGS — Hardware Accelerated GPU Scheduling ativado
- Multimedia Scheduler configurado com prioridade máxima para jogos
- GPU Priority elevada para 8
- Clock Rate do scheduler ajustado para 10.000

---

### 🌐 Módulo 4 — Rede Avançada
- **Nagle Algorithm** desativado (reduz latência em jogos online)
- **TCP Stack** otimizado: TTL, MaxUserPort, Window Scaling, Timestamps
- **Auto-Tuning** normal com DCA/NetDMA ativados e ECN desativado
- **DNS com teste automático de latência**: testa Cloudflare, Google, Quad9 e OpenDNS e aplica o mais rápido
- Reserva de 20% de banda do Windows liberada
- NIC tweaks: Interrupt Moderation OFF, RSS ON, LSO OFF, Energy Efficient Ethernet OFF
- **MSI Mode ativado na NIC** (Message Signaled Interrupts — reduz latência de IRQ)
- Cache DNS limpo ao final

---

### 🛠️ Módulo 5 — Serviços Desnecessários
Desativa 24 serviços que consomem recursos sem utilidade para a maioria dos usuários:

- DiagTrack (Telemetria)
- Serviços Xbox Live (Auth, GameSave, Network API, Accessories)
- Localização, Mapas Offline, Fax
- Registro Remoto (risco de segurança)
- WAP Push, Telefonia legada, Hotspot móvel
- AllJoyn Router (IoT legado)
- E outros

Backup automático do estado original salvo antes de desativar qualquer serviço.

---

### 🖥️ Módulo 6 — Visual e Performance
- Todas as animações do Windows desativadas
- Transparência desativada (menos uso de GPU em background)
- Widgets e Chat da taskbar removidos
- News e Interests desativados
- Menu de contexto clássico restaurado no Windows 11
- Delay de menu zerado
- Extensões de arquivo e arquivos ocultos visíveis
- Prefetch mantido para SSD/NVMe (melhora carregamento de jogos)

---

### 💾 Módulo 7 — NTFS e I/O Avançado
- **Last Access Time** desativado (reduz writes desnecessários no disco)
- **Criptografia do PageFile** desativada
- **Nomes curtos 8.3** desativados (melhora velocidade do Explorer em pastas grandes)
- NVMe: Write Cache Buffer Flushing ativado
- NVMe: StorNVMe Command Spreading desativado (reduz latência)
- I/O Timeout otimizado para SSD/NVMe
- Network Throttling desativado para jogos

---

### ⏱️ Módulo 8 — Timer Resolution
- **Dynamic Tick** desativado via BCD (timer mais consistente = FPS mais estável)
- **Platform Tick** ativado
- Platform Clock verificado e desativado se causar stuttering (Windows 11 22H2+)
- System Responsiveness ajustado para 0% (CPU 100% focada no primeiro plano)
- Backup do estado BCD salvo antes de modificar

---

### 🔌 Módulo 9 — MSI Mode (GPU + NVMe)
- **Message Signaled Interrupts** ativado para GPU e NVMe
- Elimina conflitos de IRQ entre dispositivos PCIe
- GPU com prioridade High configurada no gerenciador de interrupções
- Reduz latência de resposta da GPU durante jogos

> Requer reinicialização para ter efeito.

---

### 🔵 Módulo 10 — Otimizações AMD X3D V-Cache
Ativado automaticamente quando CPU com V-Cache é detectada:

- AMD Ryzen Balanced obrigatoriamente ativado
- Boost: Efficient Aggressive (ideal para latência do cache 3D)
- Core Parking OFF
- Transições de frequência rápidas
- Instruções para BIOS (CPPC Preferred Cores, Cool'n'Quiet, C-state, XMP/EXPO, PBO desativado)

---

### 🎯 Módulo 11 — Analisador de Overclock de GPU
Banco de dados com **40+ modelos de GPU** (NVIDIA e AMD):

- RTX 4090 até GTX 1050 Ti
- RX 7900 XTX até RX 5600 XT
- Intel Arc A770/A750

Para cada GPU fornece:

| Perfil | Core OC | Mem OC | Power Limit |
|---|---|---|---|
| Conservador | Seguro para começar | Seguro | +5 a +8% |
| Moderado | Estável na maioria | Bom ganho | +8 a +12% |
| Agressivo | Máximo do modelo | Máximo | +10 a +15% |

- Análise térmica em tempo real (15 segundos com gráfico ASCII)
- Power Limit aplicado automaticamente via nvidia-smi (NVIDIA)
- Configuração de frequência mínima do core (evita stutter em menus)
- Guia passo a passo para MSI Afterburner / AMD Adrenalin

---

### 📺 Módulo 12 — Modo Streamer
Configura o sistema para rodar jogo + OBS simultaneamente sem drops:

- OBS64 com CPU Priority = High
- HAGS ativado (necessário para encode via GPU no OBS)
- Pro Audio scheduler configurado (sem drops de áudio)
- System Responsiveness ajustado para 10% (divide CPU entre jogo e encoder)
- Recomendações de configuração do OBS incluídas (encoder, bitrate, keyframe)

---

### 📊 Módulo 13 — Monitor em Tempo Real
Monitor ao vivo no terminal com atualização a cada segundo:

```
[14:32:05] CPU:  47% | RAM: 58% (9.2/16GB) | GPU: 61C/94% VRAM:7.1/8GB W:182
```

- CPU: uso percentual com código de cor (verde/amarelo/vermelho)
- RAM: uso em GB e percentual
- GPU: temperatura, utilização, VRAM usada/total, consumo em watts (requer nvidia-smi)

---

### 🗑️ Módulo 14 — Debloater
Remove **60+ aplicativos** desnecessários do Windows:

- Apps Xbox (mantém apenas o runtime necessário para jogos)
- Cortana standalone
- Apps Bing (Weather, Finance, News, Sports, Translator)
- Skype, Teams, People, Alarms, Maps, FeedbackHub
- Bloatware de terceiros: TikTok, Instagram, Facebook, CandyCrush, Netflix, Roblox
- Copilot standalone, Family Safety, Mail antigo, 3D Builder
- Bloqueia reinstalação automática pelo Windows

---

### 📥 Módulo 15 — Instalador de Programas
Instala aplicativos via winget com seleção numérica:

| Categoria | Programas |
|---|---|
| Navegadores | Chrome, Firefox, Brave, Opera |
| Comunicação | Discord, WhatsApp, Telegram, Zoom |
| Gaming | Steam, Epic Games, Ubisoft Connect, EA App |
| Utilitários | 7-Zip, Notepad++, VLC, qBittorrent, Malwarebytes, HWiNFO64, CrystalDiskInfo, CPU-Z |
| GPU/OC | MSI Afterburner, RivaTuner Statistics |
| Dev | Git, VS Code, Python 3.12, Node.js LTS |
| Multimedia | OBS Studio, GIMP, HandBrake |
| Office | LibreOffice, Adobe Acrobat Reader |

---

### 🔄 Módulo 16 — Controle do Windows Update
- Pausar atualizações por 35 dias (recomendado para gamers)
- Habilitar atualizações automáticas
- Bloquear permanentemente (com aviso de riscos)
- Forçar verificação de atualizações imediata

---

### 🔧 Módulo 17 — Reparar Windows
- `DISM /RestoreHealth` — repara a imagem do Windows
- `SFC /scannow` — verifica e repara arquivos de sistema corrompidos
- Reset de Winsock e pilha TCP/IP (opcional)
- Cache DNS limpo ao final

---

### 🧹 Módulo 18 — Limpeza do Sistema
- Pastas temporárias (`%TEMP%`, `C:\Windows\Temp`, INetCache)
- Cache do Windows Update (SoftwareDistribution)
- Lixeira esvaziada
- Logs antigos do Event Viewer (acima de 1.000 entradas) removidos
- Cache de thumbnails do Explorer removido

---

### 📄 Módulo 19 — Exportar Relatório
Gera um arquivo `.txt` com:
- Hardware detectado (CPU, GPU, RAM, Disco, SO)
- Lista completa de tweaks aplicados na sessão
- Caminho do log completo

Salvo em `%LOCALAPPDATA%\AbimalekBoost\`

---

### ↩️ Módulo 20 — Restaurar Configurações Originais
Reverte **tudo** que foi modificado:
- Plano de energia original restaurado via GUID salvo
- Serviços reativados com seus tipos de inicialização originais
- Tweaks de rede (Nagle, TCP) removidos
- Políticas de telemetria e Cortana removidas
- Efeitos visuais e transparência restaurados
- BCD revertido ao estado pré-otimização

---

## 💾 O que é permanente

| Configuração | Permanente? | Observação |
|---|---|---|
| Tweaks de registro | ✅ Sim | Persiste até restaurar |
| Plano de energia | ✅ Sim | Salvo no Windows |
| Serviços desativados | ✅ Sim | StartType = Disabled |
| NTFS (fsutil) | ✅ Sim | Nível de sistema de arquivos |
| BCD (Dynamic Tick) | ✅ Sim | Gravado no bootloader |
| DNS configurado | ✅ Sim | Por adaptador de rede |
| MSI Mode | ✅ Sim | Após reinicialização |
| Debloater | ✅ Sim | Apps removidos ficam removidos |
| Power Limit nvidia-smi | ❌ Não | Reseta ao reiniciar — use Afterburner |
| Frequência mínima GPU | ❌ Não | Reseta ao reiniciar |
| Flush de DNS | ❌ Não | Limpeza pontual de cache |

---

## 🔙 Restauração

Para reverter **todas** as modificações:

1. Execute o script como Administrador
2. Escolha a opção **[5] Restaurar Configurações Originais**
3. Reinicie o computador

Os backups ficam salvos em:
```
%LOCALAPPDATA%\OtimizadorInteligente\Backup\
```

---

## ⚠️ Aviso Legal

- Este script modifica configurações do sistema operacional. Use por sua conta e risco.
- Todas as alterações são reversíveis via opção de restauração.
- Recomendado criar um **Ponto de Restauração do Sistema** antes de executar.
- Não são feitas modificações em arquivos de sistema, apenas em registro, serviços e configurações do Windows.
- O script **não instala drivers**, não modifica o bootloader de forma permanente sem confirmação e não faz overclock de hardware automaticamente.

---

## 📁 Estrutura de arquivos gerados

```
%LOCALAPPDATA%\AbimalekBoost\
├── Backup\
│   ├── plano.txt          ← GUID do plano de energia original
│   ├── servicos.json      ← Estado original dos serviços
│   └── bcd.txt            ← Flag de tweaks BCD aplicados
├── Logs\
│   └── v4_XXXXXXXX_*.log  ← Log completo da sessão
└── Relatorio_*.txt        ← Relatório exportado (se solicitado)
```

---

## 📜 Licença

MIT License — livre para usar, modificar e distribuir.
