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
select e.ENCOUNTERID, e.patid, e.admit_date, e.enc_type
  from "&&PCORNET_CDM".ENCOUNTER e
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED') 
  and cast(((cast(e.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <= 89 
  and cast(((cast(e.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18
;


/* 
Collect data to put summary for the study sample. 
Further data collection will be performed for this population: 
*/
drop table DenominatorSummary;
create table DenominatorSummary as

/*          Get all encounters for each patient sorted by date: */     
with Denominator_init as(
select e.PATID, e.ADMIT_DATE, row_number() over (partition by e.PATID order by e.ADMIT_DATE asc) rn 
  from encounter_of_interest e
)
/* Collect visits reported on different days: */
, Denomtemp0v as (
select distinct uf.PATID, uf.ADMIT_DATE
, row_number() over (partition by uf.PATID order by uf.ADMIT_DATE asc) rn 
  from Denominator_init uf
)
/* Collect number of visits (from ones recorded on different days) for each person: */
, Denomtemp1v as (
select x.PATID, count(distinct x.ADMIT_DATE) as NumberOfVisits 
  from Denomtemp0v x
  group by x.PATID
  order by x.PATID
)
/* Collect date of the first visit: */
, Denomtemp2v as (
select x.PATID, x.ADMIT_DATE as FirstVisit 
  from Denomtemp0v x
  where x.rn=1
)

select x.PATID, b.FirstVisit, x.NumberOfVisits
  from Denomtemp1v x
  left join Denomtemp2v b
  on x.PATID=b.PATID;

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
 
insert into FG_initial
select ds.PATID, l.LAB_ORDER_DATE, row_number() over (partition by l.PATID order by l.LAB_ORDER_DATE asc) rn  
  from DenominatorSummary ds
  join "&&PCORNET_CDM".LAB_RESULT_CM l 
  on ds.PATID=l.PATID
  join encounter_of_interest e
  on l.ENCOUNTERID=e.ENCOUNTERID 
  where (l.LAB_LOINC in ('1558-6', '1493-6', '10450-5', '1554-5', '17865-7', '14771-0', '77145-1', '1500-8', '1523-0', '1550-3','14769-4','14770-2','14771-0','1556-0','1557-8','21004-7','35184-1','40193-5','41604-0','53049-3','62851-1','62852-9','76629-5','77145-1') 
	or 
	 (l.RAW_LAB_NAME in ('Fasting glucose  ','Glucose ','GLUCOSE FASTING ','Glucose p 10h fast SerPl-mCnc ','Glucose p 12h fast SerPl-mCnc ','Glucose p 8h fast SerPl-mCnc ','Glucose p fast BldC Glucomtr-mCnc ','Glucose p fast BldC Glucomtr-sCnc ','Glucose p fast BldC-mCnc ','Glucose p fast BldV-mCnc ','Glucose p fast SerPl-mCnc ','Glucose p fast SerPl-msCnc ','Glucose p fast SerPl-sCnc ','Glucose pre-meal SerPl-mCnc ','Glucose pre-meal SerPl-sCnc ','Glucose tolerance ','Glucose Tolerance Test ','PhenX - fasting plasma glucose for diabetes screening - blood draw protocol','PhenX - fasting plasma glucose for diabetes screening - glucometer protocol'
))
	and l.RESULT_NUM >= 126 and l.RESULT_UNIT='mg/dL')
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
select ds.PATID, l.LAB_ORDER_DATE, row_number() over (partition by l.PATID order by l.LAB_ORDER_DATE asc) rn  
  from DenominatorSummary ds
  join "&&PCORNET_CDM".LAB_RESULT_CM l 
  on ds.PATID=l.PATID
  join encounter_of_interest e
  on l.ENCOUNTERID=e.ENCOUNTERID 
  where (l.LAB_LOINC in ('2345-7','14749-6','10449-7','12614-4','14743-9','14760-3','14761-1','14768-6','14769-4','15074-8','1521-4','1547-9','16165-3','16166-1','16167-9','16168-7','16169-5','16170-3','16915-1','21004-7','2339-0','2340-8','2341-6','27353-2','34546-2','35211-2','39480-9','39481-7','40858-3','41651-1','41652-9','41653-7','41896-2','41897-0','41898-8','41899-6','41900-2','43151-0','44919-9','45052-8','45053-6','45054-4','45055-1','45056-9','47995-6','48986-4','48988-0','48989-8','48990-6','48991-4','48992-2','48993-0','48994-8','51596-5','52041-1','53094-9','53474-3','53553-4','54246-4','5914-7','59812-8','59813-6','59814-4','59815-1','62856-0','6689-4','6777-7','72171-2','72516-8','74244-5','74774-1','75864-9','77135-2','77677-3','80959-0','LP43629-2','LP51365-2','LP51830-5','LP71758-4'
)
	and (l.RAW_LAB_NAME in ('Blood glucose monitors','Est. average glucose Bld gHb Est-mCnc ','Est. average glucose Bld gHb Est-sCnc ','EST AVG GLUCOSE ','Estimated average glucose ','Glucose','Glucose 10 AM SerPl-mCnc ','Glucose 10 PM SerPl-mCnc ','Glucose 11 AM SerPl-mCnc ','Glucose 11 AM SerPl-sCnc ','GLUCOSE @11AM, SERUM ','Glucose 12 AM SerPl-mCnc ','Glucose 12 AM SerPl-sCnc ','Glucose 12 PM SerPl-mCnc ','Glucose 12 PM SerPl-sCnc ','Glucose 1.5h p meal SerPl-sCnc ','Glucose 1h p meal SerPl-mCnc ','Glucose 2h p meal BldC-sCnc ','Glucose 2h p meal Bld-mCnc ','Glucose 2h p meal SerPl-mCnc ','Glucose 2h p meal SerPl-sCnc ','GLUCOSE, 2 HR POST PRANDIAL ','Glucose 2 PM SerPl-mCnc ','Glucose 3 AM SerPl-mCnc ','Glucose 3 PM SerPl-mCnc ','Glucose 3 PM SerPl-sCnc ','Glucose 4 AM specimen SerPl-sCnc','Glucose 4 PM SerPl-mCnc ','Glucose 4 PM SerPl-sCnc ','GLUCOSE @4PM, SERUM ','Glucose 5 PM SerPl-mCnc ','Glucose 6 AM SerPl-mCnc ','Glucose 6 PM SerPl-mCnc ','Glucose 7 AM BldC Glucomtr-sCnc ','Glucose 7 AM SerPl-sCnc ','Glucose 7h p meal SerPl-mCnc ','Glucose 8 AM SerPl-mCnc ','Glucose 8 AM SerPl-sCnc ','Glucose 8 PM SerPl-mCnc ','Glucose 8 PM SerPl-sCnc ','GLUCOSE, ACCU-CHEK, mg/dl ','Glucose BldA-mCnc ','Glucose BldA-sCnc ','Glucose BldC Glucomtr-mCnc ','Glucose BldC Glucomtr-sCnc ','Glucose BldCo-sCnc ','Glucose BldC-sCnc ','Glucose Bld Manual Strip-mCnc ','Glucose Bld-mCnc ','Glucose Bld Ql Strip ','Glucose Bld-sCnc ','Glucose Bld Strip.auto-mCnc ','Glucose Bld Strip.auto-sCnc ','Glucose Bld Test Str Auto-mCnc ','Glucose BldV-mCnc ','Glucose BldV-sCnc ','Glucose BS BldC-mCnc ','Glucose BS SerPl-mCnc ','Glucose BS SerPl-sCnc ','Glucose mean value ','Glucose meter device panel','Glucose meter device Vendor name','Glucose meter device Vendor serial number','Glucose meter device Vendor software version','GLUCOSE, PLASMA ','Glucose p meal SerPl-mCnc ','Glucose p meal SerPl-sCnc ','Glucose pre 12h fast SerPl-sCnc ','Glucose SerPlBld-mCnc ','Glucose SerPl-mCnc ','Glucose SerPl-msCnc ','Glucose SerPl-sCnc ','Glucose tolerance','Glucose tolerance 2 hours panel - Serum or Plasma','HEDIS 2014 Value Set - Glucose Tests ','HEDIS 2015, 2016 Value Set - Glucose Tests ','Model Cd Glucose Mtr Dev ','PhenX - oral glucose tolerance test protocol ','Protein and Glucose panel  ','Type of Glucose meter device','Vendor device model code of Glucose meter','WHOLE BLOOD GLUCOSE '
))
	and l.RESULT_NUM >= 200 and l.RESULT_UNIT='mg/dL')
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
  join "&&PCORNET_CDM".ENCOUNTER e
  on l.ENCOUNTERID=e.ENCOUNTERID 
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where ((REGEXP_LIKE (l.DX, '250\..[0|1|2|3]') and l.DX_TYPE = '09') or (REGEXP_LIKE (l.DX, 'E1[0|1]') and l.DX_TYPE = '10'))
	and (l.ENC_TYPE in ('IP', 'EI', 'AV', 'ED'))
	and cast(((cast(l.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)<=89 
  and cast(((cast(l.ADMIT_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)>=18;
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
---------------------------------------------------------------------------------------------------------------
                               Sulfonylurea:
                   collect meds based on matching names:                       */
insert into SulfonylureaByNames_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where (
  regexp_like(a.RAW_RX_MED_NAME, 'Acetohexamide','i') or regexp_like(a.RAW_RX_MED_NAME, 'D[i|y]melor','i') or regexpr_like(a.RAW_RX_MED_NAME, 'glimep[e,i]ride','i') or
  /*  This is combination of glimeperide-rosiglitazone :  */
  regexp_like(a.RAW_RX_MED_NAME,'Avandaryl','i') or regexp_like(a.RAW_RX_MED_NAME,'Amaryl','i') or
  /*  this is combination of glimepiride-pioglitazone:  */
  regexp_like(a.RAW_RX_MED_NAME,'Duetact','i') or
 regexp_like(a.RAW_RX_MED_NAME,'gliclazide','i') or regexp_like(a.RAW_RX_MED_NAME,'Uni Diamicron','i') or regexp_like(a.RAW_RX_MED_NAME,'glipizide','i') or
  /*  this is combination of metformin-glipizide :  */
 regexp_like(a.RAW_RX_MED_NAME,'Metaglip','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Glucotrol','i') or regexp_like(a.RAW_RX_MED_NAME,'Min[i|o]diab','i') or regexp_like(a.RAW_RX_MED_NAME,'Glibenese','i') or regexp_likeUPPER(a.RAW_RX_MED_NAME,'Glucotrol XL','i') or regexp_like(a.RAW_RX_MED_NAME,'Glipizide XL','i') or
  regexp_like(a.RAW_RX_MED_NAME,'glyburide','i') or regexp_like(a.RAW_RX_MED_NAME,'Glucovance','i') or
regexp_like(a.RAW_RX_MED_NAME,'glibenclamide','i') or regexp_like(a.RAW_RX_MED_NAME,'DiaBeta','i') or regexp_like(a.RAW_RX_MED_NAME,'Glynase','i') or
regexp_like(a.RAW_RX_MED_NAME,'Micronase','i') or regexp_like(a.RAW_RX_MED_NAME,'chlorpropamide','i') or regexp_like(a.RAW_RX_MED_NAME,'Diabinese','i') or regexp_like(a.RAW_RX_MED_NAME,'Apo-Chlorpropamide','i') or
regexp_like(a.RAW_RX_MED_NAME,'Glucamide','i') or regexp_like(a.RAW_RX_MED_NAME,'Novo-Propamide','i') or regexp_like(a.RAW_RX_MED_NAME,'Insulase','i') or
regexp_like(a.RAW_RX_MED_NAME,'tolazamide','i') or regexp_like(a.RAW_RX_MED_NAME,'Tolinase','i') or regexp_like(a.RAW_RX_MED_NAME,'Glynase PresTab','i') or
regexp_like(a.RAW_RX_MED_NAME,'Tolamide','i') or regexp_like(a.RAW_RX_MED_NAME,'tolbutamide','i') or regexp_like(a.RAW_RX_MED_NAME,'Orinase','i') or
regexp_like(a.RAW_RX_MED_NAME,'Tol-Tab','i') or regexp_like(a.RAW_RX_MED_NAME,'Apo-Tolbutamide','i') or regexp_like(a.RAW_RX_MED_NAME,('Novo-Butamide','i') or regexp_like(a.RAW_RX_MED_NAME,'Glyclopyramide','i') or
regexp_like(a.RAW_RX_MED_NAME,'Deamelin[-]S','i') or regexp_like(a.RAW_RX_MED_NAME,'Gliquidone','i') or regexp_like(a.RAW_RX_MED_NAME,'Glurenorm','i') 
  )
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)<=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)>=18;
  /*            collect meds based on matching RXNORM codes:  */
COMMIT;
insert into SulfonylureaByRXNORM_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where a.RXNORM_CUI in (3842,153843,153844,153845,197306,197307,197495,197496,197737,198291,198292,198293,198294,199245,199246,199247,199825,201056,201057,201058,201059,201060,201061,201062,201063,201064,201919,201921,201922,203289,203295,203679,203680,203681,205828,205830,205872,205873,205875,205876,205879,205880,207953,207954,207955,208012,209204,214106,214107,217360,217364,217370,218942,220338,221173,224962,227211,241604,241605,245266,246391,246522,246523,246524,250919,252259,252960,260286,260287,261351,261974,284743,285129,310488,310489,310490,310534,310536,310537,310539,313418,313419,314000,314006,315107,315239,315273,315274,315647,315648,315978,315979,315980,315987,315988,315989,315990,315991,315992,316832,316833,316834,316835,316836,317379,317637,328851,330349,331496,332029,332808,332810,333394,336701,351452,352381,352764,353028,362611,367762,368204,368586,368696,368714,369297,369304,369373,369500,369557,369562,370529,371465,371466,371467,372318,372319,372320,372333,372334,374149,374152,374635,375952,376236,376868,378730,379559,379565,379568,379570,379572,379802,379803,379804,380849,389137,391828,393405,393406,405121,429841,430102,430103,430104,430105,432366,432780,432853,433856,438506,440285,440286,440287,465455,469978,542029,542030,542031,542032,563154,564035,564036,564037,564038,565327,565408,565409,565410,565667,565668,565669,565670,565671,565672,565673,565674,565675,566055,566056,566057,566718,566720,566761,566762,566764,566765,566768,566769,568684,568685,568686,568742,569831,573945,573946,574089,574090,574571,574612,575377,600423,600447,602543,602544,602549,602550,606253,607784,607816,647208,647235,647236,647237,647239,669981,669982,669983,669984,669985,669986,669987,687730,700835,706895,706896,731455,731457,731461,731462,731463,827400,844809,844824,844827,847706,847707,847708,847710,847712,847714,847716,847718,847720,847722,847724,849585,861731,861732,861733,861736,861737,861738,861740,861741,861742,861743,861745,861747,861748,861750,861752,861753,861755,861756,861757,865567,865568,865569,865570,865571,865572,865573,865574,881404,881405,881406,881407,881408,881409,881410,881411,1007411,1007582,1008873,1120401,1125922,1128359,1130921,1132391,1132805,1135219,1135428,1147918,1153126,1153127,1155467,1155468,1155469,1155470,1155471,1155472,1156197,1156198,1156199,1156200,1156201,1157121,1157122,1157240,1157241,1157242,1157243,1157244,1157245,1157246,1157247,1157642,1157643,1157644,1165203,1165204,1165205,1165206,1165207,1165208,1165845,1169680,1169681,1170663,1170664,1171233,1171234,1171246,1171247,1171248,1171249,1171933,1171934,1173427,1173428,1175658,1175659,1175878,1175879,1175880,1175881,1176496,1176497,1177973,1177974,1178082,1178083,1179112,1179113,1183952,1183954,1183958,1185049,1185624,1309022,1361492,1361493,1361494,1361495,1384487,1428269,1741234)
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)<=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)>=18;
COMMIT;
/*                             Alpha-glucosidase inhibitor:
                           collect meds based on matching names:     */
insert into AlGluInhByNames_init
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where (
  regexp_like(a.RAW_RX_MED_NAME,'acarbose','i') or regexp_like(a.RAW_RX_MED_NAME,'Precose','i') or regexp_like(a.RAW_RX_MED_NAME,'Glucobay','i') or regexp_like(a.RAW_RX_MED_NAME,'miglitol','i') or regexp_like(a.RAW_RX_MED_NAME,'Glyset','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Voglibose','i') or regexp_like(a.RAW_RX_MED_NAME,'Basen','i') 
    )
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)<=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)>=18;
COMMIT;
/*  collect meds based on matching RXNORM codes:  */
insert into AlGluInhByByRXNORM_init
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where a.RXNORM_CUI in (16681,30009,137665,151826,199149,199150,200132,205329,205330,205331,209247,209248,213170,213485,213486,213487,217372,315246,315247,315248,316304,316305,316306,368246,368300,370504,372926,569871,569872,573095,573373,573374,573375,1153649,1153650,1157268,1157269,1171936,1171937,1185237,1185238,1598393,1741321)
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)<=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)>=18;
COMMIT;
/*  Glucagon-like Peptide-1 Agonists:
   collect meds based on matching names:  */
insert into GLP1AByNames_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where (
  regexp_like(a.RAW_RX_MED_NAME,'Lixisenatide','i') or regexp_like(a.RAW_RX_MED_NAME,'Adlyxin','i') or regexp_like(a.RAW_RX_MED_NAME,'Lyxumia','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Albiglutide','i') or regexp_like(a.RAW_RX_MED_NAME,'Tanzeum','i') or regexp_like(a.RAW_RX_MED_NAME,'Eperzan','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Dulaglutide','i') or regexp_like(a.RAW_RX_MED_NAME,'Trulicity','i') 
  )
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/*   collect meds based on matching RXNORM codes:  */
insert into GLP1AByRXNORM_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where a.RXNORM_CUI in (1440051,1440052,1440053,1440056,1534763,1534797,1534798,1534800,1534801,1534802,1534804,1534805,1534806,1534807,1534819,1534820,1534821,1534822,1534823,1534824,1551291,1551292,1551293,1551295,1551296,1551297,1551299,1551300,1551301,1551302,1551303,1551304,1551305,1551306,1551307,1551308,1593645,1649584,1649586,1659115,1659117,1803885,1803886,1803887,1803888,1803889,1803890,1803891,1803892,1803893,1803894,1803895,1803896,1803897,1803898,1803902,1803903)
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)<=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)>=18;
COMMIT;
/*  Dipeptidyl peptidase IV inhibitor:
   collect meds based on matching names:  */
insert into DPIVInhByNames_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where (
  regexp_like(a.RAW_RX_MED_NAME,'alogliptin','i') or regexp_like(a.RAW_RX_MED_NAME,'Kazano','i') or regexp_like(a.RAW_RX_MED_NAME,'Oseni','i')
  or regexp_like(a.RAW_RX_MED_NAME,'Nesina','i') or regexp_like(a.RAW_RX_MED_NAME,'Anagliptin','i') or regexp_like(a.RAW_RX_MED_NAME,'Suiny','i') or
  regexp_like(a.RAW_RX_MED_NAME,'linagliptin','i') or regexp_like(a.RAW_RX_MED_NAME,'Jentadueto','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Jentadueto XR','i') or regexp_like(a.RAW_RX_MED_NAME,'Glyxambi','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Tradjenta','i') or regexp_like(a.RAW_RX_MED_NAME,'saxagliptin','i') or
  /*  this is combination of metformin-saxagliptin :   */
  regexp_like(a.RAW_RX_MED_NAME,'Kombiglyze XR','i')
  or regexp_like(a.RAW_RX_MED_NAME,'Onglyza','i') or regexp_like(a.RAW_RX_MED_NAME, 'sitagliptin','i') or
  /*  this is combination of metformin-vildagliptin :   */
  regexp_like(a.RAW_RX_MED_NAME,'Eucreas','i') or
  /*  this is combination of sitagliptin-simvastatin:   */
  regexp_like(a.RAW_RX_MED_NAME,'Juvisync','i') or regexp_like(a.RAW_RX_MED_NAME,'Epistatin','i') or regexp_like(a.RAW_RX_MED_NAME,'Synvinolin','i') or regexp_like(a.RAW_RX_MED_NAME,'Zocor','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Janumet','i') or regexp_like(a.RAW_RX_MED_NAME,'Janumet XR','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Januvia','i') or regexp_like(a.RAW_RX_MED_NAME,'Teneligliptin','i') or regexp_like(a.RAW_RX_MED_NAME,'Tenelia','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Vildagliptin','i') or regexp_like(a.RAW_RX_MED_NAME,'Galvus','i') or regexp_like(a.RAW_RX_MED_NAME,'Zomelis','i')
  )
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)<=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)>=18;
COMMIT;
/* collect meds based on matching RXNORM codes:  */
insert into DPIVInhByRXNORM_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where a.RXNORM_CUI in (36567,104490,104491,152923,196503,208220,213319,368276,563653,563654,565109,568935,573220,593411,596554,621590,638596,665031,665032,665033,665034,665035,665036,665037,665038,665039,665040,665041,665042,665043,665044,669475,700516,729717,757603,757708,757709,757710,757711,757712,857974,858034,858035,858036,858037,858038,858039,858040,858041,858042,858043,858044,861769,861770,861771,861819,861820,861821,1043560,1043561,1043562,1043563,1043565,1043566,1043567,1043568,1043569,1043570,1043572,1043574,1043575,1043576,1043578,1043580,1043582,1043583,1043584,1048346,1100699,1100700,1100701,1100702,1100703,1100704,1100705,1100706,1128666,1130631,1132606,1145961,1158518,1158519,1159662,1159663,1161605,1161606,1161607,1161608,1164580,1164581,1164670,1164671,1167810,1167811,1167814,1167815,1179163,1179164,1181729,1181730,1187973,1187974,1189800,1189801,1189802,1189803,1189804,1189806,1189808,1189810,1189811,1189812,1189813,1189814,1189818,1189821,1189823,1189827,1243015,1243016,1243017,1243018,1243019,1243020,1243022,1243026,1243027,1243029,1243033,1243034,1243036,1243037,1243038,1243039,1243040,1243826,1243827,1243829,1243833,1243834,1243835,1243839,1243842,1243843,1243844,1243845,1243846,1243848,1243849,1243850,1312409,1312411,1312415,1312416,1312418,1312422,1312423,1312425,1312429,1365802,1368000,1368001,1368002,1368003,1368004,1368005,1368006,1368007,1368008,1368009,1368010,1368011,1368012,1368017,1368018,1368019,1368020,1368033,1368034,1368035,1368036,1368381,1368382,1368383,1368384,1368385,1368387,1368391,1368392,1368394,1368395,1368396,1368397,1368398,1368399,1368400,1368401,1368402,1368403,1368405,1368409,1368410,1368412,1368416,1368417,1368419,1368423,1368424,1368426,1368430,1368431,1368433,1368434,1368435,1368436,1368437,1368438,1368440,1368444,1372692,1372706,1372717,1372738,1372754,1431025,1431048,1546030,1598392,1602106,1602107,1602108,1602109,1602110,1602111,1602112,1602113,1602114,1602115,1602118,1602119,1602120,1692194,1727500,1741248,1741249,1791055,1796088,1796089,1796090,1796091,1796092,1796093,1796094,1796095,1796096,1796097,1796098,1803420)
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)<=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)>=18;
COMMIT;
/* Meglitinide:
 collect meds based on matching names:  */
insert into MeglitinideByNames_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where (
  regexp_like(a.RAW_RX_MED_NAME,'nateglinide','i') or regexp_like(a.RAW_RX_MED_NAME,'Starlix','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Prandin','i') or regexp_like(a.RAW_RX_MED_NAME,'NovoNorm','i') 
  )
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/*   collect meds based on matching RXNORM codes:  */
insert into MeglitinideByRXNORM_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where a.RXNORM_CUI in (213218,213219,213220,219335,226911,226912,226913,226914,274332,284529,284530,311919,314142,330385,330386,368289,374648,389139,393408,402943,402944,402959,430491,430492,446631,446632,573136,573137,573138,574042,574043,574044,574957,574958,1158396,1158397,1178121,1178122,1178433,1178434,1184631,1184632)
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer)>=18;
COMMIT;
/*  Amylinomimetics:
 collect meds based on matching names:  */
