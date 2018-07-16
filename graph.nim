import node
import random

type Graph = object
  nodes: seq[Node]

func size*(g: Graph): int =
  return g.nodes.len

#shuffles the positions of all the nodes within g
func shuffle*(g: Graph): void =
  var nums: seq[int]
  for i in 0 ..< size(g):
    nums.add(i)
  var pos: int
  random.randomize()
  for n in g.nodes:
    pos = rand(nums.len)
    n.position = nums[pos]
    nums.delete(pos)

func findIndSetRight*(g: Graph): seq[Node] =
  for n in g.nodes:
    if testRight(n):
        result.add(n)

func findIndSetLeft*(g: Graph): seq[Node] =
  for n in g.nodes:
    if testLeft(n):
        result.add(n)
