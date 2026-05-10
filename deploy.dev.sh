#!/bin/bash
# =============================================================================
# EPAA-AA — Script de Dev (Desarrollo Local)
# Uso: bash deploy.dev.sh [opción]
#
# Opciones:
#   (sin args)         Levanta el stack completo con hot-reload
#   --rebuild          Fuerza rebuild de imágenes (borra imágenes dangling)
#   --clean-volumes    Elimina volúmenes de node_modules y hace rebuild total
#                      (usar cuando cambias package.json / hay errores de deps)
#   --down             Detiene y elimina contenedores (preserva node_modules)
#   --reset            Detiene todo, limpia imágenes Y volúmenes del proyecto
#                      (útil para empezar desde cero en dev)
# =============================================================================

set -e

PROJECT_LABEL="com.epaa.project=epaa-aa"
ENV_LABEL="com.epaa.env=development"
COMPOSE_FILE="docker-compose.dev.yml"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# Helper: eliminar contenedores con nombre reservado que queden fuera del stack
# =============================================================================
force_remove_conflicting() {
  local CONFLICTING
  CONFLICTING=$(docker compose -f "$COMPOSE_FILE" config 2>/dev/null | grep 'container_name:' | awk '{print $2}')
  if [ -n "$CONFLICTING" ]; then
    for CNAME in $CONFLICTING; do
      if docker ps -a --format '{{.Names}}' | grep -qx "$CNAME"; then
        echo -e "${YELLOW}  → Eliminando contenedor conflictivo: $CNAME${NC}"
        docker rm -f "$CNAME"
      fi
    done
  fi
}

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   🛠️  EPAA-AA Entorno de Desarrollo    ${NC}"
echo -e "${CYAN}========================================${NC}"

# =============================================================================
# --down: Bajar stack limpiamente
# =============================================================================
if [[ "$1" == "--down" ]]; then
  echo -e "\n${YELLOW}Deteniendo stack de desarrollo...${NC}"
  docker compose -f "$COMPOSE_FILE" down --remove-orphans || true
  force_remove_conflicting
  echo -e "${GREEN}✅ Stack detenido. Los volúmenes de node_modules fueron preservados.${NC}"
  exit 0
fi

# =============================================================================
# --reset: Limpieza total (imágenes + volúmenes de node_modules)
# =============================================================================
if [[ "$1" == "--reset" ]]; then
  echo -e "\n${RED}⚠️  RESET TOTAL del entorno de desarrollo...${NC}"
  echo -e "${YELLOW}Esto eliminará imágenes Y volúmenes de node_modules del proyecto.${NC}"
  read -p "¿Estás seguro? (s/N): " confirm
  if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    echo -e "${YELLOW}Operación cancelada.${NC}"
    exit 0
  fi

  echo -e "\n${YELLOW}[1/3] Deteniendo stack y eliminando contenedores huérfanos...${NC}"
  docker compose -f "$COMPOSE_FILE" down --remove-orphans || true
  force_remove_conflicting
  echo -e "${GREEN}✅ Stack detenido${NC}"

  echo -e "\n${YELLOW}[2/3] Eliminando imágenes del proyecto (dev)...${NC}"
  IMAGES=$(docker images --filter "label=$PROJECT_LABEL" --filter "label=$ENV_LABEL" -q)
  if [ -n "$IMAGES" ]; then
    docker rmi -f $IMAGES
    echo -e "${GREEN}✅ Imágenes eliminadas${NC}"
  else
    echo -e "${GREEN}✅ No hay imágenes para eliminar${NC}"
  fi

  echo -e "\n${YELLOW}[3/3] Eliminando volúmenes de node_modules del proyecto...${NC}"
  docker volume ls --filter "label=$PROJECT_LABEL" --filter "label=$ENV_LABEL" -q | xargs -r docker volume rm
  echo -e "${GREEN}✅ Volúmenes node_modules eliminados${NC}"

  echo -e "\n${GREEN}✅ Reset completado. Usa 'bash deploy.dev.sh' para levantar desde cero.${NC}"
  exit 0
fi

