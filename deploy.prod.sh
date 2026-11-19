#!/usr/bin/env bash
# =============================================================================
# EPAA-AA — Enterprise Production Deployment & Lifecycle Management Script
# =============================================================================
# Descripción:
#   Script profesional de orquestación, compilación y despliegue del stack
#   de microservicios EPAA en entorno de producción (Docker Compose + BuildKit).
#   Incluye recolección de basura inteligente de caché (BuildKit Cache GC),
#   verificación de salud, resolución de conflictos y diagnóstico de recursos.
#
# Uso:
#   ./deploy.prod.sh [OPCIONES]
#
# Ejemplos:
#   ./deploy.prod.sh                      # Despliegue estándar con caché inteligente
#   ./deploy.prod.sh --clean-all          # Rebuild nuclear (elimina 100% build cache e imágenes)
#   ./deploy.prod.sh --prune-cache        # Purgar caché de compilación acumulado
#   ./deploy.prod.sh --service documents  # Desplegar un solo microservicio específico
#   ./deploy.prod.sh --status             # Consultar estado de salud y contenedores
#   ./deploy.prod.sh --help               # Ver ayuda completa y opciones
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes y Configuración Global
# -----------------------------------------------------------------------------
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.prod.yml"
readonly PROJECT_NAME="sigepaa-services-production"
readonly PROJECT_LABEL="com.epaa.project=epaa-aa"
readonly ENV_LABEL="com.epaa.env=production"
readonly DEFAULT_CACHE_RETENTION="24h"
readonly HEALTH_WAIT_SECONDS=10

# Metadatos del despliegue
START_TIME=$(date +%s)
FLAG_CLEAN_ALL=false
FLAG_PRUNE_CACHE_ONLY=false
FLAG_NO_CACHE=false
FLAG_STATUS_ONLY=false
FLAG_LOGS_ONLY=false
FLAG_DISK_ONLY=false
TARGET_SERVICE=""
CACHE_RETENTION="${DEFAULT_CACHE_RETENTION}"

# -----------------------------------------------------------------------------
# Detección de Terminal y Definición de Colores
# -----------------------------------------------------------------------------
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  CLR_RESET='\033[0m'
  CLR_BOLD='\033[1m'
  CLR_DIM='\033[2m'
  CLR_RED='\033[0;31m'
  CLR_GREEN='\033[0;32m'
  CLR_YELLOW='\033[1;33m'
  CLR_BLUE='\033[0;34m'
  CLR_MAGENTA='\033[0;35m'
  CLR_CYAN='\033[0;36m'
  CLR_WHITE='\033[1;37m'
else
  CLR_RESET=''
  CLR_BOLD=''
  CLR_DIM=''
  CLR_RED=''
  CLR_GREEN=''
  CLR_YELLOW=''
  CLR_BLUE=''
  CLR_MAGENTA=''
  CLR_CYAN=''
  CLR_WHITE=''
fi

# -----------------------------------------------------------------------------
# Funciones de Logging y UI
# -----------------------------------------------------------------------------
log_info()    { echo -e "${CLR_CYAN}ℹ [INFO]${CLR_RESET} $*"; }
log_step()    { echo -e "\n${CLR_BOLD}${CLR_BLUE}▶ [$1]${CLR_RESET} ${CLR_WHITE}$2${CLR_RESET}"; }
log_success() { echo -e "${CLR_GREEN}✔ [OK]${CLR_RESET} $*"; }
log_warn()    { echo -e "${CLR_YELLOW}⚠ [WARN]${CLR_RESET} $*"; }
log_error()   { echo -e "${CLR_RED}✖ [ERROR]${CLR_RESET} $*" >&2; }

print_banner() {
  echo -e "${CLR_CYAN}======================================================================${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_WHITE}  🚀 EPAA-AA — PLATAFORMA DE PRODUCCIÓN (SIGEPAA)                   ${CLR_RESET}"
  echo -e "${CLR_DIM}  Stack: Docker Compose v2 | BuildKit GC | Microservicios NestJS/Kafka ${CLR_RESET}"
  echo -e "${CLR_CYAN}======================================================================${CLR_RESET}"
}

