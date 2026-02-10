--Определить регионы с наибольшим количеством зарегистрированных доноро

select region, sum(confirmed_donations+unconfirmed_donations) as summ
from donorsearch.user_anon_data  
where region is not null 
group by region
order by summ desc;

--Изучить динамику общего количества донаций в месяц за 2022 и 2023 годы

select DATE_TRUNC('month', donation_date::timestamp) AS donation_month, 
	count(user_id) as q
from donorsearch.donation_anon
WHERE donation_date BETWEEN '2022-01-01' AND '2023-12-31'
group by DATE_TRUNC('year', donation_date::timestamp), donation_month
order by DATE_TRUNC('year', donation_date::timestamp), donation_month, q desc ;


--Определить наиболее активных доноров в системе, учитывая только данные о зарегистрированных и подтвержденных донациях. 
select SUM(COALESCE(confirmed_donations, 0) + COALESCE(donations_before_registration, 0)) AS total_sum,
    id
from donorsearch.user_anon_data
WHERE confirmed_donations IS NOT null and confirmed_donations>0
   OR donations_before_registration IS NOT null and donations_before_registration>0
GROUP BY id
order by total_sum desc;

--Оценить, как система бонусов влияет на зарегистрированные в системе донации.
--всего доноров
select count(distinct id)
from donorsearch.user_anon_data;
--265836
--доноры с бонусами
select count(distinct user_id)
from donorsearch.user_anon_bonus;
--9345


--найти интервал с первого использования бонуса по сейчас
-- 2024-05-17 дата самой последней донации
with base as (select user_id,
	MIN(date_of_use)::date-AGE('2024-05-17'::date, MIN(date_of_use)) AS before_bonus_date, 
	--дата отсчета интевала безбонусной программы до первого использования бонуса
	AGE('2024-05-17'::date, MIN(date_of_use)) as interval_after_first_bonus,
	--интервал от первого бонуса до последней донации
	MIN(date_of_use) as first_bonus_date
	-- дата начала использования бонусов
	from donorsearch.user_anon_bonus
	GROUP by user_id), 
befor_bonus as 
	(select --считаем донации до начала испольхования бонусов
		dp.user_id, 
		before_bonus_date, 
		interval_after_first_bonus, 
		count(blood_class) as quantyty_befor
	from donorsearch.donation_anon as dp
	full join base as b on dp.user_id=b.user_id
	where donation_date between before_bonus_date and first_bonus_date
	GROUP by dp.user_id, before_bonus_date, interval_after_first_bonus),
after_bonus AS (--считаем донации после начала испольхования бонусов
    SELECT 
        dp.user_id, 
        b.first_bonus_date, 
        coalesce (COUNT(dp.blood_class),0) AS quantyty_after
    FROM donorsearch.donation_anon AS dp
    full JOIN base AS b ON dp.user_id = b.user_id
    WHERE dp.donation_date > b.first_bonus_date
    GROUP BY dp.user_id, b.first_bonus_date
)
--считаем общее количество донаций до и после бонусов
SELECT 
sum(quantyty_befor) as quantyty_befor,
avg(quantyty_befor) as avg_quantyty_befor,
sum(quantyty_after) as quantyty_after,
avg(quantyty_after) as avg_quantyty_after,
(select avg(confirmed_donations) as avg_no_bonus_ever
from donorsearch.user_anon_data
where count_bonuses_taken=0 or count_bonuses_taken is null),
(select avg(confirmed_donations) as avg_bonus
from donorsearch.user_anon_data
where count_bonuses_taken>0 or count_bonuses_taken is not null)
FROM befor_bonus AS bb
full JOIN after_bonus AS ab ON bb.user_id = ab.user_id;
-- до начала бонусной программы доноры совершили больше донаций, 
-- но в пересчете на среднее после начала бонусной программы доноры стали чаще сдавать кровь, 
-- однако общее количество донаций снизилось
--в целом те доноры которые получали когда либо бонусы в среднем чаще сдавали кровь


--Исследовать вовлечение новых доноров через социальные сети, учитывая только тех, 
--кто совершил хотя бы одну донацию. Узнать, сколько по каким каналам пришло доноров,
--и среднее количество донаций по каждому каналу.

