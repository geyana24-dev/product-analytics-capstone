/*CREATE TABLE transactions (
    date_time TIMESTAMP,
    receipt_num VARCHAR(50),
    category VARCHAR(50),
    full_name VARCHAR(200),
    amount_full VARCHAR(50),
    amount_discount VARCHAR(50),
    customer_id VARCHAR(50),
    year1 VARCHAR(10),
    month1 VARCHAR(10),
    amount_clean FLOAT,
    date_only TIMESTAMP);*/
	/*WITH first_purchase AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(date_time)) AS cohort_month
    FROM transactions
    GROUP BY customer_id
)
SELECT *
FROM first_purchase;*/ -- определяем первый месяц покупки для создания когортного анализа
-- Для каждой покупки определяем когорту и месяц активности
   /*WITH first_purchase AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(date_time)) AS cohort_month
    FROM transactions
    GROUP BY customer_id
)
SELECT
    t.customer_id,
    fp.cohort_month,
    DATE_TRUNC('month', t.date_time) AS activity_month
FROM transactions t
JOIN first_purchase fp
    ON t.customer_id = fp.customer_id;*/
--Считаем номер месяца относительно когорты
/*WITH first_purchase AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(date_time)) AS cohort_month
    FROM transactions
    GROUP BY customer_id
)
SELECT
    fp.cohort_month,
    DATE_TRUNC('month', t.date_time) AS activity_month,
    (
        EXTRACT(YEAR FROM AGE(DATE_TRUNC('month', t.date_time), fp.cohort_month)) * 12
        +
        EXTRACT(MONTH FROM AGE(DATE_TRUNC('month', t.date_time), fp.cohort_month))
    ) AS cohort_index,
    COUNT(DISTINCT t.customer_id) AS users_count
FROM transactions t
JOIN first_purchase fp
    ON t.customer_id = fp.customer_id
GROUP BY 1,2,3
ORDER BY 1,3;*/
--Размер каждой когорты
/*WITH first_purchase AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(date_time)) AS cohort_month
    FROM transactions
    GROUP BY customer_id
)
SELECT
    cohort_month,
    COUNT(DISTINCT customer_id) AS cohort_size
FROM first_purchase
GROUP BY cohort_month
ORDER BY cohort_month;*/
-- View для когорты
CREATE OR REPLACE VIEW vw_customer_cohorts AS
WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(date_time) AS first_purchase_date,
        DATE_TRUNC('month', MIN(date_time)) AS cohort_month
    FROM transactions
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
)
SELECT *
FROM first_purchase;
-- Retention
/*WITH first_purchase AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(date_time)) AS cohort_month
    FROM transactions
    GROUP BY customer_id
),

retention AS (
    SELECT
        fp.cohort_month,

        (
            EXTRACT(YEAR FROM AGE(
                DATE_TRUNC('month', t.date_time),
                fp.cohort_month
            )) * 12
            +
            EXTRACT(MONTH FROM AGE(
                DATE_TRUNC('month', t.date_time),
                fp.cohort_month
            ))
        ) AS period_number,

        COUNT(DISTINCT t.customer_id) AS active_users
    FROM transactions t
    JOIN first_purchase fp
        ON t.customer_id = fp.customer_id
    GROUP BY 1,2
),

cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS users_count
    FROM first_purchase
    GROUP BY cohort_month
)

SELECT
    r.cohort_month,
    r.period_number,
    r.active_users,
    ROUND(
        100.0 * r.active_users / c.users_count,
        2
    ) AS retention_rate
FROM retention r
JOIN cohort_size c
    ON r.cohort_month = c.cohort_month
ORDER BY 1,2;*/
-- View для Retention
CREATE OR REPLACE VIEW vw_retention AS
WITH first_purchase AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(date_time)) AS cohort_month
    FROM transactions
    GROUP BY customer_id
),

retention AS (
    SELECT
        fp.cohort_month,

        (
            EXTRACT(YEAR FROM AGE(
                DATE_TRUNC('month', t.date_time),
                fp.cohort_month
            )) * 12
            +
            EXTRACT(MONTH FROM AGE(
                DATE_TRUNC('month', t.date_time),
                fp.cohort_month
            ))
        ) AS period_number,

        COUNT(DISTINCT t.customer_id) AS active_users
    FROM transactions t
    JOIN first_purchase fp
        ON t.customer_id = fp.customer_id
    GROUP BY 1,2
),

cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM first_purchase
    GROUP BY cohort_month
)

SELECT
    r.cohort_month,
    r.period_number,
    r.active_users,
    c.cohort_size,

    ROUND(
        100.0 * r.active_users / c.cohort_size,
        2
    ) AS retention_rate
FROM retention r
JOIN cohort_size c
    ON r.cohort_month = c.cohort_month;

--RFM
/*WITH rfm_base AS (
    SELECT
        customer_id,

        CURRENT_DATE - MAX(date_time::date) AS recency,

        COUNT(DISTINCT receipt_num) AS frequency,

        SUM(amount_clean) AS monetary
    FROM transactions
    GROUP BY customer_id
)

SELECT *
FROM rfm_base;*/
-- Присвоение баллов 
/*WITH rfm_base AS (
    SELECT
        customer_id,
        CURRENT_DATE - MAX(date_time::date) AS recency,
        COUNT(DISTINCT receipt_num) AS frequency,
        SUM(amount_clean) AS monetary
    FROM transactions
    GROUP BY customer_id
),

rfm_scores AS (
    SELECT
        customer_id,

        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,

        NTILE(5) OVER (ORDER BY frequency) AS f_score,

        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM rfm_base
)

SELECT *
FROM rfm_scores;*/
-- Сегментация клиентов
/*WITH rfm_base AS (
    SELECT
        customer_id,
        CURRENT_DATE - MAX(date_time::date) AS recency,
        COUNT(DISTINCT receipt_num) AS frequency,
        SUM(amount_clean) AS monetary
    FROM transactions
    GROUP BY customer_id
),

rfm_scores AS (
    SELECT
        customer_id,

        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,

        NTILE(5) OVER (ORDER BY frequency) AS f_score,

        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM rfm_base
)

SELECT
    *,
    CASE
        WHEN r_score >= 4
         AND f_score >= 4
         AND m_score >= 4
            THEN 'Champions'

        WHEN r_score >= 4
         AND f_score >= 3
            THEN 'Loyal'

        WHEN r_score <= 2
            THEN 'At Risk'

        ELSE 'Others'
    END AS segment
FROM rfm_scores;*/
--View для RFM
CREATE OR REPLACE VIEW vw_rfm AS
WITH rfm_base AS (
    SELECT
        customer_id,
        CURRENT_DATE - MAX(date_time::date) AS recency,
        COUNT(DISTINCT receipt_num) AS frequency,
        SUM(amount_clean) AS monetary
    FROM transactions
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT
        customer_id,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM rfm_base
)
SELECT
    *,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 3 THEN 'Loyal'
        WHEN r_score <= 2 THEN 'At Risk'
        ELSE 'Others'
    END AS segment
FROM rfm_scores;