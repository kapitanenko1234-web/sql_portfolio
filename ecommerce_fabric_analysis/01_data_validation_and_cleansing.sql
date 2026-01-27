-- 01_data_validation_and_cleaning.sql
-- Шаг 1: Поиск ошибок в данных
-- Проверяем данные на целостность и корректность

-- 1.Проверяем типы данных всех столбцов в таблицах 
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'fabric_analysis' 
    AND table_name LIKE 'fabric_analysis%'
ORDER BY table_name, ordinal_position;
-- ПРОБЛЕМЫ С ТИПАМИ ДАННЫХ:
-- 1. zip_code: в sales_vk - character varying, в sales_internet и clients - integer
-- 2. date: во всех таблицах character varying вместо date
-- 3. amount/price/cost: real (плавающая точка) может вызывать проблемы с округлением
-- 4. sold_meters в inventory: real, должен быть согласован с meters из sales
-- 5. incoming_meters в inventory: integer, должен быть real для согласованности

-- 2.Проверяем zip-коды в таблице fabric_analysis_sales_vk
SELECT 
    'sales_vk' as table_name,
    zip_code,
    COUNT(*) as count
FROM fabric_analysis.fabric_analysis_sales_vk 
GROUP BY zip_code
ORDER BY count DESC
LIMIT 15;
--181 некооректное значение индекса

-- Исследуем связь между некорректными zip_code и городами
SELECT 
    city,
    zip_code,
    COUNT(*) as count
FROM fabric_analysis.fabric_analysis_sales_vk 
WHERE zip_code = 'abcde'
GROUP BY city, zip_code
ORDER BY count DESC;
--связь установлена, некорректные индексы распределены между 8 городами 

-- Проверяем zip-коды в таблице fabric_analysis_sales_internet
SELECT 
    'sales_internet' as table_name,
    zip_code::text as zip_code,
    COUNT(*) as count
FROM fabric_analysis.fabric_analysis_sales_internet 
GROUP BY zip_code
ORDER BY count DESC
LIMIT 15;

-- Проверяем zip-коды в таблице fabric_analysis_clients
SELECT 
    'clients' as table_name,
    zip_code::text as zip_code,
    COUNT(*) as count
FROM fabric_analysis.fabric_analysis_clients 
GROUP BY zip_code
ORDER BY count DESC
LIMIT 15;

-- 3.Проверяем отрицательные значения во всех таблицах продаж и запасов
SELECT 
    'sales_vk' as table_name,
    COUNT(*) as total_rows,
    SUM(CASE WHEN meters < 0 THEN 1 ELSE 0 END) as negative_meters,
    SUM(CASE WHEN total_amount < 0 THEN 1 ELSE 0 END) as negative_amount,
    0 as negative_stock_before,
    0 as negative_incoming,
    0 as negative_sold,
    0 as negative_stock_after
FROM fabric_analysis.fabric_analysis_sales_vk
UNION ALL
SELECT 
    'sales_internet' as table_name,
    COUNT(*) as total_rows,
    SUM(CASE WHEN meters < 0 THEN 1 ELSE 0 END) as negative_meters,
    SUM(CASE WHEN total_amount < 0 THEN 1 ELSE 0 END) as negative_amount,
    0 as negative_stock_before,
    0 as negative_incoming,
    0 as negative_sold,
    0 as negative_stock_after
FROM fabric_analysis.fabric_analysis_sales_internet
UNION ALL
SELECT 
    'inventory' as table_name,
    COUNT(*) as total_rows,
    0 as negative_meters,
    0 as negative_amount,
    SUM(CASE WHEN stock_before < 0 THEN 1 ELSE 0 END) as negative_stock_before,
    SUM(CASE WHEN incoming_meters < 0 THEN 1 ELSE 0 END) as negative_incoming,
    SUM(CASE WHEN sold_meters < 0 THEN 1 ELSE 0 END) as negative_sold,
    SUM(CASE WHEN stock_after < 0 THEN 1 ELSE 0 END) as negative_stock_after
FROM fabric_analysis.fabric_analysis_inventory;
--отрицательные суммы есть в таблице продаж ВК - 223 записи

-- 4.Проверяем названия городов в таблицах продаж и клиентов
SELECT 
    'sales_vk' as table_name,
    city,
    COUNT(*) as count
FROM fabric_analysis.fabric_analysis_sales_vk 
GROUP BY city
ORDER BY city;

-- Затем выполним для sales_internet
SELECT 
    'sales_internet' as table_name,
    city,
    COUNT(*) as count
FROM fabric_analysis.fabric_analysis_sales_internet 
GROUP BY city
ORDER BY city;

-- И для clients
SELECT 
    'clients' as table_name,
    city,
    COUNT(*) as count
FROM fabric_analysis.fabric_analysis_clients 
GROUP BY city
ORDER BY city;
--обнаружено 210 некооретных названий "Москава" в ВК продажах

-- 5.Проверяем корректность sale_id в таблицах продаж
-- Проверяем sale_id на пустые и NULL значения
SELECT 
    'sales_vk' as table_name,
    COUNT(*) as total_count,
    COUNT(sale_id) as non_null_count,
    COUNT(*) - COUNT(sale_id) as null_count,
    SUM(CASE WHEN sale_id = '' THEN 1 ELSE 0 END) as empty_count
FROM fabric_analysis.fabric_analysis_sales_vk;

