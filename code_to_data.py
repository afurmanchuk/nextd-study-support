'''

Get codes used in glucose_concepts SQL view:

>>> glucose_codes = GlucoseConcepts.codes()


Get all LOINC codes from the babel audit:

>>> from lab_sheet_normalize import BabelAudit
>>> lab_terms = BabelAudit.normal_form()
>>> site_codes = set((t.c_basecode or '')[len('LOINC:'):] for t in lab_terms)


Compare SQL code to babel audit data:

>>> sorted(glucose_codes['loinc_random_glucose'] - site_codes)
[]

>>> sorted(glucose_codes['loinc_fasting_glucose'] - site_codes)
[]

Compare recent comments to babel audit data:
(comments from https://informatics.gpcnetwork.org/trac/Project/ticket/551)

>>> set(FASTING_GLUCOSE_LOINC_CODES_5) - site_codes
set()

>>> sorted(set(RANDOM_GLUCOSE_LOINC_CODES_6) - site_codes)
['50673-3', '55399-0', 'LP31895-3']


Compare recent comments to SQL code:

>>> set(FASTING_GLUCOSE_LOINC_CODES_5) - glucose_codes['loinc_fasting_glucose']
{'1555-2'}

>>> sorted(set(RANDOM_GLUCOSE_LOINC_CODES_6) -
...        set(glucose_codes['loinc_random_glucose']))
... # doctest: +NORMALIZE_WHITESPACE
['12610-2', '12646-6', '1504-0', '1506-5', '1517-2', '1530-5',
 '20436-2', '2339-0:N', '2339-0:T', '2342-4', '26779-9',
 '50586-7', '50587-5', '50588-3', '50589-1', '50608-9',
 '50673-3', '55399-0', '81637-1', 'LP31895-3', 'LP42107-0']


'''

import pkg_resources as pkg


class GlucoseConcepts(object):
    sql_lines = (pkg.resource_string(
        __name__, 'NextDvariableExtractionOracleTable1GPC.sql')
                 .decode('utf-8').split('\n'))

    [fasting_ix, random_ix] = [
        ix for ix, l in enumerate(sql_lines)
        if 'where l.LAB_LOINC in' in l]
    glucose_lines = {
        sql_lines[fasting_ix - 2].split()[1]: sql_lines[fasting_ix],
        sql_lines[random_ix - 2].split()[1]: sql_lines[random_ix]
    }

    @classmethod
    def codes(cls):
        insides = [
            (alias, _parens(cls.glucose_lines[alias]))
            for alias in ['loinc_fasting_glucose', 'loinc_random_glucose']]
        return dict(
            (alias, set(part.strip()[1:-1] for part in inside.split(',')))
            for alias, inside in insides)


def _parens(txt):
    return txt.split('(')[1].split(')')[0]


# comment:1 Dec 19 2016
# ... KUMC has no data under any of the ​LOINC codes in the current code:
LOINC_1 = ['1558-6', '1493-6', '10450-5', '1554-5', '17865-7', '14771-0',
           '77145-1', '1500-8', '1523-0', '1550-3', '14769-4']

# Here at KUMC, I found a large number of fasting glucose lab results
# under a KU-hospital-specific code that is mapped to LOINC as Glucose
# SerPl-mCnc (2345-7), but 2345-7 doesn't distinguish fasting from
# eating.
KUH_1 = ('Glucose SerPl-mCnc', '2345-7')

# comment:5 Dec 20
# Hemoglobin A1c definition for GPC sides without PCORNET CDM:
# LOINC codes:
A1C_LOINC_5 = ['4547-6', '17855-8', '17856-6', '4548-4', '4549-2', '62388-4',
               '41995-2', '59261-8', '41995-2']
A1C_NAMES_5 = [
    'Hemoglobin A1c', 'HBAC', 'Glycated Hemoglobin',
    'GLYCOHEMOGLOBIN', 'HbA1C for Type 1 Diabetes (250.01)',
    'HbA1C for Type 2 Diabetes (250.00)',
    'Hemoglobin A1C', 'Hemoglobin A1C (Glycohemoglobin)', 'HEMOGLOBIN A1C',
    'Glycated Hemoglobin', 'Hemoglobin A1C', 'Hgb A1c SFr Bld', 'HGB A1C',
    'Hgb A1c MFr Bld',
    'Hemoglobin a1c/hemoglobin.total in blood',
    'Hemoglobin A1c/Hemoglobin.total:MFr:Pt:Bld:Qn',
    'Hemoglobin A1c/Hemoglobin.total in Blood by HPLC',
    'Hemoglobin A1c/Hemoglobin.total',
    'Hgb A1c MFr Bld Calc', 'Hgb A1c Bld-mCnc', 'Hgb A1 MFr Bld',
    'Hgb A1c MFr Bld',
    'Hgb A1c MFr Bld Elph', 'Hgb A1c Bld', 'Hgb A1c SFr Bld IFCC',
    'Hgb A1c MFr Bld JDS/JSCC',
    'Hgb A1c MFr.DF Bld', 'Hgb A Bld Elph-aCnc']

