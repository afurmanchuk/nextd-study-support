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
*/

/* Check that the curated lab, med data is loaded.

Create them using extraction_tmp_ddl.sql and
import from med_info.csv, lab_review.csv respectively.
*/
select case when labs > 0 and meds > 0 then 1
       else 1 / 0 end curated_data_loaded from (
  select
    (select count(*) from nextd_med_info) meds,
    (select count(*) from nextd_lab_review) labs
  from dual
);

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
drop table DenominatorSummary;
create table DenominatorSummary as
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
create index DenominatorSummary_patid on DenominatorSummary (patid);

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
                         Part 2: Defining Diabetes Mellitus sample                                   
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----        People with HbA1c having two measures on different days within 2 years interval              -----
-----                                                                                                     -----            
-----                         Lab should meet the following requirements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    Lab value is >= 6.5 %.                                                                           -----
-----    Lab name is 'A1C' & LOINC codes '27352-2','4548-4'.                                              -----
-----    Lab should meet requirement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----                  The first pair of labs meeting requirements is collected.                          -----
-----     The date of the first HbA1c lab out the first pair will be recorded as initial event.           -----
---------------------------------------------------------------------------------------------------------------
             Get all labs for each patient sorted by date:           */
insert into A1c_initial
select ds.PATID, l.LAB_ORDER_DATE, row_number() over (partition by l.PATID order by l.LAB_ORDER_DATE asc) rn 
  from DenominatorSummary ds
  join "&&PCORNET_CDM".LAB_RESULT_CM l 
  on ds.PATID=l.PATID
  join encounter_of_interest e
  on l.ENCOUNTERID=e.ENCOUNTERID 
  where l.LAB_NAME='A1C'  
  and l.RESULT_NUM >=6.5 and l.RESULT_UNIT='PERCENT'
  ;
COMMIT;
/*    The first date out the first pair of encounters is selected:      */
insert into temp1
select uf.PATID, uf.LAB_ORDER_DATE,
row_number() over (partition by un.PATID order by uf.LAB_ORDER_DATE asc) rn 
  from A1c_initial un
  join A1c_initial uf
  on un.PATID = uf.PATID
  where abs(un.LAB_ORDER_DATE-uf.LAB_ORDER_DATE)>1 and 
  abs(cast(((cast(un.LAB_ORDER_DATE as date)-cast(uf.LAB_ORDER_DATE as date))/365.25 ) as integer))<=2;
insert into A1c_final_FirstPair
select x.PATID, x.LAB_ORDER_DATE as EventDate from temp1 x where x.rn=1;
COMMIT;
/*---------------------------------------------------------------------------------------------------------------
-----     People with fasting glucose having two measures on different days within 2 years interval       -----
-----                                                                                                     -----            
-----                         Lab should meet the following requirements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    Lab value is >= 126 mg/dL.                                                                       -----
-----    (Lab name is 'GLUF','RUGLUF' or testname 'GLUF') & LOINC codes '1558-6', '1493-6', '10450-5',    -----
-----    '1554-5', '17865-7', '14771-0', '77145-1', '1500-8', '1523-0', '1550-3','14769-4'.               -----
-----    Lab should meet requirement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----                   The first pair of labs meeting requirements is collected.                         -----
-----   The date of the first fasting glucose lab out the first pair will be recorded as initial event.   -----
---------------------------------------------------------------------------------------------------------------
-----                                    Not available in PCORNET                                         -----
-----                               extraction is done from side table                                    -----
---------------------------------------------------------------------------------------------------------------
                               Get all labs for each patient sorted by date:         */

/* Double-check that fasting glucose results are given in mg/dL

Note: currently finds no relevant results, since PCORNet specs don't
mandate including glucose labs.
This is an open issue: https://informatics.gpcnetwork.org/trac/Project/ticket/551

select l.lab_name, l.result_unit, count(*)
from "&&PCORNET_CDM".LAB_RESULT_CM l
group by l.lab_name, l.result_unit
order by l.lab_name, l.result_unit
;
*/
 
