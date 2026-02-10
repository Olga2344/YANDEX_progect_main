select table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'fantasy'

select *
FROM information_schema.key_column_usage
WHERE table_schema = 'fantasy'

SELECT *
FROM fantasy.items
;

SELECT *
FROM fantasy.classes
;

WITH pay as(SELECT race_id, count(DISTINCT id) AS paying_users
			FROM fantasy.users u
			WHERE u.payer =1
			GROUP BY race_id),
all_users AS ( SELECT 
					race_id,count(DISTINCT u.id) AS total_users, 
					avg(payer) AS avg_payer,
					avg(amount) AS avg_amount,
					sum(amount) AS sum_amount
				FROM fantasy.users u 
				LEFT JOIN fantasy.events e ON u.id = e.id
				GROUP BY race_id),
smal_table as(
			SELECT r.race,
				p.race_id,
				paying_users,
				avg_amount,
				sum_amount,
				total_users,
				sum(total_users) over() AS total,
				p.paying_users::FLOAT / a.total_users AS paying_user_by_race,--доля платящих пользователей относительно зарегистрированных в рассе
				avg_payer
			FROM pay AS p
			JOIN all_users AS a ON p.race_id = a.race_id
			JOIN fantasy.race AS r ON r.race_id = p.race_id)
SELECT 
		race,--раса
		paying_users, --покупали листы за деньги
		total_users, --всего юзеров по расам
		total, --всего польщователей
		paying_user_by_race, --доля платящих пользователей относительно зарегистрированных в рассе
		avg_payer, --доля платящих пользователей относительно всего количества пользователей
		avg_amount, -- средние траты по расам
		sum_amount -- всего покупок на расу
FROM smal_table 
ORDER BY paying_user_by_race DESC;

/*Проверьте, встречаются ли покупки с нулевой стоимостью. 
 * Если да, найдите их абсолютное количество и долю от общего числа покупок. 
 * Покупки с нулевой стоимостью не помогают зарабатывать
 *  внутриигровую валюту «райские лепестки», и их следует исключить при решении следующих задач
*/

SELECT (SELECT count(*) FROM fantasy.events e WHERE e.amount=0)::float/
(SELECT count(*) FROM fantasy.events e)


SELECT  'total_users_events',
		count(e.transaction_id) AS count_transaction,
		sum(e.amount) AS sum_purch,
		min(e.amount) AS min_amount,
		max(e.amount) max_amount,
		avg(e.amount),
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY e.amount) AS mediana,
		STDDEV(e.amount) AS standart_dev
FROM fantasy.events e-- траты всех пльзователей игры
UNION ALL
SELECT 'paying_users',
		count(e.transaction_id) AS count_transaction,
		sum(e.amount) AS sum_purch,
		min(e.amount) AS min_amount,
		max(e.amount) max_amount,
		avg(e.amount),
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY e.amount) AS mediana,
		STDDEV(e.amount) AS standart_dev
FROM fantasy.events e
WHERE id IN 
	(SELECT id FROM fantasy.users WHERE payer =1); -- траты пользователей купивших игровую валюту за деньги

SELECT id,
		count(e.transaction_id) AS count_transaction,
		sum(e.amount) AS sum_purch,
		min(e.amount) AS min_amount,
		max(e.amount) max_amount,
		avg(e.amount),
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY e.amount) AS mediana,
		STDDEV(e.amount) AS standart_dev
FROM fantasy.events e
WHERE id IN 
	(SELECT id FROM fantasy.users WHERE payer =1) 
GROUP BY id
ORDER BY sum(e.amount) DESC; --деньги по юзерам покупавшим игровую валюту за деньги
		
WITH count_amount as(SELECT id,
		count(e.transaction_id) AS count_transaction,
		sum(e.amount) AS sum_purch
		FROM fantasy.events e
		WHERE id IN (SELECT  id FROM fantasy.users WHERE payer =1)
		GROUP BY id
		ORDER BY count_transaction DESC
	)
SELECT *,
	sum(sum_purch) over() AS total_sum,
	count(count_transaction) over()  AS total_count
FROM count_amount 


/*
 * Изучите популярность эпических предметов. 
 * Для каждого предмета посчитайте общее количество внутриигровых продаж в 
 * абсолютном и относительном значениях. Относительное значение должно быть
 *  долей продажи каждого предмета от всех продаж. Найдите также долю игроков, 
 * которые хотя бы раз покупали этот предмет. Результат отфильтруйте по 
 * популярности эпического предмета среди игроков. 
 * */

