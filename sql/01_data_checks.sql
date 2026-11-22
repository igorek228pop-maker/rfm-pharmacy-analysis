-- 01_data_checks.sql
-- Проверки качества данных: таблица bonuscheques, БД Apteka

-- 1. Формат карт: строки, карты и чеки с 13-значным номером и без него
SELECT CASE WHEN card ~ '^\d{13}$' THEN '13 цифр' ELSE 'другое' END AS card_type,
       COUNT(*)               AS rows_cnt,
       COUNT(DISTINCT card)   AS cards,
       COUNT(DISTINCT doc_id) AS docs
FROM bonuscheques
GROUP BY 1;

-- 2. Период данных, число чеков, неположительные суммы (возвраты)
SELECT MIN(datetime)           AS first_dt,
       MAX(datetime)           AS last_dt,
       COUNT(*)                AS rows_cnt,
       COUNT(DISTINCT doc_id)  AS docs,
       COUNT(*) FILTER (WHERE summ_with_disc <= 0) AS non_positive
FROM bonuscheques;

-- 3. Что находится в исключённых значениях card (длина и пример)
SELECT LENGTH(card) AS card_len,
       COUNT(*)     AS rows_cnt,
       MIN(card)    AS example
FROM bonuscheques
WHERE NOT card ~ '^\d{13}$'
GROUP BY 1
ORDER BY 2 DESC;
