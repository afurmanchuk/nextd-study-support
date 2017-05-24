/*
* Authored by Brennan Connolly from KUMC, with help from Dan Connolly
* Preliminary designs for tables 2 through 10 in the Next-D study
* See Definitions_Part2.pdf for design specifications
* Table 9 not started yet
*/

--alter session set current_schema = PCORNET_CDM_C2R2;
--TODO: change PCORNET_CDM_C2R2 to "&&PCORNET_CDM" wherever it occurs
--TODO: change bconnolly to "&&user" wherever it occurs

--select x from big_table sample(1) gets 1% of big_table

--Make sure patient info from Table 1 exists (currently using a small subset of 24 patients).
select * from each_med_obs emo;
--Use emo.meddate as first encounter date for now.
--I don't expect this or any data depending on this to be very accurate until Table 1 is done.
--Until then, days_from_first_enc will often return negative numbers.

---------- Table 2 - Demographic Variables ----------
--select count(*) from PCORNET_CDM_C2R2.DEMOGRAPHIC demo;
--2,260,014

--drop table Demographic_Variables;
create table Demographic_Variables as
(
select demo.patid, 
    extract(year from demo.birth_date) as birth_year, 
    extract(month from demo.birth_date) as birth_month,
    demo.sex, demo.race, demo.hispanic 
    from PCORNET_CDM_C2R2.DEMOGRAPHIC demo
    join each_med_obs emo
    on demo.patid=emo.patid
);

--select count(*) from Demographic_Variables;
--24

---------- Table 3 - Crosswalk for Patients, Encounters and Dates ----------
--select count(*) from PCORNET_CDM_C2R2.ENCOUNTER enc;
--20,355,187

--What kinds of encounters are we actually looking for?

--drop table Pat_Enc_Date;
create table Pat_Enc_Date as 
(
select enc.patid, enc.encounterid, 
    substr(enc.admit_date, 4, 6) as admit_date, 
    (enc.admit_date - emo.meddate) as days_from_first_enc, 
    enc.enc_type, enc.facilityid
    from PCORNET_CDM_C2R2.ENCOUNTER enc
    join each_med_obs emo
    on enc.patid=emo.patid
);

--select count(*) from Pat_Enc_Date;
--1,931

---------- Table 4 - Prescription Medicines ----------
--select count(*) from PCORNET_CDM_C2R2.PRESCRIBING presc;
--62,258,988

--drop table Prescription_Meds;
create table Prescription_Meds as
(
select presc.patid, presc.encounterid, presc.prescribingid, presc.rxnorm_cui,
    substr(presc.rx_order_date, 4, 6) as rx_order_date, 
    (presc.rx_order_date - emo.meddate) as days_from_first_enc,
    presc.rx_providerid, presc.rx_days_supply, 
    (case when presc.rx_refills is null then 0 else presc.rx_refills end) as rx_refills
    from PCORNET_CDM_C2R2.PRESCRIBING presc
    join each_med_obs emo
    on presc.patid=emo.patid
);
    
--select count(*) from Prescription_Meds; 
--12,035

---------- Table 5 - Vital Signs ----------
--select count(*) from PCORNET_CDM_C2R2.VITAL vital;
--23,167,183

--drop table Vital_Signs;
create table Vital_Signs as
(
select vital.patid, vital.encounterid, vital.measure_date,
    substr(measure_date, 4, 6) as measure_date_noday,
    (measure_date - emo.meddate) as days_from_first_enc,
    vital.vitalid, vital.ht, vital.wt, 
    vital.systolic, vital.diastolic, vital.smoking
    from PCORNET_CDM_C2R2.VITAL vital
    join each_med_obs emo
    on vital.patid=emo.patid
);

--select count(*) from Vital_Signs;
--4,255

