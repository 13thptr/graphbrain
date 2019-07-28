from itertools import repeat
import logging
import spacy
from graphbrain import *
import graphbrain.constants as const
from .parser import Parser
from .nlp import token2str


deps_arg_roles = {
    'nsubj': 's',      # subject
    'nsubjpass': 'p',  # passive subject
    'agent': 'a',      # agent
    'acomp': 'c',      # subject complement
    'attr': 'c',       # subject complement
    'dobj': 'o',       # direct object
    'prt': 'o',        # direct object
    'dative': 'i',     # indirect object
    'advcl': 'x',      # specifier
    'prep': 'x',       # specifier
    'npadvmod': 'x',   # specifier
    'parataxis': 't',  # parataxis
    'intj': 'j',       # interjection
    'xcomp': 'r',      # clausal complement
    'ccomp': 'r'       # clausal complement
}


def token_head_type(token):
    head = token.head
    if head and head != token:
        return token_type(head)
    else:
        return ''


def is_noun(token):
    return token.tag_[:2] == 'NN'


def is_verb(token):
    tag = token.tag_
    if len(tag) > 0:
        return token.tag_[0] == 'V'
    else:
        return False


def is_infinitive(token):
    return token.tag_ == 'VB'


def is_compound(token):
    return token.dep_ == 'compound'


def concept_type_and_subtype(token):
    tag = token.tag_
    dep = token.dep_
    if dep == 'nmod':
        return 'cm'
    if tag[:2] == 'JJ':
        return 'ca'
    # elif is_compound(token):
    #    return 'cc'
    elif tag[:2] == 'NN':
        subtype = 'p' if 'P' in tag else 'n'
        sing_plur = 'p' if tag[-1] == 'S' else 's'
        return 'c{}.{}'.format(subtype, sing_plur)
    elif tag == 'CD':
        return 'c#'
    elif tag == 'DT':
        return 'cd'
    elif tag == 'WP':
        return 'cw'
    elif tag == 'PRP':
        return 'ci'
    else:
        return 'c'


def modifier_type_and_subtype(token):
    tag = token.tag_
    if tag == 'JJ':
        return 'ma'
    elif tag == 'JJR':
        return 'mc'
    elif tag == 'JJS':
        return 'ms'
    elif tag == 'DT':
        return 'md'
    # elif tag == 'PDT':
    #     return 'mp'
    elif tag == 'WDT':
        return 'mw'
    elif tag == 'CD':
        return 'm#'
    else:
        return 'm'


def builder_type_and_subtype(token):
    tag = token.tag_
    if tag == 'IN':
        return 'br'  # relational (proposition)
    elif tag == 'CC':
        return 'b+'
    else:
        return 'b'


def token_type(token, head=False):
    dep = token.dep_

    if dep in {'', 'subtok'}:
        return None

    head_type = token_head_type(token)
    if len(head_type) > 1:
        head_subtype = head_type[1]
    else:
        head_subtype = ''
    if len(head_type) > 0:
        head_type = head_type[0]

    if dep == 'ROOT':
        if is_verb(token):
            return 'p'
        else:
            return concept_type_and_subtype(token)
    elif dep in {'appos', 'attr', 'compound', 'dative', 'dep', 'dobj',
                 'nsubj', 'nsubjpass', 'oprd', 'pobj', 'meta'}:
        return concept_type_and_subtype(token)
    elif dep in {'advcl', 'csubj', 'csubjpass', 'parataxis'}:
        return 'p'
    elif dep in {'relcl', 'ccomp'}:
        if is_verb(token):
            return 'pr'
        else:
            return concept_type_and_subtype(token)
    elif dep in {'acl', 'pcomp', 'xcomp'}:
        if token.tag_ == 'IN':
            return 'a'
        else:
            return 'pc'
    elif dep in {'amod', 'det', 'nummod', 'preconj', 'predet'}:
        return modifier_type_and_subtype(token)
    elif dep in {'aux', 'auxpass', 'expl', 'prt', 'quantmod'}:
        if token.n_lefts + token.n_rights == 0:
            return 'a'
        else:
            return 'x'
    elif dep in {'nmod', 'npadvmod'}:
        if is_noun(token):
            return concept_type_and_subtype(token)
        else:
            return modifier_type_and_subtype(token)
    elif dep == 'cc':
        if head_type == 'p':
            return 'pm'
        else:
            return builder_type_and_subtype(token)
    elif dep == 'case':
        if token.head.dep_ == 'poss':
            return 'bp'
        else:
            return builder_type_and_subtype(token)
    elif dep == 'neg':
        return 'an'
    elif dep == 'agent':
        return 'x'
    elif dep in {'intj', 'punct'}:
        return ''
    elif dep == 'advmod':
        if token.head.dep_ == 'advcl':
            return 't'
        elif head_type == 'p':
            return 'a'
        elif head_type in {'m', 'x', 't', 'b'}:
            return 'w'
        else:
            return modifier_type_and_subtype(token)
    elif dep == 'poss':
        if is_noun(token):
            return concept_type_and_subtype(token)
        else:
            return 'mp'
    elif dep == 'prep':
        if head_type == 'p':
            return 't'
        else:
            return builder_type_and_subtype(token)
    elif dep == 'conj':
        if head_type == 'p' and is_verb(token):
            return 'p'
        else:
            return concept_type_and_subtype(token)
    elif dep == 'mark':
        if head_type == 'p' and head_subtype != 'c':
            return 'x'
        else:
            return builder_type_and_subtype(token)
    elif dep == 'acomp':
        if is_verb(token):
            return 'x'
        else:
            return concept_type_and_subtype(token)
    else:
        logging.warning('Unknown dependency (token_type): token: {}'
                        .format(token2str(token)))
        return None


