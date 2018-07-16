import node
import random

type Graph = object
  nodes: seq[Node]

func size*(g: Graph): int =
  return g.nodes.len

#shuffles the positions of all the nodes within g
func shuffle1*(g: Graph): void =
  var nums: seq[int]
  for i in 0 ..< size(g):
    nums.add(i) #sequence from 0 to number of nodes - 1
  var pos: int
  random.randomize()
  for n in g.nodes: #pick a random index in nums, assign value at index to node, remove that index from nums
    pos = rand(nums.len)
    n.position = nums[pos]
    nums.delete(pos)

func shuffle2*(g: var Graph): void =
  var newSeq: seq[Node] #new sequence to replace g.nodes
  newSeq = @[]
  var pos: int
  random.randomize()
  for i in 0 ..< size(g): #pick a random node in g.node and add to newSeq, then remove it from g.nodes
    pos = rand(size(g))
    newSeq.add(g.nodes[pos])
    g.nodes.delete(pos)
  g.nodes = newSeq #replace g.nodes with newSeq
  for i, n in g.nodes: #assign nodes position in accending order
    n.position = i

func findIndSetRight*(g: Graph): seq[Node] =
  for n in g.nodes:
    if testRight(n):
        result.add(n)

func findIndSetLeft*(g: Graph): seq[Node] =
  for n in g.nodes:
    if testLeft(n):
        result.add(n)