/*-- Smoking codes: 
01 - current everyday smoker
02 - current some day smoker
03 - former smoker
04 - never smoker
05 - smoker
06 - unknown if ever smoked
07 - heavy tobacco smoker
08 - light tobacco smoker 
NI - no information 
UN - unknown
OT - other */

--Create a table to find smoking code counts for each patient/month combination
--drop table patient_month_records;
create table patient_month_records as
(
select * from
    (
    --Unique patient/month combinations
    with patient_month_initial as 
    (select distinct patid, measure_date_noday from Vital_Signs), 
    vs as
    (select * from Vital_Signs)
    
    --Smoking code counts
    select distinct pm.patid, pm.measure_date_noday,
        (select count(*) from vs where pm.patid = vs.patid and pm.measure_date_noday = vs.measure_date_noday and vs.smoking = '01') as month_01,
        (select count(*) from vs where pm.patid = vs.patid and pm.measure_date_noday = vs.measure_date_noday and vs.smoking = '02') as month_02,
        (select count(*) from vs where pm.patid = vs.patid and pm.measure_date_noday = vs.measure_date_noday and vs.smoking = '03') as month_03,
        (select count(*) from vs where pm.patid = vs.patid and pm.measure_date_noday = vs.measure_date_noday and vs.smoking = '04') as month_04,
        (select count(*) from vs where pm.patid = vs.patid and pm.measure_date_noday = vs.measure_date_noday and vs.smoking = '05') as month_05,
        (select count(*) from vs where pm.patid = vs.patid and pm.measure_date_noday = vs.measure_date_noday and vs.smoking = '06') as month_06,
        (select count(*) from vs where pm.patid = vs.patid and pm.measure_date_noday = vs.measure_date_noday and vs.smoking = '07') as month_07,
        (select count(*) from vs where pm.patid = vs.patid and pm.measure_date_noday = vs.measure_date_noday and vs.smoking = '08') as month_08,
        (select count(*) from vs where pm.patid = vs.patid and pm.measure_date_noday = vs.measure_date_noday and vs.smoking = 'NI') as month_NI,
        (select count(*) from vs where pm.patid = vs.patid and pm.measure_date_noday = vs.measure_date_noday and vs.smoking = 'UN') as month_UN,
        (select count(*) from vs where pm.patid = vs.patid and pm.measure_date_noday = vs.measure_date_noday and vs.smoking = 'OT') as month_OT
        from Vital_Signs vs
        join patient_month_initial pm
        on vs.patid = pm.patid
    )
);

--Create a table to find all recorded smoking codes for each patient
--drop table patient_all_records;
create table patient_all_records as
(
select * from
    (
    --Unique patients
    with patient_all_records_initial as
    (select distinct patid from Vital_Signs),
    vs as
    (select * from Vital_Signs)
    
    --Smoking code counts
    select distinct par.patid,
        (select count(*) from vs where par.patid = vs.patid and vs.smoking = '01') as all_01,
        (select count(*) from vs where par.patid = vs.patid and vs.smoking = '02') as all_02,
        (select count(*) from vs where par.patid = vs.patid and vs.smoking = '03') as all_03,
        (select count(*) from vs where par.patid = vs.patid and vs.smoking = '04') as all_04,
        (select count(*) from vs where par.patid = vs.patid and vs.smoking = '05') as all_05,
        (select count(*) from vs where par.patid = vs.patid and vs.smoking = '06') as all_06,
        (select count(*) from vs where par.patid = vs.patid and vs.smoking = '07') as all_07,
        (select count(*) from vs where par.patid = vs.patid and vs.smoking = '08') as all_08,
        (select count(*) from vs where par.patid = vs.patid and vs.smoking = 'NI') as all_NI,
        (select count(*) from vs where par.patid = vs.patid and vs.smoking = 'UN') as all_UN,
        (select count(*) from vs where par.patid = vs.patid and vs.smoking = 'OT') as all_OT
        from Vital_Signs vs
        join patient_all_records_initial par
        on vs.patid = par.patid
    )
);

