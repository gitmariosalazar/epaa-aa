#!/bin/bash
# =============================================================================
# EPAA-AA — Kafka · Script de Deploy en Producción
#
# Uso:
#   bash deploy.prod.sh              → Deploy estándar (pull imagen + restart)
#   bash deploy.prod.sh --reset-data → ⚠️  Elimina TODOS los datos de Kafka y
#                                        hace deploy limpio (úsalo con cuidado)
#
# Requisitos:
#   - Docker >= 24.x con el plugin "compose" instalado
#   - El archivo .env debe existir en este mismo directorio con CLUSTER_ID
#   - La red Docker "epaa-network" debe existir previamente
# =============================================================================

set -euo pipefail  # -e: falla ante error, -u: falla ante variable sin definir,
                   # -o pipefail: falla si cualquier parte de un pipe falla

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURACIÓN
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
PROJECT_NAME="kafka-epaa-production"
SERVICE_NAME="kafka-epaa-prod"
CONTAINER_NAME="kafka-epaa-prod"
VOLUME_NAME="kafka-epaa-prod-data"
REQUIRED_NETWORK="epaa-network"
HEALTH_TIMEOUT=120   # segundos máximos esperando a que Kafka esté healthy
HEALTH_INTERVAL=5    # segundos entre cada verificación de salud

# ─────────────────────────────────────────────────────────────────────────────
# COLORES
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─────────────────────────────────────────────────────────────────────────────
# FUNCIONES UTILITARIAS
# ─────────────────────────────────────────────────────────────────────────────
log_info()    { echo -e "${BLUE}  ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}  ✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}  ⚠️  $1${NC}"; }
log_error()   { echo -e "${RED}  ❌ $1${NC}"; }
log_step()    { echo -e "\n${CYAN}${BOLD}[$1] $2${NC}"; }

abort() {
  log_error "Deploy abortado: $1"
  exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# HEADER
# ─────────────────────────────────────────────────────────────────────────────
echo -e ""
echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║   🐦‍⬛  EPAA-AA · Kafka · Producción     ║${NC}"
echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo -e "${YELLOW}  Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')${NC}"
echo -e ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 0: Pre-validaciones (fallar rápido antes de tocar nada)
# ─────────────────────────────────────────────────────────────────────────────
log_step "0/6" "Pre-validaciones del entorno"

# Verificar que docker compose (v2) está disponible
if ! docker compose version &>/dev/null; then
  abort "Docker Compose v2 no está disponible. Instala el plugin 'docker-compose-plugin'."
fi
log_info "Docker Compose v2 detectado: $(docker compose version --short)"

# Verificar que el archivo .env existe y tiene CLUSTER_ID
ENV_FILE="${SCRIPT_DIR}/.env"
if [ ! -f "$ENV_FILE" ]; then
  abort "No se encontró el archivo .env en ${SCRIPT_DIR}. Es obligatorio para CLUSTER_ID."
fi
if ! grep -q "^CLUSTER_ID=" "$ENV_FILE"; then
  abort "El archivo .env no contiene la variable CLUSTER_ID. Kafka no puede iniciar sin ella."
fi
log_info "Archivo .env encontrado con CLUSTER_ID definido"

# Verificar que la red Docker requerida existe
if ! docker network inspect "$REQUIRED_NETWORK" &>/dev/null; then
  abort "La red Docker '${REQUIRED_NETWORK}' no existe. Créala con:\n  docker network create ${REQUIRED_NETWORK}"
fi
log_info "Red Docker '${REQUIRED_NETWORK}' verificada"

log_success "Pre-validaciones superadas"

# ─────────────────────────────────────────────────────────────────────────────
# MODO --reset-data: advertencia y confirmación explícita
# ─────────────────────────────────────────────────────────────────────────────
RESET_DATA=false
if [[ "${1:-}" == "--reset-data" ]]; then
  RESET_DATA=true
  echo -e ""
  echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}${BOLD}║  ⚠️  ADVERTENCIA: --reset-data ACTIVADO          ║${NC}"
  echo -e "${RED}${BOLD}║                                                  ║${NC}"
  echo -e "${RED}${BOLD}║  Esto eliminará PERMANENTEMENTE el volumen:      ║${NC}"
  echo -e "${RED}${BOLD}║  → ${VOLUME_NAME}                    ║${NC}"
  echo -e "${RED}${BOLD}║                                                  ║${NC}"
  echo -e "${RED}${BOLD}║  Todos los topics, offsets y mensajes se         ║${NC}"
  echo -e "${RED}${BOLD}║  perderán para siempre. Esta acción es           ║${NC}"
  echo -e "${RED}${BOLD}║  IRREVERSIBLE.                                   ║${NC}"
  echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
  echo -e ""
  read -r -p "  Escribe 'CONFIRMAR' para continuar: " CONFIRM
  if [[ "$CONFIRM" != "CONFIRMAR" ]]; then
    log_info "Operación cancelada por el usuario. Ningún dato fue modificado."
    exit 0
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# PASO 1: Detener stack actual y eliminar contenedores huérfanos
# ─────────────────────────────────────────────────────────────────────────────
log_step "1/6" "Deteniendo stack actual y eliminando huérfanos"

docker compose \
  -f "$COMPOSE_FILE" \
  -p "$PROJECT_NAME" \
  down --remove-orphans || true

# Forzar eliminación de contenedor con nombre reservado si existe fuera de este stack
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  log_warning "Contenedor '${CONTAINER_NAME}' encontrado fuera del stack. Eliminando..."
  docker rm -f "$CONTAINER_NAME"
fi

