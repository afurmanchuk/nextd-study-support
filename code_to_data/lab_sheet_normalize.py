r'''lab_sheet_normalize -- normalize lab curation spreadsheets

Normalizing Spread Sheet Columns to Record Fields
-------------------------------------------------

Lab audit spreadsheets have been shared with site info in the same
column as lab name::

    >>> sheetA = """
    ... gpc,,
    ... c_name,c_totalnum,c_basecode
    ... Hgb A1c MFr.DF Bld (71875-9),,LOINC:71875-9
    ... mcw,,
    ... c_name,c_totalnum,c_basecode
    ... HEMOGLOBIN A1C WB (LOINC:17856-6),0,LOINC:17856-6
    ... """.strip()

    >>> sheetG = """
    ... mcw,,
    ... c_name,c_totalnum,c_basecode
    ... GLUCOSE FASTING (LOINC:1558-6),6009,LOINC:1558-6
    ... """.strip()

    >>> sheetA = [line.split(',') for line in sheetA.split('\n')]
    >>> sheetG = [line.split(',') for line in sheetG.split('\n')]

We can normalize this so that site info is its own field on each
record::

    >>> labsA = list(Term.from_sheet('A1c', sheetA))
    >>> labsG = list(Term.from_sheet('Glucose', sheetG))
    >>> labsA
    ... # doctest: +NORMALIZE_WHITESPACE
    [Term(sheet='A1c', site='gpc', c_name='Hgb A1c MFr.DF Bld (71875-9)',
          c_totalnum=None, c_basecode='LOINC:71875-9', category=None),
     Term(sheet='A1c', site='mcw', c_name='HEMOGLOBIN A1C WB (LOINC:17856-6)',
          c_totalnum=0, c_basecode='LOINC:17856-6', category=None)]


Which codes from Babel should be used in NEXT-D?
------------------------------------------------

Meanwhile, the SQL code has lists of codes we should use::

    >>> from code_to_data import Table1Script
    >>> glucose_codes = Table1Script.glucose_codes()
    >>> sorted(glucose_codes['loinc_fasting_glucose'])[:5]
    ['10450-5', '14769-4', '14770-2', '14771-0', '1493-6']

But that code should be changed to match the Dec comments on `ticket
551`__. We have those comments parsed and we can use them to
categorize records based on their `c_name` and `c_basecode`::

    >>> LabReview.a1c_loinc[:3]
    ['4547-6', '17855-8', '17856-6']

    >>> [LabReview.category(lab.c_name, lab.c_basecode)
    ...  for lab in (labsA + labsG)]
    ['', 'A1c', 'Fasting Glucose']

__ https://informatics.gpcnetwork.org/trac/Project/ticket/551

The `normal_form` function does this for all records in the original
(Dec 2016) Babel audit:

    >>> lab_terms = BabelAudit.normal_form()
    >>> site_codes = set(t.c_basecode[len('LOINC:'):]
    ...                  for t in lab_terms if t.c_basecode)
    >>> sorted(site_codes)[:5]
    ['10449-7', '10450-5', '10832-4', '10966-0', '10967-8']


The SQL code lists are strict subsets of the raw Babel audit list:

    >>> print(_compare(glucose_codes['loinc_random_glucose'],
    ...                site_codes, width=44))
    size: 79 vs. 846
    added 0:
    (None)
    pruned 767:
    10450-5, 10832-4, 10966-0, 10967-8, 10968-6,

    >>> print(_compare(glucose_codes['loinc_fasting_glucose'],
    ...                site_codes, width=62))
    size: 22 vs. 846
    added 0:
    (None)
    pruned 824:
    10449-7, 10832-4, 10966-0, 10967-8, 10968-6, 11032-0, 11047-8,


Meanwhile, several codes were added in the Dec comments::

    >>> print(_compare(LabReview.random_glucose_loinc,
    ...                glucose_codes['loinc_random_glucose'], width=55))
    size: 32 vs. 79
    added 21:
    12610-2, 12646-6, 1504-0, 1506-5, 1517-2, 1530-5, 20436
    pruned 68:
    12614-4, 14743-9, 14760-3, 14761-1, 14768-6, 14769-4, 1

    >>> print(_compare(LabReview.fasting_glucose_loinc,
    ...                glucose_codes['loinc_fasting_glucose'], width=55))
    size: 15 vs. 22
    added 1:
    1555-2
    pruned 8:
    1500-8, 1523-0, 21004-7, 35184-1, 40193-5, 53049-3, 628


Dr. K followed up Apr 5 by annotating the Babel audit spreadheet:

    >>> lab_ANK = [
    ...     LabNotes.categorize(l) for l in
    ...     BabelAudit.normal_form(labs=BabelAudit.labs2)]
    >>> lab_ANK[0]
    ... # doctest: +NORMALIZE_WHITESPACE
    Term(sheet='A1c', site='gpc', c_name='Hgb A1c MFr Bld Calc (17855-8)',
         c_totalnum=None, c_basecode='LOINC:17855-8', category='A1c')

    >>> a1c_ank = set(t.c_basecode[len('LOINC:'):]
    ...               for t in lab_ANK if t.category == 'A1c')
    >>> g_f_ank = set(t.c_basecode[len('LOINC:'):]
    ...               for t in lab_ANK if t.category == 'Fasting Glucose')
    >>> g_r_ank = set(t.c_basecode[len('LOINC:'):]
    ...               for t in lab_ANK if t.category == 'Random Glucose')

    >>> print(', '.join(sorted(a1c_ank)))
    ... # doctest: +NORMALIZE_WHITESPACE
    17855-8, 17856-6, 41995-2, 4548-4, 4549-2, 54039-3, 59261-8,
    62388-4, 71875-9, LP100945-7, LP16413-4

    >>> print(', '.join(sorted(g_f_ank)))
    14771-0, 1558-6

    >>> print(', '.join(sorted(g_r_ank)))
    2339-0, 2339-0:N, 2339-0:T, 2344-0, 2345-7, 54246-4, 6777-7

We can compare the results with the Dec comments::

    >>> print(_compare(a1c_ank, LabReview.a1c_loinc))
    ... # doctest: +NORMALIZE_WHITESPACE
    size: 11 vs. 10
    added 3:
    54039-3, 71875-9, LP100945-7
    pruned 2:
    4547-6, OINC codes: 'LP100945-7

    >>> print(_compare(g_f_ank, LabReview.fasting_glucose_loinc))
    ... # doctest: +NORMALIZE_WHITESPACE
    size: 2 vs. 15
    added 0:
    (None)
    pruned 13:
    10450-5, 14769-4, 14770-2, 1493-6,
    1550-3, 1554-5, 1555-2, 1556-0, 1557-8,
    17865-7, 41604-0, 76629-5, 77145-1


    >>> print(_compare(g_r_ank, LabReview.random_glucose_loinc))
    ... # doctest: +NORMALIZE_WHITESPACE
    size: 7 vs. 32
    added 2:
    2344-0, 54246-4
    pruned 27:
    10449-7, 12610-2, 12646-6, 14749-6,
    1504-0, 1506-5, 1517-2, 1521-4, 1530-5,
    20436-2, 2342-4, 26779-9, 27353-2, 43151-0,
    50586-7, 50587-5, 50588-3, 50589-1, 50608-9, 50673-3, 53553-4, 55399-0,
    72171-2, 81637-1, LP31895-3, LP42107-0, LP71758-4

'''

