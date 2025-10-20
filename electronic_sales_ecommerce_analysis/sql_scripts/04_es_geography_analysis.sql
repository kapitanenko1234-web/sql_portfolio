-- =============================================
-- E-COMMERCE ANALYSIS: GEOGRAPHICAL & TEXT ANALYSIS
-- Анализ географического распределения и текстовых данных
-- =============================================


-- Анализ 1: Распределение продаж по штатам
--извлечем буквы штата из адреса, пример: 944 Walnut St, Boston, MA 02215
SELECT purchase_address,
       SUBSTR(purchase_address, LENGTH(purchase_address) - 7, 2) as state
FROM all_sales 
LIMIT 10;

-- группируем данные по штатам и сортируем по выручке
SELECT 
    SUBSTR(purchase_address, LENGTH(purchase_address) - 7, 2) as state,
    COUNT(*) as order_count,
    SUM(quantity_ordered * price_each) as total_revenue
FROM all_sales 
GROUP BY state
ORDER BY total_revenue DESC;

--всего продажи осуществляются в 8 штатах
--Калифорния (CA) - абсолютный лидер с 27K+ заказов
--NY, TX, MA формируют вторую группу лидеров (7K-9K заказов)  
--География продаж неравномерна - разрыв между лидером и аутсайдером 30:1

-- Анализ 2: Топ-5 городов по выручке 
--извлекаем город из адреса
SELECT purchase_address,
       TRIM(SPLIT_PART(purchase_address, ',', 2)) as city
FROM all_sales 
LIMIT 5;

--считаем выручку по городам, группируем по городу, сортируем по выручке
SELECT 
    TRIM(SPLIT_PART(purchase_address, ',', 2)) as city,
    ROUND(SUM(quantity_ordered * price_each), 2) as total_revenue
FROM all_sales 
GROUP BY city
ORDER BY total_revenue DESC
LIMIT 5;

--Сан-Франциско - абсолютный лидер (3M+ выручки)
--Лос-Анджелес и Нью-Йорк формируют вторую группу (1.7M-2M)  
--Разрыв между 1 и 5 местом - 3 раза, география продаж концентрированная

-- Анализ 3: Средний чек по регионам

--данные по штатам
SELECT 
    SUBSTR(purchase_address, LENGTH(purchase_address) - 7, 2) as state,
    COUNT(DISTINCT order_id) as total_orders,
    SUM(quantity_ordered * price_each) as total_revenue
FROM all_sales 
GROUP BY state

--вычисляем средний чек
SELECT 
    SUBSTR(purchase_address, LENGTH(purchase_address) - 7, 2) as state,
    COUNT(DISTINCT order_id) as total_orders,
    SUM(quantity_ordered * price_each) as total_revenue,
    ROUND(SUM(quantity_ordered * price_each) / COUNT(DISTINCT order_id), 2) as avg_check
FROM all_sales 
GROUP BY state
ORDER BY avg_check DESC;

--стабильность среднего чека в большинстве регионов (разница всего 5$)
--CA при максимальной выручке имеет средний чек на уровне большинства
--отсутствует прямая зависимость между объемом продаж и средним чеком

-- Анализ 4: Группировка товаров по категориям через текстовые паттерны

--запрашиваем список всех товаров
SELECT DISTINCT
    product as товар,
    price_each as цена
FROM all_sales
ORDER BY product;

--поручила AI-ассичтенту определить ключевые категории товаров и текстовые паттерны
--группировка товаров по категориям через текстовые паттерны
SELECT 
    CASE 
        WHEN product LIKE '%iPhone%' OR product LIKE '%Phone%' THEN 'Phones'
        WHEN product LIKE '%Laptop%' THEN 'Laptops' 
        WHEN product LIKE '%Monitor%' THEN 'Monitors'
        WHEN product LIKE '%Headphones%' THEN 'Headphones'
        WHEN product LIKE '%Batteries%' THEN 'Batteries'
        WHEN product LIKE '%Charging Cable%' THEN 'Charging Cables'
        WHEN product LIKE '%TV%' THEN 'TVs'
        WHEN product LIKE '%Dryer%' OR product LIKE '%Washing Machine%' THEN 'Home Appliances'
        ELSE 'Other'
    END as product_category,
    COUNT(*) as order_count,
    ROUND(SUM(quantity_ordered * price_each), 2) as total_revenue
FROM all_sales 
GROUP BY product_category
ORDER BY total_revenue DESC;
--ноутбуки - самая доходная категория (4,5M$) при среднем количестве заказов
--телефоны - вторая по выручке (3M$) с высоким средним чеком
--зарядные кабели и батарейки - массовые товары с низкой маржой
--наушники - лидер по количеству заказов (17K+) при средней выручке
--мониторы показывают хороший баланс между ценой и объемом продаж

