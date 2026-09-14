#!/bin/bash
# =============================================================================
# Modulo de monitorizacao de CPU
# =============================================================================

# Devolve a percentagem actual de uso de CPU (0-100).
# Usa vmstat como metodo primario e top como fallback.
verificar_cpu() {
    local cpu_usage=0

    if command -v vmstat &>/dev/null; then
        # vmstat: coluna 'id' (idle) - subtrair de 100
        cpu_usage=$(vmstat 1 2 | tail -1 | awk '{print 100 - $15}')
    elif command -v top &>/dev/null; then
        # top: linha "Cpu(s)" - extrair valor de idle
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
    else
        echo "ERRO: nenhum comando disponivel para medir CPU (vmstat/top)" >&2
        return 1
    fi

    # Arredondar para inteiro
    printf "%.0f" "${cpu_usage}"
}

# Compara o uso de CPU com o limite configurado.
# Retorna 0 se dentro do limite, 1 se ultrapassado.
alertar_cpu() {
    local uso atual
    uso=$(verificar_cpu)
    atual=${uso:-0}

    if (( atual > CPU_MAX )); then
        return 1
    fi
    return 0
}
