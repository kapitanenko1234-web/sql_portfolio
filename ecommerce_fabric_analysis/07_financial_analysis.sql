-- 07_financial_analysis.sql
-- Финансовый анализ:
-- 1. Валовая прибыль по каналам.
-- 2. Влияние эквайринга на маржу.
-- 3. Чистая прибыль по месяцам.
 --4. ROI и ROMI по каналам.

-- 1. Валовая прибыль по каналам
SELECT 
    s.sales_channel,
    COUNT(*) as orders_count,
    SUM(s.total_amount) as total_revenue,
    SUM(s.meters * p.cost_per_meter) as total_cost,
    SUM(s.total_amount - (s.meters * p.cost_per_meter)) as gross_profit,
    ROUND((SUM(s.total_amount - (s.meters * p.cost_per_meter)) / SUM(s.total_amount) * 100)::numeric, 2) as gross_margin_percent
FROM fabric_analysis.fa_unified_sales s
JOIN fabric_analysis.fa_clean_products p ON s.product_id = p.product_id
WHERE s.status = 'Завершен'
GROUP BY s.sales_channel
ORDER BY gross_profit DESC;
-- ФИНАНСОВЫЕ ПОКАЗАТЕЛИ:
-- VK: 2.62 млн руб прибыли (55% маржа)
-- Internet:  1.80 млн руб прибыли (55% маржа)
-- КЛЮЧЕВЫЕ НАБЛЮДЕНИЯ:
-- 1. ОДИНАКОВАЯ МАРЖА: 55% по обоим каналам
-- 2. VK ЛИДИРУЕТ: На 45% больше прибыли чем Internet
-- 3. СТАБИЛЬНАЯ РЕНТАБЕЛЬНОСТЬ: Единая ценовая политика
-- ВЫВОД: Оба канала одинаково эффективны по марже, 
-- но VK приносит больше абсолютной прибыли

-- 2. Влияние эквайринга на маржу с реальными данными
SELECT 
    'Internet' as sales_channel,
    SUM(s.total_amount) as total_revenue,
    SUM(s.meters * p.cost_per_meter) as total_cost,
    -- Валовая прибыль до эквайринга
    SUM(s.total_amount - (s.meters * p.cost_per_meter)) as gross_profit_before_acquiring,
    -- Реальная сумма эквайринга из таблицы расходов
    (SELECT SUM(amount) FROM fabric_analysis.fa_clean_expenses 
     WHERE expense_type = 'Эквайринг' AND channel = 'Internet') as total_acquiring_fee,
    -- Чистая прибыль после эквайринга
    SUM(s.total_amount - (s.meters * p.cost_per_meter)) - 
    (SELECT SUM(amount) FROM fabric_analysis.fa_clean_expenses 
     WHERE expense_type = 'Эквайринг' AND channel = 'Internet') as net_profit_after_acquiring,
    -- Маржа до эквайринга
    ROUND((SUM(s.total_amount - (s.meters * p.cost_per_meter)) / SUM(s.total_amount) * 100)::numeric, 2) as gross_margin_percent,
    -- Маржа после эквайринга
    ROUND(((SUM(s.total_amount - (s.meters * p.cost_per_meter)) - 
           (SELECT SUM(amount) FROM fabric_analysis.fa_clean_expenses 
            WHERE expense_type = 'Эквайринг' AND channel = 'Internet')) / 
           SUM(s.total_amount) * 100)::numeric, 2) as net_margin_percent
FROM fabric_analysis.fa_unified_sales s
JOIN fabric_analysis.fa_clean_products p ON s.product_id = p.product_id
WHERE s.status = 'Завершен' AND s.sales_channel = 'Internet'
GROUP BY s.sales_channel;

-- ФИНАНСОВЫЕ ПОКАЗАТЕЛИ Internet-канала:
-- Выручка:          3.28 млн руб
-- Валовая прибыль:  1.80 млн руб (55.00% маржа)
-- Эквайринг:        90.6 тыс руб (2.76% от выручки)
-- Чистая прибыль:   1.71 млн руб (52.24% маржа)
-- КЛЮЧЕВЫЕ ВЫВОДЫ:
-- 1. ЭКВАЙРИНГ СЪЕДАЕТ: 2.76% от выручки
-- 2. СНИЖЕНИЕ МАРЖИ: с 55.00% до 52.24% (-2.76 п.п.)
-- 3. АБСОЛЮТНЫЕ ПОТЕРИ: 90.6 тыс руб уходит банкам
-- РЕКОМЕНДАЦИЯ: 
--Рассмотреть альтернативные платежные системы
--Оптимизировать тарифы эквайринга
--Учесть в ценообразовании

