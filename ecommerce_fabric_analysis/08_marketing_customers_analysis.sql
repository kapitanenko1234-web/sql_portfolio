-- 08_marketing_customers_analysis.sql
-- Анализ клиентов и маркетинга:  
-- 1.  Геоанализ клиентов по регионам.
-- 2. Повторные продажи по client_id (когортный анализ)
--    а. Определение когорт по месяцам первой покупки
--    б. Расчет Retention Rate (удержание) по месяцам
--    в. Анализ LTV (Lifetime Value) по когортам
--    г. Сравнение эффективности когорт
-- 3. Средний чек по клиенту.
-- 4. Сегментация клиентов по каналам.
-- 5. Определение перспективных регионов для рекламы.

-- 1. Геоанализ клиентов по регионам
SELECT 
    c.city,
    COUNT(DISTINCT c.client_id) as unique_clients,
    COUNT(s.sale_id) as total_orders,
    SUM(s.total_amount) as total_revenue,
    ROUND(AVG(s.total_amount)::numeric, 2) as avg_order_value
FROM fabric_analysis.fa_clean_clients c
JOIN fabric_analysis.fa_unified_sales s ON c.client_id = s.client_id
WHERE s.status = 'Завершен'
GROUP BY c.city
ORDER BY total_revenue DESC;
-- ВЫВОДЫ ПО ГЕОГРАФИИ:
-- 1. ТОП-3 ГОРОДА ПО ВЫРУЧКЕ:
-- Мытищи: 722K руб (107 клиентов)
-- Химки: 654K руб (87 клиентов) 
-- Люберцы: 635K руб (93 клиента)
-- 2. СРЕДНИЙ ЧЕК:
-- Максимум: Люберцы (770 руб) - самые платежеспособные
-- Минимум: Москва (706 руб) - более бюджетные покупки
-- 3. РАСПРЕДЕЛЕНИЕ:
-- Москва и МО: 8 городов-лидеров
-- Равномерное покрытие региона
-- Все города показывают стабильные показатели

-- 2. Повторные продажи по client_id
SELECT 
    client_id,
    COUNT(*) as total_orders,
    SUM(total_amount) as total_spent,
    ROUND(AVG(total_amount)::numeric, 2) as avg_order_value,
    MIN(date) as first_order_date,
    MAX(date) as last_order_date
FROM fabric_analysis.fa_unified_sales
WHERE status = 'Завершен'
GROUP BY client_id
HAVING COUNT(*) > 1
ORDER BY total_orders DESC
LIMIT 20;

-- a. Определение когорт по месяцам первой покупки
SELECT 
    client_id,
    TO_CHAR(MIN(date), 'YYYY-MM') as cohort_month,
    COUNT(*) as total_orders,
    SUM(total_amount) as total_lifetime_value
FROM fabric_analysis.fa_unified_sales
WHERE status = 'Завершен'
GROUP BY client_id
ORDER BY cohort_month, total_lifetime_value DESC;

-- Посмотрим на распределение когорт
SELECT 
    cohort_month,
    COUNT(*) as clients_count,
    ROUND(AVG(total_orders)::numeric, 2) as avg_orders_per_client,
    ROUND(AVG(total_lifetime_value)::numeric, 2) as avg_lifetime_value
FROM (
    SELECT 
        client_id,
        TO_CHAR(MIN(date), 'YYYY-MM') as cohort_month,
        COUNT(*) as total_orders,
        SUM(total_amount) as total_lifetime_value
    FROM fabric_analysis.fa_unified_sales
    WHERE status = 'Завершен'
    GROUP BY client_id
) as cohorts
GROUP BY cohort_month
ORDER BY cohort_month;

--    б. Расчет Retention Rate (удержание) по месяцам
WITH cohorts AS (
    SELECT 
        client_id,
        DATE_TRUNC('month', MIN(date)) as cohort_month
    FROM fabric_analysis.fa_unified_sales 
    WHERE status = 'Завершен'
    GROUP BY client_id
),
monthly_activity AS (
    SELECT 
        c.client_id,
        c.cohort_month,
        DATE_TRUNC('month', s.date) as activity_month,
        EXTRACT(MONTH FROM AGE(DATE_TRUNC('month', s.date), c.cohort_month)) as month_number
    FROM cohorts c
    JOIN fabric_analysis.fa_unified_sales s ON c.client_id = s.client_id
    WHERE s.status = 'Завершен'
)
SELECT 
    cohort_month,
    month_number,
    COUNT(DISTINCT client_id) as active_clients,
    ROUND((COUNT(DISTINCT client_id) * 100.0 / FIRST_VALUE(COUNT(DISTINCT client_id)) 
           OVER (PARTITION BY cohort_month ORDER BY month_number))::numeric, 2) as retention_rate
FROM monthly_activity
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number;

-- в. Анализ LTV (Lifetime Value) по когортам
-- Простой расчет LTV по когортам
SELECT 
    cohort_month,
    COUNT(*) as clients_count,
    ROUND(AVG(total_spent)::numeric, 2) as avg_ltv,
    ROUND(SUM(total_spent)::numeric, 2) as total_cohort_ltv