# -----------------------------------------------------------------------------
# Manejo de Errores y Señales (Traps)
# -----------------------------------------------------------------------------
error_handler() {
  local exit_code=$1
  local line_no=$2
  local last_command=$3
  echo -e "\n${CLR_RED}======================================================================${CLR_RESET}"
  log_error "El despliegue falló en la línea ${line_no} con código de salida ${exit_code}."
  log_error "Comando fallido: ${CLR_YELLOW}${last_command}${CLR_RESET}"
  echo -e "${CLR_RED}======================================================================${CLR_RESET}"
  exit "${exit_code}"
}

trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

format_duration() {
  local seconds=$1
  local min=$((seconds / 60))
  local sec=$((seconds % 60))
  if (( min > 0 )); then
    echo "${min}m ${sec}s"
  else
    echo "${sec}s"
  fi
}

# -----------------------------------------------------------------------------
# Ayuda y Documentación CLI
# -----------------------------------------------------------------------------
show_help() {
  cat << EOF

Uso:
  ./deploy.prod.sh [OPCIONES]

Opciones principales:
  (sin argumentos)        Despliegue estándar en producción:
                          - Detiene stack previo de forma controlada.
                          - Prunea caché viejo de BuildKit (> 24h) evitando acumulación de GB.
                          - Recompila y arranca contenedores en segundo plano.
                          - Verifica salud y estado final.

  -c, --clean-all         Limpieza profunda total (Full Nuclear Rebuild):
                          - Elimina contenedores e imágenes de producción del proyecto.
                          - Purga el 100% de la caché de BuildKit ('docker builder prune -a -f').
                          - Libera las decenas de GBs acumulados por compilaciones previas.
                          - Recompila todo desde cero.

  -p, --prune-cache       Purga inmediata de la caché de BuildKit sin desplegar.
                          Ideal para recuperar espacio en disco (100+ GB) inmediatamente.

  -n, --no-cache          Fuerza 'docker compose build --no-cache' en el despliegue.

  -s, --service <nombre>  Compila y despliega únicamente el microservicio indicado
                          (ej: documents, connection, client-gateway-epaa).

  --status                Muestra el estado actual de contenedores, puertos y memoria.

  -l, --logs              Muestra logs en tiempo real (--tail=100 -f).

  -d, --disk              Muestra reporte detallado del uso de disco en Docker y sistema.

  -h, --help              Muestra este menú de ayuda.

Parámetros avanzados:
  --retention <tiempo>    Ventana de retención para BuildKit cache (defecto: 24h, ej: 48h, 72h).

Ejemplos:
  ./deploy.prod.sh
  ./deploy.prod.sh --clean-all
  ./deploy.prod.sh --prune-cache
  ./deploy.prod.sh --service documents-service
  ./deploy.prod.sh --retention 48h

EOF
}

# -----------------------------------------------------------------------------
# Parseo de Argumentos CLI
# -----------------------------------------------------------------------------
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--clean-all)
        FLAG_CLEAN_ALL=true
        shift
        ;;
      -p|--prune-cache)
        FLAG_PRUNE_CACHE_ONLY=true
        shift
        ;;
      -n|--no-cache)
        FLAG_NO_CACHE=true
        shift
        ;;
      -s|--service)
        if [[ -z "${2:-}" || "$2" =~ ^- ]]; then
          log_error "La opción --service requiere especificar el nombre del servicio."
          exit 1
        fi
        TARGET_SERVICE="$2"
        shift 2
        ;;
      --status)
        FLAG_STATUS_ONLY=true
        shift
        ;;
      -l|--logs)
        FLAG_LOGS_ONLY=true
        shift
        ;;
      -d|--disk)
        FLAG_DISK_ONLY=true
        shift
        ;;
      --retention)
        if [[ -z "${2:-}" || "$2" =~ ^- ]]; then
          log_error "La opción --retention requiere un valor (ej: 24h, 48h)."
          exit 1
        fi
        CACHE_RETENTION="$2"
        shift 2
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        log_error "Opción desconocida: '$1'. Usa './deploy.prod.sh --help' para ver las opciones válidas."
        exit 1
        ;;
    esac
  done
}

