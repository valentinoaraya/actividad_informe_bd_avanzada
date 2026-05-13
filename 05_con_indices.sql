--  Script 05: Consultas CON índices + Dimensionamiento + Redundancias

\echo ' CONSULTA 1 — Búsqueda por email'
\echo ' Esperado CON índice: Index Scan using idx_clientes_email'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id, nombre, apellido, email, ciudad
FROM clientes
WHERE email = 'usuario5000@gmail.com';


\echo ''
\echo ' CONSULTA 2 — Rango de fechas'
\echo ' Esperado CON índice: Index Scan using idx_ordenes_fecha'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id, cliente_id, fecha, estado, total
FROM ordenes
WHERE fecha BETWEEN '2023-06-01' AND '2023-06-30';


\echo ''
\echo ' CONSULTA 3 — Filtro por estado'
\echo ' Esperado CON índice: Bitmap Heap Scan'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT estado, COUNT(*) AS cantidad, ROUND(AVG(total),2) AS ticket_promedio
FROM ordenes
WHERE estado = 'pendiente'
GROUP BY estado;


\echo ''
\echo ' CONSULTA 4 — JOIN clientes → ordenes'
\echo ' Esperado CON índice: Nested Loop + Index Scan on ordenes'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT c.nombre, c.apellido, c.ciudad,
       COUNT(o.id)           AS total_ordenes,
       ROUND(SUM(o.total),2) AS facturado_total
FROM clientes c
JOIN ordenes o ON o.cliente_id = c.id
WHERE c.ciudad = 'Mendoza'
GROUP BY c.id, c.nombre, c.apellido, c.ciudad
ORDER BY facturado_total DESC
LIMIT 20;


\echo ''
\echo ' CONSULTA 5 — Agregación por producto'
\echo ' Esperado CON índice: Index Only Scan (sin leer el heap)'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT producto_id,
       COUNT(*)        AS veces_vendido,
       SUM(cantidad)   AS unidades_totales,
       ROUND(AVG(precio_unitario), 2) AS precio_promedio
FROM detalle_ordenes
WHERE producto_id = 3500
GROUP BY producto_id;


--  PUNTO 3 — DIMENSIONAMIENTO
--  Tamaño de cada índice vs. tamaño de la tabla

\echo ''
\echo ' PUNTO 3 — Tamaño de índices vs tablas'

SELECT
    t.relname                                           AS tabla,
    ix.relname                                          AS indice,
    pg_size_pretty(pg_relation_size(t.oid))             AS tamaño_tabla,
    pg_size_pretty(pg_relation_size(ix.oid))            AS tamaño_indice,
    ROUND(
        pg_relation_size(ix.oid)::numeric
        / NULLIF(pg_relation_size(t.oid), 0) * 100, 1
    )                                                   AS pct_vs_tabla
FROM pg_class t
JOIN pg_index i  ON i.indrelid  = t.oid
JOIN pg_class ix ON ix.oid      = i.indexrelid
WHERE t.relkind = 'r'
  AND t.relname IN ('clientes','productos','ordenes','detalle_ordenes')
  AND ix.relname NOT LIKE '%_pkey'
ORDER BY t.relname, pg_relation_size(ix.oid) DESC;


\echo ''
\echo '--- Resumen total por tabla ---'

SELECT
    relname                                                AS tabla,
    pg_size_pretty(pg_relation_size(oid))                  AS solo_datos,
    pg_size_pretty(pg_indexes_size(oid))                   AS todos_indices,
    pg_size_pretty(pg_total_relation_size(oid))            AS total,
    ROUND(
        pg_indexes_size(oid)::numeric
        / NULLIF(pg_relation_size(oid), 0) * 100, 1
    )                                                      AS pct_indices
FROM pg_stat_user_tables
JOIN pg_class USING (relname)
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(oid) DESC;


--  PUNTO 4 — DETECCIÓN DE ÍNDICES REDUNDANTES / INEFICIENTES

\echo ''
\echo ' PUNTO 4a — Índices con baja o nula utilización'

SELECT
    s.relname                          AS tabla,
    s.indexrelname                     AS indice,
    s.idx_scan                         AS veces_usado,
    s.idx_tup_read                     AS filas_leidas,
    pg_size_pretty(pg_relation_size(i.indexrelid)) AS tamaño
FROM pg_stat_user_indexes s
JOIN pg_index i ON i.indexrelid = s.indexrelid
WHERE s.schemaname = 'public'
  AND s.idx_scan < 5                    -- menos de 5 usos
  AND NOT i.indisprimary
ORDER BY s.idx_scan ASC, pg_relation_size(i.indexrelid) DESC;


\echo ''
\echo ' PUNTO 4b — Índices posiblemente redundantes'

-- Detecta índices cuya primera columna es prefijo de otro índice más largo en la misma tabla 
SELECT
    a.tablename                              AS tabla,
    a.indexname                              AS indice_redundante,
    a.indexdef                               AS def_redundante,
    b.indexname                              AS indice_que_lo_cubre,
    b.indexdef                               AS def_cobertura
FROM pg_indexes a
JOIN pg_indexes b
  ON  a.tablename  = b.tablename
  AND a.indexname != b.indexname
  AND b.indexdef LIKE '%(' || (
        regexp_replace(
            regexp_replace(a.indexdef, '.* USING \w+ ON \w+ \(', ''),
            '[,\)].*', ''
        )
      ) || '%'
  AND length(b.indexdef) > length(a.indexdef)  -- b es más específico
WHERE a.schemaname = 'public'
  AND a.indexname NOT LIKE '%_pkey'
ORDER BY a.tablename, a.indexname;


\echo ''
\echo ' PUNTO 4c — Cardinalidad de columnas indexadas'
\echo ' (si n_distinct es bajo el índice probablemente no ayude)'

SELECT
    tablename                          AS tabla,
    attname                            AS columna,
    n_distinct,
    CASE
        WHEN n_distinct > 0 THEN n_distinct::text
        ELSE 'fracción: ' || abs(n_distinct)::text
    END                                AS interpretacion,
    correlation                        AS correlacion_fisica
FROM pg_stats
WHERE tablename IN ('clientes','ordenes','detalle_ordenes')
  AND attname IN ('email','ciudad','pais','estado','cliente_id','producto_id')
ORDER BY tablename, abs(n_distinct) ASC;