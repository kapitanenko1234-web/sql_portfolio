-- =============================================
-- E-COMMERCE ANALYSIS: TEMPORAL PATTERNS ANALYSIS  
-- Временной анализ для выявления паттернов поведения покупателей
-- =============================================
--1.Анализ по часам - пиковые периоды продаж
--посмотрим как выглядят наши даты
SELECT order_date 
FROM all_sales 
LIMIT 5;
--можем выбрать каждый параметр даты и времени отдельно

--анализ по часам в сутках
SELECT 
    EXTRACT(HOUR FROM order_date) as час,
    COUNT(*) as всего_заказов
FROM all_sales 
GROUP BY час
ORDER BY час;

--выявили паттерны пиковых покупок: 18-20 часов и 10-14 часов 
--ночью с 1 до 6 активность в 4 раза ниже чем днем
--с 7 утра до 9 утра активность возрастает в 2 раза
--пик активности 19.00, которая к 0 часов постепеноо снижается в 2 раза

-- 2.Анализ по дням недели - weekly patterns
--Сначала посмотрим какие дни недели есть в данных
SELECT 
    EXTRACT(DOW FROM order_date) as номер_дня_недели,
    COUNT(*) as всего_заказов
FROM all_sales 
GROUP BY номер_дня_недели
ORDER BY номер_дня_недели;

--Анализ с названиями дней, 
--берем формат ISODOW стандарт, привычный для России  
SELECT 
    CASE EXTRACT(ISODOW FROM order_date)
        WHEN 1 THEN 'Понедельник'
        WHEN 2 THEN 'Вторник'
        WHEN 3 THEN 'Среда'
        WHEN 4 THEN 'Четверг'
        WHEN 5 THEN 'Пятница'
        WHEN 6 THEN 'Суббота'
        WHEN 7 THEN 'Воскресенье'
    END as день_недели,
    COUNT(*) as всего_заказов,
    ROUND(SUM(quantity_ordered * price_each), 2) as выручка,
    ROUND(AVG(quantity_ordered * price_each), 2) as средний_чек
FROM all_sales 
GROUP BY день_недели, EXTRACT(ISODOW FROM order_date)
ORDER BY EXTRACT(ISODOW FROM order_date);

--Люди больше покупают на выходных
--Во вторник покупают дорогие товары
--Середина недели - наименее активный период
--Пятница - старт "шопинг-уикенда"
--Понедельник - стандартный рабочий день покупок

-- 3. Анализ по числам месяца - monthly trends
--выберем ТОП 5 самых дорогих продуктов
SELECT 
    product as товар,
    AVG(price_each) as цена
FROM all_sales 
GROUP BY product
ORDER BY цена DESC
LIMIT 5;

--теперь выведем количество по каждому месяцу
SELECT 
    product as товар,
    SUM(CASE WHEN month = 'January' THEN quantity_ordered ELSE 0 END) as январь,
    SUM(CASE WHEN month = 'February' THEN quantity_ordered ELSE 0 END) as февраль,
    SUM(CASE WHEN month = 'March' THEN quantity_ordered ELSE 0 END) as март,
    SUM(CASE WHEN month = 'April' THEN quantity_ordered ELSE 0 END) as апрель,
    SUM(CASE WHEN month = 'May' THEN quantity_ordered ELSE 0 END) as май,
    SUM(CASE WHEN month = 'June' THEN quantity_ordered ELSE 0 END) as июнь,
    SUM(CASE WHEN month = 'July' THEN quantity_ordered ELSE 0 END) as июль,
    SUM(CASE WHEN month = 'August' THEN quantity_ordered ELSE 0 END) as август,
    SUM(CASE WHEN month = 'September' THEN quantity_ordered ELSE 0 END) as сентябрь,
    SUM(CASE WHEN month = 'October' THEN quantity_ordered ELSE 0 END) as октябрь,
    SUM(CASE WHEN month = 'November' THEN quantity_ordered ELSE 0 END) as ноябрь,
    SUM(CASE WHEN month = 'December' THEN quantity_ordered ELSE 0 END) as декабрь
FROM all_sales 
WHERE product IN (
    'Macbook Pro Laptop', 
    'ThinkPad Laptop',
    'iPhone',
    '27in 4K Gaming Monitor',
    '34in Ultrawide Monitor'
)
GROUP BY product
ORDER BY product;
--Март, Июнь, Август, Декабрь - пиковые месяцы (в 10-50 раз выше среднего)
--Февраль, Апрель, Июль - провальные месяцы (минимальные продажи)