# -----------------------------------------------------------------------------
# Pre-flight Checks (Validación de Requisitos)
# -----------------------------------------------------------------------------
check_prerequisites() {
  log_info "Ejecutando verificaciones previas al despliegue..."

  # 1. Verificar binario de Docker
  if ! command -v docker &> /dev/null; then
    log_error "Docker CLI no está instalado en el sistema o no está en el PATH."
    exit 1
  fi

  # 2. Verificar Docker Daemon
  if ! docker info &> /dev/null; then
    log_error "No es posible comunicarse con el daemon de Docker."
    log_warn "Asegúrate de que el servicio esté activo: 'sudo systemctl start docker'"
    log_warn "O verifica permisos del usuario actual en el grupo docker: 'sudo usermod -aG docker \$USER'"
    exit 1
  fi

  # 3. Verificar Docker Compose plugin
  if ! docker compose version &> /dev/null; then
    log_error "Docker Compose (v2 plugin) no está disponible."
    exit 1
  fi

  # 4. Verificar existencia de docker-compose.prod.yml
  if [[ ! -f "$COMPOSE_FILE" ]]; then
    log_error "No se encontró el archivo de composición: ${COMPOSE_FILE}"
    exit 1
  fi

  # 5. Notificar sobre archivos de entorno si existen
  if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    log_info "Archivo de variables globales detectado: .env"
  else
    log_warn "No se encontró archivo '.env' en la raíz. Se utilizarán las variables por defecto."
  fi

  log_success "Requisitos previos validados correctamente."
}

# -----------------------------------------------------------------------------
# Diagnóstico de Uso de Disco
# -----------------------------------------------------------------------------
show_disk_report() {
  echo -e "\n${CLR_BOLD}${CLR_WHITE}=== REPORTE DE USO DE DISCO Y DOCKER ===${CLR_RESET}"
  echo -e "\n${CLR_CYAN}--- Espacio en Sistema de Archivos (/): ---${CLR_RESET}"
  df -h /
  echo -e "\n${CLR_CYAN}--- Resumen de Recursos Docker (docker system df): ---${CLR_RESET}"
  docker system df
  echo ""
}

# -----------------------------------------------------------------------------
# Purga Dedicada de Build Cache (BuildKit)
# -----------------------------------------------------------------------------
purge_build_cache() {
  local mode="${1:-selective}"
  log_info "Administrando caché de compilación de Docker BuildKit..."

  if [[ "$mode" == "all" ]]; then
    log_warn "Purgando TODO el BuildKit Cache acumulado (esto liberará los GBs retenidos)..."
    docker builder prune -a -f
    log_success "BuildKit Cache purgado en su totalidad."
  else
    log_info "Purgando caché huérfana y capas con más de ${CACHE_RETENTION} de antigüedad..."
    # Intentar con filtro de tiempo; si la versión no lo soporta, fallback a prune estándar
    docker builder prune -f --filter "until=${CACHE_RETENTION}" 2>/dev/null || docker builder prune -f
    log_success "Caché obsoleto de BuildKit depurado con éxito."
  fi
}

