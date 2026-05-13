
# Script 02: Carga de datos en Python
import random
import psycopg2
from psycopg2.extras import execute_values
from datetime import date, datetime, timedelta
import time


#  CONFIGURACIÓN DE CONEXIÓN
DB_CONFIG = {
    "host":     "localhost",
    "port":     5432,
    "dbname":   "ventas",
    "user":     "alumno",
    "password": "alumno123",
}

# Tamaño del lote para INSERT masivo
BATCH_SIZE = 10_000

#  DATOS DE REFERENCIA
NOMBRES = [
    "Juan", "María", "Carlos", "Ana", "Luis", "Laura", "Martín", "Sofía",
    "Diego", "Valentina", "Pablo", "Florencia", "Alejandro", "Camila",
    "Roberto", "Natalia", "Fernando", "Lucía", "Andrés", "Jimena",
    "Hernán", "Romina", "Gustavo", "Patricia", "Sergio", "Claudia",
]

APELLIDOS = [
    "García", "González", "Rodríguez", "Fernández", "López", "Martínez",
    "Sánchez", "Pérez", "Romero", "Sosa", "Torres", "Ruiz", "Jiménez",
    "Morales", "Álvarez", "Díaz", "Vega", "Castro", "Reyes", "Herrera",
    "Medina", "Acosta", "Ríos", "Gutiérrez", "Ortega", "Silva",
]

CIUDADES = [
    "Buenos Aires", "Córdoba", "Rosario", "Mendoza", "Tucumán",
    "La Plata", "Mar del Plata", "Salta", "Santa Fe", "San Juan",
    "Resistencia", "Neuquén", "Formosa", "San Luis", "Posadas",
    "Bahía Blanca", "Paraná", "Corrientes", "Santiago del Estero", "Jujuy",
]

DOMINIOS = ["gmail.com", "hotmail.com", "yahoo.com", "outlook.com", "live.com.ar"]

CATEGORIAS = [
    "Electrónica", "Ropa", "Hogar", "Deportes", "Libros",
    "Juguetes", "Alimentos", "Belleza", "Herramientas", "Automotor",
]

PREFIJOS_PRODUCTO = [
    "Pro", "Max", "Ultra", "Smart", "Eco",
    "Premium", "Basic", "Classic", "Sport", "Mini",
]

# Distribución realista de estados: entregado es el más frecuente
ESTADOS = (
    ["entregado"] * 4   # 40 %
    + ["enviado"] * 3   # 30 %
    + ["procesando"] * 2  # 20 %
    + ["pendiente"]     # 8 %
    + ["cancelado"]     # 2 %
)

# Rango de fechas para las órdenes
FECHA_INICIO = datetime(2022, 1, 1)
FECHA_FIN    = datetime(2024, 12, 31, 23, 59, 59)
SEGUNDOS_RANGO = int((FECHA_FIN - FECHA_INICIO).total_seconds())


#  FUNCIONES GENERADORAS
def generar_clientes(n: int):
    hoy = date.today()
    for i in range(1, n + 1):
        nombre   = random.choice(NOMBRES)
        apellido = random.choice(APELLIDOS)
        email    = f"usuario{i}@{DOMINIOS[i % len(DOMINIOS)]}"
        dias_atras = random.randint(18 * 365, 80 * 365)
        nacimiento = hoy - timedelta(days=dias_atras)
        ciudad   = random.choice(CIUDADES)
        yield (nombre, apellido, email, nacimiento, ciudad)


def generar_productos(n: int):
    for i in range(1, n + 1):
        categoria = CATEGORIAS[(i - 1) % len(CATEGORIAS)]
        prefijo   = PREFIJOS_PRODUCTO[(i - 1) % len(PREFIJOS_PRODUCTO)]
        nombre    = f"{prefijo} {categoria} {str(i).zfill(4)}"
        precio    = round(100 + (random.random() ** 0.7) * 99900, 2)
        stock     = random.randint(0, 500)
        yield (nombre, categoria, precio, stock)


def generar_ordenes(n: int, max_cliente_id: int):
    for _ in range(n):
        cliente_id = random.randint(1, max_cliente_id)
        segundos   = random.randint(0, SEGUNDOS_RANGO)
        fecha      = FECHA_INICIO + timedelta(seconds=segundos)
        estado     = random.choice(ESTADOS)
        total      = round(random.uniform(500, 500_000), 2)
        direccion  = (
            f"Calle {random.randint(1, 9999)} "
            f"N° {random.randint(1, 999)}, "
            f"Piso {random.randint(0, 20)}"
        )
        yield (cliente_id, fecha, estado, total, direccion)