insert into AmylByNames_init
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where (
  regexp_like(a.RAW_RX_MED_NAME,'Pramlintide','i') or regexp_like(a.RAW_RX_MED_NAME,'Symlin','i') or regexp_like(a.RAW_RX_MED_NAME,'SymlinPen 120','i') or regexp_like(a.RAW_RX_MED_NAME,'SymlinPen 60','i') 
  )
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/* collect meds based on matching RXNORM codes:  */
insert into AmylinomimeticsByRXNORM_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where a.RXNORM_CUI in (139953,356773,356774,486505,582702,607296,753370,753371,759000,861034,861036,861038,861039,861040,861041,861042,861043,861044,861045,1161690,1185508,1360096,1360184,1657563,1657565,1657792)
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/*  Insulin:
 collect meds based on matching names:  */
insert into InsulinByNames_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where (
  regexp_like(a.RAW_RX_MED_NAME,'Insulin aspart','i') or regexp_like(a.RAW_RX_MED_NAME,'NovoLog','i') or regexp_like(a.RAW_RX_MED_NAME,'Insulin glulisine','i') or regexp_like(a.RAW_RX_MED_NAME,'Apidra','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Insulin lispro','i') or regexp_like(a.RAW_RX_MED_NAME,'Humalog','i') or regexp_like(a.RAW_RX_MED_NAME,'Insulin inhaled','i') or regexp_like(a.RAW_RX_MED_NAME,'Afrezza','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Regular insulin','i') or regexp_like(a.RAW_RX_MED_NAME,'Humulin R','i') or regexp_like(a.RAW_RX_MED_NAME,'Novolin R','i') or regexp_like(a.RAW_RX_MED_NAME,'Insulin NPH','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Humulin N','i') or regexp_like(a.RAW_RX_MED_NAME,'Novolin N','i') or regexp_like(a.RAW_RX_MED_NAME,'Insulin detemir','i') or regexp_like(a.RAW_RX_MED_NAME,'Levemir','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Insulin glargine','i') or regexp_like(a.RAW_RX_MED_NAME,'Lantus','i') or regexp_like(a.RAW_RX_MED_NAME,'Lantus SoloStar','i') or regexp_like(a.RAW_RX_MED_NAME,'Toujeo','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Basaglar','i') or regexp_like(a.RAW_RX_MED_NAME,'Insulin degludec','i') or regexp_like(a.RAW_RX_MED_NAME,'Tresiba','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Insulin aspart protamine','i') or regexp_like(a.RAW_RX_MED_NAME,'Insulin aspart','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Actrapid','i') or regexp_like(a.RAW_RX_MED_NAME,'Hypurin','i') or regexp_like(a.RAW_RX_MED_NAME,'Iletin','i') or regexp_like(a.RAW_RX_MED_NAME,'Insulatard','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Insuman','i') or regexp_like(a.RAW_RX_MED_NAME,'Mixtard','i') or regexp_like(a.RAW_RX_MED_NAME,'NovoMix','i') or regexp_like(a.RAW_RX_MED_NAME,'NovoRapid','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Oralin','i') or regexp_like(a.RAW_RX_MED_NAME,'Abasaglar','i') or regexp_like(a.RAW_RX_MED_NAME,'V-go','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Ryzodeg','i') or regexp_like(a.RAW_RX_MED_NAME,'Insulin lispro protamine','i') or regexp_like(a.RAW_RX_MED_NAME,'insulin lispro','i') 
  )
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/* collect meds based on matching RXNORM codes:   */
insert into InsulinByRXNORM_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where a.RXNORM_CUI in (5856,6926,51428,86009,92880,92881,92942,93398,93558,93560,106888,106889,106891,106892,106894,106895,106896,106899,106900,106901,108407,108813,108814,108815,108816,108822,135805,139825,142138,150659,150831,150973,150974,150978,152598,152599,152602,152640,152644,152647,153383,153384,153386,153389,154992,203209,213442,217704,217705,217706,217707,217708,225569,226290,226291,226292,226293,226294,242120,245264,245265,247511,247512,247513,249026,249220,253181,253182,259111,260265,261111,261112,261420,261542,261551,274783,284810,285018,307383,311021,311026,311027,311028,311030,311033,311034,311035,311036,311040,311041,311048,311049,311051,311052,311059,314684,340325,340326,340327,343076,343083,343226,343258,343263,343663,349670,351297,351857,351858,351859,351860,351861,351862,351926,352385,352386,359125,359126,359127,360894,362585,362622,362777,363120,363150,363221,363534,365573,365583,365668,365670,365672,365674,365677,365679,365680,366206,372909,372910,375170,376915,378841,378857,378864,378966,379734,379740,379744,379745,379746,379747,379750,379756,379757,384982,385896,386083,386084,386086,386087,386088,386089,386091,386092,386098,388513,392660,400008,400560,405228,412453,412978,415088,415089,415090,415184,415185,440399,440650,440653,440654,451437,451439,466467,466468,467015,484320,484321,484322,485210,564390,564391,564392,564395,564396,564397,564399,564400,564401,564531,564601,564602,564603,564605,564766,564820,564881,564882,564885,564994,564995,564998,565176,565253,565254,565255,565256,573330,573331,574358,574359,575068,575137,575141,575142,575143,575146,575147,575148,575151,575626,575627,575628,575629,575679,607583,615900,615908,615909,615910,615992,616236,616237,616238,633703,636227,658226,668934,723550,724231,724343,727907,728543,731277,731280,731281,752386,752388,761522,796006,796386,801808,803192,803193,803194,816726,834989,834990,834992,835225,835226,835227,835228,835868,847186,847187,847188,847189,847191,847194,847198,847199,847200,847201,847202,847203,847204,847205,847211,847213,847230,847232,847239,847241,847252,847254,847256,847257,847259,847261,847278,847279,847343,847417,849095,865097,865098,977838,977840,977841,977842,1008501,1045051,1069670,1087799,1087800,1087801,1087802,1132383,1136628,1136712,1140739,1140763,1157459,1157460,1157461,1160696,1164093,1164094,1164095,1164824,1167138,1167139,1167140,1167141,1167142,1167934,1168563,1171289,1171291,1171292,1171293,1171295,1171296,1172691,1172692,1175624,1176722,1176723,1176724,1176725,1176726,1176727,1176728,1177009,1178119,1178120,1178127,1178128,1183426,1183427,1184075,1184076,1184077,1246223,1246224,1246225,1246697,1246698,1246699,1260529,1295992,1296093,1309028,1359484,1359581,1359684,1359700,1359712,1359719,1359720,1359855,1359856,1359934,1359936,1360036,1360058,1360172,1360226,1360281,1360383,1360435,1360482,1362705,1362706,1362707,1362708,1362711,1362712,1362713,1362714,1362719,1362720,1362721,1362722,1362723,1362724,1362725,1362726,1362727,1362728,1362729,1362730,1362731,1362732,1372685,1372741,1374700,1374701,1377831,1435649,1456746,1535271,1538910,1543200,1543201,1543202,1543203,1543205,1543206,1543207,1544488,1544490,1544568,1544569,1544570,1544571,1593805,1598498,1598618,1604538,1604539,1604540,1604541,1604543,1604544,1604545,1604546,1604550,1605101,1607367,1607643,1607992,1607993,1650256,1650260,1650262,1650264,1651315,1651572,1651574,1652237,1652238,1652239,1652240,1652241,1652242,1652243,1652244,1652639,1652640,1652641,1652642,1652643,1652644,1652645,1652646,1652647,1652648,1652754,1653104,1653106,1653196,1653197,1653198,1653200,1653202,1653203,1653204,1653206,1653209,1653449,1653468,1653496,1653497,1653499,1653506,1653899,1654060,1654190,1654192,1654341,1654348,1654379,1654380,1654381,1654651,1654850,1654855,1654857,1654858,1654862,1654863,1654866,1654909,1654910,1654911,1654912,1655063,1656705,1656706,1660643,1663228,1663229,1664772,1665830,1668430,1668441,1668442,1668448,1670007,1670008,1670009,1670010,1670011,1670012,1670013,1670014,1670015,1670016,1670017,1670018,1670020,1670021,1670022,1670023,1670024,1670025,1670404,1670405,1716525,1717038,1717039,1719496,1720524,1721033,1721039,1727493,1731314,1731315,1731316,1731317,1731318,1731319,1736613,1736859,1736860,1736861,1736862,1736863,1736864,1743273,1792701,1798387,1798388,1804446,1804447,1804505,1804506)
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/*  Sodium glucose cotransporter (SGLT) 2 inhibitors:
   collect meds based on matching names:  */