-- 3. Чистая прибыль по месяцам
-- Проверка данных расходов - суммарно по типам за все время
SELECT 
    sales.month,
    sales.revenue,
    sales.cost_of_goods,
    sales.gross_profit,
    expenses.total_expenses,
    sales.gross_profit - expenses.total_expenses as net_profit,
    ROUND(((sales.gross_profit - expenses.total_expenses) / sales.revenue * 100)::numeric, 2) as net_margin_percent
FROM (
    SELECT 
        TO_CHAR(s.date, 'YYYY-MM') as month,
        SUM(s.total_amount) as revenue,
        SUM(s.meters * p.cost_per_meter) as cost_of_goods,
        SUM(s.total_amount - (s.meters * p.cost_per_meter)) as gross_profit
    FROM fabric_analysis.fa_unified_sales s
    JOIN fabric_analysis.fa_clean_products p ON s.product_id = p.product_id
    WHERE s.status = 'Завершен'
    GROUP BY TO_CHAR(s.date, 'YYYY-MM')
) sales
JOIN (
    SELECT 
        TO_CHAR(date, 'YYYY-MM') as month,
        SUM(amount) as total_expenses
    FROM fabric_analysis.fa_clean_expenses
    GROUP BY TO_CHAR(date, 'YYYY-MM')
) expenses ON sales.month = expenses.month
ORDER BY sales.month;
-- КЛЮЧЕВЫЕ ПОКАЗАТЕЛИ:
-- Средняя выручка: ~350K руб/мес
-- Валовая маржа: ~50% стабильно
-- Чистая маржа: ~48-50% после расходов
-- Расходы: 15-20K руб/мес (5-7% от выручки)
-- ВЫВОДЫ:
-- 1. ВЫСОКАЯ РЕНТАБЕЛЬНОСТЬ: Чистая маржа 48-50% - отличный показатель
-- 2. СТАБИЛЬНОСТЬ: Прибыльность сохраняется на протяжении 2 лет
-- 3. ЭФФЕКТИВНОСТЬ: Расходы под контролем (5-7% от выручки)
-- ЛУЧШИЕ МЕСЯЦЫ:
-- Сентябрь 2018: 204K руб чистой прибыли (50.37% маржа)
-- Сентябрь 2019: 210K руб чистой прибыли (50.32% маржа)

-- 4. ROI и ROMI по каналам
-- Расходы на рекламу по каналам
SELECT 
    channel,
    SUM(amount) as marketing_spend
FROM fabric_analysis.fa_clean_expenses
WHERE expense_type = 'Реклама'
GROUP BY channel;

---- Общий ROMI для бизнеса
SELECT 
    'Total' as channel,
    SUM(s.total_amount - (s.meters * p.cost_per_meter)) as gross_profit,
    250000.85 as total_marketing_spend,
    ROUND(SUM(s.total_amount - (s.meters * p.cost_per_meter)) / 250000.85, 2) as romi
FROM fabric_analysis.fa_unified_sales s
JOIN fabric_analysis.fa_clean_products p ON s.product_id = p.product_id
WHERE s.status = 'Завершен';

-- ФИНАНСОВЫЕ ПОКАЗАТЕЛИ:
-- Валовая прибыль: 4,422,447 руб
-- Расходы на рекламу: 250,001 руб
-- ROMI = 17.69
-- ИНТЕРПРЕТАЦИЯ:
-- На 1 рубль, вложенный в рекламу, бизнес получает 17.69 рублей валовой прибыли
-- ОЦЕНКА ЭФФЕКТИВНОСТИ:
-- Средний ROMI в e-commerce: 3-5
-- Наш ROMI: 17.7 → В 3-5 раз выше нормы!
-- ВЫВОД: 
-- Маркетинговая стратегия исключительно эффективна
-- Можно увеличивать рекламные бюджеты

