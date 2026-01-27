-- 03_duplicates_analysis.sql
-- Анализ и обработка дубликатов в данных

-- ПЛАН РАБОТЫ С ДУБЛИКАТАМИ:
-- 1. Найти полные дубликаты (все поля совпадают)
-- 2. Найти неполные дубликаты (ключевые поля совпадают)
-- 3. Найти дубликаты клиентов
-- 4. Обработать найденные дубликаты

-- 1. Поиск полных дубликатов в fa_clean_sales_vk
SELECT 
    sale_id, date, client_id, city, zip_code, product_id, meters, total_amount, status,
    COUNT(*) as duplicate_count
FROM fabric_analysis.fa_clean_sales_vk
GROUP BY sale_id, date, client_id, city, zip_code, product_id, meters, total_amount, status
HAVING COUNT(*) > 1;
--есть дубликаты

-- Общее количество записей и количество дубликатов
SELECT 
    COUNT(*) as total_rows,
    COUNT(*) - COUNT(DISTINCT (sale_id, date, client_id, city, zip_code, product_id, meters, total_amount, status)) as duplicate_rows_count
FROM fabric_analysis.fa_clean_sales_vk;
-- всего 148 записей 

-- Количество дубликатов по количеству повторений
SELECT 
    MAX(duplicate_count) as max_duplicates
FROM (
    SELECT 
        COUNT(*) as duplicate_count
    FROM fabric_analysis.fa_clean_sales_vk
    GROUP BY sale_id, date, client_id, city, zip_code, product_id, meters, total_amount, status
) as duplicates;
--максимум 2 повторения каждого заказа

-- Удаляем дубликаты, оставляя только первую запись для каждого набора полных дубликатов
DELETE FROM fabric_analysis.fa_clean_sales_vk
WHERE ctid IN (
    -- Подзапрос 1: Выбираем ctid строк, которые нужно удалить (дубликаты)
    SELECT ctid
    FROM (
        -- Подзапрос 2: Нумеруем строки внутри групп дубликатов
        SELECT 
            ctid,  -- Физический адрес строки в таблице
            ROW_NUMBER() OVER (
                -- PARTITION BY: Разбиваем на группы по всем полям
                -- Каждая группа - это набор полных дубликатов
                PARTITION BY sale_id, date, client_id, city, zip_code, 
                             product_id, meters, total_amount, status
                -- ORDER BY ctid: Сортируем по физическому адресу
                -- Первая строка в каждой группе получит row_num = 1
                ORDER BY ctid
            ) as row_num  -- Номер строки внутри группы (1, 2, 3...)
        FROM fabric_analysis.fa_clean_sales_vk
    ) as numbered
    WHERE row_num > 1  -- Выбираем только дубликаты (все кроме первой строки в группе)
);

-- Проверяем остались ли дубликаты после удаления
SELECT 
    COUNT(*) as total_rows,
    COUNT(*) - COUNT(DISTINCT (sale_id, date, client_id, city, zip_code, product_id, meters, total_amount, status)) as remaining_duplicates
FROM fabric_analysis.fa_clean_sales_vk;


-- 2. Поиск неполных дубликатов по sale_id в ВК продажах
SELECT 
    sale_id,
    COUNT(*) as record_count,
    COUNT(DISTINCT date) as different_dates,
    COUNT(DISTINCT client_id) as different_clients,
    COUNT(DISTINCT product_id) as different_products
FROM fabric_analysis.fa_clean_sales_vk
GROUP BY sale_id
HAVING COUNT(*) > 1;
-- есть такие дубликаты

-- Считаем количество неполных дубликатов по sale_id
SELECT 
    COUNT(*) as duplicate_sale_ids_count
FROM (
    SELECT sale_id
    FROM fabric_analysis.fa_clean_sales_vk
    GROUP BY sale_id
    HAVING COUNT(*) > 1
) as duplicate_ids;
--получили 288 - это критично