def is_relative_concept(token):
    return token.dep_ == 'appos'


def arg_type(token):
    return deps_arg_roles.get(token.dep_, '?')


def insert_after_predicate(targ, orig):
    targ_type = targ.type()
    if targ_type[0] == 'p':
        return hedge((targ, orig))
    elif targ_type[0] == 'r':
        if targ_type == 'rm':
            inner_rel = insert_after_predicate(targ[1], orig)
            if inner_rel:
                return hedge((targ[0], inner_rel) + tuple(targ[2:]))
            else:
                return None
        else:
            return targ.insert_first_argument(orig)
    else:
        return targ.insert_first_argument(orig)
    # else:
    #     logging.warning(('Wrong target type (insert_after_predicate).'
    #                      ' orig: {}; targ: {}').format(targ, orig))
    #     return None


def nest_predicate(inner, outer, before):
    if inner.type() == 'rm':
        first_rel = nest_predicate(inner[1], outer, before)
        return hedge((inner[0], first_rel) + tuple(inner[2:]))
    elif inner.is_atom() or inner.type()[0] == 'p':
        return hedge((outer, inner))
    else:
        return hedge(((outer, inner[0]),) + inner[1:])


def _verb_features(token):
    verb_form = '-'
    tense = '-'
    aspect = '-'
    mood = '-'
    person = '-'
    number = '-'

    if token.tag_ == 'VB':
        verb_form = 'i'  # infinitive
    elif token.tag_ == 'VBD':
        verb_form = 'f'  # finite
        tense = '<'  # past
    elif token.tag_ == 'VBG':
        verb_form = 'p'  # participle
        tense = '|'  # present
        aspect = 'g'  # progressive
    elif token.tag_ == 'VBN':
        verb_form = 'p'  # participle
        tense = '<'  # past
        aspect = 'f'  # perfect
    elif token.tag_ == 'VBP':
        verb_form = 'f'  # finite
        tense = '|'  # present
    elif token.tag_ == 'VBZ':
        verb_form = 'f'  # finite
        tense = '|'  # present
        number = 's'  # singular
        person = '3'  # third person

    features = (tense, verb_form, aspect, mood, person, number)
    return ''.join(features)


# example:
# applying (and/b+ bank/cm (credit/cn.s card/cn.s)) to records/cn.p
# yields:
# (and/b+
#     (+/b.am bank/c records/cn.p)
#     (+/b.am (credit/cn.s card/cn.s) records/cn.p))
def _apply_aux_concept_list_to_concept(con_list, concept):
    concepts = tuple([('+/b.am', item, concept) for item in con_list[1:]])
    return hedge((con_list[0],) + concepts)


