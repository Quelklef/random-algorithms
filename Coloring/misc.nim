import random
import strutils

random.randomize()

var localRand = initRand(rand(int.high))
proc rand_u64*(): uint64 =
  return localRand.next()

# -- #

template times*(n: Natural, code: untyped): untyped =
  for _ in 0 ..< n:
    code

# -- #

func `*`*(s: string, n: int): string =
  result = ""
  n.times:
    result.add(s)

func joinSurround*(s: seq[string], v: string): string =
  ## Like `join`, but also includes the dlimiter at the beginning and end
  return v & s.join(v) & v
