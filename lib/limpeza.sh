#!/bin/bash
# =============================================================================
# Modulo de Limpeza de Memoria RAM
# Limpa caches e liberta memoria quando o uso ultrapassa o limite.
# =============================================================================

# Sincroniza blocos de dados pendentes para o disco.
_sincronizar_dados() {
    sync 2>/dev/null || true
}

# Limpa caches do kernel via /proc/sys/vm/drop_caches.
# Valores: 1=pagecache, 2=dentries+inodes, 3=tudo
_limpar_caches() {
    if [[ -w /proc/sys/vm/drop_caches ]]; then
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    fi
}

# Elimina ficheiros temporarios do sistema (seguro).
_limpar_temporarios() {
    # Limpar /tmp de ficheiros com mais de 2 dias
    find /tmp -type f -atime +2 -delete 2>/dev/null || true

    # Limpar cache do apt (se existir)
    if command -v apt-get &>/dev/null; then
        apt-get clean 2>/dev/null || true
    fi

    # Limpar cache do dnf/yum (se existir)
    if command -v dnf &>/dev/null; then
        dnf clean all 2>/dev/null || true
    elif command -v yum &>/dev/null; then
        yum clean all 2>/dev/null || true
    fi

    # Limpar logs de sistema antigos (mais de 7 dias, excepto os nossos)
    find /var/log -name "*.gz" -mtime +7 -delete 2>/dev/null || true
    find /var/log -name "*.old" -mtime +7 -delete 2>/dev/null || true
}

# Mostra processos que mais consomem memoria.
_top_processos_memoria() {
    ps aux --sort=-%mem 2>/dev/null | head -6 | tail -5
}

# Funcao principal de limpeza de memoria.
# Retorna 0 se limpeza bem sucedida, 1 se erro.
limpar_memoria() {
    local uso_antes uso_depois

    uso_antes=$(verificar_memoria)

    registrar "INFO" "A limpar memoria... (uso antes: ${uso_antes}%)"

    # Passo 1: Sincronizar dados pendentes para disco
    _sincronizar_dados

    # Passo 2: Limpar caches do kernel
    _limpar_caches

    # Passo 3: Limpar ficheiros temporarios
    _limpar_temporarios

    # Esperar um momento para o sistema actualizar
    sleep 2

    uso_depois=$(verificar_memoria)

    # Calcular diferenca
    local libertado=$(( uso_antes - uso_depois ))

    registrar "INFO" "Limpeza concluida: ${uso_antes}% -> ${uso_depois}% (libertados ~${libertado}%)"
    registrar "INFO" "Top processos por uso de memoria:"
    ps aux --sort=-%mem 2>/dev/null | head -6 | tail -5 | while IFS= read -r linha; do
        registrar "INFO" "  ${linha}"
    done

    return 0
}

# Verifica se e necessario limpar memoria e executa se sim.
# Retorna 0 se nao precisou de limpar, 0 se limpou com sucesso.
verificar_e_limpar_memoria() {
    local uso
    uso=$(verificar_memoria)

    if (( uso >= MEM_LIMPAR )); then
        registrar "ALERTA" "Uso de memoria (${uso}%) ultrapassa limite de limpeza (${MEM_LIMPAR}%). A iniciar limpeza..."
        limpar_memoria
        return $?
    fi

    return 0
}
