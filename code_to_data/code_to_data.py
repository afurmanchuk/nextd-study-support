'''code_to_data: migrate tabular data out of SQL code

Labs
====

Get codes used in glucose_concepts SQL view:

    >>> glucose_codes = Table1Script.glucose_codes()
    >>> sorted(glucose_codes['loinc_fasting_glucose'])[:5]
    ['10450-5', '14769-4', '14770-2', '14771-0', '1493-6']


Medications
===========

.. note:: These tests are obsolete since the hard-coded inserts have been
          replaced by use of med_info.

Medication codes are managed in long hard-coded lists in insert statements::

    >>. from pprint import pprint
    >>. for _s, dest, stmt in Table1Script.med_inserts():
    ...     if 'RXNORM' in stmt:
    ...         print(stmt)
    ... # doctest: +NORMALIZE_WHITESPACE +ELLIPSIS
    insert into SulfonylureaByRXNORM_initial
    select ds.PATID, a.RX_ORDER_DATE as MedDate
      from DenominatorSummary ds
      join "&&PCORNET_CDM".PRESCRIBING a
      on ds.PATID=a.PATID
      ...
      where a.RXNORM_CUI in (3842,153843,153844,...) and ...
    insert into GLP1AexByRXNORM_initial
    select ds.PATID, a.RX_ORDER_DATE as MedDate
      from DenominatorSummary ds
      join "&&PCORNET_CDM".PRESCRIBING a
      on ds.PATID=a.PATID
      ...
      where a.RXNORM_CUI in (...,1727493,1804447,1804505)
      and ...

Likewise, medication names are managed in long lists of patterns in
conditional expressions::

    >>. for dm_drug, dest, stmt in Table1Script.med_inserts():
    ...     if 'RXNORM' not in stmt:
    ...         print(dm_drug, _dest2drug(dest))
    ...         where = Table1Script.med_name_condition(stmt)
    ...         print(where)
    ... # doctest: +NORMALIZE_WHITESPACE +ELLIPSIS
    1 ['Sulfonylurea', 'Names']
    regexp_like(a.RAW_RX_MED_NAME, 'Acetohexamide','i') or
    regexp_like(a.RAW_RX_MED_NAME, 'D[i|y]melor','i') or
    regexp_like(a.RAW_RX_MED_NAME, 'glimep[e,i]ride','i') or
    ...
    0 ['Biguanide', 'Names']
    regexp_like(a.RAW_RX_MED_NAME,'Glucophage','i') or ...
      (regexp_like(a.RAW_RX_MED_NAME,'Metformin','i') and not (
         regexp_like(a.RAW_RX_MED_NAME,'Kazano','i') or
         regexp_like(a.RAW_RX_MED_NAME,'Invokamet','i') or
         regexp_like(a.RAW_RX_MED_NAME,'Xigduo XR','i') or ...
         )
      ) or ...

Let's turn this into tabular data::

    >>. for x in Table1Script.med_info():
    ...     pprint(x)
    ... # doctest: +NORMALIZE_WHITESPACE +ELLIPSIS
    MedInfo(dm_drug=1, drug='Sulfonylurea', by='Names', code=None, pattern='Acetohexamide',
            but_not=None, note=None)
    MedInfo(dm_drug=1, drug='Sulfonylurea', by='Names', code=None, pattern='D[i|y]melor',
            but_not=None, note=None)
    MedInfo(dm_drug=1, drug='Sulfonylurea', by='Names', code=None, pattern='glimep[e,i]ride',
            but_not=None, note=None)
    MedInfo(dm_drug=1, drug='Sulfonylurea', by='Names', code=None, pattern='Avandaryl',
            but_not=None,
            note='This is combination of glimeperide-rosiglitazone')
    ...
    MedInfo(dm_drug=1, drug='Sulfonylurea', by='RXNORM', code=3842, pattern=None,
            but_not=None, note=None)
    MedInfo(dm_drug=1, drug='Sulfonylurea', by='RXNORM', code=153843, pattern=None,
            but_not=None, note=None)
    MedInfo(dm_drug=1, drug='Sulfonylurea', by='RXNORM', code=153844, pattern=None,
            but_not=None, note=None)
    ...
    MedInfo(dm_drug=0, drug='Biguanide', by='Names', code=None, pattern='Glucophage',
            but_not=None, note=None)
    ...
    MedInfo(dm_drug=0, drug='Biguanide', by='Names', code=None, pattern='Amaryl M',
            but_not=None,
            note='this is combination of rosiglitizone-metformin')
    MedInfo(dm_drug=0, drug='Biguanide', by='Names', code=None, pattern='Avandamet',
            but_not=None, note=None)
    MedInfo(dm_drug=0, drug='Biguanide', by='Names', code=None, pattern='Metformin', but_not='Kazano',
            note=None)
    MedInfo(dm_drug=0, drug='Biguanide', by='Names', code=None, pattern='Metformin', but_not='Invokamet',
            note=None)
    MedInfo(dm_drug=0, drug='Biguanide', by='Names', code=None, pattern='Metformin', but_not='Xigduo XR',
            note=None)
    ...
    MedInfo(dm_drug=0, drug='GLP1Aex', by='RXNORM', code=1727493, pattern=None,
            but_not=None, note=None)
    MedInfo(dm_drug=0, drug='GLP1Aex', by='RXNORM', code=1804447, pattern=None,
            but_not=None, note=None)
    MedInfo(dm_drug=0, drug='GLP1Aex', by='RXNORM', code=1804505, pattern=None,
            but_not=None, note=None)

'''

