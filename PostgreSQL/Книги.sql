select *
from source_db.audition
limit 10;

select  *
from source_db.content
limit 10


--Задание 1
--Для начала продакт-менеджер хочет понять, где сервис пользуется наибольшей популярностью.
-- Выведите топ-20 городов и регионов России по суммарному количеству прочитанных и прослушанных часов любого контента с 
--мобильных устройств. Для каждой из платформ — iOS и Android — добавьте отдельный столбец с длительностью. 
--Результат должен выглядеть так: город, общая длительность прочитанного и прослушанного контента, длительность на iOS, 
--длительность на Android. Значения округлите до целых чисел для лучшей читаемости. 
--Из выдачи также исключите федеральные округа — оставьте только города и области.

select usage_geo_id_name, 
round(sum(hours),0),
round(sumIf(hours, usage_platform_ru = 'Букмейт iOS'),0) AS iOS,
round(sumIf(hours, usage_platform_ru='Букмейт Android'),0) AS Android
from source_db.audition
where usage_country_name='Россия' 
	and usage_geo_id_name not ILIKE '%округ%'
	and usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
GROUP by 1
order by 2 desc
limit 20



--С активными регионами определились, а какой контент самый популярный? 
--Получите топ-5 книг по суммарному количеству прочитанных и прослушанных часов на мобильных платформах. 
--Также вычислите среднее время чтения и прослушивания в зависимости от типа книги: текст или аудио. 
--Результат должен выглядеть так: название книги, её автор, суммарное время чтения и прослушивания, 
--среднее время чтения текстовой книги, среднее время прослушивания аудиокниги.
--В список включайте только те книги, которые используются в обоих форматах. 
--Числовые значения округляйте до двух знаков после точки.

select main_content_name, main_author_name,
		round(sum(hours),2) as avg_dur,
		round(avgIf(hours,main_content_type='Book'),2) as Book,
		round(avgIf(hours,main_content_type='Audiobook'),2) as Audiobook
from source_db.audition as a
INNER JOIN source_db.content as c on c.main_content_id=a.main_content_id
where usage_platform_ru in ('Букмейт iOS','Букмейт Android')
GROUP by 2,1
HAVING countDistinct(main_content_type)>1
order by 3 desc
limit 5




--Задание 3
--Составьте топ-10 авторов по суммарной длительности чтения их книг на всех платформах, включая веб. 
--Для каждого автора добавьте количество уникальных текстовых книг (тип контента 'Book' ) и 
--выведите среднюю длительность прослушивания их аудиокниг только на мобильных устройствах. 
--Исключите авторов, у которых нет аудиокниг.

select main_author_name,
countDistinctIf(main_content_id, main_content_type='Book') as count_books,
round(sumIf(hours,main_content_type='Book'),2) as sum_dur_read,
round(avgIf(hours, main_content_type='Audiobook' and usage_platform_ru in ('Букмейт iOS','Букмейт Android')),2) as mob
from source_db.audition as a
INNER JOIN source_db.content as c on c.main_content_id=a.main_content_id
WHERE usage_platform_ru in ('Букмейт iOS', 'Букмейт Android', 'Букмейт Web')
GROUP by 1
HAVING sumIf(hours, main_content_type='Audiobook') > 0
order by 3 desc
limit 10



--Задание 4
--У продакт-менеджера есть предположение, что среди Android-пользователей аудиокниги почти так же популярны, как тексты. 
--А среди iOS-пользователей читателей книг вдвое больше, чем слушателей, если считать по суммарной длительности сессии.
--Проверьте предположение менеджера. Для начала выделите три сегмента пользователей:
--		«Слушатель» — тот, кто преимущественно пользуется аудиокнигами. Прослушивание книг составляет 70% и выше от суммарной длительности сессий.
--		«Читатель» — преимущественно пользуется текстовыми книгами. Чтение книг — от 70%.
--		«Оба» — остальные пользователи сервиса.
--Исключите пользователей, у которых нет сессий ни с книгами, ни с аудиокнигами, и посчитайте количество пользователей в каждом из сегментов.
--На основе полученных данных проверьте предположение менеджера о том, что среди пользователей Android 
--примерно одинаковое количество читателей и слушателей, а на устройствах iOS читателей книг вдвое больше, чем слушателей. 
--Чтобы определить основную платформу пользователя, учитывайте время её использования. Например, если пользователь посещал сервис с двух устройств: 
--два часа на iOS и пять часов на Android, то основной платформой такого пользователя будет Android.


