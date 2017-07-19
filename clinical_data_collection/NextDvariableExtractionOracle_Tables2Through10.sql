/*
* Authored by Brennan Connolly from KUMC, with help from Dan Connolly and Matt Hoag
* Preliminary designs for tables 2 through 9 in the Next-D study (originally 2 through 10)
* See Definitions_Part2-2017-05-25-bb.pdf for design specifications
*/

--select x from big_table sample(1) gets 1% of big_table

--Make sure patient info from Table 1 exists
--First 100 rows can be used for testing
select * from FinalStatTable table1;
select * from FinalStatTable where rownum <= 100;

---------- Table 2 - Demographic Variables ----------
--select count(*) from "&&PCORNET_CDM".DEMOGRAPHIC demo;
--2,260,014

--drop table Demographic_Variables;
create table Demographic_Variables as
(
select demo.patid, 
    extract(year from demo.birth_date) as birth_year, 
    extract(month from demo.birth_date) as birth_month,
    demo.sex, demo.race, demo.hispanic 
    --other requested fields: language (if known) and marital status
    from "&&PCORNET_CDM".DEMOGRAPHIC demo
    join FinalStatTable table1
    on demo.patid=table1.patid
);  --1.551 seconds

--select count(*) from Demographic_Variables;
--554,167

---------- Table 3 - Crosswalk for Patients, Encounters and Dates ----------
--select count(*) from "&&PCORNET_CDM".ENCOUNTER enc;
--20,355,187

--What kinds of encounters are we actually looking for? (All encounters for each patient?)

--drop table Pat_Enc_Date;
create table Pat_Enc_Date as 
(
select enc.patid, enc.encounterid, 
    substr(enc.admit_date, 4, 6) as admit_date, 
    (round(enc.admit_date) - table1.FirstVisit) as days_from_first_enc, 
    enc.enc_type, enc.facilityid
    --other requested fields: revised encounter type encounter_rev, provider codes,
    --individual provider type and institutional provider type, facility name or type,
    --hospital department if applicable, physician specialty if applicable, insurance type
    from "&&PCORNET_CDM".ENCOUNTER enc
    join FinalStatTable table1
    on enc.patid=table1.patid
);  --52.679 seconds

--select count(*) from Pat_Enc_Date;
--18,726,616

---------- Table 4 - Medicines ----------
---- 4a. Prescription Medicines ----
--select count(*) from "&&PCORNET_CDM".PRESCRIBING presc;
--62,258,988

--drop table Prescription_Meds;
create table Prescription_Meds as
(
select presc.patid, presc.encounterid, presc.prescribingid, presc.rxnorm_cui,
    substr(presc.rx_order_date, 4, 6) as rx_order_date, 
    (round(presc.rx_order_date) - table1.FirstVisit) as days_from_first_enc,
    presc.rx_providerid, presc.rx_days_supply, 
    (case when presc.rx_refills is null then 0 else presc.rx_refills end) as rx_refills
    from "&&PCORNET_CDM".PRESCRIBING presc
    join FinalStatTable table1
    on presc.patid=table1.patid
);  --167.828 seconds
    
--select count(*) from Prescription_Meds; 
--60,111,003

---- 4b. Dispensed Medicines ----
--select count(*) from "&&PCORNET_CDM".DISPENSING disp;
--12,493,874

--drop table Dispensed_Meds;
create table Dispensed_Meds as
(
select disp.patid, disp.dispensingid, disp.ndc, 
    substr(disp.dispense_date, 4, 6) as dispense_date, 
    (round(disp.dispense_date) - table1.FirstVisit) as days_from_first_enc,
    disp.dispense_sup, disp.dispense_amt, disp.prescribingid --prescribingid is not requested directly, but might be necessary for finding other fields
    --other requested fields: disp.encounterid, disp.rx_providerid 
    from "&&PCORNET_CDM".DISPENSING disp
    join FinalStatTable table1
    on disp.patid=table1.patid
);  --27.178 seconds

--select count(*) from Dispensed_Meds; 
--12,001,683

---------- Table 5 - Vital Signs ----------
--select count(*) from "&&PCORNET_CDM".VITAL vital;
--23,167,183

