import strutils
import math
import hashes
import random
import sugar
import sequtils

from misc import rand_u64, zipWith

template high[T: uint64](t: typedesc[T]): uint64 = 18446744073709551615'u64
template low[T: uint64](t: typedesc[T]): uint64 = 0'u64

func ceildiv(x, y: int): int =
  ## Like `x div y` but instead of being eq to floor(x/y), is eq to ceil(x/y)
  result = x div y
  if x mod y != 0: result.inc

#[
We make two assumptions with the TwoColoring type:
1. Any insignificant bits stored in .data (e.g. the
   last 60 bits in a size-4 coloring) are all zero.
2. .data never contains more uint64s than it has to.
We consider these assumptions to encapsulate a desired
state, and ensure that this state is always the case.
]#
type TwoColoring* = object
  N*: int  # Size of coloring
  data*: seq[uint64]

func initTwoColoring*(N: int): TwoColoring =
  result.N = N
  result.data = newSeq[uint64](ceildiv(N, 64))
  for i in 0 ..< result.data.len:
    result.data.add(0'u64)

func `==`*(col0, col1: TwoColoring): bool =
  return col0.data == col1.data

func `[]`*(col: TwoColoring, i: int): range[0 .. 1]
func `$`*(col: TwoColoring): string =
  result = ""
  for i in 0 ..< col.N:
    result.add($col[i])

func `{}`(col: TwoColoring, i: int): range[0 .. 1] =
  return 1'u64 and (col.data[i div 64] shr (i mod 64))

func `{}=`(col: var TwoColoring, i: int, val: range[0 .. 1]) =
  if val == 1:
    col.data[i div 64] = col.data[i div 64] or      (1'u64 shl (i mod 64))
  else: # val == 0
    col.data[i div 64] = col.data[i div 64] and not (1'u64 shl (i mod 64))

func `[]`*(col: TwoColoring, i: int): range[0 .. 1] =
  when not defined(reckless):
    if i >= col.N:
      raise newException(IndexError, "Index $# out of bounds" % $i)
  return col{i}

func `[]=`*(col: var TwoColoring, i: int, val: range[0 .. 1]) =
  when not defined(reckless):
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

func `and`*(col0, col1: TwoColoring): TwoColoring =
  return TwoColoring(N: col0.N, data: zipWith((a: uint64, b: uint64) => a and b, col0.data, col1.data))

func `not`*(col: TwoColoring): TwoColoring =
  return TwoColoring(N: col.N, data: col.data.map((u: uint64) => not u))

func allZeros(col: TwoColoring): bool =
  return col.data.all((u: uint64) => u == 0)

func homogenous*(col, mask: TwoColoring): bool =
  ## Are all the colors specified by the mask the
  ## same coloring?
  let masked = col and mask
  return (not masked).allZeros or masked == mask

func shiftRightImpl(col: var TwoColoring, n: range[0 .. 64], overflow: uint64, i: int) =
  if i == col.N:
    return
  let recurOverflow = col.data[i] shl (64 - n)
  col.data[i] = (col.data[i] shr n) and overflow
  col.shiftRightImpl(n, recurOverflow, i + 1)

func `>>=`*(col: var TwoColoring, n: range[0 .. 64]) =
  ## In-place shift right
  col.shiftRightImpl(n, 0, 0)

func extend*(col: var TwoColoring, amt: int): void =
  ## Extend the coloring by the given amount

  # TODO this can be slightly faster, but it's not worth the effort rn
  # First, reset the bits that are going to be exposed
  # i.e. already exist in col.data but aren't yet in
  # bounds
  let numToExpose = min(col.data.len * 64 - col.N, amt)
  for i in 0 ..< numToExpose:
    col{col.N + i} = 0

  # How many more uints are we going to need?
  let needed_uint_c = ceildiv(col.N + amt, 64) - col.data.len
  for _ in 0 ..< needed_uint_c:
    col.data.add(0'u64)

  col.N += amt

func fromString*(val: string): TwoColoring =
  result = initTwoColoring(val.len)
  for index, chr in val:
    result[index] = ord(chr) - ord('0')