create or replace view glucose_concepts as
with loinc_concepts as (
  select concept_path, name_char, concept_cd, substr(concept_cd, length('LOINC:_')) lab_loinc
  from "&&I2B2_STAR".concept_dimension cd
  where concept_path like '\i2b2\Laboratory Tests\%'
  and concept_cd like 'LOINC:%'
)
, loinc_fasting_glucose as (
  select 1 fasting, l.* from loinc_concepts l
  where l.concept_cd in ( select c_basecode from nextd_lab_review where category = 'Fasting Glucose') 
)
, loinc_random_glucose as (
  select 0 fasting, l.* from loinc_concepts l
  where l.concept_cd in ( select c_basecode from nextd_lab_review where category = 'Random Glucose')
)
select fasting, lrg.lab_loinc, cd.name_char, cd.concept_cd, cd.concept_path
from loinc_random_glucose lrg
join "&&I2B2_STAR".concept_dimension cd
  on cd.concept_path like (lrg.concept_path || '%')
;


create or replace view glucose_results as
select obs.patient_num, obs.start_date, obs.encounter_num
     , obs.nval_num, obs.units_cd, obs.concept_cd
     , gc.name_char, gc.fasting
from
  glucose_concepts gc
join "&&I2B2_STAR".observation_fact obs on obs.concept_cd = gc.concept_cd
;

insert into FG_initial
-- LAB_ORDER_DATE became start_date, which is more likely result date-time than order date.
select ds.PATID, l.start_date, row_number() over (partition by l.patient_num order by l.start_date asc) rn  
  from DenominatorSummary ds
  join glucose_results l 
  on ds.PATID=l.patient_num
  join encounter_of_interest e
  on l.encounter_num=e.ENCOUNTERID
  where l.fasting = 1
	and l.nval_num >= 126 and lower(l.units_cd)='mg/dl'
;
COMMIT;
/*                     The first date out the first pair of encounters is selected:		*/
insert into temp2
select uf.PATID, uf.LAB_ORDER_DATE,row_number() over (partition by un.PATID order by uf.LAB_ORDER_DATE asc) rn 
  from FG_initial un
  join FG_initial uf
  on un.PATID = uf.PATID
  where abs(un.LAB_ORDER_DATE-uf.LAB_ORDER_DATE)>1 
  and abs(cast(((cast(un.LAB_ORDER_DATE as date)-cast(uf.LAB_ORDER_DATE as date))/365.25 ) as integer))<=2;
insert into FG_final_FirstPair             
select x.PATID, x.LAB_ORDER_DATE as EventDate 
  from temp1 x where x.rn=1; 
COMMIT;
/*---------------------------------------------------------------------------------------------------------------
-----     People with random glucose having two measures on different days within 2 years interval        -----
-----                                                                                                     -----            
-----                         Lab should meet the following requirements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    Lab value is >= 200 mg/dL.                                                                       -----
-----    (Lab name is 'GLUF','RUGLUF' or testname 'GLUF') & LOINC codes '1558-6', '1493-6', '10450-5',    -----
-----    '1554-5', '17865-7', '14771-0', '77145-1', '1500-8', '1523-0', '1550-3','14769-4'.               -----
-----    Lab should meet requirement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----                   The first pair of labs meeting requerements is collected.                         -----
-----   The date of the first random glucose lab out the first pair will be recorded as initial event.    -----
---------------------------------------------------------------------------------------------------------------
-----                                    Not available in PCORNET                                         -----
-----                               extraction is done from side table                                    -----
---------------------------------------------------------------------------------------------------------------
                           Get all labs for each patient sorted by date:            */
insert into RG_initial
select ds.PATID, l.start_date, row_number() over (partition by l.patient_num order by l.start_date asc) rn  
  from DenominatorSummary ds
  join glucose_results l 
  on ds.PATID=l.patient_num
  join encounter_of_interest e
  on l.encounter_num=e.ENCOUNTERID
  where l.fasting = 0
	and l.nval_num >= 200 and lower(l.units_cd)='mg/dl'
