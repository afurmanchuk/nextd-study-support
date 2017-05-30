--Table 5 - Vital Signs
--Handle case where no smoking records besides 'NI', 'UN', or 'OT' exist for the month
--by getting the smoking record from the patient's most recent measurement.

--Create test data
drop table test_records;
create table test_records (patid varchar(4), record_date date, unique_key varchar(4), change_this varchar(4)); 
insert into test_records (patid, record_date, unique_key, change_this) 
with test_data as (
    select '1111', '10-FEB-2017', '3750', '05' from dual union all
    select '1111', '12-FEB-2017', '1700', '02' from dual union all
    --select '1111', '13-FEB-2017', '1283', '02' from dual union all
    select '2222', '30-OCT-2016', '9916', '07' from dual union all
    select '2222', '12-FEB-2017', '9453', '01' from dual union all
    select '1111', '08-AUG-2015', '1422', 'NI' from dual union all
    select '1111', '05-MAR-2017', '0266', 'NI' from dual union all
    select '1111', '05-MAR-2017', '1774', 'NI' from dual union all
    select '3333', '19-JUN-2016', '1934', '03' from dual union all
    select '2222', '24-JAN-2017', '2498', '07' from dual union all
    select '1111', '20-MAR-2017', '0115', '04' from dual union all
    select '3333', '12-FEB-2017', '7444', '03' from dual union all 
    select '1111', '12-FEB-2017', '1701', '02' from dual union all
    select '1111', '07-NOV-2016', '0282', 'OT' from dual union all
    select '1111', '09-NOV-2016', '0276', '01' from dual 
)
select * from test_data;

--Select data, but replace 'NI' with most recent change_this code, if possible
select patid, record_date, unique_key, 
coalesce((
    case when change_this = 'NI' --when not in ('1', '2', '3', '4')
    then 
    (
    select --change_this||'_'||patid||'_'||record_date (for checking where the record comes from)
    decode(change_this, '01', '1', '02', '1', '03', '2', '04', '3', '05', '1', 
                        '06', '4', '07', '1', '08', '1', 'NI', '4', 'UN', '4', 'OT', '4') from 
    (
        --Subquery design from https://stackoverflow.com/a/11128479/1541090
        select patid, unique_key, change_this, record_date, 
        row_number() over (partition by patid order by tr_in.record_date desc) rn
        from test_records tr_in
        where tr_in.patid = tr_out.patid 
        and tr_in.record_date <= tr_out.record_date
        and not tr_in.change_this = 'NI'
    )
    where rn=1
    )
    else change_this end 
), 'NI') as change_this
from test_records tr_out;

--select * from test_records;

/*
For unique_key 1774 dated 05-MAR-2017, the most recent date for the same patient is 12-FEB-2017.
The corresponding change_this column value is 02.
*/
