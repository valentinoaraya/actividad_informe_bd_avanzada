-- ============================================================
--  BD AVANZADA — Actividad: Índices
--  Script 03: Consultas BASE (sin índices)
--
--  INSTRUCCIONES:
--  1. Ejecutar ANTES de crear cualquier índice.
--  2. Capturar la salida completa para el informe:
--       \o resultados_sin_indices.txt
--       \i 03_baseline_sin_indices.sql
--       \o
--  3. Guardar las métricas: "actual time", "rows", "Buffers"
-- ============================================================


-- Limpiamos cache de PostgreSQL entre consultas para medir I/O real
-- (requiere superusuario — omitir si da error de permisos)
-- DISCARD ALL;

\echo '======================================================'
\echo ' CONSULTA 1 — Búsqueda puntual por email (alta selectividad)'
\echo ' Tipo esperado SIN índice: Seq Scan'
\echo '======================================================'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id, nombre, apellido, email, ciudad
FROM clientes
WHERE email = 'usuario5000@gmail.com';


\echo ''
\echo '======================================================'
\echo ' CONSULTA 2 — Rango de fechas en ordenes (selectividad media)'
\echo ' Tipo esperado SIN índice: Seq Scan'
\echo '======================================================'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT id, cliente_id, fecha, estado, total
FROM ordenes
WHERE fecha BETWEEN '2023-06-01' AND '2023-06-30';


\echo ''
\echo '======================================================'
\echo ' CONSULTA 3 — Filtro por estado (baja selectividad ~8%)'
\echo ' Tipo esperado SIN índice: Seq Scan'
\echo '======================================================'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT estado, COUNT(*) AS cantidad, ROUND(AVG(total),2) AS ticket_promedio
FROM ordenes
WHERE estado = 'pendiente'
GROUP BY estado;


\echo ''
\echo '======================================================'
\echo ' CONSULTA 4 — JOIN clientes → ordenes (sin FK index)'
\echo ' Tipo esperado SIN índice: Hash Join + Seq Scan'
\echo '======================================================'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT c.nombre, c.apellido, c.ciudad,
       COUNT(o.id)       AS total_ordenes,
       ROUND(SUM(o.total),2) AS facturado_total
FROM clientes c
JOIN ordenes o ON o.cliente_id = c.id
WHERE c.ciudad = 'Mendoza'
GROUP BY c.id, c.nombre, c.apellido, c.ciudad
ORDER BY facturado_total DESC
LIMIT 20;


\echo ''
\echo '======================================================'
\echo ' CONSULTA 5 — Agregación en detalle_ordenes'
\echo ' (tabla de 1.5M filas — candidata a Index Only Scan)'
\echo ' Tipo esperado SIN índice: Seq Scan + HashAggregate'
\echo '======================================================'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT producto_id,
       COUNT(*)        AS veces_vendido,
       SUM(cantidad)   AS unidades_totales,
       ROUND(AVG(precio_unitario), 2) AS precio_promedio
FROM detalle_ordenes
WHERE producto_id = 3500
GROUP BY producto_id;


\echo ''
\echo '======================================================'
\echo ' RESUMEN DE TAMAÑOS (referencia para Punto 3)'
\echo '======================================================'

SELECT
    relname                                              AS tabla,
    to_char(n_live_tup, '999,999,999')                  AS filas,
    pg_size_pretty(pg_relation_size(oid))                AS tamaño_datos,
    pg_size_pretty(pg_indexes_size(oid))                 AS tamaño_indices,
    pg_size_pretty(pg_total_relation_size(oid))          AS tamaño_total
FROM pg_stat_user_tables
JOIN pg_class USING (relname)
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(oid) DESC;