----Check how many patients had codes that were not relabelled BEFORE checking for the most recent available data

--drop table smoking_exceptions;
create table smoking_exceptions as (
--View unhandled cases (such as when there are no records in the relevant month)
select * from smoking_code_records 
where smoking not in ('1', '2', '3', '4') --expect (smoking = 'NI' or smoking = 'UN' or smoking = 'OT')
--order by measure_date
);

select distinct patid from smoking_exceptions; 

--Some columns may be consistently empty
--Start with all code frequency columns, then remove columns with data until 0 rows are returned.
select * from smoking_exceptions where 
(month_01 > 0 or month_02 > 0 or month_03 > 0 or month_05 > 0 or month_07 > 0 or month_08 > 0 or month_UN > 0 or month_OT > 0 or all_UN > 0 or all_OT > 0); 
--0 rows

--View relevant columns (i.e. those not in the above query)
select * from
(select patid, smoking, month_04, month_06, month_NI, all_01, all_02, all_03, all_04, all_05, all_06, all_07, all_08, all_NI, 
row_number() over (partition by patid order by measure_date asc) rn from smoking_exceptions)
where rn = 1; 
--all other smoking code columns have zeroes

/*
----Check how many patients had codes that were not relabelled AFTER checking for the most recent available data

select distinct patid from 
(
select * from final_smoking_codes
where smoking not in ('1', '2', '3', '4')
--64 rows
);
--10 patients

----Find out which cases need to be handled before checking for the most recent available data

--drop table final_smoking_exceptions;
create table final_smoking_exceptions as
(
select * from 
    (
    select * from
    (select patid, smoking, 
    month_01, month_02, month_03, month_04, month_05, month_06, month_07, month_08, month_NI, month_UN, month_OT, 
    all_01, all_02, all_03, all_04, all_05, all_06, all_07, all_08, all_NI, all_UN, all_OT,
    row_number() over (partition by patid order by measure_date asc) rn from smoking_exceptions)
    where rn = 1
    )
where patid in 
    (
    select distinct patid from final_smoking_codes
    where smoking not in ('1', '2', '3', '4')
    )
);
*/
    
--Note: checking (a = 0 and b = 0) is the same as checking (a + b = 0)    
    
--I suspect these cases occur when the earliest encounter for a patient has No Information, but later encounters have relevant codes. In this case there will be no previous data to fall back on.
update smoking_code_records
    set smoking = 1
    where smoking not in ('1', '2', '3', '4')
    and ((all_01 + all_02 + all_05 + all_07 + all_08) > 0) 
    and ((month_01 + month_02 + month_05 + month_07 + month_08) = 0); 
    
update smoking_code_records
    set smoking = 2
    where smoking not in ('1', '2', '3', '4')
    and (all_03 > 0) 
    and ((month_01 + month_02 + month_05 + month_07 + month_08) = 0)
    and ((all_01 + all_02 + all_05 + all_07 + all_08) = 0); 
    
update smoking_code_records
    set smoking = 3
    where smoking not in ('1', '2', '3', '4')
    and (all_04 > 0) 
    and ((month_01 + month_02 + month_03 + month_05 + month_07 + month_08) = 0)
    and ((all_01 + all_02 + all_03 + all_05 + all_07 + all_08) = 0); 
    
update smoking_code_records
    set smoking = 4
    where smoking not in ('1', '2', '3', '4')
    and ((all_06 + all_NI + all_UN + all_OT) > 0) 
    and ((month_01 + month_02 + month_03 + month_04 + month_05 + month_07 + month_08) = 0)
    and ((all_01 + all_02 + all_03 + all_04 + all_05 + all_07 + all_08) = 0); 
    
select * from smoking_code_records
--where ((month_01 + month_02 + month_03 + month_04 + month_05 + month_06 + month_07 + month_08) = 0)
where smoking not in ('1', '2', '3', '4');


