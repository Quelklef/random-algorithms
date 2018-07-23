import node
import graph
import random
import io

random.randomize()

proc turanDisplay*(n: int, e: int = -1): void =
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
  display(g)


#Finds numShuffles for all simple graphs that have n nodes and e edges
proc turanAll*(n:int, e:int): seq[int] =
  var turanNum = float(n)/(2*e/n + 1)
  for i in comb(n, e):
    var g:Graph = initGraph(n)
    var numS = 1
    for j in i:
      addE(n, j, g)
    shuffle(g)
    while float(iSet(g)) < turanNum:
      numS += 1
      shuffle(g)
    result.add(numS)

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
# TODO: for some reason n =1 doesn't work, shouldn't matter tho
for n in 1 .. 10:
  for e in n-1 .. int(n*(n-1)/2):
    #report(n, e, turan(n, e))
    for o in turanAll(n, e):
      report(n, e, o)

close(outFile)
