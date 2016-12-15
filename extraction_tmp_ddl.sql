/*
                      Create all temporary tables 
*/
truncate TABLE Denominator_initial;
truncate TABLE Denomtemp0v;
truncate TABLE Denomtemp1v;
truncate TABLE Denomtemp2v;
truncate TABLE DenominatorSummary;
truncate TABLE DemographicVars;
truncate TABLE A1c_initial;
truncate TABLE temp1;
truncate TABLE A1c_final_FirstPair;
truncate TABLE FG_initial;
truncate TABLE temp2;
truncate TABLE FG_final_FirstPair;
truncate TABLE RG_initial;
truncate TABLE temp3;
truncate TABLE RG_final_FirstPair;
truncate TABLE temp4;
truncate TABLE A1cRG_final_FirstPair;
truncate TABLE temp5;
truncate TABLE A1cFG_final_FirstPair;
truncate TABLE Visits_initial ;
truncate TABLE temp6;
truncate TABLE Visits_final_FirstPair;
truncate TABLE SulfonylureaByNames_initial;
truncate TABLE SulfonylureaByRXNORM_initial;
truncate TABLE AlGluInhByNames_init;
truncate TABLE AlGluInhByByRXNORM_init;
truncate TABLE GLP1AByNames_initial;
truncate TABLE GLP1AByRXNORM_initial;
truncate TABLE DPIVInhByNames_initial;
truncate TABLE DPIVInhByRXNORM_initial;
truncate TABLE MeglitinideByNames_initial;
truncate TABLE MeglitinideByRXNORM_initial;
truncate TABLE AmylByNames_init;
truncate TABLE AmylByRXNORM_init;
truncate TABLE InsulinByNames_initial;
truncate TABLE InsulinByRXNORM_initial;
truncate TABLE SGLT2InhByNames_initial;
truncate TABLE SGLT2InhByRXNORM_initial;
truncate TABLE InclusionMeds_final;
truncate TABLE BiguanideByNames_initial;
truncate TABLE BiguanideByRXNORM_initial;
truncate TABLE ThiazolByNames_init;
truncate TABLE ThiazolByRXNORM_init;
truncate TABLE GLP1AexByNames_initial;
truncate TABLE GLP1AexByRXNORM_initial;
truncate TABLE InclUnderRestrMeds_init;
truncate TABLE p1;
truncate TABLE p2;
truncate TABLE p3;
truncate TABLE p4;
truncate TABLE InclUnderRestrMeds_final;
truncate TABLE AllDM;
truncate TABLE Miscarr_Abort;
truncate TABLE Pregn_Birth;
truncate TABLE DelivProc;
truncate TABLE PregProc;
truncate TABLE AllPregnancyWithAllDates;
truncate TABLE DeltasPregnancy;
truncate TABLE NumberPregnancy;
truncate TABLE FinalPregnancy;
truncate TABLE FinalStatTable;

drop TABLE Denominator_initial;
drop TABLE Denomtemp0v;
drop TABLE Denomtemp1v;
drop TABLE Denomtemp2v;
drop TABLE DenominatorSummary;
drop TABLE DemographicVars;
drop TABLE A1c_initial;
drop TABLE temp1;
drop TABLE A1c_final_FirstPair;
drop TABLE FG_initial;
drop TABLE temp2;
drop TABLE FG_final_FirstPair;
drop TABLE RG_initial;
drop TABLE temp3;
drop TABLE RG_final_FirstPair;
drop TABLE temp4;
drop TABLE A1cRG_final_FirstPair;
drop TABLE temp5;
drop TABLE A1cFG_final_FirstPair;
drop TABLE Visits_initial ;
drop TABLE temp6;
drop TABLE Visits_final_FirstPair;
drop TABLE SulfonylureaByNames_initial;
drop TABLE SulfonylureaByRXNORM_initial;
drop TABLE AlGluInhByNames_init;
drop TABLE AlGluInhByByRXNORM_init;
drop TABLE GLP1AByNames_initial;
drop TABLE GLP1AByRXNORM_initial;
drop TABLE DPIVInhByNames_initial;
drop TABLE DPIVInhByRXNORM_initial;
drop TABLE MeglitinideByNames_initial;
drop TABLE MeglitinideByRXNORM_initial;
drop TABLE AmylByNames_init;
drop TABLE AmylByRXNORM_init;
drop TABLE InsulinByNames_initial;
drop TABLE InsulinByRXNORM_initial;
drop TABLE SGLT2InhByNames_initial;
drop TABLE SGLT2InhByRXNORM_initial;
drop TABLE InclusionMeds_final;
drop TABLE BiguanideByNames_initial;
drop TABLE BiguanideByRXNORM_initial;
drop TABLE ThiazolByNames_init;
drop TABLE ThiazolByRXNORM_init;
drop TABLE GLP1AexByNames_initial;
drop TABLE GLP1AexByRXNORM_initial;
drop TABLE InclUnderRestrMeds_init;
drop TABLE p1;
drop TABLE p2;
drop TABLE p3;
drop TABLE p4;
drop TABLE InclUnderRestrMeds_final;
drop TABLE AllDM;
drop TABLE Miscarr_Abort;
drop TABLE Pregn_Birth;
drop TABLE DelivProc;
drop TABLE PregProc;
drop TABLE AllPregnancyWithAllDates;
drop TABLE DeltasPregnancy;
drop TABLE NumberPregnancy;
drop TABLE FinalPregnancy;
drop TABLE FinalStatTable;

