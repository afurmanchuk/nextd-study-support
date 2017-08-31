--Table of interest (Table 1)
select * from FinalStatTable;

--Jupyter notebook can't select from temp tables, so make a permanent one
--drop table Non_Temp_FST;
create table Non_Temp_FST as
(select * from FinalStatTable);

---- Questions that could be asked about this data: ----

--https://stackoverflow.com/questions/193107/print-text-in-oracle-sql-developer-sql-worksheet-window   
BEGIN
   FOR i IN 1..10 LOOP
      IF MOD(i,2) = 0 THEN     -- i is even
         begin DBMS_OUTPUT.put_line(i || ' is even'); end;
      ELSE
         begin DBMS_OUTPUT.put_line(i || ' is odd'); end;
      END IF;
   END LOOP;
END;

---- Find number of patients with at least i number of pregnancies (1 <= i <= 21) ----

--Sample SQL
select * from Non_Temp_FST 
where pregnancydate_1 is not null
order by pregnancydate_1;


--truncate table min_pregnancies;
--drop table min_pregnancies;
create table min_pregnancies
(pregnancies integer, patients integer);

declare
    sql_statement varchar2(1000);
begin
    for i in 1..21 loop
        sql_statement := 'insert into min_pregnancies (pregnancies, patients)
        select ' || i || ', count(*) from FinalStatTable 
        where pregnancydate_' || i || ' is not null';
        execute immediate sql_statement;
        --begin DBMS_OUTPUT.put_line(sql_statement); end;
    end loop;
    commit;
end;

select * from min_pregnancies;

---- Find number of patients with i number of pregnancies (1 <= i <= 20) ----

--Sample SQL
select * from Non_Temp_FST 
where pregnancydate_1 is not null
and pregnancydate_2 is null
order by pregnancydate_1;


--truncate table pregnancy_count;
--drop table pregnancy_count;
create table pregnancy_count
(pregnancies number(38,0), patients number(38,0));


declare
    sql_statement varchar2(2000);
begin
    for i in 1..20 loop
        sql_statement := 'insert into pregnancy_count (pregnancies, patients)
        select ' || i || ', count(*) from FinalStatTable 
        where pregnancydate_' || i || ' is not null
        and pregnancydate_' || (i+1) || ' is null';
        execute immediate sql_statement;
        --begin DBMS_OUTPUT.put_line(sql_statement); end;
    end loop;
    commit;
end;

select * from pregnancy_count;

---- Same as before, but only for patients with a DM onset date ----

--Sample SQL
select * from Non_Temp_FST 
where pregnancydate_1 is not null
and pregnancydate_2 is null
and dmonsetdate is not null
order by pregnancydate_1;


--truncate table pregnancy_count;
--drop table pregnancy_count_dm;
create table pregnancy_count_dm
(pregnancies number(38,0), patients number(38,0));


declare
    sql_statement varchar2(2000);
begin
    for i in 1..20 loop
        sql_statement := 'insert into pregnancy_count_dm (pregnancies, patients)
        select ' || i || ', count(*) from FinalStatTable 
        where pregnancydate_' || i || ' is not null
        and pregnancydate_' || (i+1) || ' is null
        and dmonsetdate is not null';
        execute immediate sql_statement;
        --begin DBMS_OUTPUT.put_line(sql_statement); end;
    end loop;
    commit;
end;

select * from pregnancy_count_dm;

---- How many patients have a DM onset date? ----

-- HERON query for patients with a DM diagnosis returned 87,159 patients; I expect the result to be less than that.
select count(*) from Non_Temp_FST  --FinalStatTable 
where dmonsetdate is not null;
--order by dmonsetdate;


--Find out how many patients do or do not have a dm onset date
select
(select count(*) from Non_Temp_FST
where dmonsetdate is not null) y,
(select count(*) from Non_Temp_FST
where dmonsetdate is null) n
from dual;

---- How many patients have a death date? ----

select count(*) from Non_Temp_FST  --FinalStatTable 
where death_date is not null;
--order by death_date;


-- Confirm that death dates come after first visit dates
-- If this is true, result should be 0 rows
select * from Non_Temp_FST  --FinalStatTable 
where (death_date - firstvisit) < 0;


-- If the above query returns > 0 rows, do any of the patients have DM onset dates?
select * from Non_Temp_FST  --FinalStatTable 
where (death_date - firstvisit) < 0
and dmonsetdate is not null;


-- Examine difference between death date and visit date in months
select firstvisit, death_date, round(months_between(death_date, firstvisit)) as difference from Non_Temp_FST
where death_date is not null;

-- Some differences are over 1000 months. Why?
select distinct(death_date) from Non_Temp_FST
where round(months_between(death_date, firstvisit)) > 1000;
-- This only occurs when the death_date is 31-DEC-00.

-- Categorize death data for a Jupyter notebook pie chart
select * from 
    (
    select 
        case when death_date is null then 0 --'None'
        when round(months_between(death_date, firstvisit)) > 1000 then 2 --'Death Date is 21 DEC 2100'
        when round(months_between(death_date, firstvisit)) < 0 then 3 --'Death Date before First Visit'
        else 1 /*'Normal'*/ end as Death_Description
        from Non_Temp_FST
    )
pivot
    (
    count(Death_Description)
    for Death_Description in (0, 1, 2, 3)
    )
;

---- Graph patients by number of visits ----

select numberofvisits from Non_Temp_FST
order by numberofvisits desc;

--Categorize visit counts for a Jupyter notebook
select 
(select count(*) from Non_Temp_FST where numberofvisits <= 50 and numberofvisits > 0) as "50=>x>0",
(select count(*) from Non_Temp_FST where numberofvisits <= 100 and numberofvisits > 50) as "100=>x>50",
(select count(*) from Non_Temp_FST where numberofvisits <= 150 and numberofvisits > 100) as "150=>x>100",
(select count(*) from Non_Temp_FST where numberofvisits <= 200 and numberofvisits > 150) as "200=>x>150",
(select count(*) from Non_Temp_FST where numberofvisits > 200 ) as "x>200"
from dual;

/*
select 
(select count(*) from Non_Temp_FST where numberofvisits > 500 ) as "x>500",
(select count(*) from Non_Temp_FST where numberofvisits <= 500 and numberofvisits > 400) as "500=>x>400",
(select count(*) from Non_Temp_FST where numberofvisits <= 400 and numberofvisits > 300) as "400=>x>300",
(select count(*) from Non_Temp_FST where numberofvisits <= 300 and numberofvisits > 200) as "300=>x>200",
(select count(*) from Non_Temp_FST where numberofvisits <= 200 and numberofvisits > 100) as "200=>x>100",
(select count(*) from Non_Temp_FST where numberofvisits <= 100 and numberofvisits > 0) as "100=>x>0"
from dual;
*/