insert into SGLT2InhByNames_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where (
  regexp_like(a.RAW_RX_MED_NAME,'dapagliflozin','i') or regexp_like(a.RAW_RX_MED_NAME,'F[a,o]rxiga','i') or regexp_like(a.RAW_RX_MED_NAME,'canagliflozin','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Invokana','i') or regexp_like(a.RAW_RX_MED_NAME,'Invokamet','i') or regexp_like(a.RAW_RX_MED_NAME,'Xigduo XR','i') or
  regexp_like(a.RAW_RX_MED_NAME,'Sulisent','i') or regexp_like(a.RAW_RX_MED_NAME,'empagliflozin','i') or regexp_like(a.RAW_RX_MED_NAME,'Jardiance','i') or regexp_like(a.RAW_RX_MED_NAME,'Synjardy','i') or
  /*  this one is combination of linagliptin-empagliflozin, see also Dipeptidyl Peptidase IV Inhibitors section  */
  regexp_like(a.RAW_RX_MED_NAME,'Glyxambi','i') 
  )
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/* collect meds based on matching RXNORM codes:  */
insert into SGLT2InhByRXNORM_initial
select ds.PATID, a.RX_ORDER_DATE as MedDate
  from DenominatorSummary ds
  join "&&PCORNET_CDM".PRESCRIBING a
  on ds.PATID=a.PATID
  join "&&PCORNET_CDM".ENCOUNTER e
  on a.ENCOUNTERID=e.ENCOUNTERID
  join "&&PCORNET_CDM".DEMOGRAPHIC d
  on e.PATID=d.PATID
  where a.RXNORM_CUI in (1373458,1373459,1373460,1373461,1373462,1373463,1373464,1373465,1373466,1373467,1373468,1373469,1373470,1373471,1373472,1373473,1422532,1486436,1486966,1486977,1486981,1488564,1488565,1488566,1488567,1488568,1488569,1488573,1488574,1493571,1493572,1534343,1534344,1534397,1540290,1540292,1545145,1545146,1545147,1545148,1545149,1545150,1545151,1545152,1545153,1545154,1545155,1545156,1545157,1545158,1545159,1545160,1545161,1545162,1545163,1545164,1545165,1545166,1545653,1545654,1545655,1545656,1545657,1545658,1545659,1545660,1545661,1545662,1545663,1545664,1545665,1545666,1545667,1545668,1546031,1592709,1592710,1592722,1593057,1593058,1593059,1593068,1593069,1593070,1593071,1593072,1593073,1593774,1593775,1593776,1593826,1593827,1593828,1593829,1593830,1593831,1593832,1593833,1593835,1598392,1598430,1602106,1602107,1602108,1602109,1602110,1602111,1602112,1602113,1602114,1602115,1602118,1602119,1602120,1655477,1664310,1664311,1664312,1664313,1664314,1664315,1664316,1664317,1664318,1664319,1664320,1664321,1664322,1664323,1664324,1664325,1664326,1664327,1664328,1665367,1665368,1665369,1683935,1727500)
  and e.ENC_TYPE in ('IP', 'EI', 'AV', 'ED')
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) <=89 
  and cast(((cast(a.RX_ORDER_DATE as date)-cast(d.BIRTH_DATE as date))/365.25 ) as integer) >=18;
