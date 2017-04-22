

# To create the CSV of training occurrences plus <unk> entries
cat NLSPARQL.train.data | sort | uniq -c | sort -k 2 | sed -r s/" +"/""/ | sed s/" "/"\t"/ | tail -n +2 > lexi-counts.csv
cat NLSPARQL.train.data | cut -f 2 | sort | uniq | sed '/^$/d' | sed 's/.*/1\t<unk>\t&/' >> lexi-counts.csv

# To create the lexicon file
echo "<eps> 0" > lex.csv
echo "<unk> 1" >> lex.csv
cat NLSPARQL.train.data | tr ' \t' '\n' | sort | uniq | cat -n | tail -n +2 | sed 's/^\( *\)\([^ ]*\)\t\([^ ]*\)/\3 \2/' >> lex.csv

# To create the transitions file
python do.py lexi-counts.csv | sed -e "s/^/0 0 /" | tr "\t" " " > wfst.csv
echo 0 0 >> wfst.csv

# Compile the WFST
fstcompile --isymbols=lex.csv --osymbols=lex.csv wfst.csv | fstrmepsilon > wfst.fst

# Building input FSA
echo "have you ever watched back to the future III?" | farcompilestrings --symbols=lex.csv --unknown_symbol="<unk>" --generate_keys=1 --keep_symbols | farextract --filename_suffix=".fsa"
fstprint --isymbols=lex.csv --osymbols=lex.csv 1.fsa

# Trying the WFST with "Have you ever watched back to the future III?"
fstcompose 1.fsa wfst.fst | fsttopsort | fstprint --isymbols=lex.csv --osymbols=lex.csv

# With shortest path
fstcompose 1.fsa wfst.fst | fstshortestpath | fsttopsort | fstprint --isymbols=lex.csv --osymbols=lex.csv

# Phrases of tags
cat NLSPARQL.train.data | cut -f 2 | sed 's/^$/#/' | tr '\n' ' ' | tr '#' '\n' > tagphrases.csv

# Build 3grams counts
farcompilestrings --symbols=lex.csv --unknown_symbol="<unk>" tagphrases.csv > tagphrases.far
ngramcount --order=3 --require_symbols=false tagphrases.far > trigrams.far
ngrammake --method=witten_bell trigrams.far > lang-model

# Final check
fstcompose 1.fsa wfst.fst | fstcompose - lang-model | fstshortestpath | fsttopsort | fstprint --isymbols=lex.csv --osymbols=lex.csv

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
cat prediction.csv | tr '\t' ' ' | ./conlleval.pl > eval.0.txt
