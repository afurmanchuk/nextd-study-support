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


>>> next(Table1Script.med_codes())
... # doctest: +ELLIPSIS
('SulfonylureaByRXNORM_initial', ['3842', '153843', '153844', ...

    >>> from pprint import pprint
    >>> for x in Table1Script.med_names():
    ...     pprint(x)
    ... # doctest: +ELLIPSIS
    ('SulfonylureaByNames_initial',
     ['OR',
      [['call',
        'regexp_like',
        [['IDENT', 'a.RAW_RX_MED_NAME'],
         ['LIT', "'Acetohexamide'"],
         ['LIT', "'i'"]]],
       ['call',
        'regexp_like',
        ...
    ('BiguanideByNames_initial',
     ['OR',
      [['call',
        'regexp_like',
        [['IDENT', 'a.RAW_RX_MED_NAME'], ['LIT', "'Glucophage'"], ['LIT', "'i'"]]],
       ...
       ['call',
        'regexp_like',
        [['IDENT', 'a.RAW_RX_MED_NAME'], ['LIT', "'Avandamet'"], ['LIT', "'i'"]]],
       ['AND',
        [['call',
          'regexp_like',
          [['IDENT', 'a.RAW_RX_MED_NAME'], ['LIT', "'Metformin'"], ['LIT', "'i'"]]],
         ['NOT',
          ['OR',
           [['call',
             'regexp_like',
             [['IDENT', 'a.RAW_RX_MED_NAME'], ['LIT', "'Kazano'"], ...

'''

from collections import namedtuple
import re

import pkg_resources as pkg


class Table1Script(object):
    r'''

    The SQL code is a design-time constant:

    >>> sql = Table1Script.sql_lines
    >>> [l for l in sql if 'select' in l][0].strip()
    'select e.ENCOUNTERID, e.patid, e.admit_date, e.enc_type'

    We can pick out the glucose codes:

    >>> ix = Table1Script.fasting_ix
    >>> sql[ix - 2:ix + 1]
    ... # doctest: +NORMALIZE_WHITESPACE +ELLIPSIS
    [', loinc_fasting_glucose as (\r',
     '  select 1 fasting, l.* from loinc_concepts l\r',
     "  where l.LAB_LOINC in ('1558-6', '1493-6', ..."]

    '''
    sql_lines = (pkg.resource_string(
        __name__, 'NextDvariableExtractionOracleTable1GPC.sql')
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
    def _med_inserts(cls):
        return [(s[s.index('insert into '):].split()[2], s)
                for s in cls.sql_statements
                if 'PRESCRIBING' in s and 'insert into ' in s]

    @classmethod
    def med_codes(cls):
        for dest, stmt in cls._med_inserts():
            if 'RXNORM_CUI' not in stmt:
                continue
            where = [line for line in stmt.split('\n')
                     if line.strip().startswith('where a.RXNORM_CUI in (')][0]
            yield dest, _parens(where).split(',')

    @classmethod
    def med_names(cls):
        for dest, stmt in cls._med_inserts():
            if 'RXNORM_CUI' in stmt:
                continue
            where = stmt.split('where (', 1)[1]
            where = where.split('and e.ENC_TYPE in', 1)[0].strip()[:-1]
            expr = SQLExpr(where)
            yield dest, expr.conditional()


Token = namedtuple('Token', ['type', 'value', 'span'])


def generate_tokens(pattern, txt):
    for m in re.finditer(pattern, txt):
        token = Token(m.lastgroup, m.group(), m.span())

        if token.type not in ('WS', 'COMMENT'):
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
        self._expect('IDENT')
        fun = self.current_token.value
        self._expect('LPAREN')
        args = []
        while 1:
            args.append(self.arg())
            if not self._accept('COMMA'):
                break
        self._expect('RPAREN')
        return ['call', fun, args]

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
