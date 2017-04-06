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

>>> list(BabelAudit.reviewable_form({}))[:5]
... # doctest: +NORMALIZE_WHITESPACE
[['lab', 'site', 'c_name', 'c_totalnum', 'c_basecode'],
 ['A1C', '', '', '', ''],
 ['', 'gpc', '', '', ''],
 ['', '', 'Hgb A1c MFr Bld Calc (17855-8)', '\\N', 'LOINC:17855-8'],
 ['', '', 'Hgb A1c MFr Bld HPLC (17856-6)', '\\N', 'LOINC:17856-6']]

'''

import csv
from collections import namedtuple
from io import StringIO

import pkg_resources as pkg

from code_to_data import LabReview


def main(argv, stdout):
    if '--pretty' in argv:
        out = csv.writer(stdout)
        lab_review = {'A1C': LabReview.A1C,
                      'glucose': LabReview.glucose}
        for info in BabelAudit.reviewable_form(lab_review):
            out.writerow(info)
    else:
        terms = BabelAudit.normal_form()
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

    @classmethod
    def reviewable_form(cls, predicates):
        hd = list(Term._fields)
        hd = hd[:1] + sorted(predicates.keys()) + hd[1:]
        yield hd
        filler = [''] * len(hd)

        pred_funs = [fun for _n, fun
                     in sorted(predicates.items())]
        for lab in sorted(cls.labs.keys()):
            yield [lab] + filler[1:]
            for row in cls.csv_rows(lab):
                col_a, col_b, col_c = row
                if col_b == '':
                    site = col_a
                    yield [''] + filler[1:-4] + [site, '', '', '']
                elif col_b == 'c_totalnum':
                    pass
                else:
                    yield ([''] +
                           [p(col_a, col_c)
                            for p in pred_funs] +
                           ['', col_a, col_b, col_c])


if __name__ == '__main__':
    def _script():
        from sys import argv, stdout
        main(argv, stdout)

    _script()
