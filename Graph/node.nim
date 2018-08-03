type
  NodeObj = object
    name*: string
    position*: int64 #within each graph all nodes should have a unique position from 0 to number of nodes - 1
    edges*: seq[Node]
  Node* = ref NodeObj

func initNode*(n: string): Node =
  new(result)
  result.name = n
  result.position = -1
  result.edges = @[]

func setPosition*(n: Node, i: int): void =
  n.position =  i

func equals*(n1: Node, n2: Node): bool =
  return n1.name == n2.name

func addVertex*(n1: Node, n2: Node): void =
    n1.edges.add(n2)

func connected*(n1: Node, n2: Node): bool =
  return n2 in n1.edges

func degree*(n1: Node): int =
  return n1.edges.len

func right(n1: Node, n2: Node): bool =
  if n1.position < n2.position:
    return true
  else:
    return false

func left(n1: Node, n2: Node): bool =
  return not right(n1, n2)

#checks if any connected vertices are to the right, true if there are
func testRight*(n: Node): bool =
  for i in n.edges:
    if right(n, i):
      return true
  return false

#testRight but testLeft
func testLeft*(n: Node): bool =
  for i in n.edges:
    if left(n, i):
      return true
  return false
