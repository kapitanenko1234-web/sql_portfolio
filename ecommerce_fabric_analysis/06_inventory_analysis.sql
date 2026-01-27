-- 06_inventory_analysis.sql
-- Анализ складских запасов и закупок:
-- 1. Сопоставить продажи с движением по складу.
-- 2. Найти артикулы, по которым кончился товар.
-- 3. Оборачиваемость тканей.
-- 4. Планирование минимального запаса.
-- 5. Расчёт среднего времени оборота рулона.

-- 1. Сопоставить продажи с движением по складу
-- Проблема: incoming_meters и incoming_rolls не заполнены
-- Решение: Рассчитать поступления на основе разницы запасов
-- Создаем таблицу с расчетом поступлений в метрах
-- Обновляем incoming_meters и incoming_rolls в fa_clean_inventory
UPDATE fabric_analysis.fa_clean_inventory 
SET 
    incoming_meters = calculated_data.incoming_meters,
    incoming_rolls = calculated_data.incoming_rolls
FROM (
    SELECT 
        date,
        product_id,
        -- incoming_meters = stock_before - stock_before_вчера
        (stock_before - LAG(stock_before) OVER (PARTITION BY product_id ORDER BY date)) as incoming_meters,
        -- incoming_rolls = incoming_meters / 30
        CEIL((stock_before - LAG(stock_before) OVER (PARTITION BY product_id ORDER BY date)) / 30) as incoming_rolls
    FROM fabric_analysis.fa_clean_inventory
) as calculated_data
WHERE fabric_analysis.fa_clean_inventory.date = calculated_data.date 
AND fabric_analysis.fa_clean_inventory.product_id = calculated_data.product_id;

-- Заполняем incoming_meters и incoming_rolls с учетом продаж вчерашнего дня
UPDATE fabric_analysis.fa_clean_inventory 
SET 
    incoming_meters = calculated_data.incoming_meters,
    incoming_rolls = calculated_data.incoming_rolls
FROM (
    SELECT 
        date,
        product_id,
        -- incoming_meters = (stock_before - stock_before_вчера) + sold_meters_вчера
        (stock_before - LAG(stock_before) OVER (PARTITION BY product_id ORDER BY date) 
         + LAG(sold_meters) OVER (PARTITION BY product_id ORDER BY date)) as incoming_meters,
        -- incoming_rolls = incoming_meters / 30
        CEIL((stock_before - LAG(stock_before) OVER (PARTITION BY product_id ORDER BY date) 
              + LAG(sold_meters) OVER (PARTITION BY product_id ORDER BY date)) / 30) as incoming_rolls
    FROM fabric_analysis.fa_clean_inventory
) as calculated_data
WHERE fabric_analysis.fa_clean_inventory.date = calculated_data.date 
AND fabric_analysis.fa_clean_inventory.product_id = calculated_data.product_id;


-- 1. Сопоставление продаж с движением по складу
SELECT 
    s.date,
    s.product_id,
    -- Продажи из таблицы продаж
    SUM(s.meters) as sold_from_sales,
    -- Продажи из таблицы инвентаря
    i.sold_meters as sold_from_inventory,
    -- Разница между данными
    SUM(s.meters) - i.sold_meters as sales_difference,
    -- Поступления на склад
    i.incoming_meters,
    -- Остатки
    i.stock_before,
    i.stock_after
FROM fabric_analysis.fa_unified_sales s
JOIN fabric_analysis.fa_clean_inventory i 
    ON s.product_id = i.product_id AND s.date = i.date
WHERE s.status = 'Завершен'
GROUP BY s.date, s.product_id, i.sold_meters, i.incoming_meters, i.stock_before, i.stock_after
ORDER BY ABS(SUM(s.meters) - i.sold_meters) DESC
LIMIT 20;
-- ВЫВОД: В инвентаре sold_meters включает дополнительные +-5 метров
-- которые не относятся к фактическим продажам