;
COMMIT;
/*-- The first date out the first pair of encounters is selected:		*/
insert into temp3
select uf.PATID, uf.LAB_ORDER_DATE, row_number() over (partition by un.PATID order by uf.LAB_ORDER_DATE asc) rn 
  from RG_initial un
  join RG_initial uf
  on un.PATID = uf.PATID
  where abs(un.LAB_ORDER_DATE-uf.LAB_ORDER_DATE)>1 
  and abs(cast(((cast(un.LAB_ORDER_DATE as date)-cast(uf.LAB_ORDER_DATE as date))/365.25 ) as integer))<=2;
COMMIT;
insert into RG_final_FirstPair
select x.PATID, x.LAB_ORDER_DATE as EventDate 
  from temp1 x where x.rn=1; 
COMMIT;
/*-------------------------------------------------------------------------------------------------------------
-----     People with one random glucose & one HbA1c having both measures on different days within        -----
-----                                        2 years interval                                             -----
-----                                                                                                     -----            
-----                         Lab should meet the following requirements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    See corresponding sections above for the Lab values requerements.                                -----  
-----    Lab should meet requirement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----               The first pair of HbA1c labs meeting requirements is collected.                       -----
-----        The date of the first lab out the first pair will be recorded as initial event.              -----
---------------------------------------------------------------------------------------------------------------
-----                                    Not available in PCORNET                                         -----
-----                               extraction is done from side table                                    -----
---------------------------------------------------------------------------------------------------------------
                 Get lab values from corresponding tables produced above:               */
insert into temp4
select uf.PATID, uf.LAB_ORDER_DATE as RG_date, un.LAB_ORDER_DATE as A1c_date,row_number() over (partition by un.PATID order by uf.LAB_ORDER_DATE asc) rn 
  from A1c_initial un
  join RG_initial uf
  on un.PATID = uf.PATID
  where abs(un.LAB_ORDER_DATE-uf.LAB_ORDER_DATE)>1 
  and abs(cast(((cast(un.LAB_ORDER_DATE as date)-cast(uf.LAB_ORDER_DATE as date))/365.25 ) as integer))<=2;
COMMIT;
/*-- Select the date for the first lab within the first pair:*/
insert into A1cRG_final_FirstPair
select x.PATID,
  case when RG_date < A1c_date then RG_date
	when RG_date > A1c_date then A1c_date
	else RG_date
	end as EventDate 
  from temp4 x where rn=1;
COMMIT;
/*---------------------------------------------------------------------------------------------------------------
-----     People with one fasting glucose & one HbA1c having both measures on different days within       -----
-----                                        2 years interval                                             -----
-----                                                                                                     -----            
-----                         Lab should meet the following requirements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    See corresponding sections above for the Lab values requerements.                                -----  
-----    Lab should meet requirement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----               The first pair of HbA1c labs meeting requirements is collected.                       -----
-----           The date of the first lab out the first pair will be recorded as initial event.           -----
---------------------------------------------------------------------------------------------------------------
-----                                    Not available in PCORNET                                         -----
-----                               extraction is done from side table                                    -----
---------------------------------------------------------------------------------------------------------------
                Get lab values from corresponding tables produced above:       */
insert into temp5
select uf.PATID, uf.LAB_ORDER_DATE as FG_date, un.LAB_ORDER_DATE as A1c_date,row_number() over (partition by un.PATID order by uf.LAB_ORDER_DATE asc) rn 
  from A1c_initial un
  join FG_initial uf
  on un.PATID = uf.PATID
  where abs(un.LAB_ORDER_DATE-uf.LAB_ORDER_DATE)>1 
  and abs(cast(((cast(un.LAB_ORDER_DATE as date)-cast(uf.LAB_ORDER_DATE as date))/365.25 ) as integer))<=2;
