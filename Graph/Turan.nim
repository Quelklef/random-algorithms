import node
import graph
import random
import io

random.randomize()

proc turanToString*(n: int, e: int = -1): void =
  var edges = e
  if float(e) > n*(n-1)/2:
    edges = int(n*(n-1)/2)
    echo "Too many edges, defaulting to ", edges, " edges"

  var g: Graph
  if e < 0:
    g = initRandGraph(n)
  else:
    g = initRandGraph(n, edges)

  var turanNum = float(size(g))/(2*numE(g)/size(g) + 1)

  echo "n = ", size(g), ", e = ", numE(g)
  echo "Turan's Theorm: n/(2e/n + 1) = ", turanNum

  var count = 1
  while float(iSet(g)) < turanNum:
    count += 1
    shuffle(g)
  echo "Shuffled ", count, " times"
  echo toString(g)

# Same as above minus all the print statements, and returns just the number of shuffles taken
#[ TODO: As it is now, we're just creating a single random graph given a fixed number of vertices/edges,
   instead I believe that we should go all graphs of a fixed number of vertices/edges and do a single shuffle of each.
   And then we could just keep on shuffling all of these graphs of same vertices/edges
   In terms of data, we could just give back the mean/median num shuffles
   Use this https://rosettacode.org/wiki/Combinations#Nim in edge creation
]#
proc turan*(n: int, e: int = -1): int =
  result = 1
  var edges = e
  if float(e) > n*(n-1)/2:
    edges = int(n*(n-1)/2)
  var g: Graph
  if e < 0:
    g = initRandGraph(n)
  else:
    g = initRandGraph(n, edges)
  var turanNum = float(size(g))/(2*numE(g)/size(g) + 1)
  while float(iSet(g)) < turanNum:
    result += 1
    shuffle(g)

let outFile = open("graphdata.txt", fmAppend)

let tabular = initTabular(
    ["Vertices", "Edges", "Shuffles"],
    [ 3        ,  2     , 10        ],
)
proc report(values: varargs[string, `$`]) =
  echo tabular.row(values)
  outFile.writeRow(values)

echo tabular.title()
for n in 1 .. 10:
  for e in n-1 .. int(n*(n-1)/2):
    report(n, e, turan(n, e))

close(outFile)
