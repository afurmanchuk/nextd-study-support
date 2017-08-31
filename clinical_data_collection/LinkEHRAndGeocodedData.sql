/*
* Table 9 creation code; requires access to de-identified patient data
* Copyright (c) 2017 University of Kansas Medical Center
* Authored by Brennan Connolly from KUMC
* TODO: Swap KUMC-specific schema and table names for substitutions.
*/

---- Transfer Next-D Cohort data (FinalStatTable a.k.a. Table 1) to the database with Census data ----

-- Export data from production database to csv file
--drop table NextD_FinalStatTable;
create table NextD_FinalStatTable (
PATID VARCHAR2(128 BYTE),	
FIRSTVISIT DATE,	
NUMBEROFVISITS NUMBER(38,0),	
DMONSETDATE DATE,	
DEATH_DATE DATE,	
PREGNANCYDATE_1 DATE,	
PREGNANCYDATE_2 DATE,	
PREGNANCYDATE_3 DATE,	
PREGNANCYDATE_4 DATE,	
PREGNANCYDATE_5 DATE,	
PREGNANCYDATE_6 DATE,	
PREGNANCYDATE_7 DATE,	
PREGNANCYDATE_8 DATE,	
PREGNANCYDATE_9 DATE,	
PREGNANCYDATE_10 DATE,	
PREGNANCYDATE_11 DATE,	
PREGNANCYDATE_12 DATE,	
PREGNANCYDATE_13 DATE,	
PREGNANCYDATE_14 DATE,	
PREGNANCYDATE_15 DATE,	
PREGNANCYDATE_16 DATE,	
PREGNANCYDATE_17 DATE,	
PREGNANCYDATE_18 DATE,	
PREGNANCYDATE_19 DATE,	
PREGNANCYDATE_20 DATE,	
PREGNANCYDATE_21 DATE
)
;
-- Import data from csv file 

---- Approach 1 from https://informatics.gpcnetwork.org/trac/Project/ticket/544#comment:13 ----

-- Link patient IDs to census tract
--drop table patient_tract;
create table patient_tract as
select z.patid, (gk.fipsst || gk.fipsco || gk.tract_id) gtract_acs from 
-- Change z.patid to z.* for more information
    (
    select y.*, zs.name state from
        (
        select x.*, cpat.add_line_1, cpat.add_line_2, cpat.city, cpat.state_c, cpat.zip  from
            (
            select fst.patid, pmap.patient_ide from nextd_finalstattable fst
            left join nightherondata.patient_mapping pmap
            on fst.patid = pmap.patient_num
            where patient_ide_source = 'Epic@kumed.com' -- EHR source
            ) x 
        left join clarity.patient cpat
        on x.patient_ide = cpat.pat_id
        ) y
    left join clarity.zc_state zs
    on y.state_c = zs.state_c
    ) z
left join (select distinct address, city, state, zip, fipsst, fipsco, tract_id from mpc.geocoded_kumc) gk
on (z.add_line_1 || ' ' || z.add_line_2) = gk.address
and z.city = gk.city
and z.state = gk.state
and z.zip = gk.zip
;

---- Investigate quality of the data ----

select count(*) from nextd_finalstattable;  -- ~554000 Rows
select count(*) from patient_tract;         -- ~554000 Rows
select count(*) from patient_tract
where gtract_acs is null;                   -- ~389000 Rows (~70%)

-- Find patients with more than one tract ID associated with them
select patid, count(patid) amount
from patient_tract
group by patid
having count (patid) > 1;

-- Find the addresses related to the above discrepancies
select target_fid, loc_name, address, match_addr, arc_address, city from mpc.geocoded_kumc
where address in 
    (
    select distinct address from 
        (
        select add_line_1 || ' ' || add_line_2 address from patient_tract
        where patid in 
            (-- Patient IDs more than one tract ID associated with them
            select patid from 
                (
                select patid, count(patid) amount
                from patient_tract
                group by patid
                having count (patid) > 1
                )
            ) 
        ) 
    )
;

---- Approach 2 from https://informatics.gpcnetwork.org/trac/Project/ticket/544#comment:13 ----

-- Column names derived from census data provided by David Van Riper
--drop table census_data_tract;
create table census_data_tract (
tractid number,
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
)
;
-- Import from csv file with census tract data

select count(*) from census_data_tract; -- ~74000 rows

-- Link patient IDs to geocoded variables
--drop table Status_Variables;
create table Status_Variables as
(
select pt.patid, cdt.* from patient_tract pt
left join census_data_tract cdt
on pt.gtract_acs = cdt.tractid
)
;

-- @@@@@@@@@@ IMPORANT: Remove tract ID column from the table before exporting. @@@@@@@@@@ --
alter table Status_Variables drop column tractid;

select * from Status_Variables;

