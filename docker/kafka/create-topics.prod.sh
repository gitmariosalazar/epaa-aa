#!/bin/bash
# =============================================================================
# EPAA-AA — Kafka · Creación de Topics de Producción
#
# Uso:
#   bash create-topics.prod.sh            → Crea todos los topics
#   bash create-topics.prod.sh --list     → Lista los topics existentes
#   bash create-topics.prod.sh --delete   → ⚠️  Elimina y recrea todos los topics
#
# Requisitos:
#   - El contenedor "kafka-epaa-prod" debe estar corriendo y HEALTHY
# =============================================================================

set -euo pipefail

CONTAINER="kafka-epaa-prod"
BOOTSTRAP="localhost:9192"
PARTITIONS=6
REPLICATION=1

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
log_skip()    { echo -e "${CYAN}  ⏭  $1 (ya existe)${NC}"; }

# ─────────────────────────────────────────────────────────────────────────────
# LISTADO DE TODOS LOS TOPICS DEL PROYECTO
# Formato: "nombre_topic:particiones:replication"
# ─────────────────────────────────────────────────────────────────────────────
TOPICS=(
  # ── Microservicios de negocio ──────────────────────────────────────────────
  "authentication_topic:6:1"
  "authentication_topic.reply:6:1"
  "clients_topic:6:1"
  "clients_topic.reply:6:1"
  "companies_topic:6:1"
  "companies_topic.reply:6:1"
  "connection_topic:6:1"
  "connection_topic.reply:6:1"
  "epaa_database_legacy_topic:6:1"
  "epaa_database_legacy_topic.reply:6:1"
  "inventory_topic:6:1"
  "inventory_topic.reply:6:1"
  "location_topic:6:1"
  "location_topic.reply:6:1"
  "notifications_topic:6:1"
  "notifications_topic.reply:6:1"
  "property_topic:6:1"
  "property_topic.reply:6:1"
  "qrcode_topic:6:1"
  "qrcode_topic.reply:6:1"
  "readings_topic:6:1"
  "readings_topic.reply:6:1"
  "work_orders_topic:6:1"
  "work_orders_topic.reply:6:1"
  "workers_topic:6:1"
  "workers_topic.reply:6:1"
  "sigame_legacy_topic:6:1"
  "sigame_legacy_topic.reply:6:1"

  # ── Topics internos de Kafka (necesarios para KRaft/transacciones) ─────────
  "__consumer_offsets:50:1"
  "__transaction_state:50:1"
)

echo -e ""
echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║  🐦‍⬛  EPAA-AA · Kafka · Gestión de Topics   ║${NC}"
echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo -e ""

# ─────────────────────────────────────────────────────────────────────────────
# Verificar que el contenedor existe y está healthy
# ─────────────────────────────────────────────────────────────────────────────
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo "not_found")
if [[ "$HEALTH" != "healthy" ]]; then
  log_error "El contenedor '${CONTAINER}' no está healthy (estado: ${HEALTH})."
  log_info  "Levanta Kafka primero con: bash deploy.prod.sh"
  exit 1
fi
log_success "Contenedor '${CONTAINER}' está HEALTHY"

