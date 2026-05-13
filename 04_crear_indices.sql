--  Script 04: Creación de índices

--  BLOQUE A — Índices útiles y justificados

-- Búsqueda puntual de cliente por email
--      Creamos un índice para el email de los clientes
--      Tiene alta selectividad ya que todos los emails son distintos
CREATE INDEX idx_clientes_email
    ON clientes (email);

-- A2: Rango de fechas en órdenes
--      Lo utilizamos para encontrar órdenes que estén dentro de un rango de fechas,
--      Es bueno para comparaciones <, >, etc.
CREATE INDEX idx_ordenes_fecha
    ON ordenes (fecha);

-- A3: FK de órdenes a clientes
--     Sin este índice el JOIN hace Seq Scan en ordenes por cada cliente
--     Con el índice encontramos rápidamente las órdenes de cada cliente.
CREATE INDEX idx_ordenes_cliente_id
    ON ordenes (cliente_id);

-- A4: FK de detalle_ordenes a ordenes
--     Lo mismo que el anterior pero ahora de detalle_ó]ordenes a ordenes
CREATE INDEX idx_detalle_ordenes_orden_id
    ON detalle_ordenes (orden_id);

-- A5: Índice compuesto (estado, fecha) para consultas filtro + rango
--     Permite Index Scan en: WHERE estado = 'X' AND fecha BETWEEN ...
--     Entonces nos trae rápidamente las ordenes que tengan un estado específico en un rango de fechas determinado.
CREATE INDEX idx_ordenes_estado_fecha
    ON ordenes (estado, fecha);

-- A6: Índice de cobertura en detalle_ordenes
--     Cubre (producto_id, cantidad, precio_unitario) → Index Only Scan
--     Incluye todas las columnas necesarias para ciertas consultas, por lo que SQL no tiene que ir a la tabla real a buscar los datos.
CREATE INDEX idx_detalle_cobertura_producto
    ON detalle_ordenes (producto_id, cantidad, precio_unitario);


--  BLOQUE B — Índices REDUNDANTES / INEFICIENTES (a propósito)

-- B1: REDUNDANTE — ya existe idx_ordenes_estado_fecha (A5)
--     Un índice compuesto (estado, fecha) cubre consultas solo por estado
CREATE INDEX idx_ordenes_estado_redundante
    ON ordenes (estado);

-- B2: REDUNDANTE — idx_ordenes_cliente_id (A3) ya empieza por cliente_id
--     Un índice compuesto que empieza con la misma columna cubre al simple
--     (en este caso son el mismo, pero si hubiera uno compuesto, sobraría)
--     Lo dejamos igual para demostrar la detección con pg_stats
CREATE INDEX idx_ordenes_cliente_fecha_compuesto
    ON ordenes (cliente_id, fecha);

-- B3: INEFICIENTE — índice en columna de muy baja cardinalidad
--     "pais" tiene solo 1 valor ('Argentina') → índice inútil
--     PostgreSQL preferirá Seq Scan siempre
CREATE INDEX idx_clientes_pais_inutil
    ON clientes (pais);

-- B4: HASH en columna que ya tiene B-tree (A1)
--     Hash es más rápido en igualdad exacta, pero B-tree ya lo cubre y además soporta LIKE, ORDER BY, rangos.
CREATE INDEX idx_clientes_email_hash
    ON clientes USING HASH (email);


--  VERIFICACIÓN
SELECT
    indexname                               AS indice,
    tablename                               AS tabla,
    indexdef                                AS definicion
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname NOT LIKE '%_pkey'
ORDER BY tablename, indexname;