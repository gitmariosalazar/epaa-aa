#!/bin/bash
# =============================================================================
# EPAA-AA — Kafka · Script de Deploy en Desarrollo
#
# Uso:
#   bash deploy.dev.sh              → Deploy estándar (pull imagen + restart)
#   bash deploy.dev.sh --reset-data → ⚠️  Elimina TODOS los datos de Kafka Dev y
#                                        hace deploy limpio (úsalo con cuidado)
#
# Requisitos:
#   - Docker >= 24.x con el plugin "compose" instalado
#   - El archivo .env.dev debe existir en este mismo directorio con CLUSTER_ID
#   - La red Docker "epaa-network-dev" debe existir previamente
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURACIÓN
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.dev.yml"
PROJECT_NAME="kafka-epaa-development"
SERVICE_NAME="kafka-epaa-dev"
CONTAINER_NAME="kafka-epaa-dev"
VOLUME_NAME="${PROJECT_NAME}_kafka-epaa-data-dev" # Docker compose añade el nombre del proyecto como prefijo a los volumenes
REQUIRED_NETWORK="epaa-network-dev"
HEALTH_TIMEOUT=120
HEALTH_INTERVAL=5

# ─────────────────────────────────────────────────────────────────────────────
# COLORES
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}  ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}  ✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}  ⚠️  $1${NC}"; }
log_error()   { echo -e "${RED}  ❌ $1${NC}"; }
log_step()    { echo -e "\n${CYAN}${BOLD}[$1] $2${NC}"; }

abort() {
  log_error "Deploy abortado: $1"
  exit 1
}

echo -e ""
echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║   🐦‍⬛  EPAA-AA · Kafka · Desarrollo     ║${NC}"
echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo -e "${YELLOW}  Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')${NC}"
echo -e ""

log_step "0/6" "Pre-validaciones del entorno"

if ! docker compose version &>/dev/null; then
  abort "Docker Compose v2 no está disponible."
fi
log_info "Docker Compose v2 detectado"

ENV_FILE="${SCRIPT_DIR}/.env.dev"
if [ ! -f "$ENV_FILE" ]; then
  abort "No se encontró el archivo .env.dev en ${SCRIPT_DIR}."
fi

if ! docker network inspect "$REQUIRED_NETWORK" &>/dev/null; then
  abort "La red Docker '${REQUIRED_NETWORK}' no existe. Créala con:\n  docker network create ${REQUIRED_NETWORK}"
fi
log_success "Pre-validaciones superadas"

RESET_DATA=false
if [[ "${1:-}" == "--reset-data" ]]; then
  RESET_DATA=true
  echo -e ""
  echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}${BOLD}║  ⚠️  ADVERTENCIA: --reset-data ACTIVADO          ║${NC}"
  echo -e "${RED}${BOLD}║                                                  ║${NC}"
  echo -e "${RED}${BOLD}║  Esto eliminará PERMANENTEMENTE el volumen:      ║${NC}"
  echo -e "${RED}${BOLD}║  → ${VOLUME_NAME}                    ║${NC}"
  echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
  echo -e ""
  read -r -p "  Escribe 'CONFIRMAR' para continuar: " CONFIRM
  if [[ "$CONFIRM" != "CONFIRMAR" ]]; then
    log_info "Operación cancelada."
    exit 0
  fi
fi

log_step "1/6" "Deteniendo stack actual y eliminando huérfanos"
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down --remove-orphans || true
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  docker rm -f "$CONTAINER_NAME"
fi
log_success "Stack detenido"

log_step "2/6" "Gestión del volumen de datos"
if [ "$RESET_DATA" = true ]; then
  log_warning "Eliminando volumen de datos: ${VOLUME_NAME}"
  if docker volume inspect "$VOLUME_NAME" &>/dev/null; then
    docker volume rm "$VOLUME_NAME"
    log_success "Volumen eliminado."
  fi
fi

log_step "3/6" "Actualizando imagen Docker de Kafka"
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" pull
log_success "Imagen lista"

log_step "4/6" "Levantando el stack de Kafka"
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d --remove-orphans --force-recreate
log_success "Contenedor iniciado"

log_step "5/6" "Verificando estado de salud del broker"
ELAPSED=0
while true; do
  HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "not_found")
  case "$HEALTH" in
    healthy) log_success "Kafka está HEALTHY"; break ;;
    starting) echo -ne "\r${YELLOW}  ⏳ Iniciando... ${ELAPSED}s${NC}" ;;
    unhealthy) abort "Kafka reportó UNHEALTHY." ;;
    not_found) abort "Contenedor no encontrado." ;;
    *) echo -ne "\r${YELLOW}  ⏳ Estado: ${HEALTH}${NC}" ;;
  esac
  if [ "$ELAPSED" -ge "$HEALTH_TIMEOUT" ]; then abort "Timeout alcanzado."; fi
  sleep "$HEALTH_INTERVAL"
  ELAPSED=$((ELAPSED + HEALTH_INTERVAL))
done

log_step "6/6" "Estado final"
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps

echo -e "\n${GREEN}${BOLD}   ✅  Deploy completado exitosamente${NC}\n"
