#!/bin/bash
# =============================================================================
# Modulo de Notificacao (Alertas)
# Envia alertas via desktop, som, Telegram e/ou email.
# =============================================================================

# Envia notificacao desktop via notify-send (popup no ecrã).
# Argumento: $1 = titulo, $2 = mensagem
_notificar_desktop() {
    local titulo="$1"
    local mensagem="$2"

    if [[ "${NOTIFICAR_DESKTOP}" != "true" ]]; then
        return 0
    fi

    if ! command -v notify-send &>/dev/null; then
        return 1
    fi

    notify-send -u critical -i dialog-warning "${titulo}" "${mensagem}" 2>/dev/null
    return $?
}

# Emite alerta sonoro via speaker ou aplay.
# Argumento: $1 = titulo (opcional, para contexto)
_notificar_som() {
    local titulo="${1:-Alerta}"

    if [[ "${NOTIFICAR_SOM}" != "true" ]]; then
        return 0
    fi

    # Tentar aplay com ficheiro de som do sistema
    if command -v aplay &>/dev/null; then
        local sons=("/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
                    "/usr/share/sounds/freedesktop/stereo/complete.oga"
                    "/usr/share/sounds/freedesktop/stereo/bell.oga"
                    "/usr/share/sounds/sound-icons/attention.wav")
        for som in "${sons[@]}"; do
            if [[ -f "${som}" ]]; then
                aplay -q "${som}" 2>/dev/null &
                return 0
            fi
        done
    fi

    # Fallback: beep via /dev/video0 (se disponivel) ou terminal bell
    if command -v beep &>/dev/null; then
        beep -f 800 -l 200 -n 200 -f 1000 -l 200 2>/dev/null &
    else
        printf '\a'  # Terminal bell
    fi
    return 0
}

# Envia notificacao via Telegram Bot API.
# Argumento: $1 = mensagem a enviar
_enviar_telegram() {
    local mensagem="$1"

    if [[ "${NOTIFICAR_TELEGRAM}" != "true" ]]; then
        return 0
    fi

    if [[ -z "${TELEGRAM_BOT_TOKEN}" || "${TELEGRAM_BOT_TOKEN}" == "SEU_BOT_TOKEN_AQUI" ]]; then
        echo "AVISO: Telegram nao configurado (token em falta)" >&2
        return 1
    fi

    if [[ -z "${TELEGRAM_CHAT_ID}" || "${TELEGRAM_CHAT_ID}" == "SEU_CHAT_ID_AQUI" ]]; then
        echo "AVISO: Telegram nao configurado (chat_id em falta)" >&2
        return 1
    fi

    if ! command -v curl &>/dev/null; then
        echo "ERRO: comando 'curl' necessario para Telegram" >&2
        return 1
    fi

    local url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    curl -s -X POST "${url}" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${mensagem}" \
        -d "parse_mode=HTML" \
        --max-time 10 >/dev/null 2>&1

    return $?
}

# Envia notificacao via email (msmtp ou sendmail).
# Argumento: $1 = assunto, $2 = corpo da mensagem
_enviar_email() {
    local assunto="$1"
    local corpo="$2"

    if [[ "${NOTIFICAR_EMAIL}" != "true" ]]; then
        return 0
    fi

    if [[ -z "${EMAIL_DESTINATARIO}" ]]; then
        echo "AVISO: Email nao configurado (destinatario em falta)" >&2
        return 1
    fi

    # Tentar msmtp primeiro, depois sendmail
    if command -v msmtp &>/dev/null; then
        echo -e "Subject: ${assunto}\nFrom: ${EMAIL_REMETENTE}\nTo: ${EMAIL_DESTINATARIO}\n\n${corpo}" | \
            msmtp "${EMAIL_DESTINATARIO}" 2>/dev/null
        return $?
    elif command -v sendmail &>/dev/null; then
        echo -e "Subject: ${assunto}\nFrom: ${EMAIL_REMETENTE}\nTo: ${EMAIL_DESTINATARIO}\n\n${corpo}" | \
            sendmail "${EMAIL_DESTINATARIO}" 2>/dev/null
        return $?
    else
        echo "AVISO: nenhum cliente de email encontrado (msmtp/sendmail)" >&2
        return 1
    fi
}

# Funcao principal de notificacao - envia para todos os canais configurados.
# Argumento: $1 = titulo do alerta, $2 = mensagem detalhada
notificar() {
    local titulo="$1"
    local mensagem="$2"
    local hostname
    hostname=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "unknown")
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Notificacoes locais (instantaneas, sem redes sociais)
    _notificar_desktop "${titulo}" "${mensagem}" >/dev/null
    _notificar_som "${titulo}" >/dev/null

    # Notificacoes externas (configuraveis)
    local corpo_completo="[${hostname}] ${timestamp}\n\n${titulo}\n${mensagem}"
    _enviar_telegram "<b>${titulo}</b>\n\n${mensagem}\n\n<i>Host: ${hostname} | ${timestamp}</i>" >/dev/null
    _enviar_email "[Monitor] ${titulo}" "${corpo_completo}" >/dev/null
}
