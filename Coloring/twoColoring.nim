import strutils
import math
import hashes
import random
import sugar
import sequtils

from misc import rand_u64, zipWith, ceildiv
import coloringDef

func high[T: uint64](t: typedesc[T]): uint64 = 18446744073709551615'u64
func low[T: uint64](t: typedesc[T]): uint64 = 0'u64

func initColoring*(C: static[int], N: int): Coloring[2] =
  result.N = N
  result.data = newSeq[uint64](ceildiv(N, 64))
  for i in 0 ..< result.data.len:
    result.data.add(0'u64)

func `==`*(col0, col1: Coloring[2]): bool =
  return col0.data == col1.data

func `{}`(col: Coloring[2], i: int): range[0 .. 1] =
  return 1'u64 and (col.data[i div 64] shr (i mod 64))

func `{}=`(col: var Coloring[2], i: int, val: range[0 .. 1]) =
  if val == 1:
    col.data[i div 64] = col.data[i div 64] or      (1'u64 shl (i mod 64))
  else: # val == 0
    col.data[i div 64] = col.data[i div 64] and not (1'u64 shl (i mod 64))

func `[]`*(col: Coloring[2], i: int): range[0 .. 1] =
  when not defined(reckless):
    if i >= col.N:
      raise newException(IndexError, "Index $# out of bounds" % $i)
  return col{i}

func `[]=`*(col: var Coloring[2], i: int, val: range[0 .. 1]) =
  when not defined(reckless):
    if i >= col.N:
      raise newException(IndexError, "Index $# out of bounds" % $i)
  col{i} = val

func `+=`*(col: var Coloring[2], amt: uint64) =
  ## May overflow
  col.data[0] += amt
  if col.data.len > 1:
    col.data[1] += (col.data[0] < amt).uint64

proc randomize*(col: var Coloring[2]): void =
  ## Randomize a two-coloring
  for i in 0 ..< col.data.len:
    col.data[i] = rand_u64()

func `and`*(col0, col1: Coloring[2]): Coloring[2] =
  return Coloring[2](N: col0.N, data: zipWith((a: uint64, b: uint64) => a and b, col0.data, col1.data))

func `not`*(col: Coloring[2]): Coloring[2] =
  return Coloring[2](N: col.N, data: col.data.map((u: uint64) => not u))

func allZeros(col: Coloring[2]): bool =
  return col.data.all((u: uint64) => u == 0)

func homogenous*(col, mask: Coloring[2]): bool =
  ## Are all the colors specified by the mask the
  ## same coloring?
  let masked = col and mask
  return (not masked).allZeros or masked == mask

func shiftRightImpl(col: var Coloring[2], n: range[0 .. 64], overflow: uint64, i: int) =
  if i == col.N:
    return
  let recurOverflow = col.data[i] shl (64 - n)
  col.data[i] = (col.data[i] shr n) and overflow
  col.shiftRightImpl(n, recurOverflow, i + 1)

func `>>=`*(col: var Coloring[2], n: range[0 .. 64]) =
  ## In-place shift right
  col.shiftRightImpl(n, 0, 0)

func `$`*(col: Coloring[2]): string =
  result = ""
  for i in 0 ..< col.N:
    result.add($col[i])

