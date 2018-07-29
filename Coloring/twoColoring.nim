import strutils
import math
import hashes
import random
import sugar
import sequtils
import hashes

from misc import rand_u64, times

template high[T: uint64](t: typedesc[T]): uint64 = 18446744073709551615'u64
template low[T: uint64](t: typedesc[T]): uint64 = 0'u64

func ceildiv(x, y: int): int =
  ## Like `x div y` but instead of being eq to floor(x/y), is eq to ceil(x/y)
  result = x div y
  if x mod y != 0: result.inc

#[
We encode two-colorings as sequences of uint64s.
Each uint64 (henceforth 'uis') represent 64 colorings.
The LEAST SIGNIFICANT digit of each ui represent the
first coloring, and the MOST SIGNIFICANT represents the
last coloring.

We maintain the following state:
- There are never more uis than there need to be
]#
type TwoColoring* = object
  N*: int  # Size of coloring
  data*: seq[uint64]

func initTwoColoring*(N: int): TwoColoring =
  result.N = N
  result.data = @[]
  for _ in 1 .. ceildiv(N, 64):
    result.data.add(0'u64)

func `==`*(col0, col1: TwoColoring): bool =
  return col0.N == col1.N and col0.data == col1.data

func asBinReversed(x: uint64): string =
  ## Return the binary string representation of a uint64, reversed
  result = ""
  for i in 0 ..< 64:
    result &= $(1'u64 and (x shr i))

func `[]`*(col: TwoColoring, i: int): range[0 .. 1]
func `$`*(col: TwoColoring): string =
  result = ""
  for ui in col.data:
    result &= asBinReversed(ui)
  result = result[0 ..< col.N]

func `{}`(col: TwoColoring, i: int): range[0 .. 1] =
  return 1'u64 and (col.data[i div 64] shr (i mod 64))

func `{}=`(col: var TwoColoring, i: int, val: range[0 .. 1]) =
  if val == 1:
    col.data[i div 64] = col.data[i div 64] or      (1'u64 shl (i mod 64))
  else: # val == 0
    col.data[i div 64] = col.data[i div 64] and not (1'u64 shl (i mod 64))

func `[]`*(col: TwoColoring, i: int): range[0 .. 1] =
  when compileOption("boundChecks"):
    if i >= col.N:
      raise newException(IndexError, "Index $# out of bounds" % $i)
  return col{i}

func `[]=`*(col: var TwoColoring, i: int, val: range[0 .. 1]) =
  when compileOption("boundChecks"):
    if i >= col.N:
      raise newException(IndexError, "Index $# out of bounds" % $i)
  col{i} = val

func `+=`*(col: var TwoColoring, amt: uint64) =
  ## May overflow
  col.data[0] += amt
  if col.data.len > 1:
    col.data[1] += (col.data[0] < amt).uint64

proc randomize*(col: var TwoColoring): void =
  ## Randomize a two-coloring
  for i in 0 ..< col.data.len:
    col.data[i] = rand_u64()

func homogenous*(col, mask: TwoColoring): bool =
  ## Are all the colors specified by the mask the
  ## same coloring?
  when compileOption("checks"):
    if col.N != mask.N:
      raise ValueError.newException("Coloring and mask must be the same size.")
  for i in 0 ..< col.data.len:
    if not ((col.data[i] and mask.data[i]) == 0 or ((col.data[i] or not mask.data[i]) == uint64.high)):
      return false
  return true

func shiftRightImpl(col: var TwoColoring, n: range[1 .. 63], overflow: uint64, i: int) =
  # n cant be 0 or 64 because for some reason `(v: uint64) shl/shr 64` is a noop
  # Note that we implement this as a "shift left" since the colorings are stored
  # in order of significance, not canonical order
  if i >= col.data.len:
    return
  let recurOverflow = col.data[i] shr (64 - n)
  col.data[i] = (col.data[i] shl n) or overflow
  col.shiftRightImpl(n, recurOverflow, i + 1)

func shiftLeftImpl(col: var TwoColoring, n: range[1 .. 63], overflow: uint64, i: int) =
  if i < 0:
    return
  let recurOverflow = col.data[i] shl (64 - n)
  col.data[i] = (col.data[i] shr n) or overflow
  col.shiftLeftImpl(n, recurOverflow, i - 1)

func `>>=`*(col: var TwoColoring, n: range[1 .. 63]) =
  ## In-place shift right
  col.shiftRightImpl(n, 0, 0)

func `<<=`*(col: var TwoColoring, n: range[1 .. 63]) =
  ## In-place shift left
  col.shiftLeftImpl(n, 0, col.data.len - 1)

func hash*(col: TwoColoring): Hash =
  return !$(0 !& hash(col.N) !& hash(col.data))

func downsizeOnce*(col: var TwoColoring) =
  ## Resize to one less
  when compileOption("boundChecks"):
    if col.N <= 0:
      raise ValueError.newException("Coloring must be bigger than length 0")
  col[col.N - 1] = 0
  col.N = col.N - 1
  if col.N mod 64 == 0:  # Remove final ui if needed
    col.data.del(col.data.len - 1)

func resize*(col: var TwoColoring, size: Natural) =
  if col.N > size:
    let uiDropCount = (col.N - size) div 64
    let zeroCount = (col.N - size) mod 64
    uiDropCount.times:
      col.data.del(col.data.len - 1)
    if col.data.len > 0:
      col.data[^1] = col.data[^1] and (2'u64^(64 - zeroCount) - 1'u64)
  elif col.N < size:
    let uiAddCount = ceildiv(size - col.N, 64)
    uiAddCount.times:
      col.data.add(0'u64)
  col.N = size

func `or`*(col0, col1: TwoColoring): TwoColoring =
  when compileOption("checks"):
    if col0.N != col1.N:
      raise ValueError.newException("The two colorings must be the same size.")

  var resultData = newSeq[uint64](col0.data.len)
  for i in 0 ..< col0.data.len:
    resultData[i] = col0.data[i] or col1.data[i]
  return TwoColoring(N: col0.N, data: resultData)
