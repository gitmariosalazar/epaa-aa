#!/bin/bash
# =============================================================================
# EPAA-AA — Script de Deploy en Producción
# Uso: bash deploy.prod.sh [--clean-all]
#
# Flags:
#   --clean-all   Elimina TODAS las imágenes del proyecto antes del rebuild
#                 (útil cuando hay cambios mayores de dependencias)
# =============================================================================

set -e

PROJECT_LABEL="com.epaa.project=epaa-aa"
COMPOSE_FILE="docker-compose.prod.yml"
PROJECT_NAME="sigepaa-services-production"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   🚀 EPAA-AA Deploy de Producción     ${NC}"
echo -e "${BLUE}========================================${NC}"

# --- Paso 1: Bajar el stack y eliminar contenedores huérfanos ---
echo -e "\n${YELLOW}[1/5] Deteniendo stack actual y eliminando contenedores huérfanos...${NC}"
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down --remove-orphans || true

# Forzar eliminación de contenedores con nombre conflictivo (creados fuera de este stack)
CONFLICTING=$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" config | grep 'container_name:' | awk '{print $2}')
if [ -n "$CONFLICTING" ]; then
  echo -e "${YELLOW}  → Verificando contenedores con nombre reservado...${NC}"
  for CNAME in $CONFLICTING; do
    if docker ps -a --format '{{.Names}}' | grep -qx "$CNAME"; then
      echo -e "${YELLOW}  → Eliminando contenedor conflictivo: $CNAME${NC}"
      docker rm -f "$CNAME"
    fi
  done
fi
echo -e "${GREEN}✅ Stack detenido${NC}"

# --- Paso 2: (Opcional) Limpiar TODAS las imágenes del proyecto ---
if [[ "$1" == "--clean-all" ]]; then
  echo -e "\n${YELLOW}[2/5] --clean-all: Eliminando imágenes del proyecto EPAA...${NC}"
  IMAGES=$(docker images --filter "label=$PROJECT_LABEL" -q)
  if [ -n "$IMAGES" ]; then
    docker rmi -f $IMAGES
    echo -e "${GREEN}✅ Imágenes del proyecto eliminadas${NC}"
  else
    echo -e "${GREEN}✅ No hay imágenes del proyecto para eliminar${NC}"
  fi
else
  echo -e "\n${YELLOW}[2/5] Limpiando imágenes dangling (huérfanas) del proyecto...${NC}"
  docker image prune -f --filter "label=$PROJECT_LABEL"
  echo -e "${GREEN}✅ Imágenes dangling eliminadas${NC}"
fi

# --- Paso 3: Limpiar volúmenes anónimos sin usar ---
echo -e "\n${YELLOW}[3/5] Limpiando volúmenes anónimos sin usar...${NC}"
docker volume prune -f
echo -e "${GREEN}✅ Volúmenes sin usar eliminados${NC}"

# --- Paso 4: Construir y levantar el stack ---
echo -e "\n${YELLOW}[4/5] Construyendo imágenes y levantando el stack...${NC}"
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d --build --remove-orphans
echo -e "${GREEN}✅ Stack levantado${NC}"

# --- Paso 5: Verificar estado de los contenedores ---
echo -e "\n${YELLOW}[5/5] Estado de los contenedores:${NC}"
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Deploy completado exitosamente${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e ""
echo -e "${YELLOW}Tip:${NC} Para ver logs en tiempo real:"
echo -e "  docker compose -f $COMPOSE_FILE -p $PROJECT_NAME logs -f --tail=50"
echo -e ""
echo -e "${YELLOW}Tip:${NC} Para un rebuild completo (limpia TODAS las imágenes):"
echo -e "  bash deploy.prod.sh --clean-all"
