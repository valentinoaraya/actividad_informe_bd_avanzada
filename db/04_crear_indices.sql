-- ============================================================
--  BD AVANZADA — Actividad: Índices
--  Script 04: Creación de índices
--
--  EJECUTAR DESPUÉS del script 03 (ya tenés los resultados base).
--
--  Incluye índices útiles Y algunos redundantes/ineficientes
--  a propósito — para cubrir el Punto 4 (detección de problemas).
-- ============================================================


-- ============================================================
--  BLOQUE A — Índices útiles y justificados
-- ============================================================

-- A1: Búsqueda puntual de cliente por email (Q1)
--     Alta selectividad → candidato perfecto a Index Scan
CREATE INDEX idx_clientes_email
    ON clientes (email);

-- A2: Rango de fechas en órdenes (Q2)
--     B-tree es ideal para BETWEEN, <, >, ORDER BY fecha
CREATE INDEX idx_ordenes_fecha
    ON ordenes (fecha);

-- A3: FK de órdenes → clientes (Q4 JOIN)
--     Sin este índice el JOIN hace Seq Scan en ordenes por cada cliente
CREATE INDEX idx_ordenes_cliente_id
    ON ordenes (cliente_id);

-- A4: FK de detalle_ordenes → ordenes
--     Acelera joins y búsquedas de ítems de una orden
CREATE INDEX idx_detalle_ordenes_orden_id
    ON detalle_ordenes (orden_id);

-- A5: Índice compuesto (estado, fecha) para consultas filtro + rango
--     Permite Index Scan en: WHERE estado = 'X' AND fecha BETWEEN ...
CREATE INDEX idx_ordenes_estado_fecha
    ON ordenes (estado, fecha);

-- A6: Índice de cobertura en detalle_ordenes (Q5)
--     Cubre (producto_id, cantidad, precio_unitario) → Index Only Scan
--     PostgreSQL no necesita ir al heap para resolver la consulta
CREATE INDEX idx_detalle_cobertura_producto
    ON detalle_ordenes (producto_id, cantidad, precio_unitario);


-- ============================================================
--  BLOQUE B — Índices REDUNDANTES / INEFICIENTES (a propósito)
--  Punto 4 del informe: detectar y justificar su eliminación
-- ============================================================

-- B1: REDUNDANTE — ya existe idx_ordenes_estado_fecha (A5)
--     Un índice compuesto (estado, fecha) cubre consultas solo por estado
--     Este índice simple es completamente superfluo
CREATE INDEX idx_ordenes_estado_redundante
    ON ordenes (estado);

-- B2: REDUNDANTE — idx_ordenes_cliente_id (A3) ya empieza por cliente_id
--     Un índice compuesto que empieza con la misma columna cubre al simple
--     (en este caso son el mismo, pero si hubiera uno compuesto, sobraría)
--     Lo dejamos igual para demostrar la detección con pg_stats
CREATE INDEX idx_ordenes_cliente_fecha_compuesto
    ON ordenes (cliente_id, fecha);
-- NOTA: idx_ordenes_cliente_id ahora es redundante respecto a este

-- B3: INEFICIENTE — índice en columna de muy baja cardinalidad
--     "pais" tiene solo 1 valor ('Argentina') → índice inútil
--     PostgreSQL preferirá Seq Scan siempre
CREATE INDEX idx_clientes_pais_inutil
    ON clientes (pais);

-- B4: HASH en columna que ya tiene B-tree (A1)
--     Hash es más rápido en igualdad exacta, pero B-tree ya lo cubre
--     y además soporta LIKE, ORDER BY, rangos — el hash no.
--     Tener ambos es redundante y duplica el costo de mantenimiento.
CREATE INDEX idx_clientes_email_hash
    ON clientes USING HASH (email);


-- ============================================================
--  VERIFICACIÓN — listar todos los índices creados
-- ============================================================
SELECT
    indexname                               AS indice,
    tablename                               AS tabla,
    indexdef                                AS definicion
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname NOT LIKE '%_pkey'          -- excluimos PKs
ORDER BY tablename, indexname;