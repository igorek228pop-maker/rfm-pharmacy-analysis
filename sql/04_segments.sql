-- 04_segments.sql
-- Итоговая сегментация: баллы R, F, M и 9 сегментов.
-- Правила проверяются сверху вниз, срабатывает первое подходящее.

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
),
scored AS (
    SELECT card, recency, frequency, monetary,
           CASE WHEN recency <= 36 THEN 3 WHEN recency <= 75 THEN 2 ELSE 1 END AS r,
           CASE WHEN frequency >= 4 THEN 3 WHEN frequency >= 2 THEN 2 ELSE 1 END AS f,
           CASE WHEN monetary >= 2305 THEN 3 WHEN monetary >= 884 THEN 2 ELSE 1 END AS m
    FROM rfm
),
segmented AS (
    SELECT *,
           CASE
               WHEN r = 3 AND f = 3 AND m = 3  THEN '1. VIP'
               WHEN f = 3 AND r >= 2           THEN '2. Лояльные'
               WHEN r = 3 AND f = 1            THEN '3. Новички'
               WHEN r = 3 AND f = 2            THEN '4. Растущие'
               WHEN r = 2 AND f <= 2           THEN '5. Остывающие'
               WHEN r = 1 AND f = 3 AND m = 3  THEN '6. Уходящие постоянные'
               WHEN r = 1 AND m = 3            THEN '7. Уходящие с крупным чеком'
               WHEN m = 1                      THEN '8. Спящие (M=1)'
               ELSE                                 '9. Спящие (M=2)'
           END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                                                     AS clients,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)           AS pct_clients,
       ROUND(SUM(monetary))                                         AS revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_revenue,
       ROUND(SUM(monetary) / COUNT(*))                              AS revenue_per_client,
       ROUND(SUM(monetary) / SUM(frequency))                        AS avg_check,
       ROUND(AVG(recency))                                          AS avg_recency
FROM segmented
GROUP BY segment
ORDER BY segment;
