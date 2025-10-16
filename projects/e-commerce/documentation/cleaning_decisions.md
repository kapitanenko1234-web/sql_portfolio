# 🧼 Решения по очистке данных и их обоснование

## 📊 Общий пайплайн очистки данных

---

1. Стандартизация структуры данных
Проблема: 12 таблиц с разными форматами названий колонок

```sql
-- Было: "Order ID", "Product", "Quantity Ordered"
-- Стало: order_id, product, quantity_ordered
```
Решение: Автоматизированное переименование колонок

```sql
DO $$ 
DECLARE 
    table_name TEXT;
BEGIN
    FOR table_name IN (SELECT 'sales_january' UNION ALL SELECT 'sales_february' ...)
    LOOP
        EXECUTE 'ALTER TABLE ' || table_name || ' RENAME COLUMN "Order ID" TO order_id';
        -- и так для всех колонок
    END LOOP;
END $$;
```
2. Обработка проблемных данных
Выявленные проблемы:

- Заголовки таблиц в данных ("Order ID", "Product")

- Пустые строки

- Некорректные типы данных

Решение:

```sql
-- Удаление строк-заголовков
DELETE FROM sales_march WHERE order_id = 'Order ID';

-- Удаление пустых значений
DELETE FROM sales_march WHERE quantity_ordered = '' OR price_each = '';
```
3. Консолидация данных
Объединение 12 monthly таблиц в одну общую:

```sql
INSERT INTO all_sales 
SELECT 
    order_id::VARCHAR(50),
    product::VARCHAR(200),
    quantity_ordered::INTEGER,
    price_each::DECIMAL(10,2),
    order_date::TEXT,
    purchase_address::TEXT,
    'January' as month
FROM sales_january
WHERE quantity_ordered::INTEGER > 0 AND price_each::DECIMAL > 0;
```
4. Глубокая очистка данных
Удаление некорректных записей:

```sql
DELETE FROM all_sales 
WHERE 
    -- Отсутствующие значения
    order_id IS NULL OR product IS NULL OR
    -- Некорректные бизнес-значения
    quantity_ordered <= 0 OR price_each <= 0;
```
Устранение дубликатов:

```sql
-- Создание чистой таблицы без дубликатов
CREATE TABLE all_sales_clean AS
SELECT DISTINCT ON (order_id) *
FROM all_sales
ORDER BY order_id, order_date;

-- Замена исходной таблицы
DROP TABLE all_sales;
ALTER TABLE all_sales_clean RENAME TO all_sales;
```
5. Преобразование типов данных
Приведение даты к правильному формату:

```sql
-- Добавление колонки с правильным типом
ALTER TABLE all_sales ADD COLUMN order_datetime_clean TIMESTAMP(0);

-- Преобразование данных
UPDATE all_sales 
SET order_datetime_clean = TO_TIMESTAMP(order_date, 'MM/DD/YY HH24:MI');

-- Замена старой колонки
ALTER TABLE all_sales DROP COLUMN order_date;
ALTER TABLE all_sales RENAME COLUMN order_datetime_clean TO order_date;
```
📈 Проверка качества данных
Финальная валидация
```sql
SELECT 
    month,
    COUNT(DISTINCT order_id) as уникальных_заказов,
    SUM(quantity_ordered) as всего_товаров,
    ROUND(SUM(quantity_ordered * price_each), 2) as выручка,
    ROUND(SUM(quantity_ordered * price_each) / COUNT(DISTINCT order_id), 2) as средний_чек
FROM all_sales 
GROUP BY month 
ORDER BY MIN(order_date);
```