--drop table Vital_Signs;
create table Vital_Signs as
(
select vital.patid, vital.encounterid, vital.measure_date,
    substr(measure_date, 4, 6) as measure_date_noday,
    (round(measure_date) - table1.FirstVisit) as days_from_first_enc,
    vital.vitalid, vital.ht, vital.wt, 
    vital.systolic, vital.diastolic, vital.smoking
    from "&&PCORNET_CDM".VITAL vital
    --For testing:
    --join (select * from FinalStatTable where rownum <= 100) table1
    join FinalStatTable table1
    on vital.patid=table1.patid
);  --71.09 seconds

--select count(*) from Vital_Signs;
--21,990,667 (join with full table1)
--3,342 (join with first 100 rows)

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
drop table patient_month_records;
create table patient_month_records as
(
select * from
    (
    with patient_month_initial as 
        --Unique patient/month combinations
        (select distinct patid, measure_date_noday from Vital_Signs)
    select * from 
        (
        select pm.patid, pm.measure_date_noday, vs.smoking
        from Vital_Signs vs
        join patient_month_initial pm
        on vs.patid = pm.patid
        and pm.measure_date_noday = vs.measure_date_noday
        )
    --Pivot logic by Matt Hoag
    pivot
        (
        --Smoking code counts
        count(smoking)
        for smoking in ('01', '02', '03', '04', '05', '06', '07', '08', 'NI', 'UN', 'OT')
        )
    )    
);  --56.773 seconds

--Create a table to find all recorded smoking codes for each patient
drop table patient_all_records;
create table patient_all_records as
(
select * from
    (
    with patient_all_records_initial as
        --Unique patients
        (select distinct patid from Vital_Signs)
    select * from 
        (
        select par.patid, vs.smoking
        from Vital_Signs vs
        join patient_all_records_initial par
        on vs.patid = par.patid
        )
    --Pivot logic by Matt Hoag
    pivot
        (
        --Smoking code counts
        count(smoking)
        for smoking in ('01', '02', '03', '04', '05', '06', '07', '08', 'NI', 'UN', 'OT')
        )
    )    
);  --30.676 seconds

--Make month-long and all-time smoking code counts correspond to each record in Vital_Signs
drop table smoking_code_records;
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
        par."'01'" as all_01, par."'02'" as all_02, par."'03'" as all_03, par."'04'" as all_04, 
        par."'05'" as all_05, par."'06'" as all_06, par."'07'" as all_07, par."'08'" as all_08,
        par."'NI'" as all_NI, par."'UN'" as all_UN, par."'OT'" as all_OT
        from 
        (
        select vs_in.patid, vs_in.measure_date_noday, vs_in.days_from_first_enc, vs_in.vitalid, 
            pm."'01'" as month_01, pm."'02'" as month_02, pm."'03'" as month_03, pm."'04'" as month_04, 
            pm."'05'" as month_05, pm."'06'" as month_06, pm."'07'" as month_07, pm."'08'" as month_08,
            pm."'NI'" as month_NI, pm."'UN'" as month_UN, pm."'OT'" as month_OT
            from Vital_Signs vs_in
            join patient_month_records pm
            on vs_in.measure_date_noday = pm.measure_date_noday and vs_in.patid = pm.patid
        ) x
        join patient_all_records par
        on par.patid = x.patid
    ) y
join Vital_Signs vs_out
on vs_out.vitalid = y.vitalid
);  --245.92 seconds, 111.541 seconds

--Update smoking column according to logic given in Definitions_Part2.pdf
--Current Smoker
update smoking_code_records
    set smoking = 1
    --where (month_01 > 0 or month_02 > 0 or month_05 > 0 or month_07 > 0 or month_08 > 0);     --3,448,575 rows updated, 93.041 seconds
    where ((month_01 + month_02 + month_05 + month_07 + month_08) > 0);                         --3,448,575 rows updated, 62.279 seconds
--Former Smoker
update smoking_code_records
    set smoking = 2
    --where (month_03 > 0) and not (month_01 > 0 or month_02 > 0 or month_05 > 0 or month_07 > 0 or month_08 > 0);  --6,537,979 rows updated, 88.582 seconds
    where (month_03 > 0) and ((month_01 + month_02 + month_05 + month_07 + month_08) = 0);                          --6,537,979 rows updated, 90.975 seconds
