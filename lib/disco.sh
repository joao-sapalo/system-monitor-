#!/bin/bash
# =============================================================================
# Modulo de monitorizacao de Disco
# =============================================================================

# Verifica o uso de disco em todos os pontos de montagem relevantes.
# Exclui sistemas de ficheiros temporarios (tmpfs, devtmpfs, squashfs).
# Retorna 0 se todos dentro do limite, 1 se algum ultrapassar.
verificar_disco() {
    local alertas=0

    if ! command -v df &>/dev/null; then
        echo "ERRO: comando 'df' nao encontrado" >&2
        return 1
    fi

    # Ler as linhas de uso de disco, excluindo sistemas virtuais
    while IFS= read -r line; do
        local usage mount
        usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        mount=$(echo "$line" | awk '{print $6}')

        if [[ -n "$usage" && "$usage" =~ ^[0-9]+$ ]] && (( usage > DISK_MAX )); then
            echo "ALERTA: Disco ${mount} em ${usage}% (limite: ${DISK_MAX}%)"
            alertas=1
        fi
    done < <(df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | tail -n +2)

    return "${alertas}"
}

# Retorna o uso de disco de uma particao especifica (por path de montagem).
# Uso: uso_disco "/"
uso_disco() {
    local mount="${1:-/}"
    df -h --output=pcent "${mount}" 2>/dev/null | tail -1 | tr -d '% '
}
