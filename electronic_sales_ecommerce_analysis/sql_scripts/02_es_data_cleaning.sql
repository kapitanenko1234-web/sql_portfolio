-- =============================================
-- E-COMMERCE ANALYSIS: DATA CLEANING
-- Очистка и подготовка данных
-- =============================================

--не все файлы SVC загрузились со значениями, 
--в четырех потребовалась установка для всех столбцов тип данных varchar: март, июнь, август, декабрь
--В каждой таблице данных колонки с неудобными названиями: Order ID, Product, Quantity Ordered и т.д.
--переименуем колонки в каждой таблице
-- для января
ALTER TABLE sales_january RENAME COLUMN "Order ID" TO order_id;
ALTER TABLE sales_january RENAME COLUMN "Product" TO product;
ALTER TABLE sales_january RENAME COLUMN "Quantity Ordered" TO quantity_ordered;
ALTER TABLE sales_january RENAME COLUMN "Price Each" TO price_each;
ALTER TABLE sales_january RENAME COLUMN "Order Date" TO order_date;
ALTER TABLE sales_january RENAME COLUMN "Purchase Address" TO purchase_address;
--так для каждого месяца, всего 72 операции
--Оптимизация от AI-ассистента. Ассистент предложил автоматизированное решение, которое я еще не изучала, 
--но решила применить для ускорения работы:
DO $$ 
DECLARE 
    table_name TEXT;
BEGIN
    FOR table_name IN 
        SELECT 'sales_january' UNION ALL SELECT 'sales_february' UNION ALL 
        SELECT 'sales_march' UNION ALL SELECT 'sales_april' UNION ALL 
        SELECT 'sales_may' UNION ALL SELECT 'sales_june' UNION ALL 
        SELECT 'sales_july' UNION ALL SELECT 'sales_august' UNION ALL 
        SELECT 'sales_september' UNION ALL SELECT 'sales_october' UNION ALL 
        SELECT 'sales_november' UNION ALL SELECT 'sales_december'
    LOOP
        EXECUTE 'ALTER TABLE ' || table_name || ' RENAME COLUMN "Order ID" TO order_id';
        EXECUTE 'ALTER TABLE ' || table_name || ' RENAME COLUMN "Product" TO product';
        EXECUTE 'ALTER TABLE ' || table_name || ' RENAME COLUMN "Quantity Ordered" TO quantity_ordered';
        EXECUTE 'ALTER TABLE ' || table_name || ' RENAME COLUMN "Price Each" TO price_each';
        EXECUTE 'ALTER TABLE ' || table_name || ' RENAME COLUMN "Order Date" TO order_date';
        EXECUTE 'ALTER TABLE ' || table_name || ' RENAME COLUMN "Purchase Address" TO purchase_address';
    END LOOP;
END $$;
--проверяем переименование во всех таблицах sales_
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name LIKE 'sales_%'
ORDER BY table_name, ordinal_position;

--Наполняем созданную общую таблицу данными из всех месяцев
--одновременоо приводим к нужному типу (кроме даты пока)
--здесь я задаю промпт AI-ассистенту размножить запросы и подставить нужный месяц

--Январь
INSERT INTO all_sales 
SELECT 
    order_id::VARCHAR(50), 
    product::VARCHAR(200), 
    quantity_ordered::INTEGER,
    price_each::DECIMAL(10,2),
    order_date::TEXT,
    purchase_address::TEXT,
    'January'
FROM sales_january
WHERE quantity_ordered::INTEGER > 0
   AND price_each::DECIMAL > 0;

-- Февраль
INSERT INTO all_sales 
SELECT 
    order_id::VARCHAR(50), 
    product::VARCHAR(200), 
    quantity_ordered::INTEGER,
    price_each::DECIMAL(10,2),
    order_date::TEXT,
    purchase_address::TEXT,
    'February'
FROM sales_february
WHERE quantity_ordered::INTEGER > 0
   AND price_each::DECIMAL > 0;

-- Март
INSERT INTO all_sales 
SELECT 
    order_id::VARCHAR(50), 
    product::VARCHAR(200), 
    quantity_ordered::INTEGER,
    price_each::DECIMAL(10,2),
    order_date::TEXT,
    purchase_address::TEXT,
    'March'
FROM sales_march
WHERE quantity_ordered::INTEGER > 0
   AND price_each::DECIMAL > 0;
