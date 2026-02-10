/*Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
 * имеют наиболее короткие или длинные сроки активности объявлений?
 * */
--по количеству комнат
select f.rooms,
avg(a.days_exposition )
from flats f
join advertisement a  using(id)
group by rooms;
--апарты или нет
select 
case
	when f.is_apartment =0 then 'не апартаменты'
	when f.is_apartment =1 then 'апартаменты'
end as "апартаменты или нет",
avg(a.days_exposition )
from flats f
join advertisement a  using(id)
group by is_apartment;
--разбивка по количеству прудов и парков
--парки
select parks_around3000, 
avg(a.days_exposition )
from flats f
join advertisement a  using(id)
group by parks_around3000;
--пруды
select f.ponds_around3000, 
avg(a.days_exposition )
from flats f
join advertisement a  using(id)
group by ponds_around3000;
--парки и пруды: наличие и отсутвите и их влияиние на цену и скорость продажи
select 
round(avg(CASE WHEN ponds_around3000 >=1 then a.days_exposition end)::numeric, 2) AS have_ponds,
round(avg(CASE WHEN ponds_around3000 = 0 or ponds_around3000 IS NULL then a.days_exposition end)::numeric, 2) AS no_ponds,
round(avg(CASE WHEN ponds_around3000 >=1 then a.last_price/f.total_area end)::numeric, 2) AS price_have_ponds,
round(avg(CASE WHEN ponds_around3000 = 0 or ponds_around3000 IS NULL then a.last_price/f.total_area end)::numeric, 2) AS price_no_ponds
from flats f
join advertisement a  using(id)
LEFT JOIN city AS c using(city_id)

--балконы
select 
avg(case when balcony=0 or balcony is null then a.days_exposition end) as zero_b,
avg(case when balcony>0  then a.days_exposition end) as non_zero_b
from flats f
join advertisement a  using(id);

--основной запрос с очисткой данных
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
dur_and_area as (select *,
case
	when days_exposition<32 then 'месяц'
	when days_exposition>=32 and days_exposition<=92 then 'квартал'
	when days_exposition>92 and days_exposition<180 then 'полгода'
	else 'дольше полугода'
end as duration_advt,
case
	when c.city='Санкт-Петербург' then 'Санкт-Петербург'
	else 'Лен.Область'
end as area,
CASE 
        WHEN f.floors_total <= 5 THEN 'Низкоэтажные дома (до 5 этажей)'
        WHEN f.floors_total BETWEEN 6 AND 12 THEN 'Среднеэтажные дома (5–12 этажей)'
        ELSE 'Высотки (более 12 этажей)'
    END AS building_type,
    CASE 
        WHEN f.floor = 1 THEN 'Первый этаж'
        WHEN f.floor = f.floors_total THEN 'Последний этаж'
        ELSE 'Средние этажи'
    END AS floor_category
from flats f
join advertisement a  using(id)
left join city c using(city_id)
WHERE id IN (SELECT * FROM filtered_id))
select area,building_type,floor_category, rooms,
avg(case when balcony=0 or balcony is null then days_exposition end) as zero_b,
avg(case when balcony>0  then days_exposition end) as non_zero_b,
/*avg(last_price/total_area),
min(last_price/total_area),
max(last_price/total_area)*/
count(*) as "количество обьявлений",
round(avg(days_exposition)::NUMERIC, 2) as avg_duration_advt,
avg(total_area) as total_area,
avg(living_area) as living_area,
avg(kitchen_area) as kitchen_area,
round(avg(last_price/total_area)::NUMERIC, 2) as price_for_m2
from dur_and_area
group by area,building_type,floor_category, rooms
;


/*  В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости?
 *  А в какие — по снятию? Это показывает динамику активности покупателей.
  
    Совпадают ли периоды активной публикации объявлений и периоды, когда происходит
     повышенная продажа недвижимости (по месяцам снятия объявлений)?
     
    Как сезонные колебания влияют на среднюю стоимость квадратного метра
     и среднюю площадь квартир? Что можно сказать о зависимости этих параметров от месяца?*/

----публикации обьявлений о продаже по месяцам и годам(длинная таблица)
SELECT 
    EXTRACT(YEAR FROM first_day_exposition) AS YEAR_posted, 
    EXTRACT(QUARTER FROM first_day_exposition) AS quarter_posted,
    EXTRACT(MONTH FROM first_day_exposition) AS month_posted,
    COUNT(*) AS ad_count