with t as (select 
	puid,
	--usage_platform_ru,
	round(sumIf(hours, main_content_type in ('Audiobook','Book')),2) as total_content,
	round(sumIf(hours, main_content_type = 'Audiobook'), 2) AS audiobook_hours,
	round(sumIf(hours, main_content_type = 'Book'), 2) AS book_hours,
	If(
		sumIf(hours, usage_platform_ru='Букмейт iOS')>
		sumIf(hours, usage_platform_ru='Букмейт Android'),'Букмейт iOS','Букмейт Android'
		) as main_platform,
	multiIf(
		audiobook_hours/total_content>=0.7,'Слушатель',
		book_hours/total_content>=0.7,'Читатель',
		'Оба') as segment
	from source_db.audition as a
	INNER JOIN source_db.content as c on c.main_content_id=a.main_content_id
	where usage_platform_ru in ('Букмейт iOS', 'Букмейт Android') AND c.main_content_type IN ('Book', 'Audiobook')
	GROUP by puid
	--, usage_platform_ru
	having total_content > 0
)
select main_platform,
countDistinctIf(puid,segment='Слушатель') as "Слушатель",
countDistinctIf(puid,segment='Читатель') as "Читатель",
countDistinctIf(puid,segment='Оба') as "Оба"
from t 
GROUP by 1


--Задание 5
--Изучите, существует ли связь между форматом использования приложения (прослушивание или чтение) и днём недели. 
--Падает ли использование аудиокниг в выходные на всех платформах, включая веб? 
--Чтобы это узнать, для каждого типа контента посчитайте среднее время его использования в рабочие и выходные дни и округлите до целого числа. 
--Используя оконные функции, вы также можете пользоваться и комбинаторами.


select 
	if(toDayOfWeek(msk_business_dt_str)<=5, 'Будни', 'Выходные') AS day_type,
	round(avgIf(hours,main_content_type='Audiobook'),0) as Audiobook,
	round(avgIf(hours,main_content_type='Book'),0) as Book,
	round(avgIf(hours,main_content_type='Comicbook'),0) as Comicbook
from source_db.audition as a
INNER JOIN source_db.content as c on c.main_content_id=a.main_content_id
where usage_platform_ru in ('Букмейт iOS', 'Букмейт Android', 'Букмейт Web')
GROUP by 1

select day_type,
	round(avg(Audiobook),0)as Audiobook,
	round(avg(Book),0)as Book
from (select toDate(msk_business_dt_str),
	if(toDayOfWeek(msk_business_dt_str)<=5, 'Будни', 'Выходные') AS day_type,
	round(sumIf(hours,main_content_type='Audiobook'),2) as Audiobook,
	round(sumIf(hours,main_content_type='Book'),2) as Book
from source_db.audition as a
INNER JOIN source_db.content as c on c.main_content_id=a.main_content_id
where usage_platform_ru in ('Букмейт iOS', 'Букмейт Android', 'Букмейт Web') 
	and main_content_type in ('Book','Audiobook')
GROUP by 1,2)
GROUP by 1

--Задание 6¶
--Продакт-менеджер хочет отслеживать обновления приложений на Android и iOS. 
--У него есть предположение, что больший процент пользователей iOS используют последнюю версию приложения и в целом чаще его обновляют. 
--Для начала изучите, у какой части пользователей на текущий момент стоят последние версии приложения на каждой из платформ. 
--Для этого посчитайте последнюю активную версию каждого пользователя и сравните её с последней версией у каждой платформы. 
--Для каждой платформы выведите процент пользователей с последней версией приложения и округлите его до двух знаков после точки.

with t as (select puid, 
	usage_platform_ru,
	max(app_version) OVER (PARTITION BY usage_platform_ru) AS max_app_version_platform,
	argMax(app_version, toDateTime(msk_business_dt_str)) OVER (PARTITION BY puid) AS max_app_version_user,
	max(app_version) OVER (PARTITION BY puid) AS max_app_version_user_1
	from source_db.audition as a
	where usage_platform_ru in ('Букмейт iOS', 'Букмейт Android')
)
select usage_platform_ru,
round(
		countDistinctIf(puid, max_app_version_platform=max_app_version_user)
		/countDistinct(puid)*100,2
	) as percent_new_ver
--,countDistinctIf(puid, max_app_version_user_1=max_app_version_user) as err,
--countDistinctIf(puid, max_app_version_user_1!=max_app_version_user) as err_1
from t 
group by 1



