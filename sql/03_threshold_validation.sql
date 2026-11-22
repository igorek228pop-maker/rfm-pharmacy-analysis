-- 03_threshold_validation.sql
-- Обоснование порогов: интервалы между покупками, ABC по выручке, проверка размеров групп

-- 1. Интервалы между последовательными покупками клиента (дни)
WITH clean AS (
    SELECT card, doc_id, datetime
    FROM bonuscheques
    WHERE card ~ '^\d{13}$'
      AND datetime >= '2021-07-01' AND datetime < '2022-07-01'
),
checks AS (
    SELECT card, doc_id, MAX(datetime)::date AS dt
    FROM clean GROUP BY card, doc_id
),
gaps AS (
    SELECT dt - LAG(dt) OVER (PARTITION BY card ORDER BY dt) AS gap_days
    FROM checks
)
SELECT COUNT(gap_days) AS gaps_cnt,
       PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY gap_days) AS median_gap,
       PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY gap_days) AS p75_gap,
       PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY gap_days) AS p90_gap
FROM gaps
WHERE gap_days > 0;

-- 2. ABC-анализ клиентов по выручке (A: до 80% накопленной выручки, B: до 95%, C: остальные)
WITH clean AS (
    SELECT card, doc_id, datetime, summ_with_disc
    FROM bonuscheques
    WHERE card ~ '^\d{13}$'
      AND datetime >= '2021-07-01' AND datetime < '2022-07-01'
),
checks AS (
    SELECT card, doc_id, MAX(datetime) AS dt, SUM(summ_with_disc) AS check_sum
    FROM clean GROUP BY card, doc_id
),
rfm AS (
    SELECT card,
           DATE '2022-06-10' - MAX(dt)::date AS recency,
           COUNT(*)                          AS frequency,
           SUM(check_sum)                    AS monetary
    FROM checks GROUP BY card
),
abc AS (
    SELECT card, monetary,
           SUM(monetary) OVER (ORDER BY monetary DESC) / SUM(monetary) OVER () AS cum_share,
           COUNT(*) OVER () AS total
    FROM rfm
)
SELECT CASE WHEN cum_share <= 0.8  THEN 'A'
            WHEN cum_share <= 0.95 THEN 'B' ELSE 'C' END AS grp,
       COUNT(*) AS clients,
       ROUND(100.0 * COUNT(*) / MAX(total), 1) AS pct_clients,
       MIN(monetary) AS min_monetary
FROM abc
GROUP BY 1
ORDER BY 1;

-- 3. Проверка размеров групп 1/2/3 по каждому признаку (доля клиентов и выручки)
WITH clean AS (
    SELECT card, doc_id, datetime, summ_with_disc
    FROM bonuscheques
    WHERE card ~ '^\d{13}$'
      AND datetime >= '2021-07-01' AND datetime < '2022-07-01'
),
checks AS (
    SELECT card, doc_id, MAX(datetime) AS dt, SUM(summ_with_disc) AS check_sum
    FROM clean GROUP BY card, doc_id
),
rfm AS (
    SELECT card,
           DATE '2022-06-10' - MAX(dt)::date AS recency,
           COUNT(*)                          AS frequency,
           SUM(check_sum)                    AS monetary
    FROM checks GROUP BY card
),
scored AS (
    SELECT recency, frequency, monetary,
           CASE WHEN recency <= 36 THEN 3 WHEN recency <= 75 THEN 2 ELSE 1 END AS r,
           CASE WHEN frequency >= 4 THEN 3 WHEN frequency >= 2 THEN 2 ELSE 1 END AS f,
           CASE WHEN monetary >= 2305 THEN 3 WHEN monetary >= 884 THEN 2 ELSE 1 END AS m
    FROM rfm
)
SELECT 'R' AS dim, r AS score, COUNT(*) AS clients,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)           AS pct_clients,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_revenue
FROM scored GROUP BY r
UNION ALL
SELECT 'F', f, COUNT(*),
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1),
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1)
FROM scored GROUP BY f
UNION ALL
SELECT 'M', m, COUNT(*),
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1),
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1)
FROM scored GROUP BY m
ORDER BY dim, score;
