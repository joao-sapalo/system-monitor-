#!/bin/bash
# =============================================================================
# Modulo de monitorizacao de Servicos Systemd
# =============================================================================

# Verifica se os servicos listados em SERVICOS_MONITORAR estao activos.
# Retorna 0 se todos activos, 1 se algum estiver parado.
verificar_servicos() {
    local servicos_parados=()
    local total=0

    if ! command -v systemctl &>/dev/null; then
        echo "ERRO: comando 'systemctl' nao encontrado (systemd necessario)" >&2
        return 1
    fi

    for servico in ${SERVICOS_MONITORAR}; do
        ((total++))
        if ! systemctl is-active --quiet "${servico}" 2>/dev/null; then
            servicos_parados+=("${servico}")
        fi
    done

    if [[ ${#servicos_parados[@]} -gt 0 ]]; then
        # Guardar lista de parados numa variavel global para o chamador usar
        SERVICOS_PARADOS="${servicos_parados[*]}"
        return 1
    fi

    SERVICOS_PARADOS=""
    return 0
}
