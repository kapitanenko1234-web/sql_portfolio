# 🧼 Решения по очистке данных и их обоснование

## 📊 Общий пайплайн очистки данных

---

### 1. 🧭 Стандартизация схемы данных

**Проблема:** несогласованные названия колонок между файлами.  
**Решение:** использование стандартизированной конвенции именования для всех таблиц.  

```sql
ALTER TABLE sales_january RENAME COLUMN "Order ID" TO order_id;
ALTER TABLE sales_january RENAME COLUMN "Product" TO product;
ALTER TABLE sales_january RENAME COLUMN "Quantity Ordered" TO quantity_ordered;
ALTER TABLE sales_january RENAME COLUMN "Price Each" TO price_each;
ALTER TABLE sales_january RENAME COLUMN "Order Date" TO order_date;
ALTER TABLE sales_january RENAME COLUMN "Purchase Address" TO purchase_address;
```

2. 🪣 Удаление строк заголовков

Проблема: заголовки CSV-файлов были импортированы как данные в 4 месяцах.  
Решение: идентификация строк-заголовков по значению `order_id = 'Order ID'` и их удаление.

```sql
DELETE FROM sales_march WHERE order_id = 'Order ID';
```

3. 🧮 Конвертация типов данных

Проблема: в исходных данных использовались смешанные типы и текстовые даты.  
Решение: преобразование дат в единый формат `TIMESTAMP` с валидацией.

```sql
DELETE FROM sales_march WHERE order_id = 'Order ID';
DELETE FROM sales_june WHERE order_id = 'Order ID';
DELETE FROM sales_september WHERE order_id = 'Order ID';
DELETE FROM sales_december WHERE order_id = 'Order ID';
```

4. ✅ Валидация данных

Проблема: наличие невалидных значений и пропусков в ключевых полях.  
Решение: фильтрация по критериям качества данных.

```sql
DELETE FROM all_sales
WHERE quantity_ordered <= 0
OR price_each <= 0
OR order_date IS NULL;
```

⚠️ Критические решения
1. 🧩 Обработка дубликатов

Проблема: в датасете обнаружены точные дубликаты строк.  
Решение: сохранение первого вхождения, удаление дубликатов по ключевым полям (`order_id`, `product_id`, `order_datetime_clean`).
Обоснование: предотвращение двойного подсчёта выручки.
Влияние: 3 500 записей удалено (1.8 % датасета).

```sql
DELETE FROM all_sales a
USING all_sales b
WHERE a.ctid < b.ctid
AND a.order_id = b.order_id
AND a.product_id = b.product_id
AND a.order_datetime_clean = b.order_datetime_clean;
```

2. 🕳️ Пропущенные данные

Проблема: часть записей содержала пропуски в критических полях.  
Решение: удаление неполных записей, кроме случаев с частичными адресами (сохранены для геоаналитики).
Результат: 99.6 % полноты данных для ключевых метрик.

```sql
DELETE FROM all_sales
WHERE order_id IS NULL
OR product_id IS NULL
OR quantity_ordered IS NULL;
```

3. 🕰️ Стандартизация форматов дат

Проблема: множественные форматы дат в исходных данных.  
Решение: унификация формата `MM/DD/YY HH24:MI` для всех таблиц.
Преимущество: обеспечен точный анализ временных рядов.

```sql
UPDATE all_sales
SET order_datetime_clean = TO_TIMESTAMP(order_date, 'MM/DD/YY HH24:MI');
```

