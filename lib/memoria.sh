#!/bin/bash
# =============================================================================
# Modulo de monitorizacao de Memoria (RAM)
# =============================================================================

# Devolve a percentagem actual de uso de memoria RAM (0-100).
# Usa o comando free para calcular: (total - available) / total * 100
verificar_memoria() {
    local total available usage

    if ! command -v free &>/dev/null; then
        echo "ERRO: comando 'free' nao encontrado" >&2
        return 1
    fi

    total=$(free -m | awk '/^Mem:/ {print $2}')
    available=$(free -m | awk '/^Mem:/ {print $7}')

    if [[ -z "$total" || "$total" -eq 0 ]]; then
        echo "ERRO: nao foi possivel obter dados de memoria" >&2
        return 1
    fi

    usage=$(awk "BEGIN {printf \"%.0f\", (($total - $available) / $total) * 100}")
    echo "${usage}"
}

# Compara o uso de memoria com o limite configurado.
# Retorna 0 se dentro do limite, 1 se ultrapassado.
alertar_memoria() {
    local atual
    atual=$(verificar_memoria)

    if (( atual > MEM_MAX )); then
        return 1
    fi
    return 0
}