import csv
from collections import namedtuple
from io import StringIO

import pkg_resources as pkg


def main(argv, stdout):
    if '--2016-12' in argv:
        labs = BabelAudit.normal_form()
        labs = [
            lab._replace(
                category=LabReview.category(
                    lab.c_name, lab.c_basecode))
            for lab in labs]
    else:
        labs = [
            LabNotes.categorize(l) for l in
            BabelAudit.normal_form(labs=BabelAudit.labs2)
        ]
    export(stdout, Term._fields, labs)


def export(wr, cols, rows):
    out = csv.writer(wr)
    out.writerow(cols)
    out.writerows(rows)


class Term(namedtuple('Term',
                      ['sheet', 'site',
                       'c_name', 'c_totalnum', 'c_basecode',
                       'category'])):
    @classmethod
    def from_sheet(cls, sheet, rows):
        site = None
        for row in rows:
            col_a, col_b, col_c = row[:3]
            if col_c == '':
                site = col_a
                continue
            elif col_b == 'c_totalnum':
                continue
            else:
                yield cls(sheet, site,
                          col_a, _null(col_b, int), _null(col_c),
                          row[3:] or None)


def _null(s, ty=str):
    if s in ('', r'\N'):
        return None
    return ty(s)


class BabelAudit(object):
    A1C = pkg.resource_string(
        __name__, 'LOINC-search-Across-GPC-sites-2017-01-06-A1c.csv')
    glucose = pkg.resource_string(
        __name__, 'LOINC-search-Across-GPC-sites-2017-01-06-glucose.csv')

    labs = {'A1c': A1C,
            'Glucose': glucose}

    A1C2 = pkg.resource_string(
        __name__, 'LOINC-search-Across-GPC-sites-2017-04-05_ANK-A1c.csv')
    glucose2 = pkg.resource_string(
        __name__, 'LOINC-search-Across-GPC-sites-2017-04-05_ANK-glucose.csv')

    labs2 = {'A1c': A1C2,
             'Glucose': glucose2}

    @classmethod
    def normal_form(cls,
                    labs=labs):
        terms = []
        for lab in sorted(labs.keys()):
            rows = cls.csv_rows(lab, labs=labs)
            terms.extend(Term.from_sheet(lab, rows))
        return terms

    @classmethod
    def csv_rows(cls, lab,
                 labs=labs):
        with StringIO(labs[lab].decode('utf-8')) as data:
            rows = csv.reader(data)
            for row in rows:
                yield row


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
    def category(cls, c_name, c_basecode):
        if not (c_basecode or '').startswith('LOINC:'):
            return ''
        loinc_code = c_basecode[len('LOINC:'):]
        random = ('Random Glucose'
                  if loinc_code in cls.random_glucose_loinc
                  else '')
        fasting = ('Fasting Glucose'
                   if loinc_code in cls.fasting_glucose_loinc
                   else '')

        a1c = ('A1c' if loinc_code in cls.a1c_loinc
               else '')

        # return all 3 to detect overlap
        return a1c + random + fasting


