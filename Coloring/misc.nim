
import random
import tables
import strutils
import math
import options

random.randomize()

var localRand = initRand(rand(int.high))
proc rand_u64*(): uint64 =
  return localRand.next()

# -- #

template times*(n: Natural, code: untyped): untyped =
  for _ in 0 ..< n:
    code

template loopfrom*(ident: untyped, n: int, code: untyped): untyped =
  var ident = n
  while true:
    code
    inc(ident)

# -- #

func `*`*(s: string, n: int): string =
  result = ""
  n.times:
    result.add(s)

func alignCenter*(val: string, width: int): string =
  return alignLeft(
    " " * ((width - val.len) div 2) & val,
    width,
  )

func joinSurround*(s: seq[string], v: string): string =
  ## Like `join`, but also includes the dlimiter at the beginning and end
  return v & s.join(v) & v

func replaceMany*(s: string, repl: Table[string, string]): string =
  ## Behaviour is undefined if duplicate keys exist
  result = ""

  var i = 0
  while i < s.len:
    block continueOuter:
      for term in repl.keys:
        if s.continuesWith(term, i):
          result.add(repl[term])
          i += term.len
          break continueOuter
      result.add(s[i])
      inc(i)

when isMainModule:
  assert("cool wow nice" == "nice cool wow".replaceMany({"nice": "cool", "cool": "wow", "wow": "nice"}.toTable))
  assert("abc" == "123".replaceMany({"1": "a", "2": "b", "3": "c"}.toTable))

# -- #

func zipWith*[T](f: proc(a, b: T): T, s0, s1: seq[T]): seq[T] =
  let resLen = min(s0.len, s1.len)
  result = newSeq[T](resLen)
  for i in 0 ..< resLen:
    result[i] = f(s0[i], s1[i])

# -- #

func ceildiv*(x, y: int): int =
  result = x div y
  if x mod y != 0:
    inc(result)