--Never Smoker
update smoking_code_records
    set smoking = 3
    --where (all_04 > 0) and not (all_01 > 0 or all_02 > 0 or all_03 > 0 or all_05 > 0 or all_07 > 0 or all_08 > 0);    --9,956,966 rows updated, 184.146 seconds
    where (all_04 > 0) and ((all_01 + all_02 + all_03 + all_05 + all_07 + all_08) = 0);                                 --9,956,966 rows updated, 137.518 seconds
--Unknown
update smoking_code_records
    set smoking = 4
    --where (all_06 > 0 or all_NI > 0 or all_UN > 0 or all_OT > 0) and not (all_01 > 0 or all_02 > 0 or all_03 > 0 or all_04 > 0 or all_05 > 0 or all_07 > 0 or all_08 > 0);    --279,377 rows updated, 7.981 seconds
    where ((all_06 + all_NI + all_UN + all_OT) > 0) and ((all_01 + all_02 + all_03 + all_04 + all_05 + all_07 + all_08) = 0);                                                   --279,377 rows updated, 14.557 seconds

--Other Cases (see CaseWhereSmokingNotRelabelled.sql)
update smoking_code_records
    set smoking = 1
    where smoking not in ('1', '2', '3', '4')
    and ((all_01 + all_02 + all_05 + all_07 + all_08) > 0) 
    and ((month_01 + month_02 + month_05 + month_07 + month_08) = 0); --770,961 rows updated, 29.541 seconds
    
update smoking_code_records
    set smoking = 2
    where smoking not in ('1', '2', '3', '4')
    and (all_03 > 0) 
    and ((month_01 + month_02 + month_05 + month_07 + month_08) = 0)
    and ((all_01 + all_02 + all_05 + all_07 + all_08) = 0); --996,809 rows updated, 31.81 seconds
    
update smoking_code_records
    set smoking = 3
    where smoking not in ('1', '2', '3', '4')
    and (all_04 > 0) 
    and ((month_01 + month_02 + month_03 + month_05 + month_07 + month_08) = 0)
    and ((all_01 + all_02 + all_03 + all_05 + all_07 + all_08) = 0); --0 rows updated, 11.334 seconds
    
update smoking_code_records
    set smoking = 4
    where smoking not in ('1', '2', '3', '4')
    and ((all_06 + all_NI + all_UN + all_OT) > 0) 
    and ((month_01 + month_02 + month_03 + month_04 + month_05 + month_07 + month_08) = 0)
    and ((all_01 + all_02 + all_03 + all_04 + all_05 + all_07 + all_08) = 0); --0 rows updated, 11.99 seconds

/*
--Handle cases where no codes exist for the month. (use the patient's most recent record's smoking code)
--@@@@@ Performance is awful with full patient set @@@@@--
--These cases are already handled by the above 4 update statements...though I'm not 100% confident they are handled correctly
drop table final_smoking_codes;
create table final_smoking_codes as 
(
select patid, measure_date, measure_date_noday, days_from_first_enc, vitalid, 
coalesce
(
    (
    case when smoking not in ('1', '2', '3', '4')
    then 
        (
        select decode( smoking, '01', '1', '02', '1', '03', '2', '04', '3', '05', '1', 
                        '06', '4', '07', '1', '08', '1', 'NI', '4', 'UN', '4', 'OT', '4', 'NI') from    
        --1 - 01, 02, 05, 07, 08
        --2 - 03
        --3 - 04
        --4 - 06, NI, UN, OT
            (
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

--Check for smoking codes that were not relabelled
select * from final_smoking_codes
where smoking not in ('1', '2', '3', '4');
*/

--Join tables on matching vital IDs
--drop table NEXTD_Vital_Signs;
create table NEXTD_Vital_Signs as
(
select vs.patid, vs.encounterid, sc.measure_date_noday as measure_date, 
sc.days_from_first_enc, vs.vitalid, vs.ht, vs.wt, 
vs.systolic, vs.diastolic, sc.smoking
from Vital_Signs vs
join smoking_code_records sc
--join final_smoking_codes fsc
on vs.vitalid = sc.vitalid
);  --39.687 seconds

--Review
select * from Vital_Signs;
select * from patient_month_records order by patid;
select * from patient_all_records order by patid;
select * from smoking_code_records;
--select * from final_smoking_codes;
select * from NEXTD_Vital_Signs;