--выдает ОШИБКА: неверный синтаксис для типа integer: "Order ID"
--помним, что это проблемный файл при загрузке и делаем запрос

SELECT 'march' as месяц, COUNT(*) as заголовки 
FROM sales_march 
WHERE order_id = 'Order ID'
--получаем 35 значений

--удаляем строки с ненужными значениями
DELETE FROM sales_march WHERE order_id = 'Order ID';

-- удаляем в том числе пустые строки 
DELETE FROM sales_march WHERE quantity_ordered = '' OR price_each = '';
--то же самое делаем для остальных проблемных месяцев, но уже до запроса insert

-- Апрель
INSERT INTO all_sales 
SELECT 
    order_id::VARCHAR(50), 
    product::VARCHAR(200), 
    quantity_ordered::INTEGER,
    price_each::DECIMAL(10,2),
    order_date::TEXT,
    purchase_address::TEXT,
    'April'
FROM sales_april
WHERE quantity_ordered::INTEGER > 0
   AND price_each::DECIMAL > 0;

-- Май
INSERT INTO all_sales 
SELECT 
    order_id::VARCHAR(50), 
    product::VARCHAR(200), 
    quantity_ordered::INTEGER,
    price_each::DECIMAL(10,2),
    order_date::TEXT,
    purchase_address::TEXT,
    'May'
FROM sales_may
WHERE quantity_ordered::INTEGER > 0
   AND price_each::DECIMAL > 0;

-- Июнь, удаляем строки с ненужными значениями и пустые строки
DELETE FROM sales_june WHERE order_id = 'Order ID';

DELETE FROM sales_june WHERE quantity_ordered = '' OR price_each = '';

INSERT INTO all_sales 
SELECT 
    order_id::VARCHAR(50), 
    product::VARCHAR(200), 
    quantity_ordered::INTEGER,
    price_each::DECIMAL(10,2),
    order_date::TEXT,
    purchase_address::TEXT,
    'June'
FROM sales_june
WHERE quantity_ordered::INTEGER > 0
   AND price_each::DECIMAL > 0;

-- Июль
INSERT INTO all_sales 
SELECT 
    order_id::VARCHAR(50), 
    product::VARCHAR(200), 
    quantity_ordered::INTEGER,
    price_each::DECIMAL(10,2),
    order_date::TEXT,
    purchase_address::TEXT,
    'July'
FROM sales_july
WHERE quantity_ordered::INTEGER > 0
   AND price_each::DECIMAL > 0;

-- Август, удаляем строки с ненужными значениями и пустые строки 

DELETE FROM sales_august WHERE order_id = 'Order ID';

DELETE FROM sales_august WHERE quantity_ordered = '' OR price_each = '';

INSERT INTO all_sales 
SELECT 
    order_id::VARCHAR(50), 
    product::VARCHAR(200), 
    quantity_ordered::INTEGER,
    price_each::DECIMAL(10,2),
    order_date::TEXT,
    purchase_address::TEXT,
    'August'
FROM sales_august
WHERE quantity_ordered::INTEGER > 0
   AND price_each::DECIMAL > 0;

-- Сентябрь
INSERT INTO all_sales 
SELECT 
    order_id::VARCHAR(50), 
    product::VARCHAR(200), 
    quantity_ordered::INTEGER,
    price_each::DECIMAL(10,2),
    order_date::TEXT,
    purchase_address::TEXT,
    'September'
FROM sales_september
WHERE quantity_ordered::INTEGER > 0
   AND price_each::DECIMAL > 0;

-- Октябрь
INSERT INTO all_sales 
SELECT 
    order_id::VARCHAR(50), 
    product::VARCHAR(200), 
    quantity_ordered::INTEGER,
    price_each::DECIMAL(10,2),
    order_date::TEXT,
    purchase_address::TEXT,
    'October'
FROM sales_october
WHERE quantity_ordered::INTEGER > 0
   AND price_each::DECIMAL > 0;

-- Ноябрь
INSERT INTO all_sales 
SELECT 
    order_id::VARCHAR(50), 
    product::VARCHAR(200), 
    quantity_ordered::INTEGER,
    price_each::DECIMAL(10,2),
    order_date::TEXT,
    purchase_address::TEXT,
    'November'
FROM sales_november
WHERE quantity_ordered::INTEGER > 0
   AND price_each::DECIMAL > 0;

-- Декабрь, удаляем строки с ненужными значениями и пустые строки

