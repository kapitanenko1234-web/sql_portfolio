--Warning!
--При анализе выявлена потенциальная критическая ошибка в интерпретации данных:
--price_each = цена за 1 единицу товара, а не общая стоимость заказа
--quantity_ordered = количество единиц в заказе
--выручка должна рассчитываться: quantity_ordered × price_each

-- =============================================
-- E-COMMERCE ANALYSIS: SALES ANOMALIES DETECTION
-- Выявление аномалий продаж
-- =============================================

--делаем сводную таблицу по месяцам, ищем паттерны
SELECT 
    month,
    COUNT(order_id) as уникальных_заказов, 
    SUM(quantity_ordered) as всего_товаров,
    ROUND(SUM(quantity_ordered * price_each), 2) as выручка,
    ROUND(SUM(quantity_ordered * price_each) / COUNT(order_id), 2) as средний_чек
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

--Март, Июнь, Август, Декабрь - ОЧЕНЬ много заказов
--Февраль, Апрель, Июль - ОЧЕНЬ мало заказов
--при этом средний чек месяца немного отличается и не всегда зависит от выручки
--сравниваем средний чек и выручку
SELECT 
    month,
    COUNT(order_id) as заказов,
    ROUND(SUM(quantity_ordered * price_each), 2) as выручка,
    ROUND(SUM(quantity_ordered * price_each) / COUNT(order_id), 2) as средний_чек
FROM all_sales 
GROUP BY month
ORDER BY выручка DESC;

--Сентябрь имеет самый высокий средний чек (190), хотя выручка там небольшая
--Февраль - самый низкий чек (154) и самая низкая выручка
--сравниваем количество продаж ТОП товаров по стоимости
SELECT 
    product as товар,
    COUNT(*) as раз_продано,
    AVG(price_each) as средняя_цена,
    SUM(quantity_ordered * price_each) as выручка
FROM all_sales 
WHERE month = 'September'
GROUP BY product
ORDER BY средняя_цена DESC
LIMIT 10;


SELECT 
    product as товар,
    COUNT(*) as раз_продано,
    AVG(price_each) as средняя_цена,
    SUM(quantity_ordered * price_each) as выручка
FROM all_sales 
WHERE month = 'February'
GROUP BY product
ORDER BY средняя_цена DESC
LIMIT 10;

--проверяем не менялась ли цена за год
--упорядочим по цене по убыванию
SELECT 
    product as товар,
    AVG(CASE WHEN month = 'January' THEN price_each END) as январь,
    AVG(price_each) as средняя,
    AVG(CASE WHEN month = 'December' THEN price_each END) as декабрь
FROM all_sales 
GROUP BY product
ORDER BY средняя desc

-- выявим самые самые дорогие товары
SELECT 
    product as товар,
    ROUND(AVG(price_each), 2) as средняя_цена,
    COUNT(*) as всего_продаж
FROM all_sales 
GROUP BY product
ORDER BY средняя_цена DESC;

--всего 19 товаров
--цена на товары не менялась
--Понимаем, что есть зависимость выручки по месяцу
--от количества проданных дорогих товаров
--Считаем количество товаров с разбивкой по всем  месяцам
SELECT 
    product as товар,
    ROUND(AVG(price_each), 2) as средняя_цена,
    SUM(CASE WHEN month = 'January' THEN quantity_ordered ELSE 0 END) as "Январь",
    SUM(CASE WHEN month = 'February' THEN quantity_ordered ELSE 0 END) as "Февраль",
    SUM(CASE WHEN month = 'March' THEN quantity_ordered ELSE 0 END) as "Март",
    SUM(CASE WHEN month = 'April' THEN quantity_ordered ELSE 0 END) as "Апрель",
    SUM(CASE WHEN month = 'May' THEN quantity_ordered ELSE 0 END) as "Май",
    SUM(CASE WHEN month = 'June' THEN quantity_ordered ELSE 0 END) as "Июнь",
    SUM(CASE WHEN month = 'July' THEN quantity_ordered ELSE 0 END) as "Июль",
    SUM(CASE WHEN month = 'August' THEN quantity_ordered ELSE 0 END) as "Август",
    SUM(CASE WHEN month = 'September' THEN quantity_ordered ELSE 0 END) as "Сентябрь",
    SUM(CASE WHEN month = 'October' THEN quantity_ordered ELSE 0 END) as "Октябрь",
    SUM(CASE WHEN month = 'November' THEN quantity_ordered ELSE 0 END) as "Ноябрь",
    SUM(CASE WHEN month = 'December' THEN quantity_ordered ELSE 0 END) as "Декабрь"
FROM all_sales 
GROUP BY product
ORDER BY средняя_цена DESC;

--Анализ показал, что 9-кратная разница в выручке между месяцами 
--обусловлена объемами продаж премиум-сегмента, а не изменением цен или ассортимента.
--В высокодоходные месяцы (Март, Июнь, Август, Декабрь) 
--продавали в 10-15 раз больше дорогих товаров.
