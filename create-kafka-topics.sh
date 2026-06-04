#!/usr/bin/env bash
# =============================================================================
# create-kafka-topics.sh
# Crea los topics base (single-topic-per-service) y sus topics .reply
# Uso:
#   ./create-kafka-topics.sh         # producción (kafka-epaa-prod)
#   ./create-kafka-topics.sh dev     # desarrollo (kafka-epaa-dev)
# =============================================================================

set -euo pipefail

ENVIRONMENT="${1:-prod}"

if [[ "$ENVIRONMENT" == "dev" ]]; then
  KAFKA_CONTAINER="kafka-epaa-dev"
  BOOTSTRAP="kafka-epaa-dev:9092"
else
  KAFKA_CONTAINER="kafka-epaa-prod"
  BOOTSTRAP="kafka-epaa-prod:9192"
fi

PARTITIONS=1
REPLICATION=1

TOPICS=(
  "authentication_topic"
  "clients_topic"
  "companies_topic"
  "connection_topic"
  "documents_topic"
  "epaa_database_legacy_topic"
  "location_topic"
  "notifications_topic"
  "property_topic"
  "qrcode_topic"
  "readings_topic"
  "sigame_legacy_topic"
  "inventory_topic"
  "work_orders_topic"
  "workers_topic"
)

create_topic() {
  local topic="$1"
  docker exec "$KAFKA_CONTAINER" \
    kafka-topics --bootstrap-server "$BOOTSTRAP" \
    --create \
    --if-not-exists \
    --topic "$topic" \
    --partitions "$PARTITIONS" \
    --replication-factor "$REPLICATION" \
    >/dev/null
  echo "  - $topic"
}

echo ""
echo "Creando topics en $KAFKA_CONTAINER ($BOOTSTRAP)..."
echo ""

echo "[1/2] Topics base"
for topic in "${TOPICS[@]}"; do
  create_topic "$topic"
done

echo ""
echo "[2/2] Topics reply"
for topic in "${TOPICS[@]}"; do
  create_topic "${topic}.reply"
done

echo ""
echo "Listando topics actuales:"
docker exec "$KAFKA_CONTAINER" kafka-topics --bootstrap-server "$BOOTSTRAP" --list | sort

echo ""
echo "OK: topics base + .reply creados."
