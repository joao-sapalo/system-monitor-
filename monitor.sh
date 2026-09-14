#!/bin/bash
# =============================================================================
# Monitor de Sistema - Script Principal
# Verifica CPU, memoria, disco e servicos, registando alertas em log.
# =============================================================================
set -euo pipefail

# --- Diretorias e caminhos ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
ALERTAS_DIR="${SCRIPT_DIR}/alertas"

# --- Carregar configuracao ---
if [[ ! -f "${SCRIPT_DIR}/config.conf" ]]; then
    echo "ERRO: ficheiro config.conf nao encontrado em ${SCRIPT_DIR}" >&2
    exit 1
fi
# shellcheck source=config.conf
source "${SCRIPT_DIR}/config.conf"

# Garantir que o diretorio de logs existe
mkdir -p "${SCRIPT_DIR}/${LOG_DIR}"

# --- Carregar modulos ---
for modulo in cpu memoria disco servicos limpeza; do
    if [[ ! -f "${LIB_DIR}/${modulo}.sh" ]]; then
        echo "ERRO: modulo ${LIB_DIR}/${modulo}.sh nao encontrado" >&2
        exit 1
    fi
    # shellcheck source=lib/cpu.sh
    source "${LIB_DIR}/${modulo}.sh"
done

# Carregar modulo de notificacao
if [[ ! -f "${ALERTAS_DIR}/notificar.sh" ]]; then
    echo "ERRO: modulo ${ALERTAS_DIR}/notificar.sh nao encontrado" >&2
    exit 1
fi
# shellcheck source=alertas/notificar.sh
source "${ALERTAS_DIR}/notificar.sh"

# --- Variaveis globais ---
VERBOSE=false
CHECK_CPU=false
CHECK_MEM=false
CHECK_DISK=false
CHECK_SERV=false

# =============================================================================
# Funcoes auxiliares
# =============================================================================

# Registra mensagem no ficheiro de log com timestamp.
registrar() {
    local nivel="$1"
    local mensagem="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local entrada="[${timestamp}] [${nivel}] ${mensagem}"

    echo "${entrada}" >> "${SCRIPT_DIR}/${LOG_FILE}"

    if [[ "${VERBOSE}" == "true" ]]; then
        echo "${entrada}"
    fi
}

# Registra mensagem de erro e termina.
erro_fatal() {
    echo "ERRO: $1" >&2
    registrar "ERRO" "$1"
    exit 1
}

