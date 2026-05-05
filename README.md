# EPAA-AA — Backend de Microservicios

Sistema de microservicios para la gestión de agua potable y alcantarillado.

---

## ⚙️ Prerrequisitos

- Docker Engine **v24+** (plugin `docker compose` v2, **NO** usar `docker-compose` legacy v1)
- Crear las redes externas antes del primer arranque:

```bash
# Red de producción
docker network create epaa-network

# Red de desarrollo
docker network create epaa-network-dev
```

---

## 🚀 PRODUCCIÓN — Flujo Profesional de Deploy

> **Regla de oro:** Siempre usar el script `deploy.prod.sh`. Hace todo el ciclo limpio en orden correcto.

```bash
# Deploy normal (updates de código, hotfixes)
bash deploy.prod.sh

# Deploy con limpieza total de imágenes (cambios grandes de deps, Dockerfile, etc.)
bash deploy.prod.sh --clean-all
```

---

## 🛠️ DESARROLLO — Flujo con Hot-Reload

> Los volúmenes de `node_modules` son nombrados y persistentes entre reinicios. Solo se eliminan si se pide explícitamente.

```bash
# Levantar entorno dev por primera vez (o después de --down)
bash deploy.dev.sh

# Bajar el stack SIN eliminar node_modules (rearranque rápido)
bash deploy.dev.sh --down

# Rebuild de imágenes SIN tocar node_modules (cambios en Dockerfile.dev)
bash deploy.dev.sh --rebuild

# Reinstalar dependencias (package.json cambió → elimina node_modules y rebuild)
bash deploy.dev.sh --clean-volumes

# Reset total: elimina imágenes + node_modules + contenedores (empezar desde cero)
bash deploy.dev.sh --reset
```

### Cuándo usar cada modo de dev

| Situación | Comando |
|---|---|
| Primera vez / después de `--down` | `bash deploy.dev.sh` |
| Cambié código fuente (hot-reload lo detecta solo) | — ninguno, es automático — |
| Cambié `Dockerfile.dev` | `bash deploy.dev.sh --rebuild` |
| Cambié `package.json` | `bash deploy.dev.sh --clean-volumes` |
| Errores raros de dependencias / empezar de cero | `bash deploy.dev.sh --reset` |



## 📋 Comandos Manuales (Referencia)

> Usar solo si se necesita control granular. Para deploy completo, preferir el script.

### ✅ Levantar el stack completo

```bash
docker compose -f docker-compose.prod.yml up -d --remove-orphans
```

### ✅ Levantar y forzar rebuild de imágenes

```bash
docker compose -f docker-compose.prod.yml up -d --build --remove-orphans
```

### ✅ Levantar servicios específicos (con rebuild)

```bash
docker compose -f docker-compose.prod.yml up -d --build --remove-orphans \
  security-service \
  client-gateway-epaa \
  readings-service
```

### ✅ Detener el stack (sin eliminar datos)

```bash
docker compose -f docker-compose.prod.yml down --remove-orphans
```

> ⚠️ **Nunca usar `down -v`** en producción. El flag `-v` elimina volúmenes con datos persistentes.

### ✅ Construir imágenes sin caché (sin levantar)

```bash
# Todos los servicios
docker compose -f docker-compose.prod.yml build --no-cache

# Un servicio específico
docker compose -f docker-compose.prod.yml build --no-cache security-service
```

### ✅ Reiniciar un servicio específico (sin rebuild)

```bash
docker compose -f docker-compose.prod.yml restart security-service
```

### ✅ Reiniciar un servicio con rebuild limpio

```bash
docker compose -f docker-compose.prod.yml up -d --build --remove-orphans security-service
```

---

## 🧹 Limpieza de Huérfanos

### Eliminar imágenes dangling (huérfanas) solo del proyecto EPAA

```bash
docker image prune -f --filter "label=com.epaa.project=epaa-aa"
```

### Eliminar TODAS las imágenes del proyecto (rebuild desde cero)

```bash
docker rmi -f $(docker images --filter "label=com.epaa.project=epaa-aa" -q)
```

### Eliminar volúmenes anónimos sin uso

```bash
docker volume prune -f
```

### Limpieza general del sistema Docker (con confirmación)

```bash
docker system prune -f
```

> ⚠️ `docker system prune` elimina imágenes, redes y volúmenes no usados por **cualquier** contenedor. Usarlo con cuidado.

---

## 📊 Monitoreo

### Ver estado de todos los contenedores del stack

```bash
docker compose -f docker-compose.prod.yml ps
```

### Ver logs de todos los servicios (tiempo real)

```bash
docker compose -f docker-compose.prod.yml logs -f --tail=50
```

### Ver logs de un servicio específico

```bash
docker compose -f docker-compose.prod.yml logs -f --tail=100 security-service
```

### Ver uso de recursos (CPU/RAM)

```bash
docker stats $(docker compose -f docker-compose.prod.yml ps -q)
```

---

## 🔍 Diagnóstico de Problemas

### Ver imágenes huérfanas actuales

```bash
docker images --filter "dangling=true"
```

### Ver volúmenes sin uso

```bash
docker volume ls --filter "dangling=true"
```

### Ver contenedores huérfanos (detenidos)

```bash
docker ps -a --filter "status=exited"
```

### Inspeccionar healthcheck de un servicio

```bash
docker inspect --format='{{json .State.Health}}' security-service | jq
```

---

## 📦 Servicios del Stack

| Servicio | Puerto | Descripción |
|---|---|---|
| `client-gateway-epaa` | 3005 | API Gateway principal |
| `security-service` | 3004 | Autenticación y autorización |
| `readings-service` | 3007 | Gestión de lecturas |
| `connection-service` | 3013 | Gestión de acometidas |
| `clients-service` | 3011 | Gestión de clientes |
| `companies-service` | 3012 | Gestión de empresas |
| `property-service` | 3010 | Gestión de predios |
| `location-service` | 3017 | Gestión de ubicaciones |
| `work-orders-service` | 3014 | Órdenes de trabajo |
| `workers-service` | 3016 | Gestión de técnicos |
| `epaa-database-legacy-service` | 3009 | Servicio DB legacy |
| `sigame-legacy-service` | 3015 | Integración SIGAME |

---

## ❌ Antipatrones — Lo que NUNCA se debe hacer

```bash
# ❌ MAL: sintaxis legacy, sin --remove-orphans
sudo docker-compose -f docker-compose.prod.yml up -d

# ❌ MAL: down con -v elimina volúmenes de datos en producción
docker compose -f docker-compose.prod.yml down -v

# ❌ MAL: up sin --remove-orphans deja contenedores fantasma
docker compose -f docker-compose.prod.yml up -d

# ❌ MAL: system prune --volumes en producción sin confirmar
docker system prune --volumes -f
```

```bash
# ✅ BIEN: v2, siempre con --remove-orphans
docker compose -f docker-compose.prod.yml up -d --build --remove-orphans

# ✅ BIEN: down seguro sin tocar volúmenes
docker compose -f docker-compose.prod.yml down --remove-orphans

# ✅ MEJOR: usar el script de deploy que lo hace todo en orden
bash deploy.prod.sh
```