SELECT game_items, 
count(e.transaction_id) AS amount_of_sales,
count(e.transaction_id)::float/(SELECT count(transaction_id) FROM fantasy.events) AS share_of_sales
FROM fantasy.events e
RIGHT JOIN fantasy.items i using(item_code)
GROUP BY game_items
ORDER BY count(e.transaction_id) desc

SELECT 
    COUNT(DISTINCT e.id)::FLOAT / COUNT(DISTINCT u.id) AS purchasing_players_ratio
FROM fantasy.users u
LEFT JOIN fantasy.events e ON u.id = e.id; --Найдите также долю игроков, которые хотя бы раз покупали этот предмет.



/*1.Сначала для каждой расы посчитайте общее количество зарегистрированных игроков.
2.Затем для каждой расы посчитайте количество игроков, которые совершили покупку, 
и долю платящих игроков среди них.
3.Потом соберите информацию об активности игроков с учётом расы персонажа.
В итоговом запросе посчитайте необходимые значения*/

--количетсво покупок по пользователям с рассой
SELECT id,r.race, count(e.transaction_id)
FROM fantasy.users u
LEFT JOIN fantasy.race r USING(race_id)
LEFT JOIN fantasy.events e  USING(id)
GROUP BY  u.id,r.race;
/*Чтобы ответить на вопрос коллег, посчитайте такие показатели для каждой игровой расы:

    общее количество зарегистрированных игроков;
    количество игроков, которые совершают внутриигровые покупки, и их доля от общего количества;
    доля платящих игроков от количества игроков, которые совершили покупки;
    среднее количество покупок на одного игрока;
    средняя стоимость одной покупки на одного игрока;
    средняя суммарная стоимость всех покупок на одного игрока.*/

--количество зарегестрированных пользователей по расе с покупками
WITH rase_and_purch AS (SELECT 
		r.race, 
		count(e.transaction_id) AS  amount_of_purch,
		count(CASE WHEN u.payer = 1 AND e.amount > 0 THEN e.transaction_id END) AS purch_for_money,
		count(DISTINCT CASE WHEN u.payer = 1 THEN u.id END) AS payer,
		count(DISTINCT CASE WHEN u.payer = 1 AND e.amount > 0 THEN u.id END) AS payer_no_zero_purch,
		COUNT(DISTINCT CASE WHEN e.transaction_id IS NOT NULL THEN e.id END) AS total_amount_of_users_orders,
		count(u.id) as amount_of_race, --количество пользователей по рассе
		SUM(e.amount) AS total_sum
	FROM fantasy.users u
	LEFT JOIN fantasy.race r USING(race_id)
	LEFT JOIN fantasy.events e  USING(id)
	GROUP BY  r.race)
SELECT r.race,
	amount_of_race,  --количество пользователей по рассе
	total_amount_of_users_orders, --Игроки с любыми покупками
	amount_of_purch, --количество любых покупок
	purch_for_money, -- покупки с за деньги и без 0 стоимости
	payer_no_zero_purch, -- игроки активно участвующие в экономике игры за деньги
	payer/amount_of_race::float AS persent_payer_vs_total,--количество игроков, которые совершают внутриигровые покупки, и их доля от общего количества;
	payer_no_zero_purch::float/payer AS persent_activ_vs_payer, --доля платящих игроков от количества игроков, которые совершили покупки;
	total_sum,--сумма покупок
	total_sum::float/amount_of_purch AS avg_price, --средняя стоимость одной покупки на одного игрока
	amount_of_purch::float/total_amount_of_users_orders AS avg_amount_purchs, --среднее количество покупок на одного игрока
	total_sum::float/amount_of_race AS avg_total_cost --средняя суммарная стоимость всех покупок на одного игрока
FROM rase_and_purch r
ORDER BY purch_for_money DESC;


/*Чтобы ответить на вопрос коллег, посчитайте такие показатели для каждой игровой расы:

    общее количество зарегистрированных игроков;
    количество игроков, которые совершают внутриигровые покупки, и их доля от общего количества;
    доля платящих игроков от количества игроков, которые совершили покупки;
    среднее количество покупок на одного игрока;
    средняя стоимость одной покупки на одного игрока;
    средняя суммарная стоимость всех покупок на одного игрока.*/
WITH utau AS (SELECT count(DISTINCT id) AS total_amount_of_users
	FROM fantasy.users), --всего игроков
upafu AS (SELECT count(DISTINCT id) AS payer_amount_of_users
	FROM fantasy.users 
	WHERE payer =1), --игроки купившие лепестки
etao AS (SELECT count(DISTINCT id) AS total_amount_of_users_orders
	FROM fantasy.events), --игроки с любыми покупками
upzo AS (SELECT count(DISTINCT id) AS payer_amount_of_users_no_zero_purch
	FROM fantasy.users 
	WHERE payer =1 AND id IN (SELECT id AS total_purchasing_users
	FROM fantasy.events
	WHERE amount >0)), -- игроки активно участвующие в экономике игры за деньги
