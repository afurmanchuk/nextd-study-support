# Natural experiments for translation in diabetes (NEXT-D)

This is code to support the NEXT-D study.

Inital code by Al'ona Furmanchuk with Dan Connolly.
All contributors:
 - Al'ona Furmanchuk <alona.furmanchuk@northwestern.edu>, <furmanchuk@icnanotox.org>
 - Brennan Connolly <bconnolly@kumc.edu>
 - Dan Connolly <dckc@madmode.com>, <dconnolly@kumc.edu>
 - George Kowalski <gkowalski@mcw.edu>
 - Mei Liu <meiliu@kumc.edu>
 - Alex Stoddard <astoddard@mcw.edu>

See also:

 - [NEXT-D Data Request Detail](https://informatics.gpcnetwork.org/trac/Project/attachment/ticket/539/NEXT-D_Request%20for%20Data_Detailed_12.1.16.docx) draft of Nov 15
 - [Ticket #546](https://informatics.gpcnetwork.org/trac/Project/ticket/546)



## Implemenation overview

NEXT-D query code targets PCORNET CDM implementations, originally developed against a SQLServer (see SQLServer_impl) CDM by Al'ona Furmanchuk and then ported to Oracle (see Oracle_impl).

The SQLServer implementation using local temp tables. These are not implemented by Oracle which uses global temp tables. The Oracle implementation therefore has "init_Oracle_temp_tables_ddl.sql" to define these tables. The definitions of these tables (but note their data contents) will persist in the Oracle schema used. 

Oracle sites may wish to create a separate NEXT-D schema with select priveleges on their CDM schema to segregate 
NEXT-D specific work.

### Reference code sets
Common code references for lab and medication are in ref_code_table_data and will need to be loaded into their corresponding tables in the NEXT-D/CDM schema when required by subsquent data analysis and extract steps.

_These data are not required for the "Table1" extract due 2017-09-05_ (see [Ticket:545](https://informatics.gpcnetwork.org/trac/Project/ticket/545))

## Table 1 subset extraction (due 2017-09-05)

SQLServer code has not been updated yet for this.

Oracle code is in Oracle_impl/NextD_table1.sql. 
  - First run init_Oracle_temp_tables_ddl.sql 
  - Either modify NextD_table1.sql to reference your specific CDM schema (replacing all references to "&&PCORNET_CDM""), or rely on SqlPlus variable substition if that is your Oracle client of choice.
  - Run NextD_table1.sql
  - Extract the final result table and upload to REDCap.

## Study Info

 - Principal Investigators:
   - Bernard S. Black, JD, MA
   - Abel N. Kho, MD
 - Co-Investigators:
   - Laura J. Rasmussen-Torvik, PhD, MPH, FAHA
   - John Meurer, MD, MBA
   - Russ Waitman, PhD
   - Mei Liu, PhD
 - [Nov 2014 study protocol](http://listserv.kumc.edu/pipermail/gpc-dev/attachments/20161205/83a32ac8/attachment-0001.docx)