--Make month-long and all-time smoking code counts correspond to each record in Vital_Signs
--drop table smoking_code_records;
create table smoking_code_records as
(
select vs_out.patid, vs_out.encounterid, vs_out.measure_date, 
    y.measure_date_noday, y.days_from_first_enc, vs_out.vitalid, vs_out.smoking, 
    y.month_01, y.month_02, y.month_03, y.month_04, 
    y.month_05, y.month_06, y.month_07, y.month_08,
    y.month_NI, y.month_UN, y.month_OT,
    y.all_01, y.all_02, y.all_03, y.all_04,
    y.all_05, y.all_06, y.all_07, y.all_08,
    y.all_NI, y.all_UN, y.all_OT
    from
    (
    select x.patid, x.measure_date_noday, x.days_from_first_enc, x.vitalid,
        x.month_01, x.month_02, x.month_03, x.month_04, 
        x.month_05, x.month_06, x.month_07, x.month_08,
        x.month_NI, x.month_UN, x.month_OT,
        par.all_01, par.all_02, par.all_03, par.all_04, 
        par.all_05, par.all_06, par.all_07, par.all_08,
        par.all_NI, par.all_UN, par.all_OT
        from 
        (
        select vs_in.patid, vs_in.measure_date_noday, vs_in.days_from_first_enc, vs_in.vitalid, 
            pm.month_01, pm.month_02, pm.month_03, pm.month_04, 
            pm.month_05, pm.month_06, pm.month_07, pm.month_08,
            pm.month_NI, pm.month_UN, pm.month_OT
            from Vital_Signs vs_in
            join patient_month_records pm
            on vs_in.measure_date_noday = pm.measure_date_noday and vs_in.patid = pm.patid
        ) x
        join patient_all_records par
        on par.patid = x.patid
    ) y
join Vital_Signs vs_out
on vs_out.vitalid = y.vitalid
);

--Update smoking column according to logic given in Definitions_Part2.pdf
--Current Smoker
update smoking_code_records sc
    set smoking = 1
    where (month_01 > 0 or month_02 > 0 or month_05 > 0 or month_07 > 0 or month_08 > 0); --175 rows updated
--Former Smoker
update smoking_code_records sc
    set smoking = 2
    where (month_03 > 0) and not (month_01 > 0 or month_02 > 0 or month_05 > 0 or month_07 > 0 or month_08 > 0); --1,298 rows updated
--Never Smoker
update smoking_code_records sc
    set smoking = 3
    where (all_04 > 0) and not (all_01 > 0 or all_02 > 0 or all_03 > 0 or all_05 > 0 or all_07 > 0 or all_08 > 0); --2,355 rows updated
--Unknown
update smoking_code_records sc
    set smoking = 4
    where (all_06 > 0 or all_NI > 0 or all_UN > 0 or all_OT > 0) and not (all_01 > 0 or all_02 > 0 or all_03 > 0 or all_04 > 0 or all_05 > 0 or all_07 > 0 or all_08 > 0); --68 rows updated

--View unhandled cases (such as when there are no records in the relevant month)
select * from smoking_code_records
where smoking not in ('1', '2', '3', '4') --(smoking = 'NI' or smoking = 'UN' or smoking = 'OT')
order by measure_date;
--359 rows

