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
                         Part 2: Defining Deabetes Mellitus sample                                   
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----        People with HbA1c having two measures on different days within 2 years interval              -----
-----                                                                                                     -----            
-----                         Lab should meet the following requerements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    Lab value is >= 6.5 %.                                                                           -----
-----    Lab name is 'A1C' & LOINC codes '27352-2','4548-4'.                                              -----
-----    Lab should meet requerement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----                  The first pair of labs meeting requerements is collected.                          -----
-----     The date of the first HbA1c lab out the first pair will be recorded as initial event.           -----
---------------------------------------------------------------------------------------------------------------
             Get all labs for each patient sorted by date:           */
insert into A1c_initial (patid, lab_order_date)
with A1c_initial as(
select ds.PATID, l.LAB_ORDER_DATE, row_number() over (partition by l.PATID order by l.LAB_ORDER_DATE asc) rn 
  from DenominatorSummary ds
  join "&&PCORNET_CDM".LAB_RESULT_CM l 
  on ds.PATID=l.PATID
  join encounter_of_interest e
  on l.ENCOUNTERID=e.ENCOUNTERID 
  where l.LAB_NAME='A1C'  
  and l.RESULT_NUM >=6.5 and l.RESULT_UNIT='PERCENT' 
)
/*    The first date out the first pair of encounters is selected:      */
, temp1 as (
select uf.PATID, uf.LAB_ORDER_DATE,
row_number() over (partition by un.PATID order by uf.LAB_ORDER_DATE asc) rn 
  from A1c_initial un
  join A1c_initial uf
  on un.PATID = uf.PATID
  where abs(un.LAB_ORDER_DATE-uf.LAB_ORDER_DATE)>1 and 
  abs(cast(((cast(un.LAB_ORDER_DATE as date)-cast(uf.LAB_ORDER_DATE as date))/365.25 ) as integer))<=2)
, A1c_final_FirstPair as (
select x.PATID, x.LAB_ORDER_DATE as EventDate from temp1 x where x.rn=1)
select * from A1c_final_FirstPair;
COMMIT;
/*---------------------------------------------------------------------------------------------------------------
-----     People with fasting glucose having two measures on different days within 2 years interval       -----
-----                                                                                                     -----            
-----                         Lab should meet the following requerements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    Lab value is >= 126 mg/dL.                                                                       -----
-----    (Lab name is 'GLUF','RUGLUF' or testname 'GLUF') & LOINC codes '1558-6', '1493-6', '10450-5',    -----
-----    '1554-5', '17865-7', '14771-0', '77145-1', '1500-8', '1523-0', '1550-3','14769-4'.               -----
-----    Lab should meet requerement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----                   The first pair of labs meeting requerements is collected.                         -----
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
  where l.LAB_LOINC in ('1558-6', '1493-6', '10450-5', '1554-5', '17865-7', '14771-0', '77145-1', '1500-8', '1523-0', '1550-3','14769-4','14770-2','14771-0','1556-0','1557-8','21004-7','35184-1','40193-5','41604-0','53049-3','62851-1','62852-9','76629-5','77145-1') 
)
, loinc_random_glucose as (
  select 0 fasting, l.* from loinc_concepts l
  where l.LAB_LOINC in ('2345-7','14749-6','10449-7','12614-4','14743-9','14760-3','14761-1','14768-6','14769-4','15074-8','1521-4','1547-9','16165-3','16166-1','16167-9','16168-7','16169-5','16170-3','16915-1','21004-7','2339-0','2340-8','2341-6','27353-2','34546-2','35211-2','39480-9','39481-7','40858-3','41651-1','41652-9','41653-7','41896-2','41897-0','41898-8','41899-6','41900-2','43151-0','44919-9','45052-8','45053-6','45054-4','45055-1','45056-9','47995-6','48986-4','48988-0','48989-8','48990-6','48991-4','48992-2','48993-0','48994-8','51596-5','52041-1','53094-9','53474-3','53553-4','54246-4','5914-7','59812-8','59813-6','59814-4','59815-1','62856-0','6689-4','6777-7','72171-2','72516-8','74244-5','74774-1','75864-9','77135-2','77677-3','80959-0','LP43629-2','LP51365-2','LP51830-5','LP71758-4')
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
where gc.fasting = 0
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
-----                         Lab should meet the following requerements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    Lab value is >= 200 mg/dL.                                                                       -----
-----    (Lab name is 'GLUF','RUGLUF' or testname 'GLUF') & LOINC codes '1558-6', '1493-6', '10450-5',    -----
-----    '1554-5', '17865-7', '14771-0', '77145-1', '1500-8', '1523-0', '1550-3','14769-4'.               -----
-----    Lab should meet requerement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
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
-----                         Lab should meet the following requerements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    See corresponding sections above for the Lab values requerements.                                -----  
-----    Lab should meet requerement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----               The first pair of HbA1c labs meeting requerements is collected.                       -----
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
-----                         Lab should meet the following requerements:                                 -----
-----    Patient must be 18 years old >= age <= 89 years old during the lab ordering day.                 -----
-----    See corresponding sections above for the Lab values requerements.                                -----  
-----    Lab should meet requerement for encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',     -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----               The first pair of HbA1c labs meeting requerements is collected.                       -----
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
-----                         Visit should meet the following requerements:                               -----
-----    Patient must be 18 years old >= age <= 89 years old during on the visit day.                     -----
-----    Visit should should be of encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',           -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----                  The first pair of visits meeting requerements is collected.                        -----
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
-----                         Medication should meet the following requerements:                          -----
-----     Patient must be 18 years old >= age <= 89 years old during the ordering of medication           -----
-----    Medication should relate to encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',         -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----                The date of the first medication meeting requerements is collected.                  -----
---------------------------------------------------------------------------------------------------------------*/


