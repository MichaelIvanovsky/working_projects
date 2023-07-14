-- *****************************************************************
-- ******* e_prescr_sql.sql
-- ******* Created at: четверг 16.03.2023 12:48
-- *****************************************************************
--Этот скрипт подтягивает международные непатентованные наименования (МНН) к витрине по электронным рецептам
--Зачем это нужно: у нас есть несистематизированные наименования и ИД лекарственных препаратов. Для них нужны систематизированные расшифровки-МНН. Делалось по требованию аналитического блока команды для подготовки выгрузок.
--РАЗДЕЛ I. ПОДТЯГИВАНИЕ МНН

DROP TABLE IF EXISTS public.e_prescr_preps;

CREATE TABLE public.e_prescr_preps AS --создаём компактную таблицу для работы
WITH a AS (SELECT DISTINCT epm.lp_id::int, epm.lp_name, COUNT(*)::int AS cnt_id_name
               FROM common_analytics2.e_prescription_mart_1 epm
               GROUP BY 1, 2)
   , b AS (SELECT DISTINCT epm.lp_name, COUNT(*)::int AS cnt_name
               FROM common_analytics2.e_prescription_mart_1 epm
               GROUP BY 1)
SELECT DISTINCT a.lp_id, a.lp_name, a.cnt_id_name, b.cnt_name
    FROM b
             LEFT JOIN a
                       USING (lp_name);

GRANT SELECT ON public.e_prescr_preps to gpuser;


--МНН и ТНН
drop TABLE IF EXISTS common_analytics2.e_prescr_join_union11;
drop TABLE IF EXISTS common_analytics2.e_prescr_join_union12;
drop TABLE IF EXISTS common_analytics2.e_prescr_join_union;

CREATE TABLE common_analytics2.e_prescr_join_union11 AS
SELECT DISTINCT epp.lp_id, epp.lp_name, nm1.mnn_id, nm1.rus_mnn_title, nm1.lat_mnn_title, 'mnn_join_lev' AS source
    FROM public.e_prescr_preps epp
             JOIN common_analytics2.drug_classifier_nsi nm1
                  ON epp.lp_id = nm1.mnn_id
                      AND ( levenshtein(SPLIT_PART(LOWER(epp.lp_name), ' ', 1),
                                        SPLIT_PART(LOWER(nm1.lat_mnn_title), ' ', 1)) <= 3
                          OR
                            levenshtein(SPLIT_PART(LOWER(epp.lp_name), ' ', 1),
                                        SPLIT_PART(LOWER(nm1.rus_mnn_title), ' ', 1)) <= 3
                          OR
                            levenshtein(SPLIT_PART(LOWER(epp.lp_name), ' ', 1),
                                        SPLIT_PART(LOWER(nm1.lat_genitivus), ' ', 1)) <= 3 );

GRANT SELECT ON common_analytics2.e_prescr_join_union11 to gpuser;

CREATE TABLE common_analytics2.e_prescr_join_union12 AS
SELECT DISTINCT epp.lp_id, epp.lp_name, nm.mnn_id, nm.rus_mnn_title, nm.lat_mnn_title, 'tnn_join_lev' AS source
    FROM public.e_prescr_preps epp
             JOIN common_analytics2.drug_classifier_nsi nm
                  ON epp.lp_id = nm.trade_name_id
                      AND ( levenshtein(SPLIT_PART(LOWER(epp.lp_name), ' ', 1),
                                        SPLIT_PART(LOWER(nm.lat_title), ' ', 1)) <= 3
                          OR
                            levenshtein(SPLIT_PART(LOWER(epp.lp_name), ' ', 1),
                                        SPLIT_PART(LOWER(nm.rus_title), ' ', 1)) <= 3 )
                      AND ( levenshtein(SPLIT_PART(LOWER(epp.lp_name), ' ', 2),
                                        SPLIT_PART(LOWER(nm.lat_title), ' ', 2)) <= 3
                          OR
                            levenshtein(SPLIT_PART(LOWER(epp.lp_name), ' ', 2),
                                        SPLIT_PART(LOWER(nm.rus_title), ' ', 2)) <= 3 )
    WHERE epp.lp_name NOT IN (SELECT u2.lp_name FROM common_analytics2.e_prescr_join_union11 u2);

GRANT SELECT ON common_analytics2.e_prescr_join_union12 to gpuser;

CREATE TABLE common_analytics2.e_prescr_join_union AS
SELECT *
    FROM common_analytics2.e_prescr_join_union11 t1
UNION
SELECT *
    FROM common_analytics2.e_prescr_join_union12 t2;

