# Monitor de Sistema

Script Bash para monitorizacao de CPU, memoria, disco e servicos systemd, com sistema de alertas via Telegram e/ou email.

## Estrutura

```
monitor-sistema/
├── monitor.sh           # Script principal
├── config.conf          # Ficheiro de configuracao
├── lib/
│   ├── cpu.sh           # Verificacao de CPU
│   ├── memoria.sh       # Verificacao de memoria RAM
│   ├── disco.sh         # Verificacao de disco
│   └── servicos.sh      # Verificacao de servicos systemd
├── logs/
│   └── monitor.log      # Ficheiro de log
├── alertas/
│   └── notificar.sh     # Modulo de notificacao (Telegram/email)
└── README.md
```

## Dependencias

- `bash` 4.0+
- `coreutils` (df, free, date, find)
- `systemd` (systemctl)
- `curl` (para Telegram)
- `msmtp` ou `sendmail` (para email, opcional)

### Instalacao (Debian/Ubuntu)

```bash
sudo apt update
sudo apt install curl msmtp msmtp-mta
```

### Instalacao (RHEL/CentOS/Fedora)

```bash
sudo dnf install curl msmtp
```

## Configuracao

Edite o ficheiro `config.conf`:

```bash
# Limites de uso (percentagem)
CPU_MAX=80
MEM_MAX=85
DISK_MAX=90

# Servicos a monitorar (separados por espaco)
SERVICOS_MONITORAR="nginx postgresql ssh"

# Telegram (ativar e preencher token/chat_id)
NOTIFICAR_TELEGRAM=true
TELEGRAM_BOT_TOKEN="123456:ABC-DEF..."
TELEGRAM_CHAT_ID="-1001234567890"

# Email (ativar e configurar msmtp em /etc/msmtprc)
NOTIFICAR_EMAIL=false
EMAIL_DESTINATARIO="admin@exemplo.com"
EMAIL_REMETENTE="monitor@exemplo.com"
```

## Uso

### Execucao completa

```bash
chmod +x monitor.sh
./monitor.sh
```

### Opcoes de linha de comando

| Opcao | Descricao                        |
|-------|----------------------------------|
| `-a`  | Verificacao completa (omissao)   |
| `-c`  | Verificar apenas CPU             |
| `-m`  | Verificar apenas memoria         |
| `-d`  | Verificar apenas disco           |
| `-s`  | Verificar apenas servicos        |
| `-v`  | Modo verbose (output no terminal)|
| `-h`  | Mostrar ajuda                    |

### Exemplos

```bash
# Verificacao completa com output no terminal
./monitor.sh -a -v

# Verificar apenas CPU e memoria
./monitor.sh -c -m

# Verificar disco em modo verbose
./monitor.sh -d -v
```

## Agendamento com Cron

Para executar a cada 5 minutos:

```bash
crontab -e
```

Adicionar a linha:

```
*/5 * * * * /caminho/completo/monitor-sistema/monitor.sh -a
```

Para executar a cada 10 minutos apenas de CPU e memoria:

```
*/10 * * * * /caminho/completo/monitor-sistema/monitor.sh -c -m
```

## Logs

Os registos sao gravados em `logs/monitor.log` com o formato:

```
[2026-09-14 12:30:00] [INFO] Uso de CPU: 45% (limite: 80%)
[2026-09-14 12:30:00] [ALERTA] Uso de memoria elevado: 92% (limite: 85%)
```

A rotacao de logs e automatica: arquivos com mais de 7 dias sao eliminados (configuravel via `LOG_DIAS_RETENCAO`).

## Testes

```bash
# Verificar se o script carrega corretamente
bash -n monitor.sh

# Testar verificacao de CPU
./monitor.sh -c -v

# Testar notificacao (configurar token/chat_id primeiro)
source config.conf
source alertas/notificar.sh
notificar "Teste" "Mensagem de teste do monitor"
```
