-- 05_product_analysis.sql
-- Аналитика по товарам: 
-- ТОП-10 продаваемых артикулов.
-- Популярность цветов и рисунков.
-- Сравнение продаж Китай vs Турция.
-- Анализ динамики цены и выручки.
-- Определение аутсайдеров по продажам.

-- 1. ТОП-10 продаваемых артикулов по выручке
SELECT 
    p.product_id,
    p.country,
    p.color,
    p.pattern,
    COUNT(*) as orders_count,
    SUM(s.total_amount) as total_revenue,
    SUM(s.meters) as total_meters
FROM fabric_analysis.fa_unified_sales s
JOIN fabric_analysis.fa_clean_products p ON s.product_id = p.product_id
WHERE s.status = 'Завершен'
GROUP BY p.product_id, p.country, p.color, p.pattern
ORDER BY total_revenue DESC
LIMIT 10;

-- 2. Популярность цветов
SELECT 
    p.color,
    COUNT(*) as orders_count,
    SUM(s.total_amount) as total_revenue,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fabric_analysis.fa_unified_sales WHERE status = 'Завершен')::numeric, 1) as percent_of_total
FROM fabric_analysis.fa_unified_sales s
JOIN fabric_analysis.fa_clean_products p ON s.product_id = p.product_id
WHERE s.status = 'Завершен'
GROUP BY p.color
ORDER BY total_revenue DESC;

--Популярность рисунков
SELECT 
    p.pattern,
    COUNT(*) as orders_count,
    SUM(s.total_amount) as total_revenue,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fabric_analysis.fa_unified_sales WHERE status = 'Завершен')::numeric, 1) as percent_of_total
FROM fabric_analysis.fa_unified_sales s
JOIN fabric_analysis.fa_clean_products p ON s.product_id = p.product_id
WHERE s.status = 'Завершен'
GROUP BY p.pattern
ORDER BY total_revenue DESC;

-- 3. Сравнение продаж Китай vs Турция
SELECT 
    p.country,
    COUNT(*) as orders_count,
    SUM(s.total_amount) as total_revenue,
    SUM(s.meters) as total_meters,
    ROUND(AVG(s.total_amount)::numeric, 2) as avg_order_value,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fabric_analysis.fa_unified_sales WHERE status = 'Завершен')::numeric, 0) as percent_of_total
FROM fabric_analysis.fa_unified_sales s
JOIN fabric_analysis.fa_clean_products p ON s.product_id = p.product_id
WHERE s.status = 'Завершен'
GROUP BY p.country
ORDER BY total_revenue DESC;

-- 4. Анализ динамики цены и выручки по месяцам
SELECT 
    TO_CHAR(s.date, 'YYYY-MM') as month,
    COUNT(*) as orders_count,
    SUM(s.total_amount) as total_revenue,
    ROUND(AVG(p.price_per_meter)::numeric, 2) as avg_price_per_meter,
    ROUND(AVG(s.total_amount)::numeric, 2) as avg_order_value
FROM fabric_analysis.fa_unified_sales s
JOIN fabric_analysis.fa_clean_products p ON s.product_id = p.product_id
WHERE s.status = 'Завершен'
GROUP BY TO_CHAR(s.date, 'YYYY-MM')
ORDER BY month;

-- 5. Аутсайдеры по продажам (товары с минимальными продажами)
SELECT 
    p.product_id,
    p.country,
    p.color,
    p.pattern,
    COUNT(*) as orders_count,
    SUM(s.total_amount) as total_revenue,
    SUM(s.meters) as total_meters
FROM fabric_analysis.fa_unified_sales s
JOIN fabric_analysis.fa_clean_products p ON s.product_id = p.product_id
WHERE s.status = 'Завершен'
GROUP BY p.product_id, p.country, p.color, p.pattern
ORDER BY total_revenue ASC
LIMIT 10;