--Handle cases where no codes exist for the month. (use the patient's most recent record's smoking code)
--A decent number of 'NI' values still occur...
--drop table final_smoking_codes;
create table final_smoking_codes as 
(
select patid, measure_date, measure_date_noday, days_from_first_enc, vitalid, 
coalesce
(
    (
    case when smoking not in ('1', '2', '3', '4')
    then 
        (
        select decode(smoking, '01', '1', '02', '1', '03', '2', '04', '3', '05', '1', 
                        '06', '4', '07', '1', '08', '1', 'NI', '4', 'UN', '4', 'OT', '4', 'NI') from 
            (
            --1 - 01, 02, 05, 07, 08
            --2 - 03
            --3 - 04
            --4 - 06, NI, UN, OT
            
            --Subquery design from https://stackoverflow.com/a/11128479/1541090
            select patid, vitalid, smoking, measure_date, measure_date_noday, days_from_first_enc, 
            row_number() over (partition by patid order by sc_in.measure_date desc) rn
            from smoking_code_records sc_in
            where sc_in.patid = sc_out.patid 
            and sc_in.measure_date <= sc_out.measure_date
            and not sc_in.smoking = 'NI'
            ) sm
        where rn = 1
        )
    else smoking end 
    ), 'NI'
) as smoking
from smoking_code_records sc_out
);

--Join tables on matching vital IDs; replace precise measure_date with year/month in custom_date; include re-labelled smoking column and days_diff column
--drop table NEXTD_Vital_Signs;
create table NEXTD_Vital_Signs as
(
select vs.patid, vs.encounterid, fsc.measure_date_noday as measure_date, 
fsc.days_from_first_enc, vs.vitalid, vs.ht, vs.wt, 
vs.systolic, vs.diastolic, fsc.smoking
from Vital_Signs vs
join final_smoking_codes fsc
on vs.vitalid = fsc.vitalid
);

--Review
select * from Vital_Signs;
select * from patient_month_records order by patid;
select * from patient_all_records order by patid;
select * from smoking_code_records;
select * from final_smoking_codes;
select * from NEXTD_Vital_Signs;

---------- Table 6 - Lab Results ----------
--select count(*) from PCORNET_CDM_C2R2.LAB_RESULT_CM labs;
--96,502,167

--drop table Lab_Results;
create table Lab_Results as
(
select labs.patid, labs.encounterid, labs.lab_order_date, labs.lab_result_cm_id, 
    substr(labs.specimen_date, 4, 6) as specimen_date_noday, 
    round((labs.specimen_date - emo.meddate), 4) as days_from_first_enc, labs.specimen_date, emo.meddate, --why does days_from_first_enc yield fractions of a day?
    labs.result_num, labs.result_unit, labs.lab_name, labs.lab_loinc
    from PCORNET_CDM_C2R2.LAB_RESULT_CM labs
    join each_med_obs emo
    on labs.patid=emo.patid
    where labs.lab_loinc in (
        select substr(c_basecode, length('LOINC: ')) from bconnolly.nextd_lab_review
        where category in('Fasting Glucose', 'Random Glucose')
    )
    or labs.lab_name in ('A1C', 'LDL', 'CREATININE', 'CK', 'CK_MB', 'CK_MBI', 'TROP_I', 'TROP_T_QL', 'TROP_T_QN', 'HGB')
);

--select count(*) from Lab_Results;
--1,337

select distinct labs.lab_name from PCORNET_CDM_C2R2.LAB_RESULT_CM labs;

select substr(c_basecode, length('LOINC: ')) from bconnolly.nextd_lab_review
where category = 'Fasting Glucose';
--A1c
--Fasting Glucose
--Random Glucose

select labs.lab_name, count(*) from PCORNET_CDM_C2R2.LAB_RESULT_CM labs
where labs.lab_name is not null
group by labs.lab_name;

---------- Table 7 - Non-Urgent Visits ----------
--select count(*) from PCORNET_CDM_C2R2.PROCEDURES proc;
--23,731,186

