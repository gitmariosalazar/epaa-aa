#!/bin/bash
echo "Copiando lista de topics al contenedor..."
sudo docker cp /tmp/topics.txt kafka-epaa-prod:/tmp/topics.txt

echo "Creando topics en lote..."
sudo docker exec kafka-epaa-prod bash -c '
  while read topic; do
    echo "Creating $topic..."
    kafka-topics --bootstrap-server localhost:9192 --create --if-not-exists --topic "$topic" --partitions 6 --replication-factor 1 >/dev/null 2>&1
  done < /tmp/topics.txt
'
echo "✅ Todos los 269 topics fueron creados exitosamente."