eap as(SELECT count(transaction_id) AS amount_of_purchs
	FROM fantasy.events), --количество покупок
ets AS (SELECT sum(amount) AS total_sum
	FROM fantasy.events) 
SELECT 	total_amount_of_users, --всего игроков
total_amount_of_users_orders,  --игроки с любыми покупками
total_amount_of_users_orders::float/total_amount_of_users AS perent_user_vs_payer,
payer_amount_of_users, --игроки купившие лепестки
payer_amount_of_users_no_zero_purch,  -- игроки активно участвующие в экономике игры за деньги
payer_amount_of_users_no_zero_purch::float/payer_amount_of_users AS persent_activ_vs_payer,
amount_of_purchs, --количество покупок
total_sum, --сумма всех покупок игроков
amount_of_purchs::float/total_amount_of_users_orders AS avg_purch_for_user,
total_sum::float/total_amount_of_users_orders AS avg_cost_purch_for_user,
(SELECT AVG(amount) AS total_sum FROM fantasy.events WHERE amount > 0) AS avg
FROM utau
CROSS JOIN upafu CROSS JOIN etao CROSS JOIN upzo CROSS JOIN eap CROSS JOIN ets


SELECT *
FROM fantasy.events
ORDER BY amount DESC  

/*
 * Для каждой группы нужно посчитать:

    количество игроков, которые совершили покупки;
    количество платящих игроков, совершивших покупки, и их доля от общего количества игроков, совершивших покупку;
    среднее количество покупок на одного игрока;
    среднее количество дней между покупками на одного игрока.
    
    Сначала для каждой покупки посчитайте количество дней с предыдущей покупки — это позволит получить количество дней между покупками.
    Затем для каждого игрока посчитайте общее количество покупок и среднее значение по количеству дней между покупками. 
    Не забудьте добавить информацию о том, является ли игрок платящим.
    Потом проведите ранжирование игроков по среднему количеству дней между покупками с учётом минимального количества покупок на одного игрока.
    Далее можно приступить к расчёту необходимых значений.
 * */
SELECT 
	(SELECT count(*) FROM fantasy.events e WHERE e.amount=0) AS amount_zero_price, --всего покупеок с ценой 0
	(SELECT count(*) FROM fantasy.events e WHERE e.amount=0)::float/(SELECT count(*) FROM fantasy.events e) AS persetn_amount_zero_price--отношение к общему числу покупок;

WITH purchases AS (
    SELECT 
        id,  -- Идентификатор игрока
        transaction_id,  -- Идентификатор транзакции
        date::DATE AS purchase_date,  -- Приводим тип данных к DATE
        LAG(date::DATE) OVER (PARTITION BY id ORDER BY date::DATE) AS previous_purchase_date,  -- Получаем предыдущую дату покупки
    	payer
    FROM fantasy.events
    LEFT JOIN fantasy.users u  USING(id)
    WHERE amount > 0
),
purchases_with_interval AS (
	SELECT 
	    id,  -- Идентификатор игрока
	    transaction_id,  -- Идентификатор транзакции
	    purchase_date,  -- Дата текущей покупки
	    previous_purchase_date,  -- Дата предыдущей покупки
	    purchase_date - previous_purchase_date AS days_between_purchases,  -- Количество дней между покупками
		payer -- является ли игрок платящим
	FROM purchases
	WHERE previous_purchase_date IS NOT NULL  -- Исключаем первую покупку, так как для нее нет предыдущей
	ORDER BY id, purchase_date
),
purchs_with_group_interval AS (
	SELECT 
		id, -- Идентификатор игрока
		count(transaction_id) AS amount_of_purch, -- количество покупок
		avg(days_between_purchases) AS avg_of_days_between_purchs, --среднее колиичество дней между покупками игрока
		payer -- является ли игрок платящим
	FROM purchases_with_interval
	GROUP BY id,payer
	ORDER BY avg_of_days_between_purchs
),
purchs_with_group_interval_clear AS (
	SELECT 
		*,
		NTILE(3) OVER (ORDER BY avg_of_days_between_purchs) AS days_between_purchs_group --группирока по активности
	FROM purchs_with_group_interval
	WHERE amount_of_purch>25
	ORDER BY amount_of_purch desc
)
SELECT 
	CASE
		WHEN days_between_purchs_group=1 THEN 'высокая частота'
		WHEN days_between_purchs_group=2 THEN 'умеренная частота'
		WHEN days_between_purchs_group=3 THEN 'низкая частота'
	END AS group_name,
	count(id) AS amount_of_users, --количество юзеров в каждой группе
	count(DISTINCT CASE WHEN payer = 1 THEN id END) AS payer_amount_of_users, --количество юзеров купивших листы за деньги
	avg(payer) AS pesent_of_payer, --доля с листами за деньги от общего количества игроков
	avg(amount_of_purch) AS avg_amount_of_purch, --среднее количество покупок на одного игрока;
	avg(avg_of_days_between_purchs) AS avg_of_days_between_purchs --среднее количество дней между покупками на одного игрока
