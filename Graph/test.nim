import Turan
import graph
import node

var g: Graph = initRandGraph(20, 10)
shuffle(g)
echo iSet(g)
echo greedyISet(g)