CREATE GLOBAL TEMPORARY TABLE Denominator_initial
  (PATID VARCHAR(128),
  ADMIT_DATE DATE,
  rn INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE Denomtemp0v
  (PATID VARCHAR(128),
  ADMIT_DATE DATE,
  rn INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE Denomtemp1v
  (PATID VARCHAR(128),
  NumerOfVisits int)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE Denomtemp2v
  (PATID VARCHAR(128),
  FirstVisit DATE)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE DenominatorSummary
  (PATID VARCHAR(128),
  FirstVisit DATE,
  NumerOfVisits INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE DemographicVars
  (PATID VARCHAR(128) NOT NULL,
  SEX VARCHAR(2) NULL,
  RACE VARCHAR(2) NULL,
  HISPANIC VARCHAR(2) NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE A1c_initial
  (PATID VARCHAR(128) NOT NULL,
  LAB_ORDER_DATE date NULL,
  rn INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE temp1
  (PATID VARCHAR(128) NOT NULL,
  LAB_ORDER_DATE date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE A1c_final_FirstPair
  (PATID VARCHAR(128) NOT NULL,
  EventDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE FG_initial
  (PATID VARCHAR(128) NOT NULL,
  LAB_ORDER_DATE date NULL,
  rn INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE temp2
  (PATID VARCHAR(128) NOT NULL,
  LAB_ORDER_DATE date NULL,
  rn INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE FG_final_FirstPair  
  (PATID VARCHAR(128) NOT NULL,
  LAB_ORDER_DATE date NULL,
  rn INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE RG_initial
  (PATID VARCHAR(128) NOT NULL,
  LAB_ORDER_DATE date NULL,
  rn INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE temp3
  (PATID VARCHAR(128) NOT NULL,
  LAB_ORDER_DATE date NULL,
  rn INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE RG_final_FirstPair
  (PATID VARCHAR(128) NOT NULL,
  EventDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE temp4
  (PATID VARCHAR(128) NOT NULL,
  RG_date date NULL,
  A1c_date date NULL,
  rn INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE A1cRG_final_FirstPair
  (PATID VARCHAR(128) NOT NULL,
  EventDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE temp5
  (PATID VARCHAR(128) NOT NULL,
  FG_date date NULL,
  A1c_date date NULL,
  rn INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE A1cFG_final_FirstPair
  (PATID VARCHAR(128) NOT NULL,
  EventDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE Visits_initial 
  (PATID VARCHAR(128) NOT NULL,
  ADMIT_DATE date NULL,
  rn INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE temp6
  (PATID VARCHAR(128) NOT NULL,
  ADMIT_DATE date NULL,
  rn INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE Visits_final_FirstPair
  (PATID VARCHAR(128) NOT NULL,
  EventDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE SulfonylureaByNames_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE SulfonylureaByRXNORM_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE AlGluInhByNames_init
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE AlGluInhByByRXNORM_init
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE GLP1AByNames_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE GLP1AByRXNORM_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE DPIVInhByNames_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE DPIVInhByRXNORM_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE MeglitinideByNames_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE MeglitinideByRXNORM_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE AmylByNames_init
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE AmylByRXNORM_init
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE InsulinByNames_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE InsulinByRXNORM_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE SGLT2InhByNames_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE SGLT2InhByRXNORM_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE InclusionMeds_final
  (PATID VARCHAR(128) NOT NULL,
  EventDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE BiguanideByNames_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE BiguanideByRXNORM_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE ThiazolByNames_init
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE ThiazolByRXNORM_init
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE GLP1AexByNames_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE GLP1AexByRXNORM_initial
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE InclUnderRestrMeds_init
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE p1
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE p2
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE p3
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE p4
  (PATID VARCHAR(128) NOT NULL,
  MedDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE InclUnderRestrMeds_final
  (PATID VARCHAR(128) NOT NULL,
  EventDate date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE AllDM
  (PATID VARCHAR(128) NOT NULL,
  ADMIT_DATE date NULL)
  on commit preserve rows;
 CREATE GLOBAL TEMPORARY TABLE Miscarr_Abort
  (PATID VARCHAR(128) NOT NULL,
  ADMIT_DATE date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE Pregn_Birth
  (PATID VARCHAR(128) NOT NULL,
  ADMIT_DATE date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE DelivProc
  (PATID VARCHAR(128) NOT NULL,
  ADMIT_DATE date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE PregProc
  (PATID VARCHAR(128) NOT NULL,
  ADMIT_DATE date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE AllPregnancyWithAllDates
  (PATID VARCHAR(128) NOT NULL,
  ADMIT_DATE date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE DeltasPregnancy
  (PATID VARCHAR(128) NOT NULL,
  ADMIT_DATE date NULL,
  dif INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE NumberPregnancy
  (PATID VARCHAR(128) NOT NULL,
  ADMIT_DATE date NULL,
  rn INT)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE FinalPregnancy
  (PATID VARCHAR(128) NOT NULL, 
  PregnancyDate_1 date NULL, 
  PregnancyDate_2 date NULL, 
  PregnancyDate_3 date NULL, 
  PregnancyDate_4 date NULL, 
  PregnancyDate_5 date NULL,
  PregnancyDate_6 date NULL, 
  PregnancyDate_7 date NULL, 
  PregnancyDate_8 date NULL, 
  PregnancyDate_9 date NULL, 
  PregnancyDate_10 date NULL,
  PregnancyDate_11 date NULL, 
  PregnancyDate_12 date NULL, 
  PregnancyDate_13 date NULL, 
  PregnancyDate_14 date NULL, 
  PregnancyDate_15 date NULL,
  PregnancyDate_16 date NULL, 
  PregnancyDate_17 date NULL, 
  PregnancyDate_18 date NULL, 
  PregnancyDate_19 date NULL, 
  PregnancyDate_20 date NULL,
  PregnancyDate_21 date NULL)
  on commit preserve rows;
CREATE GLOBAL TEMPORARY TABLE FinalStatTable
  (PATID VARCHAR(128) NOT NULL, 
  FirstVisit date NULL, 
  NumberOfVisits INT, 
  DMonsetDate date NULL, 
  DEATH_DATE date NULL,
  PregnancyDate_1 date NULL, 
  PregnancyDate_2 date NULL, 
  PregnancyDate_3 date NULL, 
  PregnancyDate_4 date NULL, 
  PregnancyDate_5 date NULL,
  PregnancyDate_6 date NULL, 
  PregnancyDate_7 date NULL, 
  PregnancyDate_8 date NULL, 
  PregnancyDate_9 date NULL, 
  PregnancyDate_10 date NULL,
  PregnancyDate_11 date NULL, 
  PregnancyDate_12 date NULL, 
  PregnancyDate_13 date NULL, 
  PregnancyDate_14 date NULL, 
  PregnancyDate_15 date NULL,
  PregnancyDate_16 date NULL, 
  PregnancyDate_17 date NULL, 
  PregnancyDate_18 date NULL, 
  PregnancyDate_19 date NULL, 
  PregnancyDate_20 date NULL,
  PregnancyDate_21 date NULL)
  on commit preserve rows;
COMMIT;
