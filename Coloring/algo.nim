import coloring
import ../util

iterator skip*[T](a, step: T; n: int): T =
  ## Yield a, a + T, a + 2T, etc., n times
  var x = a
  for _ in 0 ..< n:
    yield x
    x += step

proc hasMAS*(col: Coloring; K: Positive): bool =
  if K == 1:
    return col.N >= 1

  for stepSize in 1 .. (col.N - 1) div (K - 1):
    for startLoc in 0 .. col.N - (K - 1) * stepSize - 1:
      block skipping:
        let expectedColor = col[startLoc]
        for i in skip(startLoc, stepSize, K):
          if col[i] != expectedColor:
            break skipping
        return true
  return false

proc generateSuccessCount*(C, N, K, attempts: int): int =
  var col = initColoring(C, N)
  for i in 1 .. attempts:
    col.randomize()
    if col.hasMAS(K):
      result.inc()