-- Смотрим примеры неполных дубликатов для анализа
SELECT *
FROM fabric_analysis.fa_clean_sales_vk 
WHERE sale_id IN (
    SELECT sale_id
    FROM fabric_analysis.fa_clean_sales_vk
    GROUP BY sale_id
    HAVING COUNT(*) > 1
)
ORDER BY sale_id, date
LIMIT 10;
--да это разные заказы, но один sail_id

-- Анализируем масштаб проблемы: сколько заказов затронуто
SELECT 
    COUNT(DISTINCT sale_id) as problematic_sale_ids,
    COUNT(*) as total_affected_orders
FROM fabric_analysis.fa_clean_sales_vk
WHERE sale_id IN (
    SELECT sale_id
    FROM fabric_analysis.fa_clean_sales_vk
    GROUP BY sale_id
    HAVING COUNT(*) > 1
);
-- всего 581 запись, значит некоторые id могут быть больше 2 копий 

-- Анализируем распределение по количеству записей на один sale_id
SELECT 
    records_per_id,
    COUNT(*) as sale_ids_count
FROM (
    SELECT 
        sale_id,
        COUNT(*) as records_per_id
    FROM fabric_analysis.fa_clean_sales_vk
    GROUP BY sale_id
) as id_counts
GROUP BY records_per_id
ORDER BY records_per_id DESC;
--3 записи - 5 дубликатов, 2 записи - 283 дубликатов 

-- Смотрим примеры sale_id с 3 записями
SELECT *
FROM fabric_analysis.fa_clean_sales_vk 
WHERE sale_id IN (
    SELECT sale_id
    FROM fabric_analysis.fa_clean_sales_vk
    GROUP BY sale_id
    HAVING COUNT(*) = 3
)
ORDER BY sale_id, date;
--все разные 

--Сохраняем исходные sale_id + добавляем суффикс для уникальности
UPDATE fabric_analysis.fa_clean_sales_vk 
SET sale_id = sale_id || '_' || row_number
FROM (
    SELECT ctid, ROW_NUMBER() OVER (PARTITION BY sale_id ORDER BY date) as row_number
    FROM fabric_analysis.fa_clean_sales_vk
) as numbered
WHERE fabric_analysis.fa_clean_sales_vk.ctid = numbered.ctid;

-- Проверяем уникальность sale_id после исправления
SELECT 
    COUNT(*) as total_rows,
    COUNT(DISTINCT sale_id) as unique_sale_ids,
    -- Проверяем есть ли еще дубликаты
    (SELECT COUNT(*) 
     FROM (SELECT sale_id FROM fabric_analysis.fa_clean_sales_vk GROUP BY sale_id HAVING COUNT(*) > 1) as dupes
    ) as remaining_duplicates
FROM fabric_analysis.fa_clean_sales_vk;

-- Смотрим примеры исправленных sale_id
SELECT sale_id, date, client_id, product_id, total_amount
FROM fabric_analysis.fa_clean_sales_vk 
WHERE sale_id LIKE '%\_%'  -- Ищем ID с нижним подчеркиванием (исправленные)
ORDER BY sale_id
LIMIT 15;

-- Проверяем существование суффиксов 2 и 3
SELECT COUNT(*) as count_suffix_2
FROM fabric_analysis.fa_clean_sales_vk 
WHERE sale_id LIKE '%\_2';

SELECT COUNT(*) as count_suffix_3
FROM fabric_analysis.fa_clean_sales_vk 
WHERE sale_id LIKE '%\_3';

-- 3. Проверяем дубликаты в интернет-продажах
SELECT 
    sale_id,
    COUNT(*) as record_count,
    COUNT(DISTINCT date) as different_dates,
    COUNT(DISTINCT client_id) as different_clients,
    COUNT(DISTINCT product_id) as different_products
FROM fabric_analysis.fa_clean_sales_internet
GROUP BY sale_id
HAVING COUNT(*) > 1;
--есть дубликаты