DELETE FROM sales_december WHERE order_id = 'Order ID';

DELETE FROM sales_december WHERE quantity_ordered = '' OR price_each = '';

INSERT INTO all_sales 
SELECT 
    order_id::VARCHAR(50), 
    product::VARCHAR(200), 
    quantity_ordered::INTEGER,
    price_each::DECIMAL(10,2),
    order_date::TEXT,
    purchase_address::TEXT,
    'December'
FROM sales_december
WHERE quantity_ordered::INTEGER > 0
   AND price_each::DECIMAL > 0;

-- Проверяем все ли месяцы у нас есть
SELECT month, COUNT(*) 
FROM all_sales 
GROUP BY month 
ORDER BY MIN(order_date);

--продолжем очистку таблицы all_sales
--удалим все null, в этом случае это допустимо,
--цена заказа не может быть 0 или меньше 0
--количество заказов не может быть меньше или равно 0

DELETE FROM all_sales 
WHERE 
    order_id IS NULL OR
    product IS NULL OR
    quantity_ordered IS NULL OR
    price_each IS NULL OR
    order_date IS NULL OR
    purchase_address IS NULL OR
    quantity_ordered <= 0 OR
    price_each <= 0;

--пустые строки 
SELECT * FROM all_sales 
WHERE 
    order_id = '' OR
    product = '' OR
    quantity_ordered::text = '' OR
    price_each::text = '' OR
    order_date = '' OR
    purchase_address = '' OR
    month = '';

--дубликаты заказов
SELECT * 
FROM all_sales 
WHERE order_id IN (
    SELECT order_id 
    FROM all_sales 
    GROUP BY order_id 
    HAVING COUNT(*) > 1
)
ORDER BY order_id;

--есть дубликаты
--AI-ассистент предложил оптимальный результат
--создать новую таблицу без дубликатов и присвоить ей исходное имя
--Создаем чистую таблицу без дубликатов
CREATE TABLE all_sales_clean AS
SELECT DISTINCT ON (order_id) *
FROM all_sales
ORDER BY order_id, order_date;

-- заменяем старую таблицу
DROP TABLE all_sales;

--переименовываем
ALTER TABLE all_sales_clean RENAME TO all_sales;
--проверяем снова на дубликаты

--некорректные даты, у нас основной формат order_date 08/18/19 20:11
--найдем все, что отличается, условия шаблона прописаны ИИ-ассистентом
SELECT * FROM all_sales 
WHERE 
    order_date IS NULL OR
    order_date = '' OR
    order_date !~ '^\d{2}/\d{2}/\d{2} \d{2}:\d{2}$';

-- ИСПРАВЛЯЕМ ТИП ДАТЫ для анализа временных рядов

-- 1. Добавляем новую колонку с правильным типом
ALTER TABLE all_sales ADD COLUMN order_datetime_clean TIMESTAMP(0);

-- 2. Преобразуем текст в дату
UPDATE all_sales 
SET order_datetime_clean = order_date_corrected;

-- 3. Проверяем результат
SELECT order_date, order_date_corrected, order_datetime_clean 
FROM all_sales 
LIMIT 5;

-- 4. Удаляем старую текстовую колонку
ALTER TABLE all_sales DROP COLUMN order_date;
ALTER TABLE all_sales DROP COLUMN order_date_corrected;

-- 5. Переименовываем новую колонку
ALTER TABLE all_sales RENAME COLUMN order_datetime_clean TO order_date;


--итоговая проверка

SELECT 
    month,
    COUNT(DISTINCT order_id) as уникальных_заказов,  -- Вот так правильно!
    SUM(quantity_ordered) as всего_товаров,
    ROUND(SUM(quantity_ordered * price_each), 2) as выручка,
    ROUND(SUM(quantity_ordered * price_each) / COUNT(DISTINCT order_id), 2) as средний_чек
FROM all_sales 
GROUP BY month 
ORDER BY 
    CASE month
        WHEN 'January' THEN 1
        WHEN 'February' THEN 2
        WHEN 'March' THEN 3
        WHEN 'April' THEN 4
        WHEN 'May' THEN 5
        WHEN 'June' THEN 6
        WHEN 'July' THEN 7
        WHEN 'August' THEN 8
        WHEN 'September' THEN 9
        WHEN 'October' THEN 10
        WHEN 'November' THEN 11
        WHEN 'December' THEN 12
    END;
