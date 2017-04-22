from __future__ import division, print_function

import numpy as np
import pandas as pd
from sys import argv

# load the specified file
data = pd.read_csv(argv[1], sep="\t", header=None)

# loop to count total number of occurrences
curr = None
tot = 0
tots = np.empty(len(data.index))
toti = 0

for i in data.index:
    r = data.iloc[i]
    if r[1] == curr:
        tot += int(r[0])
    else:
        tots[toti] = tot
        toti += 1
        
        tot = int(r[0])
        curr = r[1]
tots[toti] = tot

# loop as before to compute conditional probabilities -log(P(C|W))
# e.g. P(future|I-movie.name) = count(future ^ I-movie.name) / count(future)
curr = None
toti = 0

for i in data.index:
    r = data.iloc[i]
    if r[1] != curr:
        curr = r[1]
        toti += 1
    prob = r[0] / tots[toti]
	# output the data
    print(r[1], r[2], abs(-np.log(prob)), sep="\t")
