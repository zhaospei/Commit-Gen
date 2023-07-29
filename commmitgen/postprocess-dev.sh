#/bin/sh

# downloaded from https://raw.githubusercontent.com/rsennrich/wmt16-scripts/master/sample/postprocess-dev.sh

# path to moses decoder: https://github.com/moses-smt/mosesdecoder
mosesdecoder=/scratch/commitgen/mosesdecoder

# suffix of target language files
lng=msg

sed 's/\@\@ //g' | \
$mosesdecoder/scripts/recaser/detruecase.perl