log_success "Stack detenido y huérfanos eliminados"

# ─────────────────────────────────────────────────────────────────────────────
# PASO 2: (Condicional) Eliminar volumen de datos
# ─────────────────────────────────────────────────────────────────────────────
log_step "2/6" "Gestión del volumen de datos"

if [ "$RESET_DATA" = true ]; then
  log_warning "Eliminando volumen de datos: ${VOLUME_NAME}"
  if docker volume inspect "$VOLUME_NAME" &>/dev/null; then
    docker volume rm "$VOLUME_NAME"
    log_success "Volumen eliminado. Se creará vacío en el siguiente paso."
  else
    log_info "El volumen no existía, no hay nada que eliminar."
  fi
else
  # Verificar que el volumen existe (si no, se creará automáticamente)
  if docker volume inspect "$VOLUME_NAME" &>/dev/null; then
    log_success "Volumen '${VOLUME_NAME}' existente detectado — datos preservados ✓"
  else
    log_info "Volumen '${VOLUME_NAME}' no existe, Docker lo creará automáticamente."
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# PASO 3: Pull de la imagen más reciente con el tag fijo
# ─────────────────────────────────────────────────────────────────────────────
log_step "3/6" "Actualizando imagen Docker de Kafka"

# Obtener el tag de imagen directamente del compose file
KAFKA_IMAGE=$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" config \
  | grep 'image:' \
  | head -1 \
  | awk '{print $2}')

log_info "Imagen configurada: ${KAFKA_IMAGE}"
docker pull "$KAFKA_IMAGE"
log_success "Imagen actualizada"

# ─────────────────────────────────────────────────────────────────────────────
# PASO 4: Levantar el stack
# ─────────────────────────────────────────────────────────────────────────────
log_step "4/6" "Levantando el stack de Kafka"

docker compose \
  -f "$COMPOSE_FILE" \
  -p "$PROJECT_NAME" \
  up -d \
  --remove-orphans \
  --force-recreate

log_success "Contenedor iniciado"

# ─────────────────────────────────────────────────────────────────────────────
# PASO 5: Esperar a que el healthcheck pase (polling activo)
# ─────────────────────────────────────────────────────────────────────────────
log_step "5/6" "Verificando estado de salud del broker"
log_info "Esperando hasta ${HEALTH_TIMEOUT}s a que Kafka esté 'healthy'..."

ELAPSED=0
while true; do
  HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "not_found")

  case "$HEALTH" in
    healthy)
      log_success "Kafka está HEALTHY después de ${ELAPSED}s"
      break
      ;;
    starting)
      echo -ne "\r${YELLOW}  ⏳ Iniciando... ${ELAPSED}s / ${HEALTH_TIMEOUT}s${NC}"
      ;;
    unhealthy)
      echo ""
      log_error "Kafka reportó UNHEALTHY. Mostrando últimos logs:"
      docker logs --tail=30 "$CONTAINER_NAME"
      abort "El contenedor no está saludable. Revisa los logs anteriores."
      ;;
    not_found)
      echo ""
      abort "El contenedor '${CONTAINER_NAME}' no fue encontrado. ¿Falló el paso de deploy?"
      ;;
    *)
      echo -ne "\r${YELLOW}  ⏳ Estado: ${HEALTH} (${ELAPSED}s / ${HEALTH_TIMEOUT}s)${NC}"
      ;;
  esac

  if [ "$ELAPSED" -ge "$HEALTH_TIMEOUT" ]; then
    echo ""
    log_error "Timeout alcanzado (${HEALTH_TIMEOUT}s). Mostrando últimos logs:"
    docker logs --tail=50 "$CONTAINER_NAME"
    abort "Kafka no alcanzó estado 'healthy' a tiempo."
  fi

  sleep "$HEALTH_INTERVAL"
  ELAPSED=$((ELAPSED + HEALTH_INTERVAL))
done

# ─────────────────────────────────────────────────────────────────────────────
# PASO 6: Resumen final del estado
# ─────────────────────────────────────────────────────────────────────────────
log_step "6/6" "Estado final del stack"

docker compose \
  -f "$COMPOSE_FILE" \
  -p "$PROJECT_NAME" \
  ps

# ─────────────────────────────────────────────────────────────────────────────
# FOOTER
# ─────────────────────────────────────────────────────────────────────────────
echo -e ""
echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   ✅  Deploy completado exitosamente     ║${NC}"
echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo -e ""
echo -e "${YELLOW}${BOLD}Comandos útiles:${NC}"
echo -e "  ${CYAN}Logs en tiempo real:${NC}"
echo -e "    docker logs -f ${CONTAINER_NAME} --tail=100"
echo -e ""
echo -e "  ${CYAN}Listar topics existentes:${NC}"
echo -e "    docker exec ${CONTAINER_NAME} kafka-topics --bootstrap-server localhost:9192 --list"
echo -e ""
echo -e "  ${CYAN}Crear un topic manualmente:${NC}"
echo -e "    docker exec ${CONTAINER_NAME} kafka-topics --bootstrap-server localhost:9192 \\"
echo -e "      --create --topic <nombre> --partitions 6 --replication-factor 1"
echo -e ""
echo -e "  ${CYAN}Estado del grupo de consumidores:${NC}"
echo -e "    docker exec ${CONTAINER_NAME} kafka-consumer-groups --bootstrap-server localhost:9192 --list"
echo -e ""
echo -e "  ${CYAN}Deploy con reset de datos (⚠️  destruye todo):${NC}"
echo -e "    bash deploy.prod.sh --reset-data"
echo -e ""
