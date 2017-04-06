r'''lab_sheet_normalize -- normalize lab curation spreadsheets

>>> from pprint import pprint

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

>>> labsA = list(Term.from_sheet('A1c', sheetA))
>>> labsA
... # doctest: +NORMALIZE_WHITESPACE
[Term(sheet='A1c', site='gpc', c_name='Hgb A1c MFr.DF Bld (71875-9)',
      c_totalnum=None, c_basecode='LOINC:71875-9', category=None),
 Term(sheet='A1c', site='mcw', c_name='HEMOGLOBIN A1C WB (LOINC:17856-6)',
      c_totalnum=0, c_basecode='LOINC:17856-6', category=None)]

>>> labsG = list(Term.from_sheet('glucose', sheetG))

>>> [LabReview.category(lab.c_name, lab.c_basecode)
...  for lab in (labsA + labsG)]
['', 'A1C', 'fasting glucose']

'''

import csv
from collections import namedtuple
from io import StringIO

import pkg_resources as pkg

from code_to_data import LabReview


def main(argv, stdout):
    labs = BabelAudit.normal_form()
    labs = [
        lab._replace(
            category=LabReview.category(
                lab.c_name, lab.c_basecode))
        for lab in labs]
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

    labs = {'A1C': A1C,
            'glucose': glucose}

    @classmethod
    def normal_form(cls):
        terms = []
        for lab in sorted(cls.labs.keys()):
            rows = cls.csv_rows(lab)
            terms.extend(Term.from_sheet(lab, rows))
        return terms

    @classmethod
    def csv_rows(cls, lab):
        with StringIO(cls.labs[lab].decode('utf-8')) as data:
            rows = csv.reader(data)
            for row in rows:
                yield row


if __name__ == '__main__':
    def _script():
        from sys import argv, stdout
        main(argv, stdout)

    _script()