FROM advertisement
WHERE EXTRACT(YEAR FROM first_day_exposition)<>2014 AND EXTRACT(YEAR FROM first_day_exposition)<>2019
GROUP BY 
    EXTRACT(YEAR FROM first_day_exposition),
 	EXTRACT(QUARTER FROM first_day_exposition),
    EXTRACT(MONTH FROM first_day_exposition)
ORDER BY 
    EXTRACT(YEAR FROM first_day_exposition),
 	EXTRACT(QUARTER FROM first_day_exposition),
    EXTRACT(MONTH FROM first_day_exposition);

--закрытие обьявлений о продаже по месяцам и годам(динная таблица)
SELECT 
    EXTRACT(YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day') AS YEAR_posted, 
    EXTRACT(QUARTER FROM first_day_exposition + days_exposition * INTERVAL '1 day') AS quarter_posted,
    EXTRACT(MONTH FROM first_day_exposition + days_exposition * INTERVAL '1 day') AS month_posted,
    COUNT(*) AS ad_count
FROM advertisement
WHERE EXTRACT(YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day')<>2014 
AND EXTRACT(YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day')<>2019
GROUP BY 
    EXTRACT(YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day'),
 	EXTRACT(QUARTER FROM first_day_exposition + days_exposition * INTERVAL '1 day'),
    EXTRACT(MONTH FROM first_day_exposition + days_exposition * INTERVAL '1 day')
ORDER BY 
    EXTRACT(YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day'),
 	EXTRACT(QUARTER FROM first_day_exposition + days_exposition * INTERVAL '1 day'),
    EXTRACT(MONTH FROM first_day_exposition + days_exposition * INTERVAL '1 day');
--публикации обьявлений о продаже по месяцам и годам
SELECT 
    EXTRACT(MONTH FROM a.first_day_exposition) AS month_posted,
    SUM(CASE WHEN EXTRACT(YEAR FROM a.first_day_exposition) = 2015 THEN 1 ELSE 0 END) AS "2015",
    SUM(CASE WHEN EXTRACT(YEAR FROM a.first_day_exposition) = 2016 THEN 1 ELSE 0 END) AS "2016",
    SUM(CASE WHEN EXTRACT(YEAR FROM a.first_day_exposition) = 2017 THEN 1 ELSE 0 END) AS "2017",
    SUM(CASE WHEN EXTRACT(YEAR FROM a.first_day_exposition) = 2018 THEN 1 ELSE 0 END) AS "2018"
FROM 
    advertisement a
GROUP BY 
    EXTRACT(MONTH FROM a.first_day_exposition)
ORDER BY 
    month_posted;
--количество обьявлений по месяцам и годам закытые.
SELECT 
    EXTRACT(MONTH FROM first_day_exposition + days_exposition * INTERVAL '1 day') AS month_closed,
    SUM(CASE WHEN EXTRACT(YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day') = 2016 THEN 1 ELSE 0 END) AS "2016",
    SUM(CASE WHEN EXTRACT(YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day') = 2017 THEN 1 ELSE 0 END) AS "2017",
    SUM(CASE WHEN EXTRACT(YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day') = 2018 THEN 1 ELSE 0 END) AS "2018",
    SUM(CASE WHEN EXTRACT(YEAR FROM first_day_exposition + days_exposition * INTERVAL '1 day') = 2019 THEN 1 ELSE 0 END) AS "2019"
FROM 
    advertisement a
    WHERE EXTRACT(MONTH FROM first_day_exposition + days_exposition * INTERVAL '1 day') IS NOT NULL
GROUP BY 
    EXTRACT(MONTH FROM first_day_exposition + days_exposition * INTERVAL '1 day')
ORDER BY 
    EXTRACT(MONTH FROM first_day_exposition + days_exposition * INTERVAL '1 day')
;
--цена за м2 по месяцам и годам
SELECT 
    EXTRACT(MONTH FROM first_day_exposition) AS month_posted,
    round(avg(CASE WHEN EXTRACT(YEAR FROM first_day_exposition) = 2015 THEN a.last_price/f.total_area END)::NUMERIC, 2) AS "2015",
    round(avg(CASE WHEN EXTRACT(YEAR FROM first_day_exposition) = 2016 THEN a.last_price/f.total_area END)::NUMERIC, 2) AS "2016",
    round(avg(CASE WHEN EXTRACT(YEAR FROM first_day_exposition) = 2017 THEN a.last_price/f.total_area END)::NUMERIC, 2) AS "2017",
    round(avg(CASE WHEN EXTRACT(YEAR FROM first_day_exposition) = 2018 THEN a.last_price/f.total_area END)::NUMERIC, 2) AS "2018",
    round(avg(CASE WHEN EXTRACT(YEAR FROM first_day_exposition) = 2019 THEN a.last_price/f.total_area END)::NUMERIC, 2) AS "2019"
from flats f
join advertisement a using(id)
GROUP BY 
    EXTRACT(MONTH FROM first_day_exposition)
ORDER BY 
    EXTRACT(MONTH FROM first_day_exposition)
;


/*1. В каких населённые пунктах Ленинградской области 
 наиболее активно публикуют объявления о продаже недвижимости?*/
SELECT c.city, count(id)
FROM flats AS f
LEFT JOIN city AS c using(city_id)
WHERE c.city<>'Санкт-Петербург'
GROUP BY c.city 
ORDER BY count(id) DESC
LIMIT 15;


 /*2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
  * Это может указывать на высокую долю продажи недвижимости.*/
SELECT 
	c.city, 
	count(CASE WHEN a.days_exposition IS not NULL THEN 1 END) AS  closerd_advt, 
	round(count(CASE WHEN a.days_exposition IS not NULL THEN 1 END)/count(*)::numeric, 2) AS persent
FROM advertisement a
LEFT JOIN flats AS f using(id)
LEFT JOIN city AS c using(city_id)
WHERE  c.city<>'Санкт-Петербург'
GROUP BY c.city 
ORDER BY persent DESC;

/*Какова средняя стоимость одного квадратного метра и средняя площадь 
 * продаваемых квартир в различных населённых пунктах? Есть ли вариация значений по этим метрикам?*/

SELECT 
	c.city, 
	round(avg(a.last_price/f.total_area)::numeric, 2) AS price_one_m2,
	round(avg(total_area)::numeric, 2) AS total_area
	/*round(avg(CASE WHEN ponds_around3000 >=1 then a.last_price/f.total_area end)::numeric, 2) AS have_ponds,
	round(avg(CASE WHEN ponds_around3000 = 0 or ponds_around3000 IS NULL then a.last_price/f.total_area end)::numeric, 2)AS no_ponds,
	round(avg(CASE WHEN parks_around3000 >=1  then a.last_price/f.total_area end)::numeric, 2) AS have_parks,
	round(avg(CASE WHEN parks_around3000 = 0 or parks_around3000 IS NULL then a.last_price/f.total_area end)::numeric, 2) AS no_parks*/
FROM advertisement a
LEFT JOIN flats AS f using(id)
LEFT JOIN city AS c using(city_id)
WHERE  c.city<>'Санкт-Петербург'
GROUP BY c.city 
--ORDER BY price_one_m2 DESC;

/*Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
 * То есть где недвижимость продаётся быстрее, а где — медленнее.*/
SELECT 
	c.city, 
	round(avg(days_exposition)::numeric, 2) AS duration
	/*round(avg(CASE WHEN ponds_around3000 >=1 then a.last_price/f.total_area end)::numeric, 2) AS have_ponds,
	round(avg(CASE WHEN ponds_around3000 = 0 or ponds_around3000 IS NULL then a.last_price/f.total_area end)::numeric, 2)AS no_ponds,
	round(avg(CASE WHEN parks_around3000 >=1  then a.last_price/f.total_area end)::numeric, 2) AS have_parks,
	round(avg(CASE WHEN parks_around3000 = 0 or parks_around3000 IS NULL then a.last_price/f.total_area end)::numeric, 2) AS no_parks*/
FROM advertisement a
LEFT JOIN flats AS f using(id)
LEFT JOIN city AS c using(city_id)
WHERE  c.city<>'Санкт-Петербург' AND days_exposition IS NOT NULL 
GROUP BY c.city
--ORDER BY duration DESC 