select count(id) as donor,
	avg(confirmed_donations) as donation,
	case 
		when autho_vk=true then 'vk'
		when autho_ok=true then 'ok'
		when autho_tg=true then 'tg'
		when autho_yandex=true then 'ya'
		when autho_google=true then 'g'
		else 'социопат'
	end as socialmedia	
from donorsearch.user_anon_data
where confirmed_donations>0 --не считаем тех кто не сдал кровь еще ни разу
group by socialmedia
order by donation desc ;
--доноры  avg донаций		сеть
--1014	7.0433925049309665	ya
--2549	6.0470772852098862	g
--13427	5.9648469501750205	социопат
--642	5.5591900311526480	ok
--20888	5.5580716200689391	vk
--117	4.8290598290598291	tg
--

select id as donor,
	whole_blood_count,  
plasma_count,
platelets_count ,
red_cells_count,
white_cells_count
from donorsearch.user_anon_data
where confirmed_donations>0 
group by id;

--смотрим количество доноров и донаций по городам
select city,
sum(donation_count) as donation,
sum(donor_count) as donor,
sum(donation_count)/sum(donor_count)::real as avg
from donorsearch.bs_data
where donation_count>0 or donor_count>0
group by city
order by donation desc;

--Сравнить активность однократных доноров со средней активностью повторных доноров.
select id
from donorsearch.user_anon_data
where confirmed_donations=1;

select 
avg(confirmed_donations)
from donorsearch.user_anon_data as uad
where confirmed_donations>=2;


with main as (SELECT 
        uad.id,
        uad.registration_date,
        uad.confirmed_donations,
        MAX(da.donation_date) AS last_donation_date,
        min(da.donation_date) AS first_donation_date,
        AGE(MAX(da.donation_date), MIN(da.donation_date)) / (uad.confirmed_donations - 1) AS avg_interval_between_donations,
        AGE(MAX(da.donation_date), min(da.donation_date)) AS interval_donation -- период донаций
    FROM donorsearch.user_anon_data AS uad
    LEFT JOIN donorsearch.donation_anon AS da ON da.user_id = uad.id
    WHERE uad.confirmed_donations >= 2
    GROUP BY uad.id, uad.registration_date)
SELECT 
    AVG(CASE WHEN confirmed_donations BETWEEN 2 AND 50 THEN avg_interval_between_donations END) AS avg_2_50,
    AVG(CASE WHEN confirmed_donations BETWEEN 51 AND 100 THEN avg_interval_between_donations END) AS avg_51_100,
    AVG(CASE WHEN confirmed_donations BETWEEN 101 AND 200 THEN avg_interval_between_donations END) AS avg_101_200,
    AVG(CASE WHEN confirmed_donations > 200 THEN avg_interval_between_donations END) AS avg_200
FROM main;
-- с увеличением колиечства донаций растет частота донаций
-- 6 mons 39 days 07:17:39.666941	1 mon 33 days 17:15:38.153963	43 days 12:48:00.001772	29 days 29:16:55.267037
SELECT 
        uad.id,
        uad.registration_date,
        uad.confirmed_donations,
        MAX(da.donation_date) AS last_donation_date,
        min(da.donation_date) AS first_donation_date,
        AGE(MAX(da.donation_date), MIN(da.donation_date)) / (uad.confirmed_donations - 1) AS avg_interval_between_donations,
        AGE(MAX(da.donation_date), min(da.donation_date)) AS interval_donation -- период донаций
    FROM donorsearch.user_anon_data AS uad
    LEFT JOIN donorsearch.donation_anon AS da ON da.user_id = uad.id
    WHERE uad.confirmed_donations >= 2
    GROUP BY uad.id, uad.registration_date;
   
--   Сравнить данные о планируемых донациях с фактическими данными, чтобы оценить эффективность планирования.
   
   select
   		DATE_TRUNC('month', plan_date::date) as donation_month,
   		avg(case 
	   				when donation_date>plan_date then AGE(donation_date, plan_date)
   					when donation_date<plan_date then AGE(plan_date, donation_date)
   					when donation_date=plan_date then '0 days'::interval 
   		end) as interval_p_f,
   		count(donation_date) 
   from donorsearch.donation_plan
   where donation_date < '2024-01-30'-- убираем выбросы дат
   group by donation_month
  order by interval_p_f desc;
-- худшие показатели планирования были в 2020-12-01  и 2021-01-01, лучшее пларирование 2023-05-01



