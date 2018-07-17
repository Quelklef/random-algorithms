import node
import random
import sequtils
import math
import tables
import io
import misc

type Graph = object
  nodes: seq[Node]

func size*(g: Graph): int =
  return g.nodes.len

#makes a sequence of nodes with names a, b, c, etc
func seqNodes(num: int): seq[Node] =
  for i in 0 ..< num:
    result.add(initNode((chr(ord('a') + i))))

proc initGraph(n: int): Graph =
  result.nodes = seqNodes(n)

proc shuffle*(g: var Graph): void =
  var newSeq: seq[Node] #new sequence to replace g.nodes
  newSeq = @[]
  var pos: int
  for i in 0 ..< size(g): #pick a random node in g.node and add to newSeq, then remove it from g.nodes
    pos = rand(size(g)-1)
    newSeq.add(g.nodes[pos])
    g.nodes.del(pos)
  g.nodes = newSeq #replace g.nodes with newSeq
  for i, n in g.nodes: #assign nodes position in accending order
    n.position = i

#makes simple graph
#multigraphs can be treated as simple graphs for independent sets
proc initRandGraph*(n: int): Graph =
  result = initGraph(n)
  #n-1 is min num of edges in a graph, n*(n-1)/2 is max
  #returns random number inbetween min and max
  var numEdges = rand(int(n*(n-1)/2) - (n-1)) + (n-1)
  for i in 0 ..< n:
    var n1 = rand(n-1)
    var n2 = rand(n-1)
    addVertex(result.nodes[n1], result.nodes[n2])
    addVertex(result.nodes[n2], result.nodes[n1]) #effectively makes it an undirected graph
  shuffle(result)

#shuffles the positions of all the nodes within g
#[
func shuffle*(g: Graph) =
  let nums = toSeq(0 ..< g.size)
  for pair in zip(g.nodes, nums):
    setPosition(pair.a, pair.b)

proc shuffle*(g: Graph): void =
  var nums: seq[int]
  for i in 0 ..< size(g):
    nums.add(i) #sequence from 0 to number of nodes - 1
  var pos: int
  for n in g.nodes: #pick a random index in nums, assign value at index to node, remove that index from nums
    pos = rand(nums.len-1)
    n.position = nums[pos]
    nums.del(pos)

]#
let tabular = initTabular(
    ["Position", "Name", "Connected to"],
    [2         , 1     , 10],
)

proc report(values: varargs[string, `$`]) =
    echo tabular.row(values)

proc toString*(g: Graph): string =
  echo tabular.title()
  for n in g.nodes:
    var edges = ""
    for e in n.vertices:
      edges.add(" " & e.name)
    #result.add("\n" & $n.position & " (" & n.name & "):" & edges)
    report(n.position, n.name, edges)

func findIndSetRight*(g: Graph): seq[Node] =
  for n in g.nodes:
    if testRight(n):
        result.add(n)

func findIndSetLeft*(g: Graph): seq[Node] =
  for n in g.nodes:
    if testLeft(n):
        result.add(n)

func iSet*(g: Graph): seq[int] =
 return @[findIndSetLeft(g).len, findIndSetRight(g).len]

#[
func iSet*(g: Graph): int =
  shuffle(g)
  result = findIndSetLeft(g).len
  #result = findIndSetRight(g).len
]#
