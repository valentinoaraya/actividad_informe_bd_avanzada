# 📊 Análisis de Índices en PostgreSQL

**Bases de Datos Avanzada — UTN**

Proyecto experimental para medir el impacto de índices sobre rendimiento, planes de ejecución y almacenamiento en PostgreSQL 16.

---

## 📁 Archivos del proyecto

```
.
├── docker-compose.yml               # Entorno PostgreSQL dockerizado
├── 01_schema.sql                    # Creación de tablas (sin índices)
├── 02_datos.py                      # Carga de datos con Python
├── 03_baseline_sin_indices.sql      # EXPLAIN ANALYZE antes de indexar
├── 04_crear_indices.sql             # Creación de todos los índices
└── 05_con_indices.sql               # EXPLAIN ANALYZE después de indexar
```

---

## ✅ Requisitos previos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y corriendo
- Python 3

---

## 🚀 Paso a paso

### 1. Levantar PostgreSQL con Docker

Creá un archivo `docker-compose.yml` con el siguiente contenido:

```yaml
services:
    postgres:
        image: postgres:16
        container_name: bd_avanzada
        environment:
            POSTGRES_USER: alumno
            POSTGRES_PASSWORD: alumno123
            POSTGRES_DB: ventas
        ports:
            - "5432:5432"
        volumes:
            - pgdata:/var/lib/postgresql/data

volumes:
    pgdata:
```

Luego ejecutá:

```bash
docker compose up -d
```

Verificá que el contenedor esté corriendo:

```bash
docker ps
```

---

### 2. Crear las tablas

```bash
docker cp 01_schema.sql bd_avanzada:/
docker exec -it bd_avanzada psql -U alumno -d ventas -f /01_schema.sql
```

---

### 3. Cargar los datos

```bash
# Crear entorno virtual e instalar dependencia
python3 -m venv venv
source venv/bin/activate
pip install psycopg2-binary

# Ejecutar (tarda ~3-8 minutos)
python3 02_datos.py
```

Al finalizar deberías ver:

```
tabla            | filas      | tamaño_total
-----------------+------------+-------------
detalle_ordenes  | 1,500,000  | ~195 MB
ordenes          |   500,000  | ~108 MB
clientes         |   100,000  |  ~21 MB
productos        |    10,000  |   ~1 MB
```

---

### 4. Medir rendimiento SIN índices (baseline)

Copiá los scripts al contenedor y conectate:

```bash
docker cp 03_baseline_sin_indices.sql bd_avanzada:/
docker cp 04_crear_indices.sql        bd_avanzada:/
docker cp 05_con_indices.sql          bd_avanzada:/

docker exec -it bd_avanzada psql -U alumno -d ventas
```

Dentro de `psql`, capturá los resultados:

```sql
\o resultados_sin_indices.txt
\i /03_baseline_sin_indices.sql
\o
```

---

### 5. Crear los índices

```sql
\i /04_crear_indices.sql
```

---

### 6. Medir rendimiento CON índices

```sql
\o resultados_con_indices.txt
\i /05_con_indices.sql
\o
```

---

### 7. Recuperar los resultados a tu máquina

Salí de `psql` con `\q` y luego:

```bash
docker cp bd_avanzada:/resultados_sin_indices.txt .
docker cp bd_avanzada:/resultados_con_indices.txt .
```

---

## 🔌 Conexión directa a la base de datos

Si querés conectarte con un cliente gráfico (DBeaver, TablePlus, etc.):

| Parámetro  | Valor       |
| ---------- | ----------- |
| Host       | `localhost` |
| Puerto     | `5432`      |
| Base       | `ventas`    |
| Usuario    | `alumno`    |
| Contraseña | `alumno123` |

---

## 🧹 Limpiar el entorno

```bash
# Detener y eliminar el contenedor
docker compose down

# Eliminar también los datos persistentes
docker compose down -v
```

---

## 📌 Notas

- Los scripts `03` y `05` usan `EXPLAIN (ANALYZE, BUFFERS)` — los tiempos pueden variar entre ejecuciones según el estado del caché de PostgreSQL.
- La primera ejecución de una consulta suele ser más lenta (datos en disco). Las siguientes se benefician del buffer pool (RAM).
- El script `04_crear_indices.sql` incluye índices redundantes e ineficientes **a propósito**, para el análisis del Punto 4 del informe.
