import argparse
import json
import sys

from termcolor import colored

import graphbrain.constants as const
from graphbrain import hgraph, hedge
from graphbrain.corefs.names import CorefsNames
from graphbrain.corefs.onto import CorefsOnto
from graphbrain.parsers import parser_lang
from graphbrain.readers.txt import TxtReader
from graphbrain.readers.dir import DirReader
from graphbrain.readers.csv import CsvReader
from graphbrain.readers.wikipedia import WikipediaReader
from graphbrain.readers.reddit import RedditReader


def _show_logo():
    for line in const.ascii_logo.split('\n'):
        print(colored(line[:29], 'cyan'), end='')
        print(colored(line[29:], 'green'))
    print()


def error_msg(msg):
    print('{} {}'.format(colored('error:', 'red'), msg))


def cli():
    _show_logo()

    parser = argparse.ArgumentParser()

    parser.add_argument('command', type=str, help='command to execute')
    parser.add_argument('--agent', type=str, help='agent name', default=None)
    parser.add_argument('--col', type=str, help='table column', default=None)
    parser.add_argument('--corefs', help='perform coreference resolution',
                        action='store_true')
    parser.add_argument('--fields', type=str, help='field names', default=None)
    parser.add_argument('--hg', type=str,
                        help='hypergraph db', default='gb.db')
    parser.add_argument('--indir', type=str,
                        help='input directory', default=None)
    parser.add_argument('--infile', type=str, help='input file', default=None)
    parser.add_argument('--lang', type=str, help='language', default=None)
    parser.add_argument('--outdir', type=str,
                        help='output directory', default=None)
    parser.add_argument('--outfile', type=str,
                        help='output file', default=None)
    parser.add_argument('--parser', type=str, help='parser', default=None)
    parser.add_argument('--pattern', type=str, help='edge pattern',
                        default='*')
    parser.add_argument('--sequence', type=str, help='sequence name',
                        default=None)
    parser.add_argument('--show_namespaces',
                        help='show namespaces', action='store_true')
    parser.add_argument('--system', type=str, help='agent system file',
                        default=None)
    parser.add_argument('--text', type=str, help='text identifier',
                        default='title')
    parser.add_argument('--training_data', type=str,
                        help='training data for ML tasks', default=None)
    parser.add_argument('--url', type=str, help='url', default=None)

    args = parser.parse_args()

    # determine language
    if args.parser:
        plang = parser_lang(args.parser)
        if args.lang:
            if args.lang != plang:
                msg = 'specified language ({}) and parser language ({}) do '\
                      'not match'.format(args.lang, plang)
                error_msg()
                sys.exit(-1)
        else:
            args.lang = plang
    # if not lang or parser is specified, default to 'en'
    elif not args.lang:
        args.lang = 'en'

    print(colored('{}\n'.format( 'command: {}'.format(args.command)), 'white'))

    if args.agent:
        print('agent: {}'.format(args.agent))
    if args.col:
        print('column: {}'.format(args.col))
    if args.corefs:
        print('coreferences: {}'.format(args.corefs))
    if args.hg:
        print('hypergraph: {}'.format(args.hg))
    if args.infile:
        print('input file: {}'.format(args.infile))
    if args.lang:
        print('language: {}'.format(args.lang))
    if args.parser:
        print('parser: {}'.format(args.parser))
    if args.outfile:
        print('output file: {}'.format(args.outfile))
    if args.sequence:
        print('sequence: {}'.format(args.sequence))
    if args.system:
        print('system: {}'.format(args.system))
    if args.training_data:
        print('training data: {}'.format(args.training_data))
    if args.url:
        print('url: {}'.format(args.url))

    print()

    if args.command == 'create':
        hgraph(args.hg)
        print('Hypergraph database created.')
    elif args.command == 'export':
        print('exporting hypergraph...')
        hg = hgraph(args.hg)
        n = 0
        with open(args.outfile, 'w') as f:
            for edge, attributes in hg.all_attributes():
                row = [str(edge), attributes]
                f.write('{}\n'.format(json.dumps(row, ensure_ascii=False)))
                n += 1
        print('{} edges exported.'.format(n))
    elif args.command == 'import':
        print('importing hypergraph...')
        hg = hgraph(args.hg)
        n = 0
        with open(args.infile, 'r') as f:
            for line in f:
                edge_str, attributes = json.loads(line)
                hg.add_with_attributes(hedge(edge_str), attributes)
                n += 1
        print('{} edges imported.'.format(n))
    elif args.command == 'txt':
        TxtReader(args.infile,
                  hg=hgraph(args.hg),
                  sequence=args.sequence,
                  lang=args.lang,
                  corefs=args.corefs).read()
    elif args.command == 'dir':
        DirReader(args.indir,
                  hg=hgraph(args.hg),
                  sequence=args.sequence,
                  lang=args.lang,
                  corefs=args.corefs).read()
    elif args.command == 'csv':
        CsvReader(args.infile,
                  args.col,
                  hg=hgraph(args.hg),
                  sequence=args.sequence,
                  lang=args.lang,
                  corefs=args.corefs).read()
    elif args.command == 'wikipedia':
        WikipediaReader(args.url,
                        hg=hgraph(args.hg),
                        sequence=args.sequence,
                        lang=args.lang,
                        corefs=args.corefs).read()
    elif args.command == 'reddit':
        RedditReader(args.infile,
                     hg=hgraph(args.hg),
                     sequence=args.sequence,
                     lang=args.lang,
                     corefs=args.corefs).read()
    elif args.command == 'names':
        CorefsNames(hg=hgraph(args.hg), sequence=args.sequence)
    elif args.command == 'onto':
        CorefsOnto(hg=hgraph(args.hg), sequence=args.sequence)
    else:
        raise RuntimeError('Unknown command: {}'.format(args.command))

    print()