-- Анализ 5: Извлечение и анализ почтовых индексов для прогнозирование геомаркетинга

--извлекаем почтовый индекс из адреса "944 Walnut St, Boston, MA 02215"
SELECT purchase_address,
       SUBSTR(purchase_address, LENGTH(purchase_address) - 4, 5) as zip_code
FROM all_sales 
LIMIT 10;

--анализируем выручку по почтовым индексам, связываем с городами
--группируем по индексу, сортируем по выручке
SELECT 
    SUBSTR(purchase_address, LENGTH(purchase_address) - 4, 5) as zip_code,
    TRIM(SPLIT_PART(purchase_address, ',', 2)) as city,
    COUNT(*) as order_count,
    ROUND(SUM(quantity_ordered * price_each), 2) as total_revenue
FROM all_sales 
GROUP BY zip_code, city
ORDER BY total_revenue DESC
LIMIT 15;

--представление для визуализации: процентное распределение прибыли по городам
SELECT 
    zip_code,
    city, 
    total_revenue,
    ROUND(100.0 * total_revenue / SUM(total_revenue) OVER(), 1) as percent
FROM (
    SELECT 
        SUBSTR(purchase_address, LENGTH(purchase_address) - 4, 5) as zip_code,
        TRIM(SPLIT_PART(purchase_address, ',', 2)) as city,
        SUM(quantity_ordered * price_each) as total_revenue
    FROM all_sales 
    GROUP BY zip_code, city
) data
ORDER BY total_revenue DESC
LIMIT 10;


--представлено всего 10 городов
--94016 (Сан-Франциско) - абсолютный лидер по выручке (3M+)
--топ-5 индексов дают 70%+ общей выручки - высокая концентрация
--крупные города доминируют: SF, LA, NYC, Boston, Seattle
--почтовые индексы центральных районов мегаполисов - самые прибыльные
--разрыв между первым и последним местом топа - 20 раз
--география продаж крайне неравномерна

-- Анализ 6: Анализ брендов в названиях товаров

--мы знаем, что у нас 19 уникальных товаров, 
--поручаем AI-ассистенту проанализировать названия товаров и выделить бренды
--создаем расширенную логику брендов, всего получилось 11 категорий
--сразу считаем долю каждой категории в общей выручке 
WITH category_revenue AS (
    SELECT 
        CASE 
            WHEN product LIKE '%iPhone%' OR product LIKE '%Macbook%' OR product LIKE '%Apple%' THEN 'Apple'
            WHEN product LIKE '%Bose%' THEN 'Bose'
            WHEN product LIKE '%LG%' THEN 'LG'
            WHEN product LIKE '%Google%' THEN 'Google'
            WHEN product LIKE '%Vareebadd%' THEN 'Vareebadd'
            WHEN product LIKE '%ThinkPad%' THEN 'Lenovo'
            WHEN product LIKE '%Monitor%' THEN 'Monitors'
            WHEN product LIKE '%Headphones%' THEN 'Headphones'
            WHEN product LIKE '%Charging Cable%' THEN 'Charging Cables'
            WHEN product LIKE '%Batteries%' THEN 'Batteries'
            WHEN product LIKE '%TV%' OR product LIKE '%Dryer%' OR product LIKE '%Washing Machine%' THEN 'Home Appliances'
            ELSE 'Other Electronics'
        END as category,
        SUM(quantity_ordered * price_each) as revenue
    FROM all_sales 
    GROUP BY category
)
SELECT 
    category,
    revenue,
    ROUND(100.0 * revenue / SUM(revenue) OVER(), 1) as revenue_percent
FROM category_revenue
ORDER BY revenue_percent DESC;
--Apple доминирует с 43.8% выручки - каждый второй доллар от Apple
--топ-3 категории (Apple, Monitors, Lenovo) дают 75% всей выручки
--Аксессуары (Charging Cables, Batteries) массовые, но низкомаржинальные

-- Анализ 10: Кросс-анализ географии и товарных предпочтений

--что покупают в каждом городе
SELECT 
    TRIM(SPLIT_PART(purchase_address, ',', 2)) as city,
    product,
    COUNT(*) as order_count
FROM all_sales 
GROUP BY city, product
ORDER BY city, order_count DESC;
--во всех городах топ-5 идентичен: аксессуары (кабели, батарейки, наушники)
--нет географических различий в товарных предпочтениях
--Сан-Франциско лидер по объему продаж аксессуаров