GRANT SELECT ON common_analytics2.e_prescr_join_union to gpuser;

--Подстрока

DROP TABLE IF EXISTS common_analytics2.e_prescr_join_union2;
DROP TABLE IF EXISTS common_analytics2.e_prescr_join_union21;
DROP TABLE IF EXISTS common_analytics2.e_prescr_join_union22;
DROP TABLE IF EXISTS common_analytics2.e_prescr_join_union23;
DROP TABLE IF EXISTS common_analytics2.e_prescr_join_union24;
DROP TABLE IF EXISTS common_analytics2.e_prescr_join_union25;

CREATE TABLE common_analytics2.e_prescr_join_union21 AS
SELECT DISTINCT epp.lp_id, epp.lp_name, nm.mnn_id, nm.rus_mnn_title, nm.lat_mnn_title, 'substring_join'::text AS source
    FROM public.e_prescr_preps epp
             JOIN common_analytics2.drug_classifier_nsi nm
                  ON LOWER(REPLACE(REGEXP_REPLACE(SPLIT_PART(epp.lp_name, SUBSTRING(epp.lp_name, ' \d+'), 1), '[a-zA-Z]*\..*', '', 'g'), ' ', ''))
                      = LOWER(REPLACE(nm.lat_genitivus, ' ', ''))
    WHERE epp.lp_name NOT IN (SELECT u.lp_name
                                  FROM common_analytics2.e_prescr_join_union u);

GRANT SELECT ON common_analytics2.e_prescr_join_union21 to gpuser;

CREATE TABLE common_analytics2.e_prescr_join_union22 AS
SELECT DISTINCT epp.lp_id, epp.lp_name, nm.mnn_id, nm.rus_mnn_title, nm.lat_mnn_title, 'substring_join'::text AS source
    FROM public.e_prescr_preps epp
             JOIN common_analytics2.drug_classifier_nsi nm
                  ON LOWER(REPLACE(REGEXP_REPLACE(SPLIT_PART(epp.lp_name, SUBSTRING(epp.lp_name, ' \d+'), 1), '[a-zA-Z]*\..*', '', 'g'), ' ', ''))
                      = LOWER(REPLACE(nm.lat_mnn_title, ' ', ''))
    WHERE epp.lp_name NOT IN (SELECT u.lp_name
                                  FROM common_analytics2.e_prescr_join_union u
                              UNION
                              SELECT u1.lp_name
                                  FROM common_analytics2.e_prescr_join_union21 u1)
      AND LENGTH(LOWER(REPLACE(REGEXP_REPLACE(SPLIT_PART(epp.lp_name, SUBSTRING(epp.lp_name, ' \d+'), 1), '[a-zA-Z]*\..*', '', 'g'), ' ', ''))) > 0;

GRANT SELECT ON common_analytics2.e_prescr_join_union22 to gpuser;

CREATE TABLE common_analytics2.e_prescr_join_union23 AS
SELECT DISTINCT epp.lp_id, epp.lp_name, nm.mnn_id, nm.rus_mnn_title, nm.lat_mnn_title, 'substring_join'::text AS source
    FROM public.e_prescr_preps epp
             JOIN common_analytics2.drug_classifier_nsi nm
                  ON LOWER(REPLACE(REGEXP_REPLACE(SPLIT_PART(epp.lp_name, SUBSTRING(epp.lp_name, ' \d+'), 1), '[a-zA-Z]*\..*', '', 'g'), ' ', ''))
                      = LOWER(REPLACE(nm.rus_mnn_title, ' ', ''))
    WHERE epp.lp_name NOT IN (SELECT u.lp_name
                                  FROM common_analytics2.e_prescr_join_union u
                              UNION
                              SELECT u1.lp_name
                                  FROM common_analytics2.e_prescr_join_union21 u1
                              UNION
                              SELECT u2.lp_name
                                  FROM common_analytics2.e_prescr_join_union22 u2)
      AND LENGTH(LOWER(REPLACE(REGEXP_REPLACE(SPLIT_PART(epp.lp_name, SUBSTRING(epp.lp_name, ' \d+'), 1), '[a-zA-Z]*\..*', '', 'g'), ' ', ''))) > 0;

GRANT SELECT ON common_analytics2.e_prescr_join_union23 to gpuser;