class LabNotes(object):
    ok_A1c = [
        'Preferred',
        'OK',
        'NOT preferred but acceptable',
    ]

    ok_glucose = [
        'Yes',
        'allowable for now',
        # "We should discuss if we want to include point of
        # care glucose measurements, my inclination at the
        # start is NO."
        'Probably OK',
    ]

    @classmethod
    def categorize(cls, term):
        [note, fasting] = term.category[1:3]

        if not (term.c_basecode or '').startswith('LOINC:'):
            category = None
        elif (term.sheet == 'Glucose' and note in cls.ok_glucose):
            category = ('Fasting Glucose' if fasting == 'Fasting'
                        else 'Random Glucose')
        elif term.sheet == 'A1c':
            ok = (note in cls.ok_A1c or
                  ((term.c_totalnum or 0) > 0 and not note))
            category = 'A1c' if ok else None
        else:
            category = None
        return term._replace(category=category)


def _show(codes):
    print(', '.join(sorted(codes)))


def _compare(exp_items, control_items,
             width=None):
    exp_items = set(exp_items)
    control_items = set(control_items)
    added = sorted(exp_items - control_items)
    pruned = sorted(control_items - exp_items)
    return '\n'.join([
        'size: %s vs. %s' % (
            len(exp_items), len(control_items)),
        'added %s:' % len(added),
        ', '.join(added)[:width] if added else '(None)',
        'pruned %s:' % len(pruned),
        ', '.join(pruned)[:width] if pruned else '(None)'])


if __name__ == '__main__':
    def _script():
        from sys import argv, stdout
        main(argv, stdout)

    _script()