---------- Table 6 - Lab Results ----------
--select count(*) from "&&PCORNET_CDM".LAB_RESULT_CM labs;
--96,502,167

--TODO: investigate definitions for what lab_name values are wanted, exactly

--drop table Lab_Results;
create table Lab_Results as
(
select labs.patid, labs.encounterid, substr(labs.lab_order_date, 4, 6) as lab_order_date, labs.lab_result_cm_id, 
    substr(labs.specimen_date, 4, 6) as specimen_date_noday, 
    (round(labs.specimen_date) - table1.FirstVisit) as days_from_first_enc, --labs.specimen_date, table1.FirstVisit,
    labs.result_num, labs.result_unit, labs.lab_name, labs.lab_loinc
    from "&&PCORNET_CDM".LAB_RESULT_CM labs
    join FinalStatTable table1
    on labs.patid=table1.patid
    where labs.lab_loinc in (
        select loinc from nextd_lab_review
        where label in('Fasting Glucose', 'Random Glucose')
    )
    or labs.lab_name in ('A1C', 'LDL', 'CREATININE', 'CK', 'CK_MB', 'CK_MBI', 'TROP_I', 'TROP_T_QL', 'TROP_T_QN', 'HGB')
);  --72.435 seconds

--select count(*) from Lab_Results;
--6,588,420

---------- Table 7 - Diagnoses ----------
--select count(*) from "&&PCORNET_CDM".DIAGNOSIS diag;
--31,086,853

--drop table Diagnoses;
create table Diagnoses as
(
select diag.patid, diag.encounterid, diag.diagnosisid, diag.dx, diag.pdx, 
    diag.dx_type, diag.dx_source, diag.enc_type, 
    substr(diag.admit_date, 4, 6) as admit_date,
    (round(diag.admit_date) - table1.FirstVisit) as days_from_first_enc 
    --other requested fields: diag.dx_origin, revised encounter type
    from "&&PCORNET_CDM".DIAGNOSIS diag
    join FinalStatTable table1
    on diag.patid=table1.patid
);  --72.978 seconds

--select count(*) from Diagnoses;
--29,216,399

---------- Table 8 - Health Outcomes ----------

---- Non-Urgent Visits ---- 
--select count(*) from "&&PCORNET_CDM".PROCEDURES proc;
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
    (round(proc.px_date) - table1.FirstVisit) as days_from_first_enc, 
    diag.diagnosisid, diag.dx, diag.dx_type 
    from "&&PCORNET_CDM".PROCEDURES proc
    join "&&PCORNET_CDM".DIAGNOSIS diag
    on proc.patid=diag.patid
    join FinalStatTable table1
    on proc.patid=table1.patid
    --TODO: Once these lists of values are received in spreadsheet form, refer to that instead of typing out every value.
    where ( proc.px_type in ('C3', 'C4', 'CH') and proc.px in ('99385', '99386', '99387', '99395', '99396', '99397') )
    or ( proc.px_type in ('10') and proc.px in ('Z00.00', 'Z00.01') )
    or ( proc.px_type in ('09') and proc.px in ('V70.0' /* could be listed incorrectly as: 'V70', 'V70.00' */, 'V72.31' ) )
    or ( diag.dx_type in ('C3', 'C4', 'CH') and diag.dx in ('99385', '99386', '99387', '99395', '99396', '99397') )
    or ( diag.dx_type in ('10') and diag.dx in ('Z00.00', 'Z00.01') )
    or ( diag.dx_type in ('09') and diag.dx in ('V70.0' /* could be listed incorrectly as: 'V70', 'V70.00' */, 'V72.31' ) )
);

--select count(*) from Non_Urgent_Visits;
--1,477

---- Immunizations ----
--select count(*) from "&&PCORNET_CDM".PROCEDURES proc;
--23,731,186

