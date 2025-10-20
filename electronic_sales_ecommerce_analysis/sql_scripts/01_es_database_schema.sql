-- =============================================
-- E-COMMERCE ANALYSIS: SCHEMA SETUP
-- Создание структуры базы данных
-- =============================================
--после изучения структуры бызы данных принимаем решение
--о необходимости создания общей таблицы по продажам 

-- ОСНОВНАЯ ТАБЛИЦА ДЛЯ АНАЛИЗА
CREATE TABLE all_sales (
    order_id VARCHAR(50),
    product VARCHAR(200),
    quantity_ordered INTEGER,
    price_each DECIMAL(10,2),
    order_date TEXT,
    purchase_address TEXT,
    month VARCHAR(20)
);