def generar_detalles(n: int, max_orden_id: int, max_producto_id: int):
    for _ in range(n):
        orden_id        = random.randint(1, max_orden_id)
        producto_id     = random.randint(1, max_producto_id)
        cantidad        = random.randint(1, 10)
        precio_unitario = round(random.uniform(100, 100_000), 2)
        yield (orden_id, producto_id, cantidad, precio_unitario)


#  FUNCIÓN DE INSERCIÓN POR LOTES
def insertar_en_lotes(cursor, sql: str, generador, total: int, etiqueta: str):
    lote    = []
    insertados = 0
    inicio  = time.time()

    for fila in generador:
        lote.append(fila)

        if len(lote) == BATCH_SIZE:
            execute_values(cursor, sql, lote)
            insertados += len(lote)
            lote = []
            if insertados % 50_000 == 0:
                transcurrido = time.time() - inicio
                print(f"  {etiqueta}: {insertados:>10,} / {total:,}  "
                      f"({transcurrido:.1f}s transcurridos)")

    if lote:
        execute_values(cursor, sql, lote)
        insertados += len(lote)

    transcurrido = time.time() - inicio
    print(f"  ✓ {etiqueta}: {insertados:,} filas insertadas en {transcurrido:.1f}s")


#  PROGRAMA PRINCIPAL
def main():
    print("Conectando a PostgreSQL...")
    conn = psycopg2.connect(**DB_CONFIG)
    # autocommit=False → todo dentro de una transacción,
    # más rápido y seguro (si algo falla, se hace rollback completo)
    conn.autocommit = False
    cur = conn.cursor()

    try:
        print("\n[1/4] Insertando clientes (100.000 filas)...")
        insertar_en_lotes(
            cur,
            sql="""
                INSERT INTO clientes
                    (nombre, apellido, email, fecha_nacimiento, ciudad)
                VALUES %s
            """,
            generador=generar_clientes(100_000),
            total=100_000,
            etiqueta="clientes",
        )

        print("\n[2/4] Insertando productos (10.000 filas)...")
        insertar_en_lotes(
            cur,
            sql="""
                INSERT INTO productos
                    (nombre, categoria, precio, stock)
                VALUES %s
            """,
            generador=generar_productos(10_000),
            total=10_000,
            etiqueta="productos",
        )

        print("\n[3/4] Insertando órdenes (500.000 filas)...")
        insertar_en_lotes(
            cur,
            sql="""
                INSERT INTO ordenes
                    (cliente_id, fecha, estado, total, direccion_envio)
                VALUES %s
            """,
            generador=generar_ordenes(500_000, max_cliente_id=100_000),
            total=500_000,
            etiqueta="ordenes",
        )

        print("\n[4/4] Insertando detalle_ordenes (1.500.000 filas)...")
        insertar_en_lotes(
            cur,
            sql="""
                INSERT INTO detalle_ordenes
                    (orden_id, producto_id, cantidad, precio_unitario)
                VALUES %s
            """,
            generador=generar_detalles(
                1_500_000, max_orden_id=500_000, max_producto_id=10_000
            ),
            total=1_500_000,
            etiqueta="detalle_ordenes",
        )

        print("\nGuardando cambios (COMMIT)...")
        conn.commit()
        print("✓ Carga completa.\n")

        print("=== Verificación ===")
        cur.execute("""
            SELECT
                relname                                            AS tabla,
                to_char(n_live_tup, '999,999,999')                AS filas,
                pg_size_pretty(pg_total_relation_size(oid))        AS tamaño_total
            FROM pg_stat_user_tables
            JOIN pg_class USING (relname)
            WHERE schemaname = 'public'
            ORDER BY n_live_tup DESC
        """)
        print(f"{'Tabla':<20} {'Filas':>15} {'Tamaño':>12}")
        print("-" * 50)
        for tabla, filas, tamaño in cur.fetchall():
            print(f"{tabla:<20} {filas:>15} {tamaño:>12}")

    except Exception as e:
        print(f"\n✗ Error: {e}")
        conn.rollback()
        raise

    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()