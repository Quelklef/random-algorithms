
# Random Algorithms

Okay, time for a problem description...

## C-colorings

We introduce the idea of a _coloring_, which is a sequence of colors.
For instance, a red-blue coloring may be

```
red red blue blue red blue red red blue blue blue
```

We typically deal with colorings as represented by a sequence of numbers, so we would represent that as:

```
00110100111
```

Where `0` corresponds to red and `1` to blue.

We generalize the idea of a coloring to a C-coloring, which is just a coloring of C colors.
The coloring is represented as a sequence of numbers from 0 (inclusive) to C-1 (esclusive).

C-colorings are reified by the `Coloring[C: static[int]]` type in the code.

## Subsequences

We notate subsequences with `_` and `^`s, for instance:

```
110101010100001
______^^^^_____
```

In the code, however, subsequences are typically represented as 2-colorings, like:

```
110101010100001
000000111100000
```

## MAS(K)s

Also known as K-APs.

MAS stands for monochromatic arithmetic subsequence.

Monochromatic means that each item of the sequence is the same color, and arithmetic means that
each item of the sequence is the same distance apart. A MAS(K) is a MAS containing K items.

For instance, consider the following 3-coloring with a MAS(3) notated:

```
120212120120
_^_^_^______
```

The items of the MAS are 1 apart from each other, and are each the color `2`. Thus, it is a MAS(3).

## The problem

We want to find colorings that have no MAS(K)s for certain Ks.

Given a fixed C and K, we want to iterate over N and search for a C-coloring of size N that has no
MAS(K). We do this by generating random MAS(K)s and checking if they are satisfactory.

We keep track of how many randomizations it took to find a satisfactory coloring. The end goal is to
analyze the plot of N vs Number of Ranomizations.