# units: %

# Note: make sure check for units, some HbA1c labs could be measured
# in g/dL. For those (if present) conversion to percents must be done.

FASTING_GLUCOSE_LOINC_CODES_5_BY_UNITS = {
    # for labs measured in mg/DL:
    'mg/DL': [
        '1493-6', '1556-0', '10450-5', '1554-5', '1555-2', '17865-7',
        '1556-0', '41604-0', '1557-8', '1558-6', '1550-3', '41604-0'],
    # analogues codes for measurements done in mmol/L:
    'mmol/L': [
        '14770-2', '14771-0', '76629-5', '77145-1', '14769-4']}

FASTING_GLUCOSE_LOINC_CODES_5 = [
    code
    for units, codes in FASTING_GLUCOSE_LOINC_CODES_5_BY_UNITS.items()
    for code in codes]

FASTING_GLUCOSE_NAMES_5 = [
    'GLUF', 'RUGLUF', 'GLUF', 'GLUCOSE TOLERANCE 2 HR 75G',
    'GLUCOSE TOLERANCE 2 HR 75G WITH 1 HR',
    'Gluc Tolerance - Fasting', 'GLUCOSE TOLERANCE 3 HR', 'Glucose Fasting',
    '_RUO Glucose Fasting',
    'Fasting glucose [Mass/volume] in Capillary blood',
    'Glucose [Mass/volume] in Serum or Plasma --1.5 hours post 0.05-0.15 U insulin/kg IV 12 hours fasting',  # noqa
    'Glucose [Mass/volume] in Serum or Plasma --12 hours fasting',
    'Glucose [Mass/volume] in Urine --12 hours fasting',
    'Glucose [Mass/volume] in Serum or Plasma --10 hours fasting',
    'Glucose [Mass/volume] in Serum or Plasma --8 hours fasting',
    'Fasting glucose [Mass/volume] in Capillary blood',
    'Fasting glucose [Mass/volume] in Capillary blood by Glucometer',
    'Fasting glucose [Mass/volume] in Venous blood',
    'Fasting glucose [Mass/volume] in Serum or Plasma',
    'Glucose [Mass/volume] in Serum or Plasma --pre 12 hour fast',
    'Fasting glucose [Moles/volume] in Blood',
    'Fasting glucose [Moles/volume] in Serum, Plasma or Blood']

# Notes: Values should be converted if lab results are reported in
# mmol/L.  It is OK not to have fasting glucose records, since some
# places will record such measurements under random glucose codes.


# comment:6 Dec 22

#  With babel account I was able to find records in following sources:
#  mcw_terms, uiowa_terms, and uthscsa_terms.

# The following should be added to earlier posted lists:
A1C_LOINC_codes_6 = ['LP100945-7', 'LP16413-4']
A1C_NAMES_6 = ['Hemoglobin A1c | Bld-Ser-Plas', 'Hemoglobin A1c']

RANDOM_GLUCOSE_LOINC_CODES_6 = [
    '10449-7', '12610-2', '12646-6', '1504-0', '1506-5', '1517-2', '1521-4',
    '1530-5', '20436-2', '2339-0', '2339-0:N', '2339-0:T', '2342-4', '2345-7',
    '27353-2', '6777-7', 'LP42107-0', 'LP71758-4', '14749-6', '55399-0',
    '27353-2', '50588-3', 'LP31895-3', '72171-2', '50586-7', '50608-9',
    '50587-5', '50588-3', '50589-1', '50673-3', '50608-9', '81637-1',
    '72171-2', '26779-9', '43151-0', '50608-9', '50586-7', '53553-4',
    '50589-1']