FROM (
    SELECT 
        client_id,
        TO_CHAR(MIN(date), 'YYYY-MM') as cohort_month,
        SUM(total_amount) as total_spent
    FROM fabric_analysis.fa_unified_sales
    WHERE status = 'Завершен'
    GROUP BY client_id
) as client_ltv
GROUP BY cohort_month
ORDER BY cohort_month;

-- Простое сравнение эффективности когорт
WITH client_cohorts AS (
    SELECT 
        client_id,
        TO_CHAR(MIN(date), 'YYYY-MM') as cohort_month,
        SUM(total_amount) as total_spent
    FROM fabric_analysis.fa_unified_sales
    WHERE status = 'Завершен'
    GROUP BY client_id
)
SELECT 
    cohort_month,
    COUNT(*) as clients_count,
    ROUND(AVG(total_spent)::numeric, 2) as avg_ltv,
    ROUND(SUM(total_spent)::numeric, 2) as total_ltv
FROM client_cohorts
GROUP BY cohort_month
ORDER BY avg_ltv DESC;
-- КЛЮЧЕВЫЕ НАХОДКИ:
-- 1.ЛУЧШИЕ КОГОРТЫ:
--    2018-04: LTV 7,309₽ (максимальный)
--    2018-03: LTV 7,276₽ + 420 клиентов (самая большая база)
--    2018-08: LTV 6,824₽ (стабильно высокий)
-- 2.RETENTION RATE:
--    Хорошее удержание: 40-60% через 6-12 месяцев
--    Стабильное ядро лояльных клиентов
--    Когорта 2018-03: 42% активны через 11 месяцев
-- 3.LTV АНАЛИЗ:
--    Ранние когорты (2018) значительно ценнее
--    Средний LTV: 7,309₽ (2018) vs 3,312₽ (2019) ▼ -55%
--    663 клиента 2018 года = 4.84 млн руб (66% выручки)
-- 4КРИТИЧЕСКИЕ ПРОБЛЕМЫ:
--    Катастрофическое падение притока: 420 → 1 клиент
--    Снижение LTV новых клиентов на 55%
--    Бизнес зависит от старых клиентов
-- РЕКОМЕНДАЦИИ:
-- СРОЧНО усилить привлечение новых клиентов
-- Сохранять лояльность "золотого фонда" 2018 года
-- Исследовать причины падения LTV новых клиентов

-- 3. Средний чек по клиенту
SELECT 
    ROUND(AVG(order_value)::numeric, 2) as avg_order_value_per_client,
    ROUND(MIN(order_value)::numeric, 2) as min_order_value,
    ROUND(MAX(order_value)::numeric, 2) as max_order_value
FROM (
    SELECT 
        client_id,
        AVG(total_amount) as order_value
    FROM fabric_analysis.fa_unified_sales
    WHERE status = 'Завершен'
    GROUP BY client_id
) as client_orders;


-- 4. Сегментация клиентов по каналам
SELECT 
    c.registration_channel,
    COUNT(DISTINCT c.client_id) as unique_clients,
    COUNT(s.sale_id) as total_orders,
    ROUND(SUM(s.total_amount)::numeric, 2) as total_revenue,
    ROUND(AVG(s.total_amount)::numeric, 2) as avg_order_value
FROM fabric_analysis.fa_clean_clients c
JOIN fabric_analysis.fa_unified_sales s ON c.client_id = s.client_id
WHERE s.status = 'Завершен'
GROUP BY c.registration_channel
ORDER BY total_revenue DESC;

-- 5. Перспективные регионы для рекламы
SELECT 
    city,
    COUNT(DISTINCT client_id) as current_clients,
    ROUND(SUM(total_amount)::numeric, 2) as total_revenue,
    -- Потенциал для роста (относительно лидера)
    ROUND((MAX(COUNT(DISTINCT client_id)) OVER() - COUNT(DISTINCT client_id))::numeric, 0) as growth_potential_clients,
    ROUND((MAX(SUM(total_amount)) OVER() - SUM(total_amount))::numeric, 2) as growth_potential_revenue
FROM fabric_analysis.fa_unified_sales
WHERE status = 'Завершен'
GROUP BY city
ORDER BY growth_potential_revenue DESC;

-- СРЕДНИЙ ЧЕК ПО КЛИЕНТУ:
--   Средний: 735₽
--   Минимальный: 200₽
--  Максимальный: 1,469₽
--   Стабильный средний чек, хороший разброс
--  СЕГМЕНТАЦИЯ ПО КАНАЛАМ:
--  INTERNET: 631 клиент, 4.29 млн руб, чек 735₽
--  VK: 569 клиентов, 3.88 млн руб, чек 741₽
--  Оба канала эффективны, Internet лидирует по объему
-- ПЕРСПЕКТИВНЫЕ РЕГИОНЫ ДЛЯ РЕКЛАМЫ:
--    Химки: потенциал +178K руб (максимальный)
-- Королёв: потенциал +167K руб  
--   Красногорск: потенциал +159K руб
--  Фокус на города с наибольшим потенциалом роста
-- ОБЩИЕ ВЫВОДЫ:
-- Клиенты равномерно распределены между каналами
-- Средний чек стабилен и оптимален
-- Есть потенциал роста в менее охваченных городах
-- Маркетинговая стратегия сбалансирована