import options
import os
import random
import strutils

# TODO: `func`
proc optParam*(n: int): Option[TaintedString] =
  if paramCount() >= n:
    return some(paramStr(n))
  return none(TaintedString)

when isMainModule:
  import strutils
  echo(optParam(1).map(parseInt).get(20))

func sum*(s: seq[int]): int =
  result = 0
  for x in s:
    result += x

random.randomize()

var localRand = initRand(rand(int.high))
proc rand_u64*(): uint64 =
  return localRand.next()

template times*(n: Natural, code: untyped): untyped =
  for _ in 0 ..< n:
    code

func joinSurround*(s: seq[string], v: string): string =
  ## Like `join`, but also includes the dlimiter at the beginning and end
  return v & s.join(v) & v

func `*`*(s: string, n: int): string =
  result = ""
  n.times:
    result.add(s)