/*-------------------------------------------------------------------------------------------------------------
-----                   Combine all medications specific to Diabetes Mellitus                             -----
-----         The date of the first medication of any kind will be recorded for each patient              -----
-------------------------------------------------------------------------------------------------------------*/
insert /*+ append */ into InclusionMeds_final
with med_info_aux as (
  select distinct dm_drug, drug, rxcui, pattern
       /* combine but_not patterns using (pat1)|(pat2)|(pat3)... */
       , listagg(but_not, ')|(') within group (order by dm_drug, drug, rxcui, pattern, but_not) but_not
  from nextd_med_info info
  where dm_drug = 1
  group by dm_drug, drug, rxcui, pattern
)
, med_info as (
  select drug, rxcui, pattern
       , case when but_not is null then null else '(' || but_not || ')' end but_not
  from med_info_aux
)
, each_med_obs as (
  select /*+ leading(a) */ a.PATID, a.encounterid, round(a.RX_ORDER_DATE) as MedDate
      , med_info.drug
      , a.RAW_RX_MED_NAME
    from
    -- (select * from "&&PCORNET_CDM".PRESCRIBING where rownum < 1000) a
    "&&PCORNET_CDM".PRESCRIBING a
    join med_info
       on to_char(med_info.rxcui) = a.RXNORM_CUI
       or (
       regexp_like(a.RAW_RX_MED_NAME, med_info.pattern, 'i')
       and (med_info.but_not is null or
            not regexp_like(a.RAW_RX_MED_NAME, med_info.but_not, 'i')))
)

select y.PATID, y.MedDate as EventDate 
from 
	(select x.PATID, x.MedDate, row_number() over (partition by x.PATID order by x.MedDate asc) rn
	from
		(select distinct a.PATID, a.MedDate 
		from each_med_obs a
    join encounter_type_age_denominator e on a.encounterid = e.encounterid
		) x
	) y
where y.rn=1;
COMMIT;
/*-------------------------------------------------------------------------------------------------------------
-----           People with at least one ordered medications non-specific to Diabetes Mellitus            -----
-----                                                   &                                                 ----- 
-----one lab or one visit record described above. Both recorded on different days within 2 years interval.-----
-----                                                                                                     -----            
-----           Medication and another encounter should meet the following requerements:                  -----
-----        Patient must be 18 years old >= age <= 89 years old during the recorded encounter            -----
-----     Encounter should relate to encounter types: 'AMBULATORY VISIT', 'EMERGENCY DEPARTMENT',         -----
-----    'INPATIENT HOSPITAL STAY', 'EMERGENCY DEPARTMENT TO INPATIENT HOSPITAL STAY'.                    -----
-----                                                                                                     -----
-----                The date of the first medication meeting requerements is collected.                  -----
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-----                  People with medications non-specific to Diabetes Mellitus                          -----
-----                                 meeting one more requerement                                        -----
-----                         18 >= Age <=89 during the lab ordering day                                  -----
-----                    the date the first time med is recorded will be used                             -----

---------------------------------------------------------------------------------------------------------------
   Biguanide:
   collect meds based on matching names:   */