# =============================================================================
# --clean-volumes: Eliminar volúmenes de node_modules + rebuild
# (Usar cuando cambias package.json)
# =============================================================================
if [[ "$1" == "--clean-volumes" ]]; then
  echo -e "\n${YELLOW}[1/4] Deteniendo stack...${NC}"
  docker compose -f "$COMPOSE_FILE" down --remove-orphans || true
  force_remove_conflicting
  echo -e "${GREEN}✅ Stack detenido${NC}"

  echo -e "\n${YELLOW}[2/4] Eliminando volúmenes de node_modules del proyecto...${NC}"
  docker volume ls --filter "label=$PROJECT_LABEL" --filter "label=$ENV_LABEL" -q | xargs -r docker volume rm
  echo -e "${GREEN}✅ Volúmenes node_modules eliminados${NC}"

  echo -e "\n${YELLOW}[3/4] Limpiando imágenes dangling del proyecto...${NC}"
  docker image prune -f --filter "label=$PROJECT_LABEL"
  echo -e "${GREEN}✅ Imágenes dangling eliminadas${NC}"

  echo -e "\n${YELLOW}[4/4] Construyendo y levantando el stack (reinstalará node_modules)...${NC}"
  docker compose -f "$COMPOSE_FILE" up -d --build --remove-orphans
  echo -e "${GREEN}✅ Stack levantado con node_modules frescos${NC}"

  docker compose -f "$COMPOSE_FILE" ps
  echo -e "\n${CYAN}========================================${NC}"
  echo -e "${GREEN}✅ Entorno DEV listo (con deps reinstaladas)${NC}"
  echo -e "${CYAN}========================================${NC}"
  exit 0
fi

# =============================================================================
# --rebuild: Rebuild de imágenes (sin tocar node_modules)
# =============================================================================
if [[ "$1" == "--rebuild" ]]; then
  echo -e "\n${YELLOW}[1/3] Deteniendo stack...${NC}"
  docker compose -f "$COMPOSE_FILE" down --remove-orphans || true
  force_remove_conflicting
  echo -e "${GREEN}✅ Stack detenido${NC}"

  echo -e "\n${YELLOW}[2/3] Limpiando imágenes dangling del proyecto...${NC}"
  docker image prune -f --filter "label=$PROJECT_LABEL"
  echo -e "${GREEN}✅ Imágenes dangling eliminadas${NC}"

  echo -e "\n${YELLOW}[3/3] Construyendo y levantando stack...${NC}"
  docker compose -f "$COMPOSE_FILE" up -d --build --remove-orphans
  echo -e "${GREEN}✅ Stack levantado${NC}"

  docker compose -f "$COMPOSE_FILE" ps
  echo -e "\n${CYAN}========================================${NC}"
  echo -e "${GREEN}✅ Entorno DEV listo (rebuild de imágenes)${NC}"
  echo -e "${CYAN}========================================${NC}"
  exit 0
fi

# =============================================================================
# DEFAULT: Levantar stack (primera vez o después de --down)
# =============================================================================
echo -e "\n${YELLOW}[1/3] Eliminando contenedores huérfanos...${NC}"
docker compose -f "$COMPOSE_FILE" down --remove-orphans 2>/dev/null || true
echo -e "${GREEN}✅ Limpieza previa completada${NC}"

echo -e "\n${YELLOW}[2/3] Limpiando imágenes dangling del proyecto...${NC}"
docker image prune -f --filter "label=$PROJECT_LABEL"
echo -e "${GREEN}✅ Imágenes dangling eliminadas${NC}"

echo -e "\n${YELLOW}[3/3] Levantando stack de desarrollo con hot-reload...${NC}"
docker compose -f "$COMPOSE_FILE" up -d --build --remove-orphans
#docker compose -f "$COMPOSE_FILE" up --build --remove-orphans
echo -e "${GREEN}✅ Stack levantado${NC}"

docker compose -f "$COMPOSE_FILE" ps

echo -e "\n${CYAN}========================================${NC}"
echo -e "${GREEN}✅ Entorno DEV listo con hot-reload 🔥${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e ""
echo -e "${YELLOW}Comandos útiles:${NC}"
echo -e "  Ver logs:             docker compose -f $COMPOSE_FILE logs -f --tail=50"
echo -e "  Bajar stack:          bash deploy.dev.sh --down"
echo -e "  Rebuild imágenes:     bash deploy.dev.sh --rebuild"
echo -e "  Reinstalar deps:      bash deploy.dev.sh --clean-volumes"
echo -e "  Reset total:          bash deploy.dev.sh --reset"