CREATE TABLE common_analytics2.e_prescr_join_union24 AS
SELECT DISTINCT epp.lp_id, epp.lp_name, nm.mnn_id, nm.rus_mnn_title, nm.lat_mnn_title, 'substring_join'::text AS source
    FROM public.e_prescr_preps epp
             JOIN common_analytics2.drug_classifier_nsi nm
                  ON LOWER(REPLACE(REGEXP_REPLACE(SPLIT_PART(epp.lp_name, SUBSTRING(epp.lp_name, ' \d+'), 1), '[a-zA-Z]*\..*', '', 'g'), ' ', ''))
                      = LOWER(REPLACE(REGEXP_REPLACE(SPLIT_PART(nm.lat_title, SUBSTRING(nm.lat_title, ' \d+'), 1), '[a-zA-Z]*\..*', '', 'g'), ' ', ''))
    WHERE epp.lp_name NOT IN (SELECT u.lp_name
                                  FROM common_analytics2.e_prescr_join_union u
                              UNION
                              SELECT u1.lp_name
                                  FROM common_analytics2.e_prescr_join_union21 u1
                              UNION
                              SELECT u2.lp_name
                                  FROM common_analytics2.e_prescr_join_union22 u2
                              UNION
                              SELECT u3.lp_name
                                  FROM common_analytics2.e_prescr_join_union23 u3)
      AND LENGTH(LOWER(REPLACE(REGEXP_REPLACE(SPLIT_PART(epp.lp_name, SUBSTRING(epp.lp_name, ' \d+'), 1), '[a-zA-Z]*\..*', '', 'g'), ' ', ''))) > 0;

GRANT SELECT ON common_analytics2.e_prescr_join_union24 to gpuser;

CREATE TABLE common_analytics2.e_prescr_join_union25 AS
SELECT DISTINCT epp.lp_id, epp.lp_name, nm.mnn_id, nm.rus_mnn_title, nm.lat_mnn_title, 'substring_join'::text AS source
    FROM public.e_prescr_preps epp
             JOIN common_analytics2.drug_classifier_nsi nm
                  ON LOWER(REPLACE(epp.lp_name, ' ', '')) =
                     LOWER(REPLACE(nm.lat_genitivus, ' ', ''))
    WHERE epp.lp_name NOT IN (SELECT u.lp_name
                                  FROM common_analytics2.e_prescr_join_union u
                              UNION
                              SELECT u1.lp_name
                                  FROM common_analytics2.e_prescr_join_union21 u1
                              UNION
                              SELECT u2.lp_name
                                  FROM common_analytics2.e_prescr_join_union22 u2
                              UNION
                              SELECT u3.lp_name
                                  FROM common_analytics2.e_prescr_join_union23 u3
                              UNION
                              SELECT u4.lp_name
                                  FROM common_analytics2.e_prescr_join_union24 u4);

GRANT SELECT ON common_analytics2.e_prescr_join_union25 to gpuser;

CREATE TABLE common_analytics2.e_prescr_join_union2 AS
SELECT *
    FROM common_analytics2.e_prescr_join_union21 u1
UNION
SELECT *
    FROM common_analytics2.e_prescr_join_union22 u2
UNION
SELECT *
    FROM common_analytics2.e_prescr_join_union23 u3
UNION
SELECT *
    FROM common_analytics2.e_prescr_join_union24 u4
UNION
SELECT *
    FROM common_analytics2.e_prescr_join_union25 u5;

GRANT SELECT ON common_analytics2.e_prescr_join_union2 to gpuser;
--Сливаем итоги в таблицу результата

DROP TABLE IF EXISTS common_analytics2.e_prescr_mnn_result;

CREATE TABLE common_analytics2.e_prescr_mnn_result as
SELECT DISTINCT a.lp_id, a.lp_name, a.mnn_id, a.rus_mnn_title, a.lat_mnn_title, a.source
    FROM
        (select lp_id, lp_name, mnn_id, rus_mnn_title, lat_mnn_title, source
             FROM common_analytics2.e_prescr_join_union u
         UNION
         SELECT lp_id, lp_name, mnn_id, rus_mnn_title, lat_mnn_title, source
             FROM common_analytics2.e_prescr_join_union2 u2) a;


--РАЗДЕЛ II. ПОДТЯГИВАНИЕ ДАТЫ ОТПУСКА ПРЕПАРАТА ИЗ АПТЕКИ

DROP TABLE IF EXISTS common_analytics2.prescription_sale;

CREATE TABLE common_analytics2.prescription_sale AS
SELECT DISTINCT r.number_, s.sale_date::date
    FROM ods_llo_ora.emias_llo__prescription r
             LEFT JOIN ods_llo_ora.emias_llo__prescription_servicing s
                       ON s.prescription_id::bigint = r.id::bigint
                           AND s.hdp_active_flg = '1';

GRANT SELECT ON common_analytics2.prescription_sale TO gpuser;