insert into BiguanideByNames_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where (
  regexp_like(a.RAW_RX_MED_NAME,'Glucophage','i') or regexp_like(a.RAW_RX_MED_NAME,'Fortamet','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Glumetza','i') or regexp_like(a.RAW_RX_MED_NAME,'Riomet','i') or
  /*   this is combination of rosiglitizone-metformin:   */
  regexp_like(a.RAW_RX_MED_NAME,'Amaryl M','i') or regexp_like(a.RAW_RX_MED_NAME,'Avandamet','i') or
  (regexp_like(a.RAW_RX_MED_NAME,'Metformin','i')
  and not (
  regexp_like(a.RAW_RX_MED_NAME,'Kazano','i') or regexp_like(a.RAW_RX_MED_NAME,'Invokamet','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Xigduo XR','i') or regexp_like(a.RAW_RX_MED_NAME,'Synjardy','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Metaglip','i') or regexp_like(a.RAW_RX_MED_NAME,'Glucovance','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Jentadueto','i') or regexp_like(a.RAW_RX_MED_NAME,'Jentadueto XR','i') or
  /*  this one is combination of metformin-vildagliptin:  */
  regexp_like(a.RAW_RX_MED_NAME,'Eucreas','i')
  )
  ) or
  /*  this one is combination of metformin-pioglitazone :  */
  regexp_like(a.RAW_RX_MED_NAME,'Actoplus','i') or regexp_like(a.RAW_RX_MED_NAME,'Actoplus Met','i') or regexp_like(a.RAW_RX_MED_NAME,'Actoplus Met XR','i') or regexp_like(a.RAW_RX_MED_NAME,'Competact','i') or
  /*  this one is combination of metformin-repaglinide:  */
  regexp_like(a.RAW_RX_MED_NAME,'PrandiMet','i') or
  /*  this is combination of metformin-saxagliptin :  */
  regexp_like(a.RAW_RX_MED_NAME,'Kombiglyze XR','i') or
  /*  this is combination of:  */
  regexp_like(a.RAW_RX_MED_NAME,'Janumet','i') or regexp_like(a.RAW_RX_MED_NAME,' Janumet XR','i') 
  )
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/*   collect meds based on matching RXNORM codes:   */
insert into BiguanideByRXNORM_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where a.RXNORM_CUI in (6809,105376,105377,151827,152161,204045,204047,235743,236325,236510,246522,250919,285065,285129,316255,316256,330861,332809,352381,352450,361841,368254,368526,371466,372803,372804,374635,378729,378730,405304,406082,406257,428759,429841,431724,432366,432780,438507,465455,485822,541766,541768,541774,541775,577093,583192,583194,583195,600868,601021,602411,605605,607999,614348,633695,645109,647241,668418,700516,729717,729919,729920,731442,757603,790326,802051,802646,802742,805670,806287,860974,860975,860976,860977,860978,860979,860980,860981,860982,860983,860984,860985,860995,860996,860997,860998,860999,861000,861001,861002,861003,861004,861005,861006,861007,861008,861009,861010,861011,861012,861014,861015,861016,861017,861018,861019,861020,861021,861022,861023,861024,861025,861026,861027,861730,861731,861736,861740,861743,861748,861753,861760,861761,861762,861763,861764,861765,861769,861770,861771,861783,861784,861785,861787,861788,861789,861790,861791,861792,861795,861796,861797,861806,861807,861808,861816,861817,861818,861819,861820,861821,861822,861823,861824,875864,875865,876009,876010,876033,899988,899989,899991,899992,899993,899994,899995,899996,899998,900000,900001,900002,977566,997965,1007411,1008476,1043561,1043562,1043563,1043565,1043566,1043567,1043568,1043569,1043570,1043572,1043574,1043575,1043576,1043578,1043580,1043582,1043583,1043584,1048346,1083665,1128666,1130631,1130713,1131491,1132606,1143649,1145961,1155467,1155468,1156197,1161597,1161598,1161599,1161600,1161601,1161602,1161603,1161604,1161605,1161606,1161607,1161608,1161609,1161610,1161611,1165205,1165206,1165845,1167810,1167811,1169920,1169923,1171244,1171245,1171254,1171255,1172629,1172630,1175016,1175021,1182890,1182891,1184627,1184628,1185325,1185326,1185653,1185654,1243016,1243017,1243018,1243019,1243020,1243027,1243034,1243826,1243827,1243829,1243833,1243834,1243835,1243839,1243842,1243843,1243844,1243845,1243846,1243848,1243849,1243850,1305366,1308857,1313354,1365405,1365406,1365802,1368381,1368382,1368383,1368384,1368385,1368392,1372716,1372738,1431024,1431025,1486436,1493571,1493572,1540290,1540292,1545146,1545147,1545148,1545149,1545150,1545157,1545161,1545164,1548426,1549776,1592709,1592710,1592722,1593057,1593058,1593059,1593068,1593069,1593070,1593071,1593072,1593073,1593774,1593775,1593776,1593826,1593827,1593828,1593829,1593830,1593831,1593832,1593833,1593835,1598393,1598394,1655477,1664311,1664312,1664313,1664314,1664315,1664323,1664326,1665367,1692194,1741248,1741249,1791055,1796088,1796089,1796092,1796094,1796097)
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/*  Thiazolidinedione:
  collect meds based on matching names:  */
