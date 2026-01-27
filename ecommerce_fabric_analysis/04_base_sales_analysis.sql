-- 04_sales_analysis.sql
-- Анализ продаж: Базовая аналитика
-- 1 Построить динамику продаж по дням / неделям.
-- 2 Продажи по городам.
-- 3 Продажи по каналам (VK vs сайт).
-- 4 Средний чек по каналам.
-- 5 Доля отказов в заказах.

-- 1. Создаем общую таблицу продаж из очищенных данных VK и интернет-магазина
CREATE TABLE fabric_analysis.fa_unified_sales AS
-- Данные из очищенной VK таблицы
SELECT 
    sale_id,
    date,
    client_id,
    city,
    zip_code,
    product_id,
    meters,
    total_amount,
    status,
    'VK' as sales_channel
FROM fabric_analysis.fa_clean_sales_vk
UNION ALL
-- Данные из очищенной Internet таблицы
SELECT 
    sale_id,
    date,
    client_id,
    city,
    zip_code,
    product_id,
    meters,
    total_amount,
    status,
    'Internet' as sales_channel
FROM fabric_analysis.fa_clean_sales_internet;

-- Динамика продаж по дням
SELECT 
    date,
    COUNT(*) as orders_count,
    SUM(total_amount) as total_revenue,
    SUM(meters) as total_meters,
    AVG(total_amount) as avg_order_value
FROM fabric_analysis.fa_unified_sales
WHERE status = 'Завершен'
GROUP BY date
ORDER BY date;

-- Динамика продаж по месяцам с названиями месяцев
SELECT 
    TO_CHAR(date, 'YYYY-MM') as month_code,
    TO_CHAR(date, 'Month YYYY') as month_name,
    COUNT(*) as orders_count,
    SUM(total_amount) as total_revenue,
    SUM(meters) as total_meters,
    AVG(total_amount) as avg_order_value
FROM fabric_analysis.fa_unified_sales
WHERE status = 'Завершен'
GROUP BY month_code, month_name
ORDER BY month_code;
-- КЛЮЧЕВЫЕ НАБЛЮДЕНИЯ:
-- СЕЗОННОСТЬ:
-- Пики продаж: Сентябрь-Ноябрь (подготовка к зиме)
-- Спады: Июнь-Август (летний сезон)
-- ФИНАНСОВЫЕ ПОКАЗАТЕЛИ:
-- Самый прибыльный месяц: Сентябрь 2019 (422К рублей)
-- Средний чек стабилен: 700-780 рублей
-- Общая выручка: ~8-9 млн рублей в год
-- ТРЕНДЫ:
-- 2019 год стабилен после роста в 2018
-- 2020 начался с хороших показателей
-- Сентябрь - consistently самый сильный месяц
-- ОБЪЕМЫ:
-- Продажи метров ткани коррелируют с выручкой
-- В среднем 2.2-2.8 метра на заказ

-- 2.Продажи по городам (сортировка по выручке)
SELECT 
    city,
    COUNT(*) as orders_count,
    SUM(total_amount) as total_revenue,
    SUM(meters) as total_meters,
    AVG(total_amount) as avg_order_value
FROM fabric_analysis.fa_unified_sales
WHERE status = 'Завершен'
GROUP BY city
ORDER BY total_revenue DESC;
-- ТОП-8 ГОРОДОВ ПО ВЫРУЧКЕ:
-- 1. Мытищи     - 1.14 млн руб. - ЛИДЕР
-- 2. Москва     - 1.07 млн руб.  
-- 3. Реутов     - 1.06 млн руб.
-- 4. Люберцы    - 997 тыс. руб. - самый высокий средний чек (758 руб.)
-- 5. Подольск   - 988 тыс. руб. - самый низкий средний чек (718 руб.)
-- 6. Красногорск- 981 тыс. руб.
-- 7. Королёв    - 973 тыс. руб.
-- 8. Химки      - 961 тыс. руб.
-- ОСОБЕННОСТИ:
-- Распределение очень равномерное (разница всего 15% между 1 и 8 местом)
-- Люберцы: максимальный средний чек (покупают дороже)
-- Подольск: минимальный средний чек (более бюджетные покупки)
-- Все города показывают стабильные объемы (~1300-1500 заказов)

-- 3. Сравнение каналов продаж VK vs Internet, общая вырука и сркдний чек 
SELECT 
    sales_channel,
    COUNT(*) as orders_count,
    SUM(total_amount) as total_revenue,
    SUM(meters) as total_meters,
    ROUND(AVG(total_amount)::numeric, 2) as avg_order_value,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fabric_analysis.fa_unified_sales WHERE status = 'Завершен')::numeric, 0) as percent_of_total
FROM fabric_analysis.fa_unified_sales
WHERE status = 'Завершен'
GROUP BY sales_channel
ORDER BY total_revenue DESC;
-- VK приносит на 50% больше выручки
-- Средние чеки практически одинаковы (~738 руб.)
-- VK генерирует больше заказов, но не дороже

-- 3. Доля отказов по каналам продаж
SELECT 
    sales_channel,
    COUNT(*) as total_orders,
    SUM(CASE WHEN status = 'Отказ' THEN 1 ELSE 0 END) as refused_orders,
    ROUND(SUM(CASE WHEN status = 'Отказ' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)::numeric, 0) as refusal_rate_percent
FROM fabric_analysis.fa_unified_sales
GROUP BY sales_channel
ORDER BY refusal_rate_percent DESC;

-- Доля отказов по городам
SELECT 
    city,
    COUNT(*) as total_orders,
    SUM(CASE WHEN status = 'Отказ' THEN 1 ELSE 0 END) as refused_orders,
    ROUND(SUM(CASE WHEN status = 'Отказ' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)::numeric, 1) as refusal_rate_percent
FROM fabric_analysis.fa_unified_sales
GROUP BY city
ORDER BY refusal_rate_percent DESC;

-- КАНАЛЫ: Одинаковая доля отказов 10% (VK: 771, Internet: 490)
-- ГОРОДА: Максимум: Подольск (11.7%)  
-- Минимум: Реутов (8.7%), разница между городами: 3%
-- ВЫВОД: Проблема отказов системная, не зависит от канала
-- Требуется анализ причин в городах-лидерах по отказам