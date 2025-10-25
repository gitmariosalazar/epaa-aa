FROM postgis/postgis:18-3.6

# Instala pgRouting y extensiones útiles
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        postgresql-18-pgrouting \
        curl \
        vim \
        less \
        wget && \
    apt-get clean && rm -rf /var/lib/apt/lists/*