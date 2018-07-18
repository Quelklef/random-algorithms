type
  NodeObj = object
    name*: string
    position*: int64 #within each graph all nodes should have a unique position from 0 to number of nodes - 1
    vertices*: seq[Node]
  Node* = ref NodeObj

func initNode*(n: string): Node =
  new(result)
  result.name = n
  result.position = -1
  result.vertices = @[]

func setPosition*(n: Node, i: int): void =
  n.position =  i

func addVertex*(n1: Node, n2: Node): void =
    n1.vertices.add(n2)

func connected*(n1: Node, n2: Node): bool =
  return n2 in n1.vertices

func right(n1: Node, n2: Node): bool =
  if n1.position < n2.position:
    return true
  else:
    return false

func left(n1: Node, n2: Node): bool =
  return not right(n1, n2)

#checks if any connected vertices are to the right, true if there are
func testRight*(n: Node): bool =
  for i in n.vertices:
    if right(n, i):
      return true
  return false

#testRight but testLeft
func testLeft*(n: Node): bool =
  for i in n.vertices:
    if left(n, i):
      return true
  return false
