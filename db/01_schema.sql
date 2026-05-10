-- ============================================================
--  BD AVANZADA — Actividad: Índices
--  Script 01: Creación del schema (SIN índices intencional)
--
--  IMPORTANTE: Los índices se agregan en el script 03.
--  Esto nos permite medir el impacto real antes/después.
-- ============================================================

-- Limpieza previa (orden inverso por FK)
DROP TABLE IF EXISTS detalle_ordenes CASCADE;
DROP TABLE IF EXISTS ordenes          CASCADE;
DROP TABLE IF EXISTS productos        CASCADE;
DROP TABLE IF EXISTS clientes         CASCADE;


-- ============================================================
--  TABLA: clientes
--  ~100.000 filas | búsquedas por email, ciudad, apellido
-- ============================================================
CREATE TABLE clientes (
    id               SERIAL          PRIMARY KEY,
    nombre           VARCHAR(50)     NOT NULL,
    apellido         VARCHAR(50)     NOT NULL,
    email            VARCHAR(100)    NOT NULL,
    fecha_nacimiento DATE,
    ciudad           VARCHAR(50),
    pais             VARCHAR(30)     NOT NULL DEFAULT 'Argentina'
);


-- ============================================================
--  TABLA: productos
--  ~10.000 filas | filtros por categoría, rango de precio
-- ============================================================
CREATE TABLE productos (
    id        SERIAL          PRIMARY KEY,
    nombre    VARCHAR(100)    NOT NULL,
    categoria VARCHAR(50)     NOT NULL,
    precio    NUMERIC(10,2)   NOT NULL CHECK (precio > 0),
    stock     INTEGER         NOT NULL CHECK (stock >= 0)
);


-- ============================================================
--  TABLA: ordenes
--  ~500.000 filas | consultas por fecha, estado, cliente
-- ============================================================
CREATE TABLE ordenes (
    id              SERIAL          PRIMARY KEY,
    cliente_id      INTEGER         NOT NULL,
    fecha           TIMESTAMP       NOT NULL,
    estado          VARCHAR(20)     NOT NULL
                        CHECK (estado IN ('pendiente','procesando',
                                          'enviado','entregado','cancelado')),
    total           NUMERIC(12,2),
    direccion_envio TEXT
);


-- ============================================================
--  TABLA: detalle_ordenes
--  ~1.500.000 filas | tabla más grande; joins y agregaciones
-- ============================================================
CREATE TABLE detalle_ordenes (
    id              SERIAL          PRIMARY KEY,
    orden_id        INTEGER         NOT NULL,
    producto_id     INTEGER         NOT NULL,
    cantidad        INTEGER         NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2)   NOT NULL CHECK (precio_unitario > 0)
);