COMMIT;
/*-------------------------------------------------------------------------------------------------------------
-----                   Combine all medications specific to Diabetes Mellitus                             -----
-----         The date of the first medication of any kind will be recorded for each patient              -----
-------------------------------------------------------------------------------------------------------------*/
insert into InclusionMeds_final
select y.PATID, y.MedDate as EventDate 
from 
	(select x.PATID,x.MedDate,row_number() over (partition by x.PATID order by x.MedDate asc) rn
	from
		(select a.PATID,a.MedDate 
		from SulfonylureaByNames_initial as a
		union
		select b.PATID, b.MedDate
		from AlGluInhByNames_init as b
		union
		select d.PATID, d.MedDate
		from DPIVInhByNames_initial as d
		union
		select e.PATID, e.MedDate
		from MeglitinideByNames_initial as e
		union
		select f.PATID, f.MedDate
		from AmylByNames_init as f
		union
		select g.PATID, g.MedDate
		from InsulinByNames_initial as g	
		union
		select h.PATID, h.MedDate
		from SGLT2InhByNames_initial as h
		union
		select k.PATID, k.MedDate
		from GLP1AByNames_initial as k
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
  /*  this ione is combination of metformin-rosiglitazone:  */
  (regexp_like(a.RAW_RX_MED_NAME,'Avandamet','i') or
  /*  this is combination of rosiglitizone-metformin:  */
  regexp_like(a.RAW_RX_MED_NAME,'Amaryl M','i') or
  /*  this is combination of glimeperide-rosiglitazone :  */
  regexp_like(a.RAW_RX_MED_NAME,'Avandaryl','i')
  )) or
  (regexp_like(a.RAW_RX_MED_NAME,'pioglitazone','i') and not
  /*  this ione is combination of metformin-pioglitazone :  */
  (regexp_like(a.RAW_RX_MED_NAME,'Actoplus','i') or regexp_like(a.RAW_RX_MED_NAME,'Actoplus Met','i') or regexp_like(a.RAW_RX_MED_NAME,'Actoplus Met XR','i') or regexp_like(a.RAW_RX_MED_NAME,'Competact','i') or
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
