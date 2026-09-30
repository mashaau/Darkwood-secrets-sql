/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: 
 * Дата: 
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT
    COUNT(id)          AS players,      -- всего игроков
    SUM(payer)          AS payers,       -- платящих игроков
    AVG(payer::numeric) AS payers_share  -- доля платящих
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT
    r.race                AS race,         -- раса
    SUM(u.payer)            AS payers,       -- платящих игроков расы
    COUNT(u.id)              AS players,      -- всего игроков расы
    AVG(u.payer::numeric)    AS payers_share  -- доля платящих
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id = r.race_id
GROUP BY r.race
ORDER BY payers_share DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT
    COUNT(transaction_id)                              AS cnt,     -- количество покупок
    SUM(amount)                                         AS total,   -- сумма покупок
    MIN(amount)                                         AS min,     -- минимум
    MAX(amount)                                         AS max,     -- максимум
    AVG(amount)                                         AS avg,     -- среднее
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS median,  -- медиана
    STDDEV(amount)                                      AS stddev   -- стандартное отклонение
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT
    COUNT(transaction_id)                                                                 AS zero_cnt,   -- нулевых покупок
    COUNT(transaction_id)::numeric / (SELECT COUNT(transaction_id) FROM fantasy.events)    AS zero_share  -- их доля
FROM fantasy.events
WHERE amount = 0;

-- 2.3: Популярные эпические предметы:
WITH purchases AS (
    SELECT *
    FROM fantasy.events
    WHERE amount > 0
),
buyers AS (
    SELECT COUNT(DISTINCT id) AS cnt
    FROM purchases
)
SELECT
    i.game_items                                                            AS item,          -- название предмета
    COUNT(p.transaction_id)                                                 AS cnt,           -- продаж предмета
    COUNT(p.transaction_id)::numeric / SUM(COUNT(p.transaction_id)) OVER () AS share,          -- доля от всех продаж
    COUNT(DISTINCT p.id)::numeric / (SELECT cnt FROM buyers)                AS buyers_share    -- доля купивших хоть раз
FROM purchases AS p
JOIN fantasy.items AS i ON p.item_code = i.item_code
GROUP BY i.game_items
ORDER BY cnt DESC;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH purchases AS (
    SELECT *
    FROM fantasy.events
    WHERE amount > 0
),
players AS (
    SELECT
        u.id,
        u.payer,
        r.race
    FROM fantasy.users AS u
    JOIN fantasy.race AS r ON u.race_id = r.race_id
),
stats AS (
    SELECT
        id,
        COUNT(transaction_id) AS cnt,
        SUM(amount)           AS total,
        AVG(amount)           AS avg
    FROM purchases
    GROUP BY id
)
SELECT
    pl.race                                                        AS race,          -- раса
    COUNT(pl.id)                                                   AS players,       -- всего игроков расы
    COUNT(s.id)                                                    AS buyers,        -- игроков с покупками
    COUNT(s.id)::numeric / COUNT(pl.id)                            AS buyers_share,  -- их доля
    SUM(CASE WHEN s.id IS NOT NULL THEN pl.payer ELSE 0 END)::numeric
        / NULLIF(COUNT(s.id), 0)                                   AS payers_share,  -- доля платящих среди покупателей
    AVG(s.cnt)                                                     AS avg_cnt,       -- среднее число покупок
    AVG(s.avg)                                                     AS avg_price,     -- средняя цена покупки
    AVG(s.total)                                                   AS avg_total      -- средняя сумма покупок на игрока
FROM players AS pl
LEFT JOIN stats AS s ON pl.id = s.id
GROUP BY pl.race
ORDER BY buyers_share DESC;
