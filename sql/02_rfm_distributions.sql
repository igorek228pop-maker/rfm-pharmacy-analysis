-- 02_rfm_distributions.sql
-- Расчёт R, F, M по клиентам и их распределения (перцентили, частоты)
-- Дата отсчёта Recency: 2022-06-10 (день после последней транзакции в данных)
-- Monetary считается по summ_with_disc (сумма с учётом скидки)

-- 1. Перцентили R, F, M
WITH clean AS (
    SELECT card, doc_id, datetime, summ_with_disc
    FROM bonuscheques
    WHERE card ~ '^\d{13}$'
      AND datetime >= '2021-07-01' AND datetime < '2022-07-01'
),
checks AS (
    SELECT card, doc_id, MAX(datetime) AS dt, SUM(summ_with_disc) AS check_sum
    FROM clean
    GROUP BY card, doc_id
),
rfm AS (
    SELECT card,
           DATE '2022-06-10' - MAX(dt)::date AS recency,
           COUNT(*)                          AS frequency,
           SUM(check_sum)                    AS monetary
    FROM checks
    GROUP BY card
)
SELECT 'recency' AS metric,
       MIN(recency) AS min, ROUND(AVG(recency), 1) AS avg,
       PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY recency) AS p10,
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY recency) AS p25,
       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY recency) AS median,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY recency) AS p75,
       PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY recency) AS p90,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY recency) AS p95,
       MAX(recency) AS max
FROM rfm
UNION ALL
SELECT 'frequency', MIN(frequency), ROUND(AVG(frequency), 1),
       PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY frequency),
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY frequency),
       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY frequency),
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY frequency),
       PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY frequency),
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY frequency),
       MAX(frequency)
FROM rfm
UNION ALL
SELECT 'monetary', MIN(monetary), ROUND(AVG(monetary), 1),
       PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY monetary),
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY monetary),
       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY monetary),
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY monetary),
       PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY monetary),
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY monetary),
       MAX(monetary)
FROM rfm;

-- 2. Распределение по числу чеков
-- (вставьте те же блоки clean, checks, rfm перед SELECT)
-- SELECT frequency,
--        COUNT(*) AS clients,
--        ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
-- FROM rfm
-- GROUP BY frequency
-- ORDER BY frequency;
