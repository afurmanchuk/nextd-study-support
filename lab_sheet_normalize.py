r'''lab_sheet_normalize -- normalize lab curation spreadsheets

>>> sheet = """
... mcw,,
... c_name,c_totalnum,c_basecode
... HEMOGLOBIN A1C WB (LOINC:17856-6),0,LOINC:17856-6
... GHBA1C (Group:GHBA1C),95421,LOINC:4548-4
... """.strip()
>>> sheet = [line.split(',') for line in sheet.split('\n')]

>>> list(Term.from_sheet('A1c', sheet))
... # doctest: +NORMALIZE_WHITESPACE
[Term(lab='A1c', site='mcw', c_name='HEMOGLOBIN A1C WB (LOINC:17856-6)',
      c_totalnum=0, c_basecode='LOINC:17856-6'),
 Term(lab='A1c', site='mcw', c_name='GHBA1C (Group:GHBA1C)',
      c_totalnum=95421, c_basecode='LOINC:4548-4')]

'''

import csv
from collections import namedtuple

SHEETS = {
    'A1C': 'LOINC-search-Across-GPC-sites-2017-01-06-A1c.csv',
    'glucose': 'LOINC-search-Across-GPC-sites-2017-01-06-glucose.csv'}


def main(stdout, cwd):
    terms = []
    for lab, fn in SHEETS.items():
        with (cwd / fn).open('r') as data:
            terms.extend(Term.from_sheet(lab, csv.reader(data)))
    export(stdout, Term._fields, terms)


def export(wr, cols, rows):
    out = csv.writer(wr)
    out.writerow(cols)
    out.writerows(rows)


class Term(namedtuple('Term',
                      ['lab', 'site', 'c_name', 'c_totalnum', 'c_basecode'])):
    @classmethod
    def from_sheet(cls, lab, rows):
        site = None
        for row in rows:
            col_a, col_b, col_c = row
            if col_b == '':
                site = col_a
                continue
            elif col_b == 'c_totalnum':
                continue
            else:
                yield cls(lab, site, col_a, _null(col_b, int), _null(col_c))


def _null(s, ty=str):
    if s == r'\N':
        return None
    return ty(s)


if __name__ == '__main__':
    def _script():
        from pathlib import Path
        from sys import stdout
        main(stdout, cwd=Path('.'))

    _script()
