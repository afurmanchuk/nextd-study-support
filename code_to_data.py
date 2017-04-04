'''

Get codes used in glucose_concepts SQL view:

>>> glucose_codes = Table1Script.glucose_codes()


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

>>> set(LabReview.fasting_glucose_loinc) - site_codes
set()

>>> sorted(set(LabReview.random_glucose_loinc) - site_codes)
['50673-3', '55399-0', 'LP31895-3']


Compare recent comments to SQL code:

>>> set(LabReview.fasting_glucose_loinc) - glucose_codes['loinc_fasting_glucose']  # noqa
{'1555-2'}

>>> sorted(set(LabReview.random_glucose_loinc) -
...        set(glucose_codes['loinc_random_glucose']))
... # doctest: +NORMALIZE_WHITESPACE
['12610-2', '12646-6', '1504-0', '1506-5', '1517-2', '1530-5',
 '20436-2', '2339-0:N', '2339-0:T', '2342-4', '26779-9',
 '50586-7', '50587-5', '50588-3', '50589-1', '50608-9',
 '50673-3', '55399-0', '81637-1', 'LP31895-3', 'LP42107-0']


'''

import pkg_resources as pkg


class Table1Script(object):
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
    def glucose_codes(cls):
        insides = [
            (alias, _parens(cls.glucose_lines[alias]))
            for alias in ['loinc_fasting_glucose', 'loinc_random_glucose']]
        return dict(
            (alias, set(_values(inside)))
            for alias, inside in insides)


def _parens(txt):
    '''
    >>> _parens('where x in (a, b, c)')
    'a, b, c'
    '''
    return txt.split('(')[1].split(')')[0]


def _values(txt):
    '''
    >>> _values("'4547-6','17855-8', '17856-6'")
    ['4547-6', '17855-8', '17856-6']
    '''
    return [part.strip()[1:-1] for part in txt.split(',')]


class LabReview(object):
    comment_5 = (pkg.resource_string(
        __name__, 'ticket_551_comment_5.txt')
                 .decode('utf-8').split('\n'))

    comment_6 = (pkg.resource_string(
        __name__, 'ticket_551_comment_6.txt')
                 .decode('utf-8').split('\n'))

    a1c_loinc = _values(
        ' '.join(l for l in comment_5 if "'4547-6'" in l) + ', ' +
        ' '.join(l for l in comment_6 if "'LP100945-7'" in l))
    fasting_glucose_loinc = _values(
        ' '.join(l for l in comment_5 if "'1493-6'" in l or
                 "'14770-2'" in l))
    random_glucose_loinc = _values(
        ' '.join(l for l in comment_6 if "'10449-7'" in l))

    @classmethod
    def glucose(cls, c_name, c_basecode):
        if not c_basecode.startswith('LOINC:'):
            return ''
        loinc_code = c_basecode[len('LOINC:'):]
        random = ('random'
                  if loinc_code in cls.random_glucose_loinc
                  else '')
        fasting = ('fasting'
                   if loinc_code in cls.fasting_glucose_loinc
                   else '')

        return random + fasting

    @classmethod
    def A1C(cls, c_name, c_basecode):
        if not c_basecode.startswith('LOINC:'):
            return ''
        loinc_code = c_basecode[len('LOINC:'):]
        return ('A1C' if loinc_code in cls.a1c_loinc
                else '')