insert into ThiazolByNames_init
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where (
  regexp_like(a.RAW_RX_MED_NAME,'Avandia','i') or regexp_like(a.RAW_RX_MED_NAME,'Actos','i') or
  (regexp_like(a.RAW_RX_MED_NAME,'rosiglitazone','i') and not
  (
  /*  this ione is combination of metformin-rosiglitazone:  */
  regexp_like(a.RAW_RX_MED_NAME,'Avandamet','i') or
  /*  this is combination of rosiglitizone-metformin:  */
  regexp_like(a.RAW_RX_MED_NAME,'Amaryl M','i') or
  /*  this is combination of glimeperide-rosiglitazone :  */
  regexp_like(a.RAW_RX_MED_NAME,'Avandaryl','i')
  )) or
  (regexp_like(a.RAW_RX_MED_NAME,'pioglitazone','i') and not
  (
  /*  this ione is combination of metformin-pioglitazone :  */
  regexp_like(a.RAW_RX_MED_NAME,'Actoplus','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Actoplus Met','i') or regexp_like(a.RAW_RX_MED_NAME,'Actoplus Met XR','i') or regexp_like(a.RAW_RX_MED_NAME,'Competact','i') or
  /*  this is combination of glimepiride-pioglitazone:  */
  regexp_like(a.RAW_RX_MED_NAME,'Duetact','i') or
  /* this is combination of alogliptin-pioglitazone:  */
  regexp_like(a.RAW_RX_MED_NAME,'Oseni','i')
  )) or
  regexp_like(a.RAW_RX_MED_NAME,'Troglitazone','i') or regexp_like(a.RAW_RX_MED_NAME,'Noscal','i') or regexp_like(a.RAW_RX_MED_NAME,'Re[z|s]ulin','i') or regexp_like(a.RAW_RX_MED_NAME,'Romozin','i') 
  )
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/* collect meds based on matching RXNORM codes:  */
insert into ThiazolByRXNORM_init
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where a.RXNORM_CUI in (202,572,1480,2242,2465,4583,4586,4615,4622,4623,4624,4625,4626,4627,4628,4630,4631,4632,4633,4634,4635,4636,4951,5316,6053,6211,6214,6216,6885,7208,7475,8925,10481,11019,11022,11024,17547,19217,20185,21336,25511,25512,25515,25517,25520,25527,25617,25851,26061,26402,28170,30957,30958,33738,39108,39125,39131,39141,39146,39147,39149,39150,39152,39847,40224,40738,41397,46981,47026,47724,48253,50216,50278,53324,59156,59191,59208,59284,59419,59427,59513,61539,67375,68213,71877,71921,72227,72610,72622,75157,75158,82578,84108,88577,97483,97568,97609,97833,97841,97848,97852,97867,97875,97877,97881,97892,97893,97894,97919,97977,97986,98066,98075,98076,114175,117305,124953,153014,153015,153722,153723,153724,153725,160190,170941,182835,199984,199985,200065,203027,203715,204377,212281,212282,213041,217954,224003,235298,235305,237601,237602,237603,237622,237623,237624,238255,240757,242206,242614,242615,246859,248528,253198,259319,259351,259382,259383,259635,260018,260111,261241,261242,261243,261266,261267,261268,261442,261455,283847,283848,283849,284132,308043,308706,311248,311259,311260,311261,312440,312441,312859,312860,312861,314063,316124,316125,316869,316870,316871,317223,317573,331478,332435,332436,336270,336271,336906,340667,353229,358499,358500,358530,358809,368230,368234,368317,373801,374252,374606,375549,375855,378729,381259,386116,391625,391627,391633,391634,391635,391636,391645,391646,391650,391654,391671,391677,391801,393133,401993,401994,420203,428722,429088,429558,429808,430181,430343,433795,435806,436189,437129,437131,437306,437391,437392,440537,441116,476352,476353,483592,483642,565366,565367,565368,572491,572492,572980,574470,574471,574472,574495,574496,574497,577093,577605,577606,578033,580285,582044,582226,601642,602012,602014,602015,602016,602017,602018,602019,602166,602543,602544,602549,602550,602593,602594,602595,605320,606253,607999,614348,615015,615016,618299,629614,629615,631212,631213,631214,631215,631216,631217,633494,647235,647236,647237,647239,687360,690417,690728,691361,691407,692793,704551,704552,706895,706896,729115,729116,730905,731455,731457,731461,731462,731463,755768,757211,792114,792115,795807,799064,833760,834152,855905,860487,860488,860489,861760,861763,861783,861795,861806,861816,861822,885217,885249,885250,885252,895940,899988,899989,899994,899996,900001,967790,968642,968643,968644,968793,968799,968800,979613,985057,990292,1007465,1007707,1008459,1009262,1010582,1010583,1010584,1010585,1010591,1011085,1011086,1011087,1014246,1021902,1022620,1023321,1025110,1041762,1041767,1041785,1049771,1087356,1120060,1121071,1121356,1121421,1121996,1123648,1130713,1131491,1135408,1135409,1141372,1143463,1144222,1144325,1144326,1146169,1147775,1149975,1150961,1153166,1153167,1153620,1153621,1153622,1153623,1153624,1157240,1157241,1157242,1157243,1157987,1157988,1161597,1161598,1161603,1161604,1162196,1162197,1162198,1162199,1163231,1163232,1163351,1163352,1163389,1163390,1169928,1169929,1175666,1175667,1181933,1181934,1233738,1234307,1237081,1239373,1246496,1291129,1291130,1291131,1291132,1291133,1294845,1297455,1301823,1302343,1302344,1302345,1302346,1302361,1302362,1302364,1305527,1305837,1307662,1308784,1310038,1313354,1362181,1362741,1368399,1368400,1368401,1368402,1368403,1368405,1368409,1368410,1368412,1368416,1368417,1368419,1368423,1368424,1368426,1368430,1368431,1368433,1368434,1368437,1368438,1368440,1368444,1374661,1374670,1384487,1424651,1424867,1425574,1425992,1426413,1431048,1436586,1439115,1440947,1441287,1485868,1490457,1492336,1493021,1493170,1493173,1494179,1494180,1494181,1494182,1494183,1494184,1494186,1494187,1494191,1495136,1547254,1548162,1552134,1593260,1593760,1593870,1600083,1601850,1605394,1605395,1608162,1649155,1649302,1661518,1663279,1663413,1670328,1670329,1670330,1670331,1670332,1720681,1720845,1722015,1724842,1733688,1738530,1743163,1743280,1746354,1746954,1805299)
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/*  Glucagon-like Peptide-1 Agonist:
-- collect meds based on matching names:   */
insert into GLP1AexByNames_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where (
  regexp_like(a.RAW_RX_MED_NAME,'Exenatide','i') or regexp_like(a.RAW_RX_MED_NAME,'Byetta','i') or regexp_like(a.RAW_RX_MED_NAME,'Bydureon','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Liraglutide','i') or regexp_like(a.RAW_RX_MED_NAME,'Victoza','i') or regexp_like(a.RAW_RX_MED_NAME,'Saxenda','i') 
  )
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/* collect meds based on matching RXNORM codes:  */
insert into GLP1AexByRXNORM_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where a.RXNORM_CUI in (60548,475968,604751,847908,847910,847911,847913,847914,847915,847916,847917,847919,897120,897122,897123,897124,897126,1163230,1163790,1169415,1186578,1242961,1242963,1242964,1242965,1242967,1242968,1244651,1359640,1359802,1359979,1360105,1360454,1360495,1544916,1544918,1544919,1544920,1593624,1596425,1598264,1598265,1598267,1598268,1598269,1598618,1653594,1653597,1653600,1653610,1653611,1653613,1653614,1653616,1653619,1653625,1654044,1654730,1727493,1804447,1804505)
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/*---------------------------------------------------------------------------------------------------------------
  Combine all meds:    */