--Теперь продакт-менеджер хочет понять, как часто пользователи обновляют приложение на каждой из платформ. 
--Фактом обновления считайте изменение версии у каждого пользователя. 
--Представьте, что любое изменение возможно только в сторону более новой версии.
--Проверьте предположение о том, что пользователи iOS чаще обновляют приложение. 
--Посчитайте метрику update_rate, которая покажет среднюю частоту обновлений на пользователя. 
--Округлите её до двух знаков после точки.


with t as (select puid, 
	usage_platform_ru as platform,
	countDistinct(app_version) as uniq_version
	from source_db.audition
	where usage_platform_ru in ('Букмейт iOS', 'Букмейт Android')
	group by 1,2
	)
select platform,
round(avg(uniq_version-1),2) as update_rate
from t 
group by 1

--Задание 8
--Новая задача — у коллег есть опасения, что не все книги на тему магии верно размечены с точки зрения категорий.  
--Считается, что у книги должно быть не больше 3–4 категорий с темами. 
--Необходимо найти все книги на магическую тему, которые при этом не входят в художественную литературу, 
--и проверить, правильно ли они размечены.
--Начните с подсчёта книг с тегом «Магия». Выведите количество таких книг в каталоге.

select  countDistinct(main_content_id) as count,
countDistinctIf(main_content_id, length(published_topic_title_list)>4) AS num_categories
from source_db.content
WHERE has(published_topic_title_list, 'Магия')


--Задание 9
--Найдите все книги со словом «магия» в названии, для которых не проставлен тег «Магия». 
--При этом не учитывайте книги с тегом «Художественная литература». 
--Выведите количество таких книг в каталоге.

select  countDistinct(main_content_id) as count
from source_db.content
WHERE main_content_name ILIKE '%магия%' 
and NOT hasAny(published_topic_title_list, ['Художественная литература','Магия']) 



--Посчитайте среднее количество категорий у книг с тегом «Магия» и среднее количество категорий у книг в каталоге в целом. 
--Округлите значения до двух знаков после точки. Напомним, что коллегам важно, чтобы у каждой книги было не больше 3–4 категорий. 
--Получится ли не превысить рекомендованного количества?

select  
	round(avg(length(published_topic_title_list)),2) AS avg_all_categories,
	round(avgIf(length(published_topic_title_list), has(published_topic_title_list, 'Магия')),2) AS avg_magic_categories
from source_db.content


--Продакт-менеджер выяснил, что в приложении одной из мобильных платформ могла возникнуть проблема — 
--длина пользовательской сессии (поле hours_sessions_long ) записывается некорректно, 
--и это происходит как минимум в одной из стран. Чтобы найти аномалию в данных, 
--используйте такую меру дисперсии как коэффициент вариации. Напомним его формулу: 
--коэффициент определяется как отношение стандартного отклонения к среднему. 
--Чем выше этот показатель, тем более подозрительно с точки зрения анализа распределены данные.
--Исследуйте коэффициент по странам и мобильным платформам. В какой стране и на какой платформе видна аномалия в данных? 
--Ограничьте выборку одной страной, в которой коэффициент вариации для одной из платформ будет наибольшим.

SELECT
        usage_country_name,
        stddevSamp(hours_sessions_long) AS std,
        avg(hours_sessions_long) AS avg,
        stddevSamp(hours_sessions_long)/avg(hours_sessions_long) AS cof_of_var
    FROM source_db.audition
    GROUP BY usage_country_name
    ORDER BY cof_of_var DESC
    LIMIT 1

WITH t AS (
    SELECT
        usage_country_name,
        round(stddevSamp(hours_sessions_long),2) AS std,
        round(avg(hours_sessions_long),2) AS avg,
        round(stddevSamp(hours_sessions_long)/avg(hours_sessions_long),2) AS cof_of_var
    FROM source_db.audition
    WHERE usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
    GROUP BY usage_country_name
    ORDER BY cof_of_var DESC
    LIMIT 1)
SELECT 
    usage_platform_ru,
    stddevSamp(hours_sessions_long) AS std,
    avg(hours_sessions_long) AS avg,
    stddevSamp(hours_sessions_long)/avg(hours_sessions_long) AS cof_of_var
FROM source_db.audition
WHERE usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
AND usage_country_name = (SELECT usage_country_name FROM t)
GROUP BY usage_platform_ru
ORDER BY cof_of_var DESC