-- Проверяем sale_id на отличные от основного типа значения
SELECT 
    'sales_vk' as table_name,
    sale_id,
    COUNT(*) as count
FROM fabric_analysis.fabric_analysis_sales_vk 
WHERE sale_id !~ '^VK[0-9]{5}$'
GROUP BY sale_id
ORDER BY count DESC
LIMIT 20;

-- 6.Проверяем status на пустые и NULL значения во всех таблицах продаж
SELECT 
    'sales_vk' as table_name,
    COUNT(*) as total_count,
    COUNT(status) as non_null_count,
    COUNT(*) - COUNT(status) as null_count,
    SUM(CASE WHEN status = '' THEN 1 ELSE 0 END) as empty_count
FROM fabric_analysis.fabric_analysis_sales_vk
UNION ALL
SELECT 
    'sales_internet' as table_name,
    COUNT(*) as total_count,
    COUNT(status) as non_null_count,
    COUNT(*) - COUNT(status) as null_count,
    SUM(CASE WHEN status = '' THEN 1 ELSE 0 END) as empty_count
FROM fabric_analysis.fabric_analysis_sales_internet;

-- 7.Проверяем существование всех product_id в справочнике товаров
SELECT 
    'sales_vk' as table_name,
    COUNT(*) as total_sales,
    COUNT(DISTINCT s.product_id) as unique_products,
    COUNT(DISTINCT s.product_id) - COUNT(DISTINCT p.product_id) as missing_products_count
FROM fabric_analysis.fabric_analysis_sales_vk s
LEFT JOIN fabric_analysis.fabric_analysis_products p ON s.product_id = p.product_id
UNION ALL
SELECT 
    'sales_internet' as table_name,
    COUNT(*) as total_sales,
    COUNT(DISTINCT s.product_id) as unique_products,
    COUNT(DISTINCT s.product_id) - COUNT(DISTINCT p.product_id) as missing_products_count
FROM fabric_analysis.fabric_analysis_sales_internet s
LEFT JOIN fabric_analysis.fabric_analysis_products p ON s.product_id = p.product_id;
--отсутствует 1 продукт в продажах ВК

-- Находим отсутствующий product_id в VK продажах
SELECT DISTINCT s.product_id
FROM fabric_analysis.fabric_analysis_sales_vk s
LEFT JOIN fabric_analysis.fabric_analysis_products p ON s.product_id = p.product_id
WHERE p.product_id IS NULL;

-- НАЙДЕМ КОЛИЧЕСТВО ТАКИХ ПРОДАЖ:
SELECT COUNT(*) as problematic_sales_count
FROM fabric_analysis.fabric_analysis_sales_vk 
WHERE product_id = 'XXX999';
--таких продаж 210

-- ОЦЕНИМ ФИНАНСОВЫЙ МАСШТАБ:
SELECT 
    COUNT(*) as sales_count,
    SUM(meters) as total_meters,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value
FROM fabric_analysis.fabric_analysis_sales_vk 
WHERE product_id = 'XXX999';
-- 210	433.0	145275.0	691.7857142857143

-- 8.Проверяем некорректные форматы дат во всех таблицах перед преобразованием
SELECT 
    'sales_vk' as table_name,
    date,
    COUNT(*) as count
FROM fabric_analysis.fabric_analysis_sales_vk 
WHERE date IS NULL OR date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY date
UNION ALL
SELECT 
    'sales_internet' as table_name,
    date,
    COUNT(*) as count
FROM fabric_analysis.fabric_analysis_sales_internet 
WHERE date IS NULL OR date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY date
UNION ALL
SELECT 
    'inventory' as table_name,
    date,
    COUNT(*) as count
FROM fabric_analysis.fabric_analysis_inventory 
WHERE date IS NULL OR date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY date
UNION ALL
SELECT 
    'expenses' as table_name,
    date,
    COUNT(*) as count
FROM fabric_analysis.fabric_analysis_expenses 
WHERE date IS NULL OR date !~ '^\d{4}-\d{2}-\d{2}$'
GROUP BY date;

-- 9.Проверяем существование всех client_id в справочнике клиентов
SELECT 
    'sales_vk' as table_name,
    COUNT(*) as total_sales,
    COUNT(DISTINCT s.client_id) as unique_clients,
    COUNT(DISTINCT s.client_id) - COUNT(DISTINCT c.client_id) as missing_clients_count
FROM fabric_analysis.fabric_analysis_sales_vk s
LEFT JOIN fabric_analysis.fabric_analysis_clients c ON s.client_id = c.client_id
UNION ALL
SELECT 
    'sales_internet' as table_name,
    COUNT(*) as total_sales,
    COUNT(DISTINCT s.client_id) as unique_clients,
    COUNT(DISTINCT s.client_id) - COUNT(DISTINCT c.client_id) as missing_clients_count
FROM fabric_analysis.fabric_analysis_sales_internet s
LEFT JOIN fabric_analysis.fabric_analysis_clients c ON s.client_id = c.client_id;

-- 10.Проверяем проблемы с денежными полями (real тип)
SELECT 
    table_name,
    column_name,
    data_type,
    'проблема: real тип для денег' as issue
FROM information_schema.columns 
WHERE table_schema = 'fabric_analysis' 
    AND table_name LIKE 'fabric_analysis%'
    AND data_type = 'real'
    AND (column_name LIKE '%amount%' 
         OR column_name LIKE '%price%' 
         OR column_name LIKE '%cost%');