FROM purchs_with_group_interval_clear
GROUP BY group_name;


WITH rase_and_purch AS (SELECT 
		r.race, 
		count(e.transaction_id) AS  amount_of_purch,
		count(CASE WHEN u.payer = 1 AND e.amount > 0 THEN e.transaction_id END) AS purch_for_money,
		count(DISTINCT CASE WHEN u.payer = 1 THEN u.id END) AS payer,
		count(DISTINCT CASE WHEN u.payer = 1 AND e.amount > 0 THEN u.id END) AS payer_no_zero_purch,
		COUNT(DISTINCT CASE WHEN e.transaction_id IS NOT NULL THEN e.id END) AS total_amount_of_users_orders,
		count(u.id) as amount_of_race, --количество пользователей по рассе
		SUM(e.amount) AS total_sum
	FROM fantasy.users u
	LEFT JOIN fantasy.race r USING(race_id)
	LEFT JOIN fantasy.events e  USING(id)
	GROUP BY  r.race)
SELECT r.race,
	amount_of_race,  --количество пользователей по рассе
	total_amount_of_users_orders, --Игроки с любыми покупками
	amount_of_purch, --количество любых покупок
	purch_for_money, -- покупки с за деньги и без 0 стоимости
	payer_no_zero_purch, -- игроки активно участвующие в экономике игры за деньги
	payer/amount_of_race::float AS persent_payer_vs_total,--количество игроков, которые совершают внутриигровые покупки, и их доля от общего количества;
	payer_no_zero_purch::float/payer AS persent_activ_vs_payer, --доля платящих игроков от количества игроков, которые совершили покупки;
	total_sum,--сумма покупок
	total_sum::float/amount_of_purch AS avg_price, --средняя стоимость одной покупки на одного игрока
	amount_of_purch::float/total_amount_of_users_orders AS avg_amount_purchs, --среднее количество покупок на одного игрока
	total_sum::float/amount_of_race AS avg_total_cost --средняя суммарная стоимость всех покупок на одного игрока
FROM rase_and_purch r
ORDER BY purch_for_money DESC

WITH race_stats AS (
    SELECT 
        r.race,
        COUNT(u.id) AS amount_of_race, -- Количество игроков
        COUNT(DISTINCT CASE WHEN u.payer = 1 THEN u.id END) AS payer, -- Покупатели
        COUNT(DISTINCT CASE WHEN u.payer = 1 AND e.amount > 0 THEN u.id END) AS payer_no_zero_purch, -- Активные покупатели
        COUNT(e.transaction_id) AS amount_of_purch, -- Всего покупок
        SUM(e.amount) AS total_sum -- Общая сумма покупок
    FROM fantasy.users u
    LEFT JOIN fantasy.race r USING(race_id)
    LEFT JOIN fantasy.events e USING(id)
    GROUP BY r.race
)
SELECT 
    race,
    amount_of_race,
    COALESCE(payer, 0)::FLOAT / NULLIF(amount_of_race, 0) AS percent_payer_vs_total, -- Доля покупателей
    COALESCE(payer_no_zero_purch, 0)::FLOAT / NULLIF(payer, 0) AS percent_activ_vs_payer, -- Доля активных покупателей
    COALESCE(total_sum, 0)::FLOAT / NULLIF(amount_of_purch, 0) AS avg_price, -- Средняя стоимость одной покупки
    COALESCE(total_sum, 0)::FLOAT / NULLIF(amount_of_race, 0) AS avg_total_cost -- Средняя сумма покупок на игрока
FROM race_stats
ORDER BY COALESCE(total_sum, 0) DESC; -- Сортировка по общей сумме покупок



SELECT 
		CASE
			WHEN payer = 0 THEN 'неплатящий игрок'
			WHEN payer = 1 THEN 'платящий игрок'
			else 'неплатящий игрок'
		END AS payer,
		count(DISTINCT u.id),
		count(e.transaction_id) AS count_transaction,
		sum(e.amount) AS sum_purch,
		min(e.amount) AS min_amount,
		max(e.amount) max_amount,
		avg(e.amount)
FROM fantasy.events e
LEFT JOIN fantasy.users u USING(id)
WHERE amount >0
GROUP BY payer