# -----------------------------------------------------------------------------
# Paso 1: Detención de Stack y Resolución de Conflictos
# -----------------------------------------------------------------------------
stop_and_cleanup_conflicts() {
  log_step "1/5" "Deteniendo stack actual y resolviendo contenedores huérfanos..."

  # Detener stack orquestado
  docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down --remove-orphans --timeout 20 || true

  # Detectar y remover contenedores que usen los nombres reservados del proyecto
  # para evitar el clásico error "Conflict. The container name is already in use by container..."
  log_info "Verificando nombres reservados de contenedores en docker-compose..."
  local reserved_containers
  reserved_containers=$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" config --format json 2>/dev/null | grep -o '"container_name": "[^"]*"' | cut -d'"' -f4 || true)

  if [[ -n "$reserved_containers" ]]; then
    for cname in $reserved_containers; do
      if docker ps -a --format '{{.Names}}' | grep -qx "$cname"; then
        log_warn "Removiendo contenedor conflictivo existente: ${cname}"
        docker rm -f "$cname" >/dev/null 2>&1 || true
      fi
    done
  fi

  log_success "Stack detenido y conflictos de nombres resueltos."
}

# -----------------------------------------------------------------------------
# Paso 2: Limpieza de Imágenes y Gestión de BuildKit Cache
# -----------------------------------------------------------------------------
cleanup_images_and_cache() {
  log_step "2/5" "Gestionando imágenes y caché de compilación (BuildKit)..."

  if [[ "$FLAG_CLEAN_ALL" == true ]]; then
    log_warn "[--clean-all activo] Eliminando imágenes del proyecto y purgando BuildKit Cache..."
    
    # 1. Eliminar imágenes del proyecto
    local project_images
    project_images=$(docker images --filter "label=$PROJECT_LABEL" -q || true)
    if [[ -n "$project_images" ]]; then
      log_info "Eliminando imágenes asociadas a ${PROJECT_LABEL}..."
      docker rmi -f $project_images >/dev/null 2>&1 || true
      log_success "Imágenes del proyecto eliminadas."
    else
      log_info "No hay imágenes registradas para el label ${PROJECT_LABEL}."
    fi

    # 2. Purgar todo el build cache de BuildKit
    purge_build_cache "all"

  else
    log_info "Limpiando imágenes huérfanas (dangling) del proyecto..."
    docker image prune -f --filter "label=$PROJECT_LABEL" >/dev/null 2>&1 || true
    log_success "Imágenes dangling eliminadas."

    # 3. Limpieza de caché BuildKit con política de retención automática
    purge_build_cache "selective"
  fi
}

# -----------------------------------------------------------------------------
# Paso 3: Limpieza de Volúmenes Anónimos No Utilizados
# -----------------------------------------------------------------------------
cleanup_volumes() {
  log_step "3/5" "Limpiando volúmenes anónimos e imágenes intermedias sin uso..."
  docker volume prune -f >/dev/null 2>&1 || true
  log_success "Volúmenes anónimos sin usar depurados."
}

# -----------------------------------------------------------------------------
# Paso 4: Compilación y Despliegue de Servicios
# -----------------------------------------------------------------------------
build_and_deploy() {
  local target_desc="todos los microservicios"
  if [[ -n "$TARGET_SERVICE" ]]; then
    target_desc="servicio específico: ${TARGET_SERVICE}"
  fi

  log_step "4/5" "Compilando y desplegando en producción (${target_desc})..."

  local build_opts=()
  if [[ "$FLAG_NO_CACHE" == true ]]; then
    build_opts+=("--no-cache")
    log_warn "Flag --no-cache detectado: compilación forzada sin caché."
  fi

  # Habilitar BuildKit explícitamente para mayor rendimiento y control
  export DOCKER_BUILDKIT=1
  export COMPOSE_DOCKER_CLI_BUILD=1

  if [[ -n "$TARGET_SERVICE" ]]; then
    # Despliegue de un solo servicio
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" build "${build_opts[@]}" "$TARGET_SERVICE"
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d --remove-orphans "$TARGET_SERVICE"
  else
    # Despliegue de todo el stack
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d --build --remove-orphans "${build_opts[@]}"
  fi

  log_success "Contenedores iniciados en modo demonio (-d)."
}

# -----------------------------------------------------------------------------
# Paso 5: Verificación de Salud y Estado
# -----------------------------------------------------------------------------
verify_stack_health() {
  log_step "5/5" "Verificando estado de salud de los servicios..."
  log_info "Esperando ${HEALTH_WAIT_SECONDS}s para estabilización y healthchecks..."
  sleep "${HEALTH_WAIT_SECONDS}"

  echo -e "\n${CLR_CYAN}--- Estado actual de contenedores: ---${CLR_RESET}"
  docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps

  # Verificar si algún contenedor se detuvo inesperadamente
  local failed_containers
  failed_containers=$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps --filter "status=exited" -q || true)

  if [[ -n "$failed_containers" ]]; then
    log_warn "¡Atención! Uno o más contenedores se detuvieron inmediatamente tras el despliegue:"
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps --filter "status=exited"
    log_info "Mostrando últimas líneas de log de los contenedores fallidos:"
    for cid in $failed_containers; do
      local cname
      cname=$(docker inspect --format '{{.Name}}' "$cid" 2>/dev/null | tr -d '/')
      echo -e "\n${CLR_RED}=== Logs recientes de ${cname} ===${CLR_RESET}"
      docker logs --tail=15 "$cid" 2>&1 || true
    done
  else
    log_success "Todos los contenedores se encuentran levantados y en ejecución."
  fi
}

