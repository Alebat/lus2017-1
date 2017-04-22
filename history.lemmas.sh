# Adding more annotations to corpus
cat NLSPARQL.train.data | cut -f 1 > corpus1.tmp
cat NLSPARQL.train.feats.txt | sed 's/\([^\t]*\)\t\([^\t]*\)\t\([^\t]*\)/s\/\1\/\3\//' | tr '[A-Z]' '[a-z]' | sort | uniq | sed -f- corpus1.tmp > corpus2.tmp
cat NLSPARQL.train.data | cut -f 2 | paste corpus2.tmp - > corpus1.csv

# To create the CSV of training occurrences plus <unk> entries
cat corpus1.csv | sort | uniq -c | sort -k 2 | sed -r s/" +"/""/ | sed s/" "/"\t"/ | tail -n +2 | sort -nr > lexi-counts.csv
cat corpus1.csv | cut -f 2 | sort | uniq | sed '/^$/d' | sed 's/.*/1\t<unk>\t&/' >> lexi-counts.csv

# To create the lexicon file
echo "<eps> 0" > lex.csv
cat lexi-counts.csv | sed 's/^[0-9]*\t//' | tr ' \t' '\n' | sort | uniq | cat -n  | sed 's/^\( *\)\([^ ]*\)\t\([^ ]*\)/\3 \2/' >> lex.csv

# To create the transitions file
python do.py lexi-counts.csv | sed -e "s/^/0 0 /" | tr "\t" " " > wfst.csv
echo 0 0 >> wfst.csv

# Compile the WFST
fstcompile --isymbols=lex.csv --osymbols=lex.csv wfst.csv | fstrmepsilon > wfst.fst

# Phrases of tags
cat NLSPARQL.train.data | cut -f 2 | sed 's/^$/#/' | tr '\n' ' ' | tr '#' '\n' > tagphrases.csv

# Build 3grams counts
farcompilestrings --symbols=lex.csv --unknown_symbol="<unk>" tagphrases.csv > tagphrases.far
ngramcount --order=3 --require_symbols=false tagphrases.far > ngrams.far
ngrammake --method=witten_bell ngrams.far > lang-model

# Prediction
cat NLSPARQL.test.data | cut -f 1 | sed 's/^$/#/' | tr '\n' ' ' | tr '#' '\n' | sed 's/^ //' | \
while read line
do
   echo $line | farcompilestrings --symbols=lex.csv --unknown_symbol="<unk>" --generate_keys=1 --keep_symbols | farextract --filename_suffix=".fsa"
   fstcompose 1.fsa wfst.fst | fstcompose - lang-model | fstshortestpath | fsttopsort | fstprint --isymbols=lex.csv --osymbols=lex.csv
done > prediction.raw.csv

# Formatting and removing epsilons
cat prediction.raw.csv | sed 's/^[0-9]*\t[0-9\.]*$/-X-/' | sed -r 's/^[0-9\ ]+$/-X-/' | sed '/<eps>/d' | cut -f 4 | paste NLSPARQL.test.data - | sed 's/.*-X-//' > prediction.csv

# Evaluation
cat prediction.csv | tr '\t' ' ' | ./conlleval.pl -l > eval.txt
