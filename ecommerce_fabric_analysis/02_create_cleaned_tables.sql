-- 02_create_cleaned_views.sql
-- Шаг 2: Исправление и создание очищенных материализованных таблиц с правильными данными

-- 📋 ВЫЯВЛЕННЫЕ ПРОБЛЕМЫ:
-- 1. sales_vk: 181 запись с zip_code = 'abcde'
-- 2. sales_vk: 210 продаж с несуществующим product_id = 'XXX999' 
-- 3. sales_vk: 223 записи с отрицательными total_amount  
-- 4. sales_vk: 210 записей с городом 'Москава' вместо 'Москва'
-- 5. Все таблицы: date как text вместо date
-- 6. sales_vk, sales_internet, products, expenses: денежные поля как real
-- 7. zip_code: неконсистентные типы между таблицами

-- Шаг 1: Создаем базовую копию таблицы sales_vk
CREATE TABLE fabric_analysis.fa_clean_sales_vk AS
SELECT *
FROM fabric_analysis.fabric_analysis_sales_vk;

-- Шаг 2: Исправляем город Москва в созданной таблице
UPDATE fabric_analysis.fa_clean_sales_vk 
SET city = 'Москва'
WHERE city = 'Москава';

-- Проверяем исправление города Москва
SELECT 
    city,
    COUNT(*) as count
FROM fabric_analysis.fa_clean_sales_vk 
WHERE city IN ('Москва', 'Москава')
GROUP BY city;

-- Шаг 3: Исправляем отрицательные суммы
UPDATE fabric_analysis.fa_clean_sales_vk 
SET total_amount = ABS(total_amount)
WHERE total_amount < 0;

-- Проверяем исправление отрицательных сумм
SELECT 
    COUNT(*) as total_rows,
    SUM(CASE WHEN total_amount < 0 THEN 1 ELSE 0 END) as negative_amount_count
FROM fabric_analysis.fa_clean_sales_vk;

--Шаг 4: Исправляем zip_code 'abcde'. Нужно присвоить правильные индексы для каждого города
-- Сначала посмотрим распределение городов с некорректным zip_code
SELECT 
    city,
    COUNT(*) as count
FROM fabric_analysis.fa_clean_sales_vk 
WHERE zip_code = 'abcde'
GROUP BY city;

-- присваиваем правильные индексы по городам
UPDATE fabric_analysis.fa_clean_sales_vk 
SET zip_code = 
    CASE 
        WHEN city = 'Подольск' THEN '142100'
        WHEN city = 'Королёв' THEN '141060' 
        WHEN city = 'Красногорск' THEN '143400'
        WHEN city = 'Москва' THEN '101000'
        WHEN city = 'Реутов' THEN '143960'
        WHEN city = 'Мытищи' THEN '141000'
        WHEN city = 'Химки' THEN '141400'
        WHEN city = 'Люберцы' THEN '140000'
        ELSE zip_code  -- оставляем как есть для других городов
    END
WHERE zip_code = 'abcde';

-- Проверяем исправление zip_code
SELECT 
    zip_code,
    COUNT(*) as count
FROM fabric_analysis.fa_clean_sales_vk 
WHERE zip_code = 'abcde' OR zip_code IS NULL
GROUP BY zip_code;

-- Шаг 5: Изменяем тип данных столбца date на тип date в продажах ВК
ALTER TABLE fabric_analysis.fa_clean_sales_vk 
ALTER COLUMN date TYPE date USING date::date;

-- Проверяем тип данных столбца date
SELECT 
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'fabric_analysis' 
    AND table_name = 'fa_clean_sales_vk'
    AND column_name = 'date';

-- Шаг 6: Преобразуем денежные поля в numeric в fa_clean_sales_vk
ALTER TABLE fabric_analysis.fa_clean_sales_vk 
ALTER COLUMN meters TYPE numeric(10,2),
ALTER COLUMN total_amount TYPE numeric(10,2);

-- Проверяем типы данных денежных полей в fa_clean_sales_vk
SELECT 
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'fabric_analysis' 
    AND table_name = 'fa_clean_sales_vk'
    AND column_name IN ('meters', 'total_amount');

