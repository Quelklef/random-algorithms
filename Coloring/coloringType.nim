type Coloring* = ref object of RootObj
  N*: int
  C*: int

method `==`*(c0, c1: Coloring): bool {.base, gcSafe.} =
  assert(false)

method `[]`*(c: Coloring; i: int): int {.base, gcSafe.} =
  assert(false)

method `[]=`*(c: var Coloring; i, val: int) {.base, gcSafe.} =
  assert(false)

method randomize*(c: var Coloring) {.base, gcSafe.} =
  assert(false)

method homogenous*(c, mask: Coloring): bool {.base, gcSafe.} =
  assert(false)

method shiftRight*(c: var Coloring) {.base, gcSafe.} =
  assert(false)

method `or`*(c0, c1: Coloring): Coloring {.base, gcSafe.} =
  assert(false)

method `$`*(c: Coloring): string {.base, gcSafe.} =
  assert(false)