--drop table Immunizations;
create table Immunizations as
(
select proc.patid, proc.encounterid, proc.proceduresid, proc.px, proc.px_type, 
    substr(proc.px_date, 4, 6) as px_date,
    (round(proc.px_date) - table1.FirstVisit) as days_from_first_enc,
    diag.diagnosisid, diag.admit_date, diag.dx, diag.dx_type
    from "&&PCORNET_CDM".PROCEDURES proc
    join "&&PCORNET_CDM".DIAGNOSIS diag
    on proc.patid=diag.patid
    join FinalStatTable table1
    on proc.patid=table1.patid
    --TODO: Once these lists of values are received in spreadsheet form, refer to that instead of typing out every value.
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

--Data on Poor Glycemic Control and LDL is also requested for this table.

---------- Table 9 - Socio-Economic Status Variables ----------
--"All variables used here will be collected at the Census Tract level."

--Create table and import tract-level census data 
--see LinkEHRAndGeocodedData.sql for details
--drop table Status_Variables;
create table Status_Variables (
patid number,
prop_white number,
prop_black number,
prop_hispanic number,
prop_nh_white number,
prop_nh_black number,
prop_h_white number,
prop_h_black number,
prop_asian number,
prop_other number,
prop_female number,
prop_yrs_under_5 number,
prop_yrs_5_19 number,
prop_yrs_20_24 number,
prop_yrs_25_34 number,
prop_yrs_35_44 number,
prop_yrs_45_54 number,
prop_yrs_55_64 number,
prop_yrs_65_74 number,
prop_yrs_75_84 number,
prop_yrs_85_plus number,
prop_married number,
prop_never_married number,
prop_divorced number,
prop_widowed number,
prop_english number,
prop_spanish number,
prop_other_language number,
prop_poor_english number,
prop_lt_high_school number,
prop_high_school number,
prop_some_college number,
prop_college_grad number,
prop_employer number,
prop_direct number,
prop_medicare number,
prop_medicaid number,
prop_tricare_va number,
prop_medicare_medicaid number,
prop_no_insurance number,
prop_employed number,
prop_unemployed number,
prop_nilf number,
prop_full_time number,
prop_part_time number,
prop_vet number,
median_hh_income number,
median_earnings number,
per_capita_income number,
prop_hh_size_1 number,
prop_hh_size_2 number,
prop_hh_size_3 number,
prop_hh_size_4plus number,
prop_home_owner number,
median_gross_rent number,
prop_us_native_born number,
prop_us_foreign_born number,
prop_non_us number,
prop_poverty number,
prop_disabled number,
prop_food_stamps number,
tdi number,
moe_median_hh_income number,
moe_median_earnings number,
moe_per_capita_income number,
moe_median_gross_rent number,
moe_prop_white number,
moe_prop_black number,
moe_prop_hispanic number,
moe_prop_nh_white number,
moe_prop_nh_black number,
moe_prop_h_white number,
moe_prop_h_black number,
moe_prop_asian number,
moe_prop_other number,
moe_prop_female number,
moe_prop_yrs_under_5 number,
moe_prop_yrs_5_19 number,
moe_prop_yrs_20_24 number,
moe_prop_yrs_25_34 number,
moe_prop_yrs_35_44 number,
moe_prop_yrs_45_54 number,
moe_prop_yrs_55_64 number,
moe_prop_yrs_65_74 number,
moe_prop_yrs_75_84 number,
moe_prop_yrs_85_plus number,
moe_prop_married number,
moe_prop_never_married number,
moe_prop_divorced number,
moe_prop_widowed number,
moe_prop_english number,
moe_prop_spanish number,
moe_prop_other_language number,
moe_prop_poor_english number,
moe_prop_lt_high_school number,
moe_prop_high_school number,
moe_prop_some_college number,
moe_prop_college_grad number,
moe_prop_employer number,
moe_prop_direct number,
moe_prop_medicare number,
moe_prop_medicaid number,
moe_prop_tricare_va number,
moe_prop_medicare_medicaid number,
moe_prop_no_insurance number,
moe_prop_employed number,
moe_prop_unemployed number,
moe_prop_nilf number,
moe_prop_full_time number,
moe_prop_part_time number,
moe_prop_vet number,
moe_prop_hh_size_1 number,
moe_prop_hh_size_2 number,
moe_prop_hh_size_3 number,
moe_prop_hh_size_4plus number,
moe_prop_home_owner number,
moe_prop_us_native_born number,
moe_prop_us_foreign_born number,
moe_prop_non_us number,
moe_prop_poverty number,
moe_prop_disabled number,
moe_prop_food_stamps number,
primary_RUCA number,
secondary_RUCA number
);