--drop table Non_Urgent_Visits;
create table Non_Urgent_Visits as 
(
select proc.patid, proc.encounterid, proc.enc_type,
    proc.admit_date,
    substr(proc.admit_date, 4, 6) as admit_date_noday, 
    (row_number() over (partition by proc.patid, proc.admit_date order by proc.admit_date desc)) as admit_date_orderNumber, --not sure if this is correctly set up
    proc.proceduresid, proc.px, proc.px_type, 
    substr(proc.px_date, 4, 6) as px_date,
    (proc.px_date - emo.meddate) as days_from_first_enc, 
    diag.diagnosisid, diag.dx, diag.dx_type 
    from PCORNET_CDM_C2R2.PROCEDURES proc
    join PCORNET_CDM_C2R2.DIAGNOSIS diag
    on proc.patid=diag.patid
    join each_med_obs emo
    on proc.patid=emo.patid
    where ( proc.px_type in ('C3', 'C4', 'CH') and proc.px in ('99385', '99386', '99387', '99395', '99396', '99397') )
    or ( proc.px_type in ('10') and proc.px in ('Z00.00', 'Z00.01') )
    or ( proc.px_type in ('09') and proc.px in ('V70.0' /* could be listed incorrectly as: 'V70', 'V70.00' */, 'V72.31' ) )
    or ( diag.dx_type in ('C3', 'C4', 'CH') and diag.dx in ('99385', '99386', '99387', '99395', '99396', '99397') )
    or ( diag.dx_type in ('10') and diag.dx in ('Z00.00', 'Z00.01') )
    or ( diag.dx_type in ('09') and diag.dx in ('V70.0' /* could be listed incorrectly as: 'V70', 'V70.00' */, 'V72.31' ) )
);

--select count(*) from Non_Urgent_Visits;
--1,477

---------- Table 8 - Immunizations ----------
--select count(*) from PCORNET_CDM_C2R2.PROCEDURES proc;
--23,731,186

--drop table Immunizations;
create table Immunizations as
(
select proc.patid, proc.encounterid, proc.proceduresid, proc.px, proc.px_type, 
    substr(proc.px_date, 4, 6) as px_date,
    (proc.px_date - emo.meddate) as days_from_first_enc,
    diag.diagnosisid, diag.admit_date, diag.dx, diag.dx_type
    from PCORNET_CDM_C2R2.PROCEDURES proc
    join PCORNET_CDM_C2R2.DIAGNOSIS diag
    on proc.patid=diag.patid
    join each_med_obs emo
    on proc.patid=emo.patid
    where ( proc.px_type in ('C3', 'C4', 'CH') and proc.px in ('G0245', 'G0246', 'G0247') )
    or ( proc.px_type in ('10') and proc.px in ('Z01.00', 'Z01.01', 'Z01.110', 'Z01.10', 'Z01.118', 'Z04.8') )
    or ( proc.px_type in ('09') and proc.px in ('V72.85') )
    or ( diag.dx_type in ('C3', 'C4', 'CH') and diag.dx in ('G0245', 'G0246', 'G0247') )
    or ( diag.dx_type in ('10') and diag.dx in ('Z01.00', 'Z01.01', 'Z01.110', 'Z01.10', 'Z01.118', 'Z04.8') )
    or ( diag.dx_type in ('09') and diag.dx in ('V72.85') )
);

--select count(*) from Immunizations;
--1,512,526 without emo join (71 minute runtime)
--0 with emo join (small data set atm)

----------Table 9 - Health Outcomes ----------


---------- Table 10 - Diagnoses ----------
--select count(*) from PCORNET_CDM_C2R2.DIAGNOSIS diag;
--31,086,853

--drop table Diagnoses;
create table Diagnoses as
(
select diag.patid, diag.encounterid, diag.diagnosisid, diag.pdx, diag.dx, diag.enc_type, 
    substr(diag.admit_date, 4, 6) as admit_date,
    (diag.admit_date - emo.meddate) as days_from_first_enc  
    from PCORNET_CDM_C2R2.DIAGNOSIS diag
    join each_med_obs emo
    on diag.patid=emo.patid
);

--select count(*) from Diagnoses;
--5,746

--select distinct diag.pdx from PCORNET_CDM_C2R2.DIAGNOSIS diag; 
--NI, P, and X
