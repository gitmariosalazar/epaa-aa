# EPAA-AA — Backend de Microservicios

Sistema de microservicios para la gestión de agua potable y alcantarillado.

---

## ⚙️ Prerrequisitos Globales

Asegúrate de haber creado las redes de Docker antes del primer arranque:
```bash
# Red de producción
docker network create epaa-network || true

# Red de desarrollo
docker network create epaa-network-dev || true

# Carpetas de imágenes requeridas por los contenedores
sudo mkdir -p /home/sigepaa/sigepaa/images/{readings,connections,qrcodes,work_orders}
```

---

## 🚀 PRODUCCIÓN: DEPLOY DESDE CERO (RESET TOTAL)

Usa este flujo si el servidor se corrompe, tienes errores de "UNKNOWN_TOPIC", o quieres empezar con una instalación 100% limpia. Apagará el sistema y destruirá el historial de Kafka.

**1. Apagar todo y resetear Kafka:**
```bash
docker compose -f docker-compose.prod.yml -p sigepaa-services-production down --remove-orphans
cd docker/kafka
bash deploy.prod.sh --reset-data
# (Escribe CONFIRMAR cuando el script te lo pida)
```

**2. Levantar el Corazón de Mensajería (Kafka):**
```bash
# (Sigues dentro de la carpeta docker/kafka)
bash deploy.prod.sh
# Espera a que diga "✅ Kafka está HEALTHY" (puede tardar hasta 30s)

# Crear los 26 tópicos del sistema
bash create-topics.prod.sh
```

**3. Levantar Microservicios (Reconstrucción total):**
```bash
cd /home/mariosalazar/Desktop/Epaa/Git/backend/epaa-aa
bash deploy.prod.sh --clean-all
```

**4. Monitoreo en Producción:**
```bash
docker compose -f docker-compose.prod.yml -p sigepaa-services-production logs -f --tail=50
```

---

## 🛠️ DESARROLLO (DEV): DEPLOY DESDE CERO (RESET TOTAL)

Usa este flujo si Node.js se rompe, si tienes problemas con librerías de NPM, o si Kafka en desarrollo deja de funcionar y quieres resetear todo.

**1. Apagar todo y limpiar dependencias:**
```bash
# Desde la raíz del backend (/home/mariosalazar/Desktop/Epaa/Git/backend/epaa-aa)
bash deploy.dev.sh --reset

# Apagar Kafka Dev y destruir su volumen de datos
cd docker/kafka
bash deploy.dev.sh --reset-data
# (Escribe CONFIRMAR cuando te lo pida)
```

**2. Levantar Kafka Dev:**
```bash
# (Sigues dentro de la carpeta docker/kafka)
bash deploy.dev.sh
# Espera a que diga "✅ Kafka está HEALTHY"

# Opcional pero recomendado: Crear los tópicos con las mismas particiones de Producción
bash create-topics.dev.sh
```

**3. Levantar Microservicios (con reinstalación de node_modules):**
```bash
cd /home/mariosalazar/Desktop/Epaa/Git/backend/epaa-aa
bash deploy.dev.sh --clean-volumes
```

**4. Monitoreo en Dev:**
```bash
docker compose -f docker-compose.dev.yml logs -f --tail=50
```

---

## 📋 Comandos Rápidos de Uso Diario

Si tu sistema ya está sano y solo quieres hacer operaciones de rutina, usa estos comandos desde la raíz del backend:

**Desarrollo (Hot-Reload):**
* `bash deploy.dev.sh` → Levanta el entorno normal.
* `bash deploy.dev.sh --down` → Apaga el entorno sin borrar `node_modules`.

**Producción:**
* `bash deploy.prod.sh` → Aplica actualizaciones de código rápidamente.

---

## 🏗️ CÓMO AGREGAR UN NUEVO TÓPICO O MICROSERVICIO

Si en el futuro creas un nuevo microservicio (ej. `billing-service`) o necesitas un nuevo tópico en Kafka, debes seguir exactamente estos **3 pasos** para que la arquitectura lo reconozca:

### Paso 1: Declararlo en el Script de Producción
Abre el archivo `docker/kafka/create-topics.prod.sh` y agrega tu tópico (y obligatoriamente su versión `.reply`) en el arreglo `TOPICS=( ... )`.

```bash
# Ejemplo de lo que debes agregar:
"billing_topic:6:1"
"billing_topic.reply:6:1"
```

### Paso 2: Enseñarle la ruta al Gateway (Diccionario)
El Gateway necesita saber a qué tópico enviar las peticiones. Abre el archivo `client-gateway/src/shared/kafka/kafka-proxy.service.ts` y mapea la primera palabra de tus endpoints al nuevo tópico:

```typescript
const serviceMapping: Record<string, string> = {
  // ...
  'billing': 'billing_topic',     // Todo lo que empiece por billing. (ej. billing.create)
  'invoices': 'billing_topic',    // Todo lo que empiece por invoices.
};
```

### Paso 3: Configurar el `main.ts` del Microservicio
Abre el archivo `main.ts` de tu nuevo microservicio y asegúrate de usar la clase `CustomServerKafka` (para evitar errores de formateo JSON) indicando que escuche tu nuevo tópico:

```typescript
app.connectMicroservice<MicroserviceOptions>({
  strategy: new CustomServerKafka({
    client: {
      clientId: 'BILLING_KAFKA_CLIENT_ID',
      brokers: [process.env.KAFKA_BROKERS || 'localhost:9092'],
    },
    consumer: { groupId: 'BILLING_KAFKA_GROUP_ID' },
    topics: ['billing_topic'], // 👈 AQUÍ LE DICES QUE ESCUCHE EL NUEVO TÓPICO
  }),
});
```

**Para desplegar este cambio:**
1. **Desarrollo:** Corre `bash deploy.dev.sh`. Kafka auto-creará el tópico al instante.
2. **Producción:** Ejecuta `bash docker/kafka/create-topics.prod.sh` y luego `bash deploy.prod.sh` para actualizar el código.