COMMIT;
/*     Select the date for the first lab within the first pair:      */
insert into A1cFG_final_FirstPair
select x.PATID,
  case when FG_date < A1c_date then FG_date
	when FG_date > A1c_date then A1c_date
	else FG_date
	end as EventDate 
  from temp5 x where rn=1;
COMMIT;
/*-------------------------------------------------------------------------------------------------------------
-----               People with two visits (inpatient, outpatient, or emergency department)               -----
-----             relevant to type 1 Diabetes Mellitus or type 2 Diabetes Mellitus diagnosis              -----
-----                        recorded on different days within 2 years interval                           -----
-----                                                                                                     -----            
-----                         Visit should meet the following requirements:                               -----
-----    Patient must be 18 years old >= age <= 89 years old during on the visit day.                     -----
-----    Visit should should be of encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',           -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----                  The first pair of visits meeting requirements is collected.                        -----
-----     The date of the first visit out the first pair will be recorded as initial event.               -----
---------------------------------------------------------------------------------------------------------------
               Get all visits of specified types for each patient sorted by date:  */
insert into Visits_initial 
select ds.PATID, l.ADMIT_DATE, row_number() over (partition by l.PATID order by l.ADMIT_DATE asc) rn  
  from DenominatorSummary ds
  join "&&PCORNET_CDM".DIAGNOSIS l 
  on ds.PATID=l.PATID
  join encounter_of_interest e
  on l.ENCOUNTERID=e.ENCOUNTERID 
  where ((REGEXP_LIKE (l.DX, '250\..[0|1|2|3]') and l.DX_TYPE = '09') or (REGEXP_LIKE (l.DX, 'E1[0|1]') and l.DX_TYPE = '10'))
;
COMMIT;
/* Select the date for the first visit within the first pair: */
insert into temp6
select uf.PATID, uf.ADMIT_DATE,row_number() over (partition by un.PATID order by uf.ADMIT_DATE asc) rn 
  from Visits_initial un
  join Visits_initial uf
  on un.PATID = uf.PATID
  where abs(un.ADMIT_DATE-uf.ADMIT_DATE)>1 
  and abs(cast(((cast(un.ADMIT_DATE as date)-cast(uf.ADMIT_DATE as date))/365.25 ) as integer))<=2;
insert into Visits_final_FirstPair
select x.PATID, x.ADMIT_DATE as EventDate 
  from temp6 x where x.rn=1;  
COMMIT;
/*-------------------------------------------------------------------------------------------------------------
-----            People with at least one ordered medications specific to Diabetes Mellitus               -----
-----                                                                                                     -----            
-----                         Medication should meet the following requirements:                          -----
-----     Patient must be 18 years old >= age <= 89 years old during the ordering of medication           -----
-----    Medication should relate to encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',         -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
---------------------------------------------------------------------------------------------------------------*/
-----                The date of the first medication meeting requirements is collected.                  -----


/*-------------------------------------------------------------------------------------------------------------
-----                   Combine all medications specific to Diabetes Mellitus                             -----
-----         The date of the first medication of any kind will be recorded for each patient              -----
-------------------------------------------------------------------------------------------------------------*/

create or replace view each_med_obs as
with med_info_aux as (
  select distinct dm_drug, drug, rxcui, pattern
       /* combine but_not patterns using (pat1)|(pat2)|(pat3)... */
       , listagg(but_not, ')|(') within group (order by dm_drug, drug, rxcui, pattern, but_not) but_not
  from nextd_med_info info
  group by dm_drug, drug, rxcui, pattern
)
, med_info as (
  select dm_drug, drug, rxcui, pattern
       , case when but_not is null then null else '(' || but_not || ')' end but_not
  from med_info_aux
)
select /*+ leading(a) */ a.PATID, a.encounterid, round(a.RX_ORDER_DATE) as MedDate
    , med_info.dm_drug
    , med_info.drug
    , a.RAW_RX_MED_NAME
  from
  -- for testing:
  -- (select * from "&&PCORNET_CDM".PRESCRIBING where rownum < 1000) a
  "&&PCORNET_CDM".PRESCRIBING a
  join med_info
     on to_char(med_info.rxcui) = a.RXNORM_CUI
     or (
     regexp_like(a.RAW_RX_MED_NAME, med_info.pattern, 'i')
     and (med_info.but_not is null or
          not regexp_like(a.RAW_RX_MED_NAME, med_info.but_not, 'i')))
