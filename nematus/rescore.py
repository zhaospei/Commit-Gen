'''
Rescoring an n-best list of translations using a translation model.
'''
import sys
import argparse
import tempfile

import numpy
import json

from data_iterator import TextIterator
from util import load_dict, load_config
from alignment_util import *
from compat import fill_options

from theano_util import (load_params, init_theano_params)
from nmt import (pred_probs, build_model, prepare_data, init_params)

from theano.sandbox.rng_mrg import MRG_RandomStreams as RandomStreams
import theano

def rescore_model(source_file, nbest_file, saveto, models, options, b, normalize, verbose, alignweights):

    trng = RandomStreams(1234)

    fs_log_probs = []

    for model, option in zip(models, options):

        # load model parameters and set theano shared variables
        params = numpy.load(model)
        tparams = init_theano_params(params)

        trng, use_noise, \
            x, x_mask, y, y_mask, \
            opt_ret, \
            cost = \
            build_model(tparams, option)
        inps = [x, x_mask, y, y_mask]
        use_noise.set_value(0.)

        if alignweights:
            sys.stderr.write("\t*** Save weight mode ON, alignment matrix will be saved.\n")
            outputs = [cost, opt_ret['dec_alphas']]
            f_log_probs = theano.function(inps, outputs)
        else:
            f_log_probs = theano.function(inps, cost)

        fs_log_probs.append(f_log_probs)

    def _score(pairs, alignweights=False):
        # sample given an input sequence and obtain scores
        scores = []
        alignments = []
        for i, f_log_probs in enumerate(fs_log_probs):
            score, alignment = pred_probs(f_log_probs, prepare_data, options[i], pairs, normalize=normalize, alignweights = alignweights)
            scores.append(score)
            alignments.append(alignment)

        return scores, alignments

    lines = source_file.readlines()
    nbest_lines = nbest_file.readlines()

    if alignweights: ### opening the temporary file.
        temp_name = saveto.name + ".json"
        align_OUT = tempfile.NamedTemporaryFile(prefix=temp_name)

    with tempfile.NamedTemporaryFile(prefix='rescore-tmpin') as tmp_in, tempfile.NamedTemporaryFile(prefix='rescore-tmpout') as tmp_out:
        for line in nbest_lines:
            linesplit = line.split(' ||| ')
            idx = int(linesplit[0])   ##index from the source file. Starting from 0.
            tmp_in.write(lines[idx])
            tmp_out.write(linesplit[1] + '\n')

        tmp_in.seek(0)
        tmp_out.seek(0)
        pairs = TextIterator(tmp_in.name, tmp_out.name,
                        options[0]['dictionaries'][:-1], options[0]['dictionaries'][1],
                         n_words_source=options[0]['n_words_src'], n_words_target=options[0]['n_words'],
                         batch_size=b,
                         maxlen=float('inf'),
                         sort_by_length=False) #TODO: sorting by length could be more efficient, but we'd have to synchronize scores with n-best list after


        scores, alignments = _score(pairs, alignweights)

        for i, line in enumerate(nbest_lines):
            score_str = ' '.join(map(str,[s[i] for s in scores]))
            saveto.write('{0} {1}\n'.format(line.strip(), score_str))

        ### optional save weights mode.
        if alignweights:
            for line in alignments:
                align_OUT.write(line + "\n")
    if alignweights:
        combine_source_target_text(source_file, nbest_file, saveto.name, align_OUT)
        align_OUT.close()

def main(models, source_file, nbest_file, saveto, b=80,
         normalize=False, verbose=False, alignweights=False):

    # load model model_options
    options = []
    for model in models:
        options.append(load_config(model))

        fill_options(options[-1])

    rescore_model(source_file, nbest_file, saveto, models, options, b, normalize, verbose, alignweights)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-b', type=int, default=80,
                        help="Minibatch size (default: %(default)s))")
    parser.add_argument('-n', action="store_true",
                        help="Normalize scores by sentence length")
    parser.add_argument('-v', action="store_true", help="verbose mode.")
    parser.add_argument('--models', '-m', type=str, nargs = '+', required=True,
                        help="model to use. Provide multiple models (with same vocabulary) for ensemble decoding")
    parser.add_argument('--source', '-s', type=argparse.FileType('r'),
                        required=True, metavar='PATH',
                        help="Source text file")
    parser.add_argument('--input', '-i', type=argparse.FileType('r'),
                        default=sys.stdin, metavar='PATH',
                        help="Input n-best list file (default: standard input)")
    parser.add_argument('--output', '-o', type=argparse.FileType('w'),
                        default=sys.stdout, metavar='PATH',
                        help="Output file (default: standard output)")
    parser.add_argument('--walign', '-w',required = False,action="store_true",
                        help="Whether to store the alignment weights or not. If specified, weights will be saved in <input>.alignment")

    args = parser.parse_args()

    main(args.models, args.source, args.input,
         args.output, b=args.b, normalize=args.n, verbose=args.v, alignweights=args.walign)
