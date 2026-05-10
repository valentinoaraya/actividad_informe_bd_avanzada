-- ============================================================
--  BD AVANZADA — Actividad: Índices
--  Script 02: Carga de datos (datos realistas con generate_series)
--
--  Tiempo estimado: 3–8 minutos según hardware.
--  Ejecutar DESPUÉS de 01_schema.sql
-- ============================================================

-- Desactivamos autocommit implícito para inserción más rápida
BEGIN;

-- ============================================================
--  CLIENTES — 100.000 filas
-- ============================================================
DO $$
DECLARE
    v_nombres   TEXT[] := ARRAY[
        'Juan','María','Carlos','Ana','Luis','Laura','Martín','Sofía',
        'Diego','Valentina','Pablo','Florencia','Alejandro','Camila',
        'Roberto','Natalia','Fernando','Lucía','Andrés','Jimena',
        'Hernán','Romina','Gustavo','Patricia','Sergio','Claudia'
    ];
    v_apellidos TEXT[] := ARRAY[
        'García','González','Rodríguez','Fernández','López','Martínez',
        'Sánchez','Pérez','Romero','Sosa','Torres','Ruiz','Jiménez',
        'Morales','Álvarez','Díaz','Vega','Castro','Reyes','Herrera',
        'Medina','Acosta','Ríos','Gutiérrez','Ortega','Silva'
    ];
    v_ciudades  TEXT[] := ARRAY[
        'Buenos Aires','Córdoba','Rosario','Mendoza','Tucumán',
        'La Plata','Mar del Plata','Salta','Santa Fe','San Juan',
        'Resistencia','Neuquén','Formosa','San Luis','Posadas',
        'Bahía Blanca','Paraná','Corrientes','Santiago del Estero','Jujuy'
    ];
    n_nombres   INT := array_length(v_nombres,  1);
    n_apellidos INT := array_length(v_apellidos, 1);
    n_ciudades  INT := array_length(v_ciudades,  1);
BEGIN
    INSERT INTO clientes (nombre, apellido, email, fecha_nacimiento, ciudad)
    SELECT
        v_nombres  [ 1 + (random() * (n_nombres   - 1))::int ],
        v_apellidos[ 1 + (random() * (n_apellidos - 1))::int ],
        -- Email único: prefijo + id + dominio rotado
        'usuario' || i || '@' ||
            (ARRAY['gmail.com','hotmail.com','yahoo.com','outlook.com','live.com.ar'])
            [ 1 + (i % 5) ],
        -- Edad entre 18 y 80 años
        CURRENT_DATE - ( (18 * 365) + (random() * (62 * 365))::int ),
        v_ciudades [ 1 + (random() * (n_ciudades  - 1))::int ]
    FROM generate_series(1, 100000) AS s(i);

    RAISE NOTICE 'clientes: OK (100.000 filas)';
END $$;


-- ============================================================
--  PRODUCTOS — 10.000 filas
--  Distribución: 10 categorías × 1.000 productos c/u
-- ============================================================
DO $$
DECLARE
    v_categorias TEXT[] := ARRAY[
        'Electrónica','Ropa','Hogar','Deportes','Libros',
        'Juguetes','Alimentos','Belleza','Herramientas','Automotor'
    ];
    v_prefijos   TEXT[] := ARRAY[
        'Pro','Max','Ultra','Smart','Eco',
        'Premium','Basic','Classic','Sport','Mini'
    ];
    cat_idx  INT;
    pref_idx INT;
BEGIN
    INSERT INTO productos (nombre, categoria, precio, stock)
    SELECT
        -- Nombre: "Prefijo Categoría NNN"
        (v_prefijos  [ 1 + ((i-1) % array_length(v_prefijos,   1)) ]) || ' ' ||
        (v_categorias[ 1 + ((i-1) % array_length(v_categorias, 1)) ]) || ' ' ||
        lpad(i::text, 4, '0'),
        -- Categoría determinista (1.000 por categoría)
        v_categorias[ 1 + ((i-1) % array_length(v_categorias, 1)) ],
        -- Precio: distribución asimétrica (mayoría entre $500 y $50.000)
        ROUND( (100 + (random()^0.7 * 99900))::numeric, 2 ),
        -- Stock: 0–500 unidades
        (random() * 500)::int
    FROM generate_series(1, 10000) AS s(i);

    RAISE NOTICE 'productos: OK (10.000 filas)';
END $$;


-- ============================================================
--  ORDENES — 500.000 filas
--  Fechas: 2022-01-01 → 2024-12-31 (3 años)
--  Estados: distribución realista (mayoría "entregado")
-- ============================================================
DO $$
DECLARE
    v_estados TEXT[] := ARRAY[
        'entregado','entregado','entregado','entregado',  -- 40 %
        'enviado','enviado','enviado',                    -- 30 %
        'procesando','procesando',                        -- 20 %
        'pendiente',                                      --  8 %
        'cancelado'                                       --  2 % (pero random lo equilibra)
    ];
    n_estados INT := array_length(v_estados, 1);
BEGIN
    INSERT INTO ordenes (cliente_id, fecha, estado, total, direccion_envio)
    SELECT
        1 + (random() * 99999)::int,
        -- Timestamp aleatorio dentro del período de 3 años
        TIMESTAMP '2022-01-01 00:00:00'
            + ( random() * (EXTRACT(EPOCH FROM
                TIMESTAMP '2024-12-31 23:59:59' -
                TIMESTAMP '2022-01-01 00:00:00')) )::int
            * INTERVAL '1 second',
        v_estados[ 1 + (random() * (n_estados - 1))::int ],
        -- Total entre $500 y $500.000
        ROUND( (500 + random() * 499500)::numeric, 2 ),
        'Calle ' || (1 + (random() * 9999)::int) || ' N° ' ||
                    (1 + (random() *  999)::int)  ||
                    ', Piso ' || (random() * 20)::int
    FROM generate_series(1, 500000) AS s(i);

    RAISE NOTICE 'ordenes: OK (500.000 filas)';
END $$;


-- ============================================================
--  DETALLE_ORDENES — 1.500.000 filas
--  Entre 1 y 5 ítems por orden (promedio ~3)
-- ============================================================
DO $$
BEGIN
    INSERT INTO detalle_ordenes (orden_id, producto_id, cantidad, precio_unitario)
    SELECT
        -- orden_id: referencia a ordenes existentes
        1 + (random() * 499999)::int,
        -- producto_id: referencia a productos existentes
        1 + (random() * 9999)::int,
        -- cantidad: entre 1 y 10 unidades
        1 + (random() * 9)::int,
        -- precio_unitario: entre $100 y $100.000
        ROUND( (100 + random() * 99900)::numeric, 2 )
    FROM generate_series(1, 1500000) AS s(i);

    RAISE NOTICE 'detalle_ordenes: OK (1.500.000 filas)';
END $$;

COMMIT;

-- ============================================================
--  VERIFICACIÓN FINAL
-- ============================================================
SELECT
    relname       AS tabla,
    n_live_tup    AS filas_estimadas,
    pg_size_pretty(pg_total_relation_size(oid)) AS tamaño_total
FROM pg_stat_user_tables
JOIN pg_class USING (relname)
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;