# Verifica se os comandos necessarios estao disponiveis.
verificar_dependencias() {
    local comandos=("df" "free" "systemctl" "curl")
    local em_falta=()

    for cmd in "${comandos[@]}"; do
        if ! command -v "${cmd}" &>/dev/null; then
            em_falta+=("${cmd}")
        fi
    done

    if [[ ${#em_falta[@]} -gt 0 ]]; then
        erro_fatal "Comandos em falta: ${em_falta[*]}. Instale-os antes de continuar."
    fi
}

# Rotação de logs: apaga registos com mais de N dias.
rotacao_logs() {
    local logfile="${SCRIPT_DIR}/${LOG_FILE}"

    if [[ ! -f "${logfile}" ]]; then
        return 0
    fi

    # Mover log actual para arquivo com data
    local arquivo="${logfile}.$(date '+%Y%m%d')"
    if [[ ! -f "${arquivo}" ]]; then
        cp "${logfile}" "${arquivo}"
        > "${logfile}"
        registrar "INFO" "Log anterior arquivado em ${arquivo}"
    fi

    # Eliminar arquivos com mais de N dias
    find "${SCRIPT_DIR}/${LOG_DIR}" -name "monitor.log.*" -mtime "+${LOG_DIAS_RETENCAO}" -delete 2>/dev/null || true
}

# =============================================================================
# Funcoes de verificacao
# =============================================================================

executar_verificacao_cpu() {
    registrar "INFO" "A iniciar verificacao de CPU..."

    local uso
    uso=$(verificar_cpu)
    registrar "INFO" "Uso de CPU: ${uso}% (limite: ${CPU_MAX}%)"

    if ! alertar_cpu; then
        local msg="Uso de CPU elevado: ${uso}% (limite: ${CPU_MAX}%)"
        registrar "ALERTA" "${msg}"
        notificar "Alerta de CPU" "${msg}"
    fi
}

executar_verificacao_memoria() {
    registrar "INFO" "A iniciar verificacao de memoria..."

    local uso
    uso=$(verificar_memoria)
    registrar "INFO" "Uso de memoria: ${uso}% (limite: ${MEM_MAX}%)"

    if ! alertar_memoria; then
        local msg="Uso de memoria elevado: ${uso}% (limite: ${MEM_MAX}%)"
        registrar "ALERTA" "${msg}"
        notificar "Alerta de Memoria" "${msg}"
    fi

    # Limpar memoria se ultrapassar o limite de limpeza
    if (( uso >= MEM_LIMPAR )); then
        registrar "INFO" "Memoria acima de ${MEM_LIMPAR}% - a iniciar limpeza..."
        local antes="${uso}"
        verificar_e_limpar_memoria
        local depois
        depois=$(verificar_memoria)
        registrar "INFO" "Limpeza concluida: ${antes}% -> ${depois}%"
    fi
}

executar_verificacao_disco() {
    registrar "INFO" "A iniciar verificacao de disco..."

    local resultado
    if ! resultado=$(verificar_disco); then
        registrar "ALERTA" "${resultado}"
        notificar "Alerta de Disco" "${resultado}"
    else
        registrar "INFO" "Uso de disco dentro dos limites."
    fi
}

executar_verificacao_servicos() {
    registrar "INFO" "A iniciar verificacao de servicos..."

    if ! verificar_servicos; then
        local msg="Servicos parados: ${SERVICOS_PARADOS}"
        registrar "ALERTA" "${msg}"
        notificar "Alerta de Servicos" "${msg}"
    else
        registrar "INFO" "Todos os servicos estao activos."
    fi
}

# =============================================================================
# Menu de ajuda
# =============================================================================

mostrar_ajuda() {
    cat <<EOF
Uso: $(basename "$0") [OPCOES]

Monitor de Sistema - verifica CPU, memoria, disco e servicos.

Opcoes:
  -a          Verificacao completa (por omissao)
  -c          Verificar apenas CPU
  -m          Verificar apenas memoria
  -d          Verificar apenas disco
  -s          Verificar apenas servicos
  -v          Modo verbose (mostra output no terminal)
  -h          Mostra esta ajuda

Exemplos:
  $(basename "$0")            # Verificacao completa
  $(basename "$0") -c -v      # Verificar CPU, modo verbose
  $(basename "$0") -m -d      # Verificar memoria e disco
EOF
}

# =============================================================================
# Parsing de argumentos
# =============================================================================

parsear_opcoes() {
    # Se nenhum argumento, executar tudo
    if [[ $# -eq 0 ]]; then
        CHECK_CPU=true
        CHECK_MEM=true
        CHECK_DISK=true
        CHECK_SERV=true
        return
    fi

    while getopts "acmdsvh" opt; do
        case "${opt}" in
            a) CHECK_CPU=true; CHECK_MEM=true; CHECK_DISK=true; CHECK_SERV=true ;;
            c) CHECK_CPU=true ;;
            m) CHECK_MEM=true ;;
            d) CHECK_DISK=true ;;
            s) CHECK_SERV=true ;;
            v) VERBOSE=true ;;
            h) mostrar_ajuda; exit 0 ;;
            *) mostrar_ajuda; exit 1 ;;
        esac
    done
}

# =============================================================================
# Programa principal
# =============================================================================

main() {
    parsear_opcoes "$@"
    verificar_dependencias
    rotacao_logs

    registrar "INFO" "=== Inicio da verificacao do monitor de sistema ==="

    local erros=0

    if [[ "${CHECK_CPU}" == "true" ]]; then
        executar_verificacao_cpu || ((erros++))
    fi

    if [[ "${CHECK_MEM}" == "true" ]]; then
        executar_verificacao_memoria || ((erros++))
    fi

    if [[ "${CHECK_DISK}" == "true" ]]; then
        executar_verificacao_disco || ((erros++))
    fi

    if [[ "${CHECK_SERV}" == "true" ]]; then
        executar_verificacao_servicos || ((erros++))
    fi

    if (( erros > 0 )); then
        registrar "ALERTA" "Verificacao concluida com ${erros} alerta(s)."
    else
        registrar "INFO" "Verificacao concluida sem alertas."
    fi

    registrar "INFO" "=== Fim da verificacao ==="
}

main "$@"
