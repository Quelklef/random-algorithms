from misc import ceildiv

#[
We make two assumptions with the TwoColoring type:
1. Any insignificant bits stored in .data (e.g. the
   last 60 bits in a size-4 coloring) are all zero.
2. .data never contains more uint64s than it has to.
We consider these assumptions to encapsulate a desired
state, and ensure that this state is always the case.
]#
type Coloring*[C: static[int]] = object
  when C == 2:
    N*: int  # Size of the coloring. Needed because .data pads to nearest 64
    data*: seq[uint64]
  else:
    data*: seq[range[0 .. C - 1]]