-- Исправляем тип zip_code в таблице fa_clean_sales_vk на text
ALTER TABLE fabric_analysis.fa_clean_sales_vk 
ALTER COLUMN zip_code TYPE text;

-- Проверяем исправление
SELECT 
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'fabric_analysis' 
    AND table_name = 'fa_clean_sales_vk'
    AND column_name = 'zip_code';

--Шаг 7: Оставляем 'XXX999' как есть - это будет агрегирующий артикул для неопознанных товаров
--Это лучше для аналитической целостности

-- Шаг 8: Создаем очищенную копию таблицы sales_internet
CREATE TABLE fabric_analysis.fa_clean_sales_internet AS
SELECT 
    sale_id,
    date::date as date,
    client_id,
    city,
    zip_code::text as zip_code,  -- integer → text
    product_id,
    meters::numeric(10,2) as meters,  -- real → numeric
    total_amount::numeric(10,2) as total_amount,  -- real → numeric
    status
FROM fabric_analysis.fabric_analysis_sales_internet;

-- Проверяем создание и типы данных таблицы fa_clean_sales_internet
SELECT 
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'fabric_analysis' 
    AND table_name = 'fa_clean_sales_internet'
ORDER BY ordinal_position;

-- Шаг 9: Создаем очищенную копию таблицы clients
CREATE TABLE fabric_analysis.fa_clean_clients AS
SELECT 
    client_id,
    city,
    region,
    zip_code::text as zip_code,  -- integer → text
    registration_channel
FROM fabric_analysis.fabric_analysis_clients;

-- Проверяем создание и типы данных таблицы fa_clean_clients
SELECT 
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'fabric_analysis' 
    AND table_name = 'fa_clean_clients'
ORDER BY ordinal_position;

-- Шаг 10: Создаем очищенную копию таблицы products
CREATE TABLE fabric_analysis.fa_clean_products AS
SELECT 
    product_id,
    country,
    color,
    pattern,
    price_per_meter::numeric(10,2) as price_per_meter,  -- real → numeric
    cost_per_meter::numeric(10,2) as cost_per_meter,    -- real → numeric
    active
FROM fabric_analysis.fabric_analysis_products;

-- Проверяем создание и типы данных таблицы fa_clean_products
SELECT 
    column_name,
    data_type  
FROM information_schema.columns 
WHERE table_schema = 'fabric_analysis' 
    AND table_name = 'fa_clean_products'
ORDER BY ordinal_position;

-- Шаг 11: Создаем очищенную копию таблицы inventory
CREATE TABLE fabric_analysis.fa_clean_inventory AS
SELECT 
    date::date as date,
    product_id,
    stock_before::numeric(10,2) as stock_before,      -- real → numeric
    incoming_rolls,
    incoming_meters::numeric(10,2) as incoming_meters, -- integer → numeric
    sold_meters::numeric(10,2) as sold_meters,        -- real → numeric
    stock_after::numeric(10,2) as stock_after         -- real → numeric
FROM fabric_analysis.fabric_analysis_inventory;

-- Проверяем создание и типы данных таблицы fa_clean_inventory
SELECT 
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'fabric_analysis' 
    AND table_name = 'fa_clean_inventory'
ORDER BY ordinal_position;

-- Шаг 12: Создаем очищенную копию таблицы expenses
CREATE TABLE fabric_analysis.fa_clean_expenses AS
SELECT 
    date::date as date,
    expense_type,
    channel,
    amount::numeric(10,2) as amount  -- real → numeric
FROM fabric_analysis.fabric_analysis_expenses;

-- Проверяем создание и типы данных таблицы fa_clean_expenses
SELECT 
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'fabric_analysis' 
    AND table_name = 'fa_clean_expenses'
ORDER BY ordinal_position;

-- СОЗДАНЫ ОЧИЩЕННЫЕ ТАБЛИЦЫ:
-- fa_clean_sales_vk      (исправлены: город, zip_code, отрицательные суммы, типы данных)
-- fa_clean_sales_internet (исправлены: типы данных)
-- fa_clean_clients        (исправлены: типы данных)  
-- fa_clean_products       (исправлены: типы данных)
-- fa_clean_inventory      (исправлены: типы данных)
-- fa_clean_expenses       (исправлены: типы данных)