insert into InclUnderRestrMeds_init
select y.PATID, y.MedDate 
  from 
	(select x.PATID,x.MedDate,row_number() over (partition by x.PATID order by x.MedDate asc) rn
	from
		(select a.PATID,a.MedDate 
		from #BiguanideByNames_initial as a
		union
		select b.PATID, b.MedDate
		from #ThiazolByNames_init as b
		union
		select c.PATID, c.MedDate
		from #GLP1AexByNames_initial as c
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
-----                       Encounter should meet the following requerements:                             -----
-----           Patient must be 18 years old >= age <= 89 years old during the encounter day.             -----
-----                                                                                                     -----
-----                 The date of the first encounter for each pregnancy is collected.                    -----
---------------------------------------------------------------------------------------------------------------
 Cases with miscarriage or abortion diagnosis codes:*/
insert into Miscarr_Abort
select ds.PATID, dia.ADMIT_DATE 
  from DenominatorSummary ds
  join "&&PCORNET_CDM".DIAGNOSIS as dia 
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
  join "&&PCORNET_CDM".DIAGNOSIS as dia 
  on ds.PATID=dia.PATID
	join "&&PCORNET_CDM".ENCOUNTER e
	on dia.ENCOUNTERID=e.ENCOUNTERID 
	join "&&PCORNET_CDM".DEMOGRAPHIC d
	on e.PATID=d.PATID	
	where (regexp_like(dia.DX,'6[4|5|6|7][0|1|2|3|4|5|6|7|8|9]\..' and dia.DX_TYPE = '09') 
  and cast(((cast(dia.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <= 89 
  and cast(((cast(dia.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18);
COMMIT;
/* Cases with delivery procedures in ICD-9 coding:*/
insert into DelivProc
select ds.PATID, p.ADMIT_DATE 
  from DenominatorSummary ds
  join capricorn.dbo.PROCEDURES as p 
  on ds.PATID=p.PATID
	join "&&PCORNET_CDM".ENCOUNTER e
	on p.ENCOUNTERID=e.ENCOUNTERID 
	join "&&PCORNET_CDM".DEMOGRAPHIC d
	on e.PATID=d.PATID	
		where ((regexp_like(p.PX,'7[2|3|4|5]\..' and p.PX_TYPE = '09') or (p.PX like '^1' and p.PX_TYPE = '10'))
		and cast(((cast(p.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <= 89 
    and cast(((cast(p.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)>=18;
COMMIT;
/* Cases with delivery procedures in CPT coding:		*/
insert into PregProc
select ds.PATID, p.ADMIT_DATE 
  from DenominatorSummary ds
  join capricorn.dbo.PROCEDURES as p 
  on ds.PATID=p.PATID
	join "&&PCORNET_CDM".ENCOUNTER e
	on p.ENCOUNTERID=e.ENCOUNTERID 
	join "&&PCORNET_CDM".DEMOGRAPHIC d
	on e.PATID=d.PATID	
	where (regexp_like(p.PX,'59[0|1|2|3|4|5|6|7|8|9][0|1|2|3|4|5|6|7|8|9][0|1|2|3|4|5|6|7|8|9]' and p.PX_TYPE='C3') 
	and cast(((cast(p.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <= 89 
  and cast(((cast(p.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18);
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
