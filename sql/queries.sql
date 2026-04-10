-- =====================================
-- DATA CLEANING & PREPARATION
-- =====================================

-- Clean base table
CREATE OR REPLACE TABLE `pollo-listo-base-de-xc.pollolistosalesanalytics.venta_comandas` AS
SELECT
  CAST(foliocuenta AS STRING) AS foliocuenta,
  orden,
  fechaapertura AS fecha_hora,
  claveproducto AS producto_id,
  descripcion AS producto,
  cantidad,
  CAST(importe AS FLOAT64) AS total
FROM `pollo-listo-base-de-xc.pollolistosalesanalytics.venta_comandas`;

-- Final table with date & hour
CREATE OR REPLACE TABLE `pollo-listo-base-de-xc.pollolistosalesanalytics.ventas_final` AS
SELECT
  *,
  DATE(fecha_hora) AS fecha,
  EXTRACT(HOUR FROM fecha_hora) AS hora
FROM `pollo-listo-base-de-xc.pollolistosalesanalytics.venta_comandas`;

-- =====================================
-- KPIs
-- =====================================

SELECT
  COUNT(DISTINCT foliocuenta) AS tickets,
  SUM(total) AS total_revenue,
  SUM(total) / COUNT(DISTINCT foliocuenta) AS avg_ticket
FROM `pollo-listo-base-de-xc.pollolistosalesanalytics.ventas_final`;

-- =====================================
-- BEST & WORST DAY (excluding opening)
-- =====================================

(
SELECT 
  'Best Day (excluding opening)' AS type,
  fecha,
  SUM(total) AS revenue
FROM `pollo-listo-base-de-xc.pollolistosalesanalytics.ventas_final`
GROUP BY fecha
ORDER BY revenue DESC
LIMIT 1 OFFSET 1
)

UNION ALL

(
SELECT 
  'Worst Day' AS type,
  fecha,
  SUM(total) AS revenue
FROM `pollo-listo-base-de-xc.pollolistosalesanalytics.ventas_final`
GROUP BY fecha
ORDER BY revenue ASC
LIMIT 1
);

-- =====================================
-- SALES BY HOUR
-- =====================================

SELECT
  hora,
  SUM(total) AS revenue,
  ROUND(SUM(total) / SUM(SUM(total)) OVER() * 100, 2) AS percentage
FROM `pollo-listo-base-de-xc.pollolistosalesanalytics.ventas_final`
GROUP BY hora
ORDER BY hora;

-- =====================================
-- TOP PRODUCTS
-- =====================================

SELECT
  producto,
  SUM(cantidad) AS units_sold,
  SUM(total) AS revenue
FROM `pollo-listo-base-de-xc.pollolistosalesanalytics.ventas_final`
GROUP BY producto
ORDER BY revenue DESC
LIMIT 10;

-- =====================================
-- PARETO ANALYSIS
-- =====================================

SELECT
  producto,
  SUM(total) AS revenue,
  ROUND(SUM(total) / SUM(SUM(total)) OVER() * 100, 2) AS percentage,
  ROUND(
    SUM(SUM(total)) OVER(ORDER BY SUM(total) DESC) 
    / SUM(SUM(total)) OVER() * 100, 2
  ) AS cumulative_percentage
FROM `pollo-listo-base-de-xc.pollolistosalesanalytics.ventas_final`
GROUP BY producto
ORDER BY revenue DESC;

-- =====================================
-- SALES BY DAY OF WEEK
-- =====================================

SELECT
  FORMAT_DATE('%A', fecha) AS day_of_week,
  EXTRACT(DAYOFWEEK FROM fecha) AS order_day,
  SUM(total) AS revenue,
  ROUND(SUM(total) / SUM(SUM(total)) OVER() * 100, 2) AS percentage
FROM `pollo-listo-base-de-xc.pollolistosalesanalytics.ventas_final`
GROUP BY day_of_week, order_day
ORDER BY order_day;

-- =====================================
-- AVERAGE TICKET BY DAY OF WEEK
-- =====================================

SELECT
  FORMAT_DATE('%A', fecha) AS day_of_week,
  EXTRACT(DAYOFWEEK FROM fecha) AS order_day,
  SUM(total) / COUNT(DISTINCT foliocuenta) AS avg_ticket
FROM `pollo-listo-base-de-xc.pollolistosalesanalytics.ventas_final`
GROUP BY day_of_week, order_day
ORDER BY order_day;

-- =====================================
-- PRODUCT COMBINATIONS (MAIN + SIDES)
-- =====================================

WITH combinaciones AS (
  SELECT
    a.producto AS main_dish,
    b.producto AS side,
    COUNT(*) AS times_bought
  FROM `pollo-listo-base-de-xc.pollolistosalesanalytics.ventas_final` a
  JOIN `pollo-listo-base-de-xc.pollolistosalesanalytics.ventas_final` b
    ON a.foliocuenta = b.foliocuenta
    AND a.producto != b.producto

  WHERE 
    (
      LOWER(a.producto) LIKE '%pollo%' OR
      LOWER(a.producto) LIKE '%carne%' OR
      LOWER(a.producto) LIKE '%chamorro%' OR
      LOWER(a.producto) LIKE '%pechuga%' OR
      LOWER(a.producto) LIKE '%costilla%'
    )
    AND
    (
      LOWER(b.producto) = '1/2 lt sopa fria' OR
      LOWER(b.producto) = '1/2 lt arroz rojo' OR
      LOWER(b.producto) = '1/2 lt pure de papa' OR
      LOWER(b.producto) = 'guacamole' OR
      LOWER(b.producto) = '1/2 lt frijoles charros'
    )

  GROUP BY main_dish, side
),

ranking AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY main_dish ORDER BY times_bought DESC) AS rank
  FROM combinaciones
)

SELECT
  main_dish,
  side,
  times_bought
FROM ranking
WHERE rank = 1
ORDER BY times_bought DESC;