-- Суммарные продажи по каждому артикулу за все время
SELECT 
    COALESCE(s.product_id, i.product_id) as product_id,
    COALESCE(s.total_sales, 0) as total_sales_meters,
    COALESCE(i.total_inventory, 0) as total_inventory_meters,
    COALESCE(s.total_sales, 0) - COALESCE(i.total_inventory, 0) as difference
FROM (
    SELECT product_id, SUM(meters) as total_sales
    FROM fabric_analysis.fa_unified_sales
    WHERE status = 'Завершен'
    GROUP BY product_id
) s
FULL OUTER JOIN (
    SELECT product_id, SUM(sold_meters) as total_inventory
    FROM fabric_analysis.fa_clean_inventory
    GROUP BY product_id
) i ON s.product_id = i.product_id
ORDER BY ABS(COALESCE(s.total_sales, 0) - COALESCE(i.total_inventory, 0)) DESC;

-- Суммарные продажи по всем артикулам (кроме XXX999)
SELECT 
    'Все артикулы кроме XXX999' as description,
    SUM(total_sales_meters) as total_sales_sum,
    SUM(total_inventory_meters) as total_inventory_sum,
    SUM(total_sales_meters) - SUM(total_inventory_meters) as total_difference
FROM (
    SELECT 
        COALESCE(s.product_id, i.product_id) as product_id,
        COALESCE(s.total_sales, 0) as total_sales_meters,
        COALESCE(i.total_inventory, 0) as total_inventory_meters
    FROM (
        SELECT product_id, SUM(meters) as total_sales
        FROM fabric_analysis.fa_unified_sales
        WHERE status = 'Завершен'
        GROUP BY product_id
    ) s
    FULL OUTER JOIN (
        SELECT product_id, SUM(sold_meters) as total_inventory
        FROM fabric_analysis.fa_clean_inventory
        GROUP BY product_id
    ) i ON s.product_id = i.product_id
) as all_products
WHERE product_id != 'XXX999';

-- АНАЛИЗ ПРОБЛЕМЫ:
-- Общая нехватка: 2,614.50 метров
-- Продажи XXX999: только 370.50 метров
-- НЕСООТВЕТСТВИЕ: 2,614.50 - 370.50 = 2,244.00 метров ОБЪЯСНЕНИЯ НЕТ!
-- ВЫВОД: 
-- Проблема НЕ ТОЛЬКО в XXX999
-- Есть СИСТЕМНАЯ ОШИБКА в данных инвентаря
-- sold_meters в инвентаре систематически ЗАВЫШЕНЫ
-- РЕКОМЕНДАЦИЯ: Для анализа использовать fa_unified_sales и 
--игнорировать sold_meters из инвентаря как недостоверные

-- 2. Найти артикулы, по которым кончился товар (нулевые остатки)
SELECT 
    product_id,
    COUNT(*) as zero_stock_days,
    MIN(date) as first_zero_day,
    MAX(date) as last_zero_day,
    -- Среднее время отсутствия товара между поступлениями
    AVG(days_between_incoming) as avg_days_out_of_stock
FROM (
    SELECT 
        product_id,
        date,
        stock_after,
        -- Количество дней до следующего поступления
        LEAD(date) OVER (PARTITION BY product_id ORDER BY date) - date as days_between_incoming
    FROM fabric_analysis.fa_clean_inventory
    WHERE incoming_meters > 0 OR date = (SELECT MIN(date) FROM fabric_analysis.fa_clean_inventory)
) as stock_data
WHERE stock_after = 0
GROUP BY product_id
HAVING COUNT(*) >= 3  -- Товары, которые отсутствовали минимум 3 дня
ORDER BY zero_stock_days DESC;