class ParserEN(Parser):
    def __init__(self, lemmas=False):
        super().__init__(lemmas=lemmas)
        self.lang = 'en'
        self.nlp = spacy.load('en_core_web_lg')

    def _build_atom_predicate(self, token, ent_type, ps):
        text = token.text.lower()
        et = ent_type

        # create verb features string
        verb_features = _verb_features(token)

        # create arguments string
        args = [arg_type(ps.tokens[entity]) for entity in ps.entities]
        args_string = ''.join([arg for arg in args if arg != '?'])

        # assign predicate subtype
        # (declarative, imperative, interrogative, ...)
        if len(ps.child_tokens) > 0:
            last_token = ps.child_tokens[-1][0]
        else:
            last_token = None
        if len(ent_type) == 1:
            # interrogative cases
            if (last_token and
                    last_token.tag_ == '.' and
                    last_token.dep_ == 'punct' and
                    last_token.lemma_.strip() == '?'):
                ent_type = 'p?'
            # imperative cases
            elif (is_infinitive(token) and 's' not in args_string and
                    'TO' not in [child[0].tag_
                                 for child in ps.child_tokens]):
                ent_type = 'p!'
            # declarative (by default)
            else:
                ent_type = 'pd'

        et = '{}.{}.{}'.format(ent_type, verb_features, args_string)

        return build_atom(text, et, self.lang)

    def _build_atom_subpredicate(self, token, ent_type):
        text = token.text.lower()
        et = ent_type

        if is_verb(token):
            # create verb features string
            verb_features = _verb_features(token)
            et = 'xv.{}'.format(verb_features)

        return build_atom(text, et, self.lang)

    def _build_atom_auxiliary(self, token, ent_type):
        text = token.text.lower()
        et = ent_type

        if is_verb(token):
            # create verb features string
            verb_features = _verb_features(token)
            et = 'av.{}'.format(verb_features)  # verbal
        elif token.tag_ == 'MD':
            et = 'am'  # modal
        elif token.tag_ == 'TO':
            et = 'ai'  # infinitive
        elif token.tag_ == 'RBR':
            et = 'ac'  # comparative
        elif token.tag_ == 'RBS':
            et = 'as'  # superlative
        elif token.tag_ == 'RP' or token.dep_ == 'prt':
            et = 'ap'  # particle
        elif token.tag_ == 'EX':
            et = 'ae'  # existential

        return build_atom(text, et, self.lang)

    def _concept_role(self, concept):
        if concept.is_atom():
            token = self.atom2token[concept]
            if token.dep_ == 'compound':
                return 'a'
            else:
                return 'm'
        else:
            return '?'

    def _compose_concepts(self, concepts):
        first = concepts[0]
        if first.is_atom():
            concept_roles = [self._concept_role(concept)
                             for concept in concepts]
            builder = '+/b.{}/.'.format(''.join(concept_roles))
            return hedge(builder).connect(concepts)
        else:
            return hedge((first[0],
                          self._compose_concepts(first[1:] + concepts[1:])))

    def post_process(self, entity):
        if entity.is_atom():
            token = self.atom2token.get(entity)
            if token:
                ent_type = self.atom2token[entity].ent_type_
                temporal = ent_type in {'DATE', 'TIME'}
            else:
                temporal = False
            return entity, temporal
        else:
            entity, temps = zip(*[self.post_process(item) for item in entity])
            entity = hedge(entity)
            temporal = True in temps
            ct = entity.connector_type()

            # Multi-noun concept, e.g.: (south america) -> (+ south america)
            if ct[0] == 'c':
                return self._compose_concepts(entity), temporal

            # Assign concept roles where possible
            # e.g. (on/br referendum/c (gradual/m (nuclear/m phaseout/c))) ->
            # (on/br.ma referendum/c (gradual/m (nuclear/m phaseout/c)))
            elif ct[0] == 'b' and len(entity) == 3:
                connector = entity[0]
                if connector.is_atom():
                    if ct == 'br':
                        connector = connector.replace_atom_part(
                            1, '{}.ma'.format(ct))
                    elif ct == 'bp':
                        connector = connector.replace_atom_part(
                            1, '{}.am'.format(ct))

                return hedge((connector,) + entity[1:]), temporal

            # Builders with one argument become modifiers
            # e.g. (on/b ice) -> (on/m ice)
            elif ct[0] == 'b' and entity[0].is_atom() and len(entity) == 2:
                ps = entity[0].parts()
                ps[1] = 'm' + ct[1:]
                return hedge(('/'.join(ps),) + entity[1:]), temporal

            # A meta-modifier applied to a concept defined my a modifier
            # should apply to the modifier instead.
            # e.g.: (stricking/w (red/m dress)) -> ((stricking/w red/m) dress)
            elif (ct[0] == 'w' and
                    entity[0].is_atom() and
                    len(entity) == 2 and
                    not entity[1].is_atom() and
                    entity[1].connector_type()[0] == 'm'):
                return (hedge(((entity[0], entity[1][0]),) + entity[1][1:]),
                        temporal)

            # Make sure that specifier arguments are of the specifier type,
            # entities are surrounded by an edge with a trigger connector if
            # necessary. E.g.: today -> {t/t/. today}
            elif ct[0] == 'p':
                pred = entity.predicate()
                if pred:
                    role = pred.role()
                    if len(role) > 2:
                        arg_roles = role[2]
                        if 'x' in arg_roles:
                            proc_edge = list(entity)
                            trigger = 't/tt/.' if temporal else 't/t/.'
                            for i, arg_role in enumerate(arg_roles):
                                arg_pos = i + 1
                                if (arg_role == 'x' and
                                        arg_pos < len(proc_edge) and
                                        proc_edge[arg_pos].is_atom()):
                                    tedge = (hedge(trigger),
                                             proc_edge[arg_pos])
                                    proc_edge[arg_pos] = hedge(tedge)
                            return hedge(proc_edge), False
                return entity, temporal

            # Make triggers temporal, if appropriate.
            # e.g.: (in/t 1976) -> (in/tt 1976)
            elif ct[0] == 't':
                if temporal:
                    trigger_atom = entity[0].atom_with_type('t')
                    triparts = trigger_atom.parts()
                    newparts = (triparts[0], 'tt')
                    if len(triparts) > 2:
                        newparts += tuple(triparts[2:])
                    trigger = hedge('/'.join(newparts))
                    entity = entity.replace_atom(trigger_atom, trigger)
                return entity, False
            else:
                return entity, temporal

    def _clean_parse_state(self):
        return self._ParseState(extra_edges=set(),
                                tokens={},
                                child_tokens=[],
                                positions={},
                                children=[],
                                entities=[])

    def _parse_token_children(self, token, ps):
        ps.child_tokens.extend(zip(token.lefts, repeat(True)))
        ps.child_tokens.extend(zip(token.rights, repeat(False)))

        for child_token, pos in ps.child_tokens:
            child, child_extra_edges = self.parse_token(child_token)
            if child:
                ps.extra_edges.update(child_extra_edges)
                ps.positions[child] = pos
                ps.tokens[child] = child_token
                child_type = child.type()
                if child_type:
                    ps.children.append(child)
                    if child_type[0] in {'c', 'r', 'd', 's'}:
                        ps.entities.append(child)

        ps.children.reverse()

    def _build_atom(self, token, ent_type, ps):
        text = token.text.lower()
        et = ent_type

        if ent_type[0] == 'p' and ent_type != 'pm':
            atom = self._build_atom_predicate(token, ent_type, ps)
        elif ent_type[0] == 'x':
            atom = self._build_atom_subpredicate(token, ent_type)
        elif ent_type[0] == 'a':
            atom = self._build_atom_auxiliary(token, ent_type)
        else:
            atom = build_atom(text, et, self.lang)

        self.atom2token[atom] = token
        return atom

    def _add_lemmas(self, token, entity, ent_type, ps):
        text = token.lemma_.lower()
        if text != token.text.lower():
            lemma = build_atom(text, ent_type[0], self.lang)
            lemma_edge = hedge((const.lemma_pred, entity, lemma))
            ps.extra_edges.add(lemma_edge)

    def parse_token(self, token):
        # check what type token maps to, return None if if maps to nothing
        ent_type = token_type(token)
        if ent_type == '' or ent_type is None:
            return None, None

        # create clean parse state
        ps = self._clean_parse_state()

        # parse token children
        self._parse_token_children(token, ps)

        atom = self._build_atom(token, ent_type, ps)
        entity = atom
        logging.debug('ATOM: {}'.format(atom))

        # lemmas
        if self.lemmas:
            self._add_lemmas(token, entity, ent_type, ps)

        # process children
        relative_to_concept = []
        for child in ps.children:
            child_type = child.type()

            logging.debug('entity: [%s] %s', ent_type, entity)
            logging.debug('child: [%s] %s', child_type, child)

            if child_type[0] in {'c', 'r', 'd', 's'}:
                if ent_type[0] == 'c':
                    if (child.connector_type() in {'pc', 'pr'} or
                            is_relative_concept(ps.tokens[child])):
                        logging.debug('choice: 1')
                        relative_to_concept.append(child)
                    elif child.connector_type()[0] == 'b':
                        if (child.connector_type() == 'b+' and
                                child.contains_atom_type('cm')):
                            logging.debug('choice: 2a')
                            entity = _apply_aux_concept_list_to_concept(child,
                                                                        entity)
                        elif entity.connector_type()[0] == 'c':
                            logging.debug('choice: 2b')
                            entity = entity.nest(child, ps.positions[child])
                        else:
                            logging.debug('choice: 3')
                            entity = entity.apply_fun_to_atom(
                                lambda target:
                                    target.nest(child, ps.positions[child]),
                                    atom)
                    elif child.connector_type()[0] in {'x', 't'}:
                        logging.debug('choice: 4')
                        entity = entity.nest(child, ps.positions[child])
                    else:
                        if ((atom.type()[0] == 'c' and
                                child.connector_type()[0] == 'c') or
                                is_compound(ps.tokens[child])):
                            if entity.connector_type()[0] == 'c':
                                if (child.connector_type()[0] == 'c' and
                                        entity.connector_type() != 'cm'):
                                    logging.debug('choice: 5a')
                                    entity = entity.sequence(
                                        child, ps.positions[child])
                                else:
                                    logging.debug('choice: 5b')
                                    entity = entity.sequence(
                                        child, ps.positions[child], flat=False)
                            else:
                                logging.debug('choice: 6')
                                entity = entity.apply_fun_to_atom(
                                    lambda target:
                                        target.sequence(
                                            child, ps.positions[child]),
                                        atom)
                        else:
                            logging.debug('choice: 7')
                            entity = entity.apply_fun_to_atom(
                                lambda target:
                                    target.connect((child,)),
                                    atom)
                elif ent_type[0] in {'p', 'r', 'd', 's'}:
                    logging.debug('choice: 8')
                    result = insert_after_predicate(entity, child)
                    if result:
                        entity = result
                    else:
                        logging.warning(('insert_after_predicate failed'
                                         'with: {}').format(self.cur_text))
                else:
                    logging.debug('choice: 9')
                    entity = entity.insert_first_argument(child)
            elif child_type[0] == 'b':
                if entity.connector_type()[0] == 'c':
                    logging.debug('choice: 10')
                    entity = child.connect(entity)
                else:
                    logging.debug('choice: 11')
                    entity = entity.nest(child, ps.positions[child])
            elif child_type[0] == 'p':
                # TODO: Pathological case
                # e.g. "Some subspecies of mosquito might be 1s..."
                if child_type == 'pm':
                    logging.debug('choice: 12')
                    entity = child + entity
                else:
                    logging.debug('choice: 13')
                    entity = entity.connect((child,))
            elif child_type[0] in {'m', 'x', 't'}:
                logging.debug('choice: 14')
                entity = hedge((child, entity))
            elif child_type[0] == 'a':
                logging.debug('choice: 15')
                entity = nest_predicate(entity, child, ps.positions[child])
            elif child_type == 'w':
                if ent_type[0] in {'d', 's'}:
                    logging.debug('choice: 16')
                    entity = nest_predicate(entity, child, ps.positions[child])
                    # pass
                else:
                    logging.debug('choice: 17')
                    entity = entity.nest(child, ps.positions[child])
            else:
                logging.warning('Failed to parse token (parse_token): {}'
                                .format(token))
                logging.debug('choice: 18')
                pass

            ent_type = entity.type()
            logging.debug('result: [%s] %s\n', ent_type, entity)

        if len(relative_to_concept) > 0:
            relative_to_concept.reverse()
            entity = hedge((':/b/.', entity) + tuple(relative_to_concept))

        return entity, ps.extra_edges