;

/* Performance note:

We expect full table scans only on DENOMINATORSUMMARY, ENCOUNTER.
The PRESCRIBING is indexed by PRESCRIBING_ENCOUNTERID.

SELECT PLAN_TABLE_OUTPUT line FROM TABLE(DBMS_XPLAN.DISPLAY());
*/
-- explain plan for
insert /*+ append */ into InclusionMeds_final
select y.PATID, y.MedDate as EventDate 
from 
	(select x.PATID, x.MedDate, row_number() over (partition by x.PATID order by x.MedDate asc) rn
	from
		(select a.PATID, a.MedDate 
		from each_med_obs a
    join encounter_type_age_denominator e on a.encounterid = e.encounterid
    where dm_drug = 1  -- specific to Diabetes Mellitus
		) x
	) y
where y.rn=1;
COMMIT;
/*-------------------------------------------------------------------------------------------------------------
-----           People with at least one ordered medications non-specific to Diabetes Mellitus            -----
-----                                                   &                                                 ----- 
-----one lab or one visit record described above. Both recorded on different days within 2 years interval.-----
-----                                                                                                     -----            
-----           Medication and another encounter should meet the following requirements:                  -----
-----        Patient must be 18 years old >= age <= 89 years old during the recorded encounter            -----
-----     Encounter should relate to encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',         -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----                The date of the first medication meeting requirements is collected.                  -----
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                  People with medications non-specific to Diabetes Mellitus                          -----
-----                                 meeting one more requerement                                        -----
-----                         18 >= Age <=89 during the lab ordering day                                  -----
-----                    the date the first time med is recorded will be used                             -----

---------------------------------------------------------------------------------------------------------------*/


/*---------------------------------------------------------------------------------------------------------------
  Combine all meds:    */
insert /*+ append */ into InclUnderRestrMeds_init
select y.PATID, y.MedDate as EventDate 
from 
	(select x.PATID, x.MedDate, row_number() over (partition by x.PATID order by x.MedDate asc) rn
	from
		(select a.PATID, a.MedDate 
		from each_med_obs a
    join encounter_type_age_denominator e on a.encounterid = e.encounterid
    where dm_drug = 0 -- non-specific to Diabetes Mellitus
		) x
	) y
where y.rn=1;
COMMIT;

/* Get set of patients having one med & one visit:  */
insert into p1
select x.PATID, x.MedDate 
  from InclUnderRestrMeds_init x
  join Visits_initial y
  on x.PATID=y.PATID;
COMMIT;
/* Get set of patients having one med & one HbA1c:  */
insert into p2
select x.PATID, x.MedDate 
  from InclUnderRestrMeds_init x
  join A1c_initial y
  on x.PATID=y.PATID;
COMMIT;
/* Get set of patients having one med & fasting glucose measurement:  */
insert into p3
select x.PATID, x.MedDate 
  from InclUnderRestrMeds_init x
  join FG_initial y
  on x.PATID=y.PATID;
COMMIT;
/* Get set of patients having one med & random glucose measurement:  */
insert into p4
select x.PATID, x.MedDate
  from InclUnderRestrMeds_init x
  join RG_initial y
  on x.PATID=y.PATID;