from collections import namedtuple
import csv
import re

import pkg_resources as pkg


def main(stdout):
    data = Table1Script.med_info()
    export(stdout, MedInfo._fields, data)


def export(wr, cols, rows):
    out = csv.writer(wr)
    out.writerow(cols)
    out.writerows(rows)


class MedInfo(namedtuple(
        'MedInfo', 'dm_drug, drug, by, code, pattern, but_not, note')):
    pass


class Table1Script(object):
    r'''

    The SQL code is a design-time constant:

    >>> sql = Table1Script.sql_lines
    >>> [l for l in sql if 'select e.' in l][0].strip()
    'select e.ENCOUNTERID, e.patid, e.BIRTH_DATE, e.admit_date, e.enc_type'

    We can pick out the glucose codes:

    >>> ix = Table1Script.fasting_ix
    >>> sql[ix - 2:ix + 1]
    ... # doctest: +NORMALIZE_WHITESPACE +ELLIPSIS
    [', loinc_fasting_glucose as (\r',
     '  select 1 fasting, l.* from loinc_concepts l\r',
     "  where l.LAB_LOINC in ('1558-6', '1493-6', ..."]

    '''
    sql_lines = (pkg.resource_string(
        __name__, '../NextDvariableExtractionOracleTable1GPC.sql')
                 .decode('utf-8').split('\n'))

    sql_statements = '\n'.join(sql_lines).split(';\r\n')

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

    @classmethod
    def med_info(cls):
        for dm_drug, dest, stmt in cls.med_inserts():
            if 'RXNORM_CUI' in stmt:
                for info in cls.med_codes(dm_drug, dest, stmt):
                    yield info
            else:
                where = cls.med_name_condition(stmt)
                for info in cls.med_names(dm_drug, dest, where):
                    yield info

    @classmethod
    def med_inserts(cls):
        prefix = 'People with at least one ordered medications '
        suffixes = [(1, 'specific to Diabetes Mellitus'),
                    (0, 'non-specific to Diabetes Mellitus')]
        dm_drug = None
        for s in cls.sql_statements:
            for (status, suffix) in suffixes:
                if (prefix + suffix) in s:
                    dm_drug = status
            if ('insert into ' in s and
                    'PRESCRIBING' in s):
                dest = s[s.index('insert into '):].split()[2]
                yield (dm_drug, dest, s)

    @classmethod
    def med_codes(cls, dm_drug, dest, stmt):
        drug, by = _dest2drug(dest)
        where = [line for line in stmt.split('\n')
                 if line.strip().startswith('where a.RXNORM_CUI in (')][0]
        for code in _parens(where).split(','):
            yield MedInfo(dm_drug, drug, by, int(code), None, None, None)

    @classmethod
    def med_name_condition(cls, stmt):
        where = stmt.split('where (', 1)[1]
        # Strip stuff after name constraint.
        where = where.split('and e.ENC_TYPE in', 1)[0]
        return where.strip()[:-1]  # no parens

    @classmethod
    def med_names(cls, dm_drug, dest, where):
        expr = SQLExpr(where).conditional()
        drug, by = _dest2drug(dest)
        if expr[0] != 'OR':
            raise SyntaxError(expr[0])
        outer = None
        for disjunct in expr[1]:
            if disjunct[0] == 'call':
                pat, doc = _pattern(disjunct)
                yield MedInfo(dm_drug, drug, by,
                              None, pat, None, doc)
            elif disjunct[0] == 'AND':
                for conjunct in disjunct[1]:
                    if conjunct[0] == 'call':
                        outer, _doc = _pattern(conjunct)
                    elif conjunct[0] == 'NOT':
                        negated = conjunct[1]
                        if negated[0] == 'OR':
                            for inner_dis in negated[1]:
                                if inner_dis[0] == 'call':
                                    inner, doc = _pattern(inner_dis)
                                    yield MedInfo(dm_drug, drug, by,
                                                  None, outer, inner, doc)
                                else:
                                    raise SyntaxError(inner_dis)
                        else:
                            raise SyntaxError(negated)
                    else:
                        raise SyntaxError(conjunct)
            else:
                raise SyntaxError(disjunct)