# ─────────────────────────────────────────────────────────────────────────────
# MODO --list: solo mostrar topics existentes
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--list" ]]; then
  echo -e "\n${CYAN}${BOLD}Topics existentes en el broker:${NC}"
  docker exec "$CONTAINER" kafka-topics \
    --bootstrap-server "$BOOTSTRAP" \
    --list
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# MODO --delete: eliminar todos los topics del proyecto (NO los internos de Kafka)
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--delete" ]]; then
  echo -e ""
  echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}${BOLD}║  ⚠️  ADVERTENCIA: --delete ACTIVADO              ║${NC}"
  echo -e "${RED}${BOLD}║                                                  ║${NC}"
  echo -e "${RED}${BOLD}║  Se eliminarán TODOS los topics de negocio.      ║${NC}"
  echo -e "${RED}${BOLD}║  Los mensajes no consumidos se perderán.         ║${NC}"
  echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
  echo -e ""
  read -r -p "  Escribe 'CONFIRMAR' para continuar: " CONFIRM
  if [[ "$CONFIRM" != "CONFIRMAR" ]]; then
    log_info "Operación cancelada."
    exit 0
  fi

  echo -e "\n${YELLOW}Eliminando topics de negocio...${NC}"
  for ENTRY in "${TOPICS[@]}"; do
    TOPIC_NAME="${ENTRY%%:*}"
    if [[ "$TOPIC_NAME" == __* ]]; then
      log_warning "Saltando topic interno: ${TOPIC_NAME}"
      continue
    fi
    EXISTS=$(docker exec "$CONTAINER" kafka-topics \
      --bootstrap-server "$BOOTSTRAP" \
      --list 2>/dev/null | grep -x "$TOPIC_NAME" || true)
    if [[ -n "$EXISTS" ]]; then
      docker exec "$CONTAINER" kafka-topics \
        --bootstrap-server "$BOOTSTRAP" \
        --delete \
        --topic "$TOPIC_NAME" 2>/dev/null && log_success "Eliminado: ${TOPIC_NAME}" || log_error "Error al eliminar: ${TOPIC_NAME}"
    else
      log_skip "$TOPIC_NAME no existía"
    fi
  done
  echo -e "\n${YELLOW}Recreando topics...${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# CREAR TOPICS (modo normal o tras --delete)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${CYAN}${BOLD}Creando topics...${NC}"
CREATED=0
SKIPPED=0
FAILED=0

for ENTRY in "${TOPICS[@]}"; do
  IFS=':' read -r TOPIC_NAME PARTS REPL <<< "$ENTRY"

  EXISTS=$(docker exec "$CONTAINER" kafka-topics \
    --bootstrap-server "$BOOTSTRAP" \
    --list 2>/dev/null | grep -x "$TOPIC_NAME" || true)

  if [[ -n "$EXISTS" ]]; then
    log_skip "$TOPIC_NAME"
    ((SKIPPED++)) || true
    continue
  fi

  docker exec "$CONTAINER" kafka-topics \
    --bootstrap-server "$BOOTSTRAP" \
    --create \
    --topic "$TOPIC_NAME" \
    --partitions "$PARTS" \
    --replication-factor "$REPL" \
    --if-not-exists 2>/dev/null \
    && { log_success "Creado: ${TOPIC_NAME} (particiones=${PARTS}, replication=${REPL})"; ((CREATED++)) || true; } \
    || { log_error "Error al crear: ${TOPIC_NAME}"; ((FAILED++)) || true; }
done

# ─────────────────────────────────────────────────────────────────────────────
# RESUMEN FINAL
# ─────────────────────────────────────────────────────────────────────────────
echo -e ""
echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   📋 Resumen                             ║${NC}"
echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo -e "  ${GREEN}Creados:  ${CREATED}${NC}"
echo -e "  ${CYAN}Existían: ${SKIPPED}${NC}"
echo -e "  ${RED}Errores:  ${FAILED}${NC}"
echo -e ""
echo -e "${CYAN}${BOLD}Topics en el broker:${NC}"
docker exec "$CONTAINER" kafka-topics \
  --bootstrap-server "$BOOTSTRAP" \
  --list

echo -e ""
echo -e "${YELLOW}${BOLD}Comandos útiles:${NC}"
echo -e "  ${CYAN}Listar topics:${NC}"
echo -e "    bash create-topics.prod.sh --list"
echo -e ""
echo -e "  ${CYAN}Detalles de un topic:${NC}"
echo -e "    docker exec ${CONTAINER} kafka-topics --bootstrap-server ${BOOTSTRAP} --describe --topic <nombre>"
echo -e ""
echo -e "  ${CYAN}Eliminar y recrear todos:${NC}"
echo -e "    bash create-topics.prod.sh --delete"
echo -e ""