COMMIT;
insert into p5
select x.PATID, x.MedDate
from #InclusionUnderRestrictionMeds_initial x
join #A1cFG_final_FirstPair y
on x.PATID=y.PATID
COMMIT;
/* Collect all non-specific to Diabetes Mellitus meds:  */
insert into InclUnderRestrMeds_final
select y.PATID, y.MedDate as EventDate 
  from
  (select x.PATID, x.MedDate,row_number() over(partition by x.PATID order by x.MedDate asc)rn
  from
  (select a.PATID, a.MedDate  
  from p1 a
  union
  select b.PATID, b.MedDate  
  from p2 b
  union
  select c.PATID, c.MedDate  
  from p3 c
  union
  select d.PATID, d.MedDate  
  from p4 d
  union
  select e.PATID, e.MedDate
  from p5 as e
  union
  select f.PATID, f.MedDate
  from p6 as f
  )x
  )y
  where y.rn=1;
COMMIT;
/*-------------------------------------------------------------------------------------------------------------
-----                                      Defining onset date                                            -----
-------------------------------------------------------------------------------------------------------------*/
insert into AllDM
select y.PATID, y.EventDate
  from 
	(select x.PATID,x.EventDate,row_number() over (partition by x.PATID order by x.EventDate asc) rn
	from
		(select a.PATID,a.EventDate 
		from Visits_final_FirstPair a
		union
		select b.PATID, b.EventDate
		from InclusionMeds_final b
		union
		select c.PATID, c.EventDate
		from A1c_final_FirstPair c
		union
		select d.PATID, d.EventDate
		from FG_final_FirstPair d
		union
		select e.PATID, e.EventDate
		from RG_final_FirstPair e
		union
		select f.PATID, f.EventDate
		from A1cFG_final_FirstPair f
		union
		select g.PATID, g.EventDate
		from A1cRG_final_FirstPair g
		union
		select h.PATID, h.EventDate
		from InclusionMeds_final h
		union
		select k.PATID, k.EventDate
		from InclUnderRestrMeds_final k
		) x
	) y
  where y.rn=1;
  COMMIT;
/*-------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                                    Part 3: Defining Pregnancy                                       ----- 
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
		where ((regexp_like(dia.DX,'63[0|1|2|3|4|5|6|7|8|9]\..') and dia.DX_TYPE = '09') or (regexp_like(dia.DX, '^O') and dia.DX_TYPE = '10'))
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
	where (regexp_like(dia.DX,'6[4|5|6|7][0|1|2|3|4|5|6|7|8|9]\..') and dia.DX_TYPE = '09')
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
  (select x.PATID,x.ADMIT_DATE,DATEDIFF(m, Lag(x.ADMIT_DATE, 1,NULL) OVER(partition by x.PATID ORDER BY x.ADMIT_DATE), x.ADMIT_DATE) as dif
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
/*-------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                 Part4: Combine results from all parts of the code into final table:                 -----
---------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------*/
insert into FinalStatTable
select ds.PATID, ds.FirstVisit, ds.NumberOfVisits, x.EventDate as DMonsetDate, d.DEATH_DATE, 
p.PregnancyDate_1, p.PregnancyDate_2, p.PregnancyDate_3, p.PregnancyDate_4, p.PregnancyDate_5,
p.PregnancyDate_6, p.PregnancyDate_7, p.PregnancyDate_8, p.PregnancyDate_9, p.PregnancyDate_10,
p.PregnancyDate_11, p.PregnancyDate_12, p.PregnancyDate_13, p.PregnancyDate_14, p.PregnancyDate_15,
p.PregnancyDate_16, p.PregnancyDate_17, p.PregnancyDate_18, p.PregnancyDate_19, p.PregnancyDate_20,
p.PregnancyDate_21
  from DenominatorSummary ds
  left join AllDM x
  on a.PATID=x.PATID
  left join "&&PCORNET_CDM".DEATH d
  on a.PATID=d.PATID
  left join FinalPregnancy p
  on a.PATID=p.PATID;
  COMMIT;
/*-------------------------------------------------------------------------------------------------------------
-----                               Table #FinalStatTable is Table 1                                      -----
-----                          will be used for post-processing analysis                                  ------
-----                             
-------------------------------------------------------------------------------------------------------------*/
