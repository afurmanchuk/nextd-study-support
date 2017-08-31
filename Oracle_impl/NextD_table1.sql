/*---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                          Part 1: Defining Denominator or Study Sample                               -----  
--------------------------------------------------------------------------------------------------------------- 
---------------------------------------------------------------------------------------------------------------
-----                People with at least two encounters recorded on different days                       -----
-----                                                                                                     -----            
-----                       Encounter should meet the following requerements:                             -----
-----    Patient must be 18 years old >= age <= 89 years old during the encounter day.                    -----
-----    Encounter should be encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',                 -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----          The date of the first encounter and total number of encounters is collected.               -----
---------------------------------------------------------------------------------------------------------------
Using CDM C3R1
*/

/* Check that the curated lab, med data is loaded.
Create them using extraction_tmp_ddl.sql and
import from med_info.csv, lab_review.csv respectively.
*/
/*
select case when labs > 0 and meds > 0 then 1
       else 1 / 0 end curated_data_loaded from (
  select
    (select count(*) from nextd_med_info) meds,
    (select count(*) from nextd_lab_review) labs
  from dual
);
*/

create or replace view encounter_of_interest as
with age_at_visit as (
  select cast(d.BIRTH_DATE as date) BIRTH_DATE
       , cast(((cast(e.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) age
       , e.*
  from "&&PCORNET_CDM".ENCOUNTER e
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
)
select e.ENCOUNTERID, e.patid, e.BIRTH_DATE, e.admit_date, e.enc_type
from age_at_visit e
  where e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED') 
  and e.age between 18 and 89 
;


/* 
Collect data to put summary for the study sample. 
Further data collection will be performed for this population: 
*/
INSERT INTO DenominatorSummary
  (PATID,
   BIRTH_DATE,
   FirstVisit,
   NumberOFVisits)
/*          Get all encounters for each patient sorted by date: */     
with Denominator_init as(
select e.PATID, e.BIRTH_DATE, e.ADMIT_DATE
     , row_number() over (partition by e.PATID order by e.ADMIT_DATE asc) rn 
  from encounter_of_interest e
)
/* Collect visits reported on different days: */
, Denomtemp0v as (
select distinct uf.PATID, uf.BIRTH_DATE, uf.ADMIT_DATE
, row_number() over (partition by uf.PATID order by uf.ADMIT_DATE asc) rn 
  from Denominator_init uf
)
/* Collect number of visits (from ones recorded on different days) for each person: */
, Denomtemp1v as (
select x.PATID, x.BIRTH_DATE, count(distinct x.ADMIT_DATE) as NumberOfVisits 
  from Denomtemp0v x
  group by x.PATID, x.BIRTH_DATE
  order by x.PATID
)
/* Collect date of the first visit: */
, Denomtemp2v as (
select x.PATID, x.BIRTH_DATE, x.ADMIT_DATE as FirstVisit 
  from Denomtemp0v x
  where x.rn=1
)

select x.PATID, b.BIRTH_DATE, b.FirstVisit, x.NumberOfVisits
  from Denomtemp1v x
  left join Denomtemp2v b
  on x.PATID=b.PATID;

/* Constrain encounters using just DenominatorSummary, not all of DEMOGRAPHIC. */
create or replace view encounter_type_age_denominator as
with age_at_visit as (
  select cast(d.BIRTH_DATE as date) BIRTH_DATE
       , cast(((cast(e.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) age
       , e.*
  from "&&PCORNET_CDM".ENCOUNTER e
  join DenominatorSummary d
  on e.PATID=d.PATID
)
select e.ENCOUNTERID, e.patid, e.BIRTH_DATE, e.admit_date, e.enc_type
  from age_at_visit e
  where e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED') 
  and e.age between 18 and 89
;
/*-------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                                    Part 2: Defining Pregnancy                                       ----- 
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                             People with pregnancy-related encounters                                -----
-----                                                                                                     -----            
-----                       Encounter should meet the following requirements:                             -----
-----           Patient must be 18 years old >= age <= 89 years old during the encounter day.             -----
-----                                                                                                     -----
-----                 The date of the first encounter for each pregnancy is collected.                    -----
---------------------------------------------------------------------------------------------------------------
 Cases with miscarriage or abortion diagnosis codes:*/

insert into Miscarr_Abort
select ds.PATID, dia.ADMIT_DATE 
  from DenominatorSummary ds
  join "&&PCORNET_CDM".DIAGNOSIS dia 
  on ds.PATID=dia.PATID
	join "&&PCORNET_CDM".ENCOUNTER e
	on dia.ENCOUNTERID=e.ENCOUNTERID 
	join "&&PCORNET_CDM".DEMOGRAPHIC d
	on e.PATID=d.PATID
		where ((regexp_like(dia.DX,'63[0|1|2|3|4|5|6|7|8|9]\..') and dia.DX_TYPE = '09') or ((regexp_like(dia.DX, '^O') or regexp_like(dia.DX, 'A34.*') or regexp_like(dia.DX, 'Z3[3|4|6].*')) and dia.DX_TYPE = '10'))
		and cast(((cast(dia.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <= 89 
    and cast(((cast(dia.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/*-- Cases with pregnancy and birth diagnosis codes:*/
insert into Pregn_Birth
select ds.PATID,dia.ADMIT_DATE 
  from DenominatorSummary ds
  join "&&PCORNET_CDM".DIAGNOSIS dia 
  on ds.PATID=dia.PATID
	join "&&PCORNET_CDM".ENCOUNTER e
	on dia.ENCOUNTERID=e.ENCOUNTERID 
	join "&&PCORNET_CDM".DEMOGRAPHIC d
	on e.PATID=d.PATID	
	where ((regexp_like(dia.DX,'6[4|5|6|7][0|1|2|3|4|5|6|7|8|9]\..') or regexp_like(dia.DX, 'V2[2|3|8].*')) and dia.DX_TYPE = '09')
  and cast(((cast(dia.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <= 89 
  and cast(((cast(dia.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/* Cases with delivery procedures in ICD-9 coding:*/
insert into DelivProc
select ds.PATID, p.ADMIT_DATE 
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PROCEDURES p 
  on ds.PATID=p.PATID
	join "&&PCORNET_CDM".ENCOUNTER e
	on p.ENCOUNTERID=e.ENCOUNTERID 
	join "&&PCORNET_CDM".DEMOGRAPHIC d
	on e.PATID=d.PATID	
		where ((regexp_like(p.PX,'7[2|3|4|5]\..') and p.PX_TYPE = '09') or (p.PX like '^1' and p.PX_TYPE = '10'))
		and cast(((cast(p.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <= 89 
    and cast(((cast(p.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)>=18;
COMMIT;
/* Cases with delivery procedures in CPT coding:		*/
insert into PregProc
select ds.PATID, p.ADMIT_DATE 
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PROCEDURES p 
  on ds.PATID=p.PATID
	join "&&PCORNET_CDM".ENCOUNTER e
	on p.ENCOUNTERID=e.ENCOUNTERID 
	join "&&PCORNET_CDM".DEMOGRAPHIC d
	on e.PATID=d.PATID	
	where (regexp_like(p.PX,'59[0|1|2|3|4|5|6|7|8|9][0|1|2|3|4|5|6|7|8|9][0|1|2|3|4|5|6|7|8|9]') and p.PX_TYPE in ('C3', 'C4', 'CH'))
    /* Changed to include C4 (and CH for later updates) since it refers to the same thing as C3 according to the CDM 3.1 Specification */
	and cast(((cast(p.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <= 89 
  and cast(((cast(p.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/*---------------------------------------------------------------------------------------------------------------
 Collect all encounters related to pregnancy:  */
insert into AllPregnancyWithAllDates
select x.PATID,x.ADMIT_DATE 
  from
  (select a.PATID, a.ADMIT_DATE 
  from Miscarr_Abort a
  union
  select b.PATID, b.ADMIT_DATE
  from Pregn_Birth b
  union
  select c.PATID, c.ADMIT_DATE
  from DelivProc c
  union
  select d.PATID, d.ADMIT_DATE
  from PregProc d)x
  group by x.PATID, x.ADMIT_DATE;
COMMIT;
/*---------------------------------------------------------------------------------------------------------------
-- Find separate pregnancy events:                                   
-- Calculate time difference between each pregnancy encounter, select the first encounter of each pregnancy event:  */
insert into DeltasPregnancy
select x2.PATID,x2.ADMIT_DATE,x2.dif 
  from
  (select x.PATID, x.ADMIT_DATE, round(months_between(x.ADMIT_DATE, Lag(x.ADMIT_DATE, 1,NULL) OVER(partition by x.PATID ORDER BY x.ADMIT_DATE))) as dif
  from AllPregnancyWithAllDates x)x2
  where x2.dif is NULL or x2.dif>=12;
COMMIT;
/* Number pregnancies:  */
insert into NumberPregnancy
select x.PATID, x.ADMIT_DATE, row_number() over (partition by x.PATID order by x.ADMIT_DATE asc) rn 
  from DeltasPregnancy x;
COMMIT;
/* Transponse pregnancy table into single row per patient. Currently allows 21 sepearate pregnacy events:  */
insert into FinalPregnancy
select * 
  from
  (select PATID, ADMIT_DATE, rn
  from NumberPregnancy) 
  pivot (max(ADMIT_DATE) for (rn) in (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21)
  ) order by PATID;     
COMMIT;

--Exclude pregnancy encounters from the encounters of interest and create a new view from the remaining encounters
create or replace view encounter_exclude_pregnancy as 
(
select * from encounter_of_interest
where encounterid not in
    (
    --Find encounters that fall within one year of pregnancy admit dates
    select /*distinct*/ eoi.encounterid 
    --eoi.birth_date, eoi.enc_type, eoi.patid, np.patid, 
    --eoi.admit_date, np.admit_date, (eoi.admit_date - np.admit_date) as date_diff
    from encounter_of_interest eoi
    join NumberPregnancy np
    on eoi.patid = np.patid
    where abs(eoi.admit_date - np.admit_date) <= 365
    )
);
COMMIT;

/*-------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                 Part4: Combine results from all parts of the code into final table:                 -----
---------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------
-----                               Table FinalStatTable is Table 1                                      -----
-----                          will be used for post-processing analysis                                  ------
-----                             
-------------------------------------------------------------------------------------------------------------*/
/*-------------------------------------------------------------------------------------------------------------*/
/* Data Request for 9/5: Without the DM onset column */
/*-------------------------------------------------------------------------------------------------------------*/
DROP TABLE FinalStatTable;
CREATE GLOBAL TEMPORARY TABLE FinalStatTable
  (PATID VARCHAR(128) NOT NULL, 
  FirstVisit date NULL, 
  NumberOfVisits INT, 
  DEATH_DATE date NULL,
  PregnancyDate_1 date NULL, 
  PregnancyDate_2 date NULL, 
  PregnancyDate_3 date NULL, 
  PregnancyDate_4 date NULL, 
  PregnancyDate_5 date NULL,
  PregnancyDate_6 date NULL, 
  PregnancyDate_7 date NULL, 
  PregnancyDate_8 date NULL, 
  PregnancyDate_9 date NULL, 
  PregnancyDate_10 date NULL,
  PregnancyDate_11 date NULL, 
  PregnancyDate_12 date NULL, 
  PregnancyDate_13 date NULL, 
  PregnancyDate_14 date NULL, 
  PregnancyDate_15 date NULL,
  PregnancyDate_16 date NULL, 
  PregnancyDate_17 date NULL, 
  PregnancyDate_18 date NULL, 
  PregnancyDate_19 date NULL, 
  PregnancyDate_20 date NULL,
  PregnancyDate_21 date NULL)
  on commit preserve rows;
COMMIT;

insert into FinalStatTable
select ds.PATID, ds.FirstVisit, ds.NumberOfVisits, d.DEATH_DATE, 
p.PregnancyDate_1, p.PregnancyDate_2, p.PregnancyDate_3, p.PregnancyDate_4, p.PregnancyDate_5,
p.PregnancyDate_6, p.PregnancyDate_7, p.PregnancyDate_8, p.PregnancyDate_9, p.PregnancyDate_10,
p.PregnancyDate_11, p.PregnancyDate_12, p.PregnancyDate_13, p.PregnancyDate_14, p.PregnancyDate_15,
p.PregnancyDate_16, p.PregnancyDate_17, p.PregnancyDate_18, p.PregnancyDate_19, p.PregnancyDate_20,
p.PregnancyDate_21
  from DenominatorSummary ds
  left join "&&PCORNET_CDM".DEATH d
  on ds.PATID=d.PATID
  left join FinalPregnancy p
  on ds.PATID=p.PATID;
  COMMIT;
  
select count(distinct patid) from FinalStatTable; /* 570512 */
select * from FinalStatTable;

/* For dates, only show YYYY-MM */
select patid, to_char(firstvisit, 'YYYY-MM') firstvisit, numberofvisits, to_char(death_date, 'YYYY-MM') death_date, 
to_char(PregnancyDate_1, 'YYYY-MM') PregnancyDate1, to_char(PregnancyDate_2, 'YYYY-MM') PregnancyDate2, to_char(PregnancyDate_3, 'YYYY-MM') PregnancyDate3, to_char(PregnancyDate_4, 'YYYY-MM') PregnancyDate4, to_char(PregnancyDate_5, 'YYYY-MM') PregnancyDate5,
to_char(PregnancyDate_6, 'YYYY-MM') PregnancyDate6, to_char(PregnancyDate_7, 'YYYY-MM') PregnancyDate7, to_char(PregnancyDate_8, 'YYYY-MM') PregnancyDate8, to_char(PregnancyDate_9, 'YYYY-MM') PregnancyDate9, to_char(PregnancyDate_10, 'YYYY-MM') PregnancyDate10, 
to_char(PregnancyDate_11, 'YYYY-MM') PregnancyDate11, to_char(PregnancyDate_12, 'YYYY-MM') PregnancyDate12, to_char(PregnancyDate_13, 'YYYY-MM') PregnancyDate13, to_char(PregnancyDate_14, 'YYYY-MM') PregnancyDate14, to_char(PregnancyDate_15, 'YYYY-MM') PregnancyDate15,
to_char(PregnancyDate_16, 'YYYY-MM') PregnancyDate16, to_char(PregnancyDate_17, 'YYYY-MM') PregnancyDate17, to_char(PregnancyDate_18, 'YYYY-MM') PregnancyDate18, to_char(PregnancyDate_19, 'YYYY-MM') PregnancyDate19, to_char(PregnancyDate_20, 'YYYY-MM') PregnancyDate20,
to_char(PregnancyDate_21, 'YYYY-MM') PregnancyDate21 from FinalStatTable;