-- Анализируем распределение по количеству записей на один sale_id в интернет-продажах
SELECT 
    records_per_id,
    COUNT(*) as sale_ids_count
FROM (
    SELECT 
        sale_id,
        COUNT(*) as records_per_id
    FROM fabric_analysis.fa_clean_sales_internet
    GROUP BY sale_id
) as id_counts
GROUP BY records_per_id
ORDER BY records_per_id DESC;
--3 записи по 3 дубликата, по 2	дубликата 119 записей

-- Исправляем sale_id в интернет-продажах 
UPDATE fabric_analysis.fa_clean_sales_internet 
SET sale_id = sale_id || '_' || row_number
FROM (
    SELECT ctid, ROW_NUMBER() OVER (PARTITION BY sale_id ORDER BY date) as row_number
    FROM fabric_analysis.fa_clean_sales_internet
) as numbered
WHERE fabric_analysis.fa_clean_sales_internet.ctid = numbered.ctid
AND row_number > 1;  

-- Проверяем ТЕКУЩЕЕ состояние sale_id в интернет-продажах
SELECT 
    records_per_id,
    COUNT(*) as sale_ids_count
FROM (
    SELECT 
        sale_id,
        COUNT(*) as records_per_id
    FROM fabric_analysis.fa_clean_sales_internet
    GROUP BY sale_id
) as id_counts
GROUP BY records_per_id
ORDER BY records_per_id DESC;

-- Финальная проверка уникальности во всех таблицах продаж
SELECT 
    'VK sales' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT sale_id) as unique_sale_ids
FROM fabric_analysis.fa_clean_sales_vk
UNION ALL
SELECT 
    'Internet sales' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT sale_id) as unique_sale_ids
FROM fabric_analysis.fa_clean_sales_internet;

-- 4. Проверяем дубликаты во всех очищенных таблицах
SELECT 
    'clients' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT client_id) as unique_ids,
    COUNT(*) - COUNT(DISTINCT client_id) as duplicate_rows
FROM fabric_analysis.fa_clean_clients
UNION ALL
SELECT 
    'products' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT product_id) as unique_ids,
    COUNT(*) - COUNT(DISTINCT product_id) as duplicate_rows
FROM fabric_analysis.fa_clean_products
UNION ALL
SELECT 
    'inventory' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT (date, product_id)) as unique_ids,
    COUNT(*) - COUNT(DISTINCT (date, product_id)) as duplicate_rows
FROM fabric_analysis.fa_clean_inventory
UNION ALL
SELECT 
    'expenses' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT (date, expense_type, channel)) as unique_ids,
    COUNT(*) - COUNT(DISTINCT (date, expense_type, channel)) as duplicate_rows
FROM fabric_analysis.fa_clean_expenses;

-- Убираем суффикс _1 из sale_id в таблице fa_clean_sales_vk
UPDATE fabric_analysis.fa_clean_sales_vk 
SET sale_id = REPLACE(sale_id, '_1', '')
WHERE sale_id LIKE '%\_1';

-- Смотрим примеры sale_id в таблице
SELECT sale_id, COUNT(*) 
FROM fabric_analysis.fa_clean_sales_vk 
WHERE sale_id LIKE '%\_3%'
GROUP BY sale_id
LIMIT 10;

-- ИТОГ ОЧИСТКИ ДАННЫХ:

-- fa_clean_sales_vk: 
--    - Исправлены города 'Москава' → 'Москва'
--    - Исправлены отрицательные суммы
--    - Исправлены zip_code 'abcde'
--    - Удалены полные дубликаты
--    - Исправлены некорректные sale_id (добавлены суффиксы)

-- fa_clean_sales_internet:
--    - Исправлены типы данных
--    - Удалены полные дубликаты  
--    - Исправлены некорректные sale_id

-- fa_clean_clients, products, inventory, expenses:
--    - Исправлены типы данных
--    - Дубликатов нет