# -----------------------------------------------------------------------------
# Resumen Final y Consejos Operativos
# -----------------------------------------------------------------------------
show_summary() {
  local end_time
  end_time=$(date +%s)
  local elapsed=$((end_time - START_TIME))
  local elapsed_formatted
  elapsed_formatted=$(format_duration "$elapsed")

  echo -e "\n${CLR_CYAN}======================================================================${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_GREEN}✔ DESPLIEGUE COMPLETADO EXITOSAMENTE en ${elapsed_formatted}${CLR_RESET}"
  echo -e "${CLR_CYAN}======================================================================${CLR_RESET}"
  echo -e ""
  echo -e "${CLR_WHITE}${CLR_BOLD}Comandos útiles de operación:${CLR_RESET}"
  echo -e "  ${CLR_CYAN}• Ver logs en tiempo real:${CLR_RESET}   docker compose -f ${COMPOSE_FILE} -p ${PROJECT_NAME} logs -f --tail=50"
  echo -e "  ${CLR_CYAN}• Logs de un servicio:${CLR_RESET}       docker compose -f ${COMPOSE_FILE} -p ${PROJECT_NAME} logs -f --tail=50 <servicio>"
  echo -e "  ${CLR_CYAN}• Reiniciar un servicio:${CLR_RESET}     docker compose -f ${COMPOSE_FILE} -p ${PROJECT_NAME} restart <servicio>"
  echo -e "  ${CLR_CYAN}• Consultar estado:${CLR_RESET}          ./deploy.prod.sh --status"
  echo -e "  ${CLR_CYAN}• Purgar caché acumulado:${CLR_RESET}    ./deploy.prod.sh --prune-cache"
  echo -e "  ${CLR_CYAN}• Despliegue limpio total:${CLR_RESET}   ./deploy.prod.sh --clean-all"
  echo -e ""
}

# -----------------------------------------------------------------------------
# Flujo Principal (Main)
# -----------------------------------------------------------------------------
main() {
  parse_arguments "$@"

  print_banner

  # Subrutinas de sólo lectura o consulta
  if [[ "$FLAG_STATUS_ONLY" == true ]]; then
    check_prerequisites
    echo -e "\n${CLR_BOLD}${CLR_WHITE}=== ESTADO DEL STACK DE PRODUCCIÓN ===${CLR_RESET}"
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps
    exit 0
  fi

  if [[ "$FLAG_LOGS_ONLY" == true ]]; then
    check_prerequisites
    log_info "Mostrando logs del stack (Ctrl+C para salir)..."
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs -f --tail=100
    exit 0
  fi

  if [[ "$FLAG_DISK_ONLY" == true ]]; then
    check_prerequisites
    show_disk_report
    exit 0
  fi

  if [[ "$FLAG_PRUNE_CACHE_ONLY" == true ]]; then
    check_prerequisites
    log_info "Modo purga de BuildKit Cache solicitado..."
    show_disk_report
    purge_build_cache "all"
    show_disk_report
    log_success "Purga de caché completada."
    exit 0
  fi

  # Flujo de Despliegue Completo
  check_prerequisites
  stop_and_cleanup_conflicts
  cleanup_images_and_cache
  cleanup_volumes
  build_and_deploy
  verify_stack_health
  show_summary
}

main "$@"
