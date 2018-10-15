import options
import os
import random
import strutils
import tables

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

func `{}`*[A, B](s: string, sl: HSlice[A, B]): string =
  ## Like `[]`, but instead of erroring when out of range,
  ## just shortens the result
  ## "abcd"{1 .. 100} == "abcd"
  when A is BackwardsIndex:
    let lo = s.len - sl.a.int
  else:
    let lo = sl.a

  when B is BackwardsIndex:
    let hi = s.len - sl.b.int
  else:
    let hi = sl.b

  return s[max(lo, 0) .. min(hi, s.len - 1)]

func `|=`*[K, V](t0: var Table[K, V], t1: Table[K, V]) =
  for key, val in t1.pairs:
    t0[key] = val

func `|`*[K, V](t0, t1: Table[K, V]): Table[K, V] =
  result = t0
  result |= t1

proc numLines*(f: string): int =
    return f.readFile.string.countLines - 1

proc createFile*(f: string) =
  close(open(f, mode = fmWrite))

proc toBase*(x, b: int): string =
  if x == 0: return "0"
  if x < 0: return "-" & (-x).toBase(b)
  var x = x
  var s: seq[int] = @[]
  while x > 0:
    let r = x mod b
    s.add(r)
    x = x div b
  for i in countdown(s.len - 1, 0):
    result &= $s[i]