def _pattern(call):
    if not (call[0] == 'call' and
            call[1] == 'regexp_like' and
            len(call[2]) == 3 and
            call[2][0] == ['IDENT', 'a.RAW_RX_MED_NAME'] and
            call[2][1][0] == 'LIT' and
            call[2][2] == ['LIT', "'i'"]):
        raise SyntaxError(call)
    pattern_lit = call[2][1][1]
    docstring = call[3]
    if docstring:
        docstring = docstring.replace('/* ', '').replace('*/', '')
        docstring = docstring.strip().rstrip(':').strip()
    return pattern_lit[1:-1], docstring


def _dest2drug(name):
    name = name.rsplit('_', 1)[0]
    return name.split('By', 1)


Token = namedtuple('Token', ['type', 'value', 'span'])


def generate_tokens(pattern, txt):
    for m in re.finditer(pattern, txt):
        token = Token(m.lastgroup, m.group(), m.span())

        if token.type not in ('WS'):
            # print("token:", token, file=stderr)
            yield token


class SQLExpr(object):
    # ack: https://docs.python.org/3/library/re.html#writing-a-tokenizer
    '''
    >>> re.match(SQLExpr.lex_pattern, 'regexp_like').group('IDENT')
    'regexp_like'
    '''
    token_specification = [
        ('LIT',     r"'[^']*'"),
        ('LPAREN',  r'\('),
        ('RPAREN',  r'\)'),
        ('COMMA',   r','),
        ('OR',      r'or'),
        ('AND',     r'and'),
        ('NOT',     r'not'),
        ('IDENT',   r"[\w_]+(\.[\w_]+)?"),
        ('COMMENT', r'/\*([^*]|\*[^/])*\*/'),
        ('WS',      r'\s+'),
        ]
    lex_pattern = '|'.join('(?P<%s>%s)' % pair for pair in token_specification)

    def __init__(self, txt):
        self.tokens = generate_tokens(self.lex_pattern, txt)
        self.current_token = None
        self.next_token = None
        self._advance()

    def _advance(self):
        self.current_token, self.next_token = (
            self.next_token, next(self.tokens, None))

    def _accept(self, token_type):
        # if there is next token and token type matches
        if self.next_token and self.next_token.type == token_type:
            self._advance()
            return True
        else:
            return False

    def _expect(self, token_type):
        if not self._accept(token_type):
            raise SyntaxError(
                'Expected %s got: %s' % (token_type, self.next_token))

    def conditional(self, connectives=['OR', 'AND']):
        parts = []
        connective = connectives[0]
        while 1:
            parts.append(self.comp(connectives))
            if not self._accept(connective):
                break
        if len(parts) == 1:
            return parts[0]
        else:
            return [connective, parts]

        if connective == 'OR' and self.next_token:
            raise SyntaxError(
                'Expected EOF; got: %s', self.next_token)

    def comp(self, connectives):
        if self._accept('LPAREN'):
            inner = self.conditional()
            self._expect('RPAREN')
            return inner

        if self._accept('NOT'):
            inner = self.conditional()
            return ['NOT', inner]

        rest = connectives[1:]
        if rest:
            return self.conditional(rest)
        else:
            return self.call()

    def call(self):
        docstring = None
        if self._accept('COMMENT'):
            docstring = self.current_token.value
        self._expect('IDENT')
        fun = self.current_token.value
        self._expect('LPAREN')
        args = []
        while 1:
            args.append(self.arg())
            if not self._accept('COMMA'):
                break
        self._expect('RPAREN')
        return ['call', fun, args, docstring]

    def arg(self):
        if not self._accept('LIT'):
            self._expect('IDENT')
        return [self.current_token.type, self.current_token.value]


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


if __name__ == '__main__':
    def _script():
        from sys import stdout
        main(stdout)

    _script()