-- ВЫВОДЫ:
-- P0034: отсутствовал 6 раз, в среднем 7 дней между поставками
-- P0098: отсутствовал 6 раз, в среднем 6 дней между поставками  
-- P0072: отсутствовал 6 раз, в среднем 7 дней между поставками
-- ПРОБЛЕМЫ:
-- 1. Системные перебои поставок для топ-3 товаров
-- 2. Длительные периоды отсутствия (до 7 дней)
-- 3. Потери продаж из-за регулярного дефицита
-- РЕКОМЕНДАЦИИ:
-- Увеличить страховой запас для P0034, P0098, P0072
-- Оптимизировать логистику для быстрых поставок
-- Настроить уведомления о низких остатках

-- 3,4. Расчет оборачиваемости тканей по месяцам и планирование запасов
SELECT 
    TO_CHAR(date, 'YYYY-MM') as month,
    -- Средний запас за месяц
    ROUND(AVG(stock_after)::numeric, 2) as avg_monthly_stock,
    -- Продажи за месяц
    SUM(sold_meters) as monthly_sales,
    -- Оборачиваемость (в разах, а не процентах)
    ROUND(SUM(sold_meters) / AVG(stock_after)::numeric, 2) as turnover_rate
FROM fabric_analysis.fa_clean_inventory
GROUP BY TO_CHAR(date, 'YYYY-MM')
ORDER BY month;

-- ТРЕНДЫ ОБОРАЧИВАЕМОСТИ:
-- 2018-03: 28.17 ← ВЫСОКАЯ оборачиваемость
-- 2018-08: 14.42 ← СНИЖЕНИЕ на 49%
-- 2019-02: 12.67 ← НИЗКАЯ оборачиваемость
-- ВЫВОДЫ:
-- 1. РЕЗКОЕ ПАДЕНИЕ: Оборачиваемость упала с 28 до 13 раз в месяц (-54%)
-- 2. РОСТ ЗАПАСОВ: Средние остатки выросли с 38 до 77 метров (+103%)
-- 3. СТАБИЛЬНЫЕ ПРОДАЖИ: Объем продаж ~1000-1400 метров в месяц
-- ПРОБЛЕМА: Запасы растут быстрее продаж → деньги "заморожены" в излишках
-- РЕКОМЕНДАЦИЯ: Оптимизировать закупки и сократить страховые запасы

-- 5. Расчет среднего времени оборота рулона (дни)
SELECT 
    TO_CHAR(date, 'YYYY-MM') as month,
    -- Средний запас за месяц
    ROUND(AVG(stock_after)::numeric, 2) as avg_monthly_stock,
    -- Продажи за месяц
    SUM(sold_meters) as monthly_sales,
    -- Среднее время оборота (дни) = Средний запас / Среднедневные продажи
    ROUND(
        AVG(stock_after) / (SUM(sold_meters) / COUNT(DISTINCT date))::numeric, 
        1
    ) as avg_turnover_days
FROM fabric_analysis.fa_clean_inventory
GROUP BY TO_CHAR(date, 'YYYY-MM')
ORDER BY month;

-- Формула: Время оборота = Средний запас / Среднедневные продажи
-- ДИНАМИКА ВРЕМЕНИ ОБОРОТА:
-- 2018-03: 1.1 дня ← ОЧЕНЬ БЫСТРЫЙ оборот
-- 2019-02: 2.2 дня ← УВЕЛИЧЕНИЕ в 2 раза
-- 2020-02: 3.2 дня ← МЕДЛЕННЫЙ оборот
-- ВЫВОДЫ:
-- 1. РЕЗКОЕ ЗАМЕДЛЕНИЕ: Время оборота выросло с 1.1 до 3.2 дня (+191%)
-- 2. РОСТ "ЗАЛЕЖАЛОГО" ТОВАРА: Рулоны лежат на складе в 3 раза дольше
-- 3. УХУДШЕНИЕ ЭФФЕКТИВНОСТИ: Деньги дольше "заморожены" в запасах
-- ПРОБЛЕМА: Избыточные запасы при стабильных продажах
-- РЕКОМЕНДАЦИЯ: Сократить объем закупок на 30-40% для оптимизации оборотных средств