RANDOM_GLUCOSE_NAMES_6 = [
    'Est. average glucose Bld gHb Est-mCnc',
    'Glucose 1h p meal SerPl?-mCnc',
    'Glucose 2h p chal SerPl?-mCnc', 'Glucose 1h p chal SerPl?-mCnc',
    'Glucose 1h p 50 g Glc PO SerPl?-mCnc',
    'Glucose 1h p 50 g Lac PO SerPl?-mCnc',
    'Glucose 2h p 50 g Lac PO SerPl?-mCnc',
    'GLUCOSE, 2 HR POST PRANDIAL',
    'Glucose 2h p meal SerPl?-mCnc',
    'Glucose 3h p 100 g Glc PO SerPl?-mCnc',
    'Glucose 2h p Glc SerPl?-mCnc',
    'Glucose Bld-mCnc',
    'Glucose Bld-mCnc (Numeric)',
    'Glucose Bld-mCnc (Text)',
    'CSF Glucose (Group:CSF-GLU)',
    'GLUCOSE-CSF',
    'Glucose SerPl?-mCnc',
    'EST AVG GLUCOSE',
    'Est. average glucose Bld gHb Est-mCnc',
    'GLUCOSE',
    'Glucose (Group:GLU)',
    'Glucose | Bld-Ser-Plas',
    'Estimated average glucose | Bld-Ser-Plas',
    'CHEMP', 'GLU CP', 'KIDP', 'SGLU', 'GLU', 'SBAMET', 'SCHEM', 'SRENAL',
    'Glucose 1 Hour', '_RUO Glucose 1 HR', 'BASIC CHEMISTRY PANEL',
    'BASIC METABOLIC PANEL W/ CA (SERUM)', 'Basic Metabolic Panel, Serum (OP)',
    'Chemistry Panel, Basic',
    'Chemistry Panel, Kidney',
    'Chemistry Panel,Basic',
    'Comprehen Metabolic Panel',
    'Comprehensive Metabolic Panel, Serum',
    'Comprehensive Metabolic Panel, Serum (OP)',
    'Glucose Level, Serum',
    'GLUCOSE TOLERANCE 3 HR',
    'Metabolic Panel, Comprehensive',
    'Renal Profile (Serum)', 'Glucose 3 Hour', 'Basic Chem 8 (NMPG)',
    'Basic Metabolic Panel',
    'Basic Metabolic Panel',
    'BMP', 'Chem 8', 'Chemistry Panel, Comp V70.0', 'CHEMP',
    'COMPREHENSIVE METABOLIC PANEL (SERUM)',
    'GLUCOSE LEVEL 30 MINS POST-STIM',
    'GLUCOSE LEVEL CRITICAL POINT', 'Glucose Level V77.1',
    'GLUCOSE TOLERANCE 2 HR 75G', 'GLUCOSE TOLERANCE 2 HR 75G WITH 1 HR',
    'RENAL CHEMISTRY PANEL SERUM',
    'Glucose 2 Hour', 'Glucose 2 HRS', 'Chem 14',
    'Chemistry Panel, Comprehensive Metabolic (tag: CMP',
    'COMPREHENSIVE CHEM PANEL', 'GLUCOSE 1 HR POST PRANDIAL',
    'GLUCOSE 2 HR POST PRANDIAL', 'Glucose 2HR Tolerance', 'Glucose Level',
    'Glucose Level - 1Hr PP', 'GLUCOSE LEVEL 120 MINS POST-STIM',
    'GLUCOSE LEVEL 60 MINS POST-STIM', 'GLUCOSE LEVEL FASTING OR RANDOM',
    'Glucose Level, 2Hr PP', 'Kidney Chemistry Panel', 'Glucose 2 HR',
    'Basic Metabolic Panel, Serum', 'CCP1 (Comp Chem)',
    'Chemistry Panel Comprehensive, Serum', 'Chemistry Panel, Basic',
    'Chemistry Panel, Comprehensive Metabolic',
    'Comprehensive Chemistry Panel',
    'Comprehensive Metabolic Panel', 'Glucose Level - 2Hr PP',
    'GLUCOSE LEVEL 90 MINS POST-STIM',
    'Glucose Level, Plasma (Outreach order Glucose, Ser',
    'RENAL FUNCTION PANEL'
    ]

# Units: mg/DL

# Notes: For glucose tests LOINC codes alone are not sufficient. Lab
# names should be second parameter for selection.

# Exclude tests that are clearly marked as Obstetrics and
# Gynecology. Such test name most likely will have OB abbreviation in
# it.

# Exclude cerebrospinal fluids and urine tests. Urine glucose testing
# is a screening tool, but it is not sensitive enough for diagnosis or
# monitoring.
