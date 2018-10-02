import strutils
import math
import tables

import coloring

type TrialSpec* = object
  C*: int

  # The goal number of colorings to generate
  coloringCount*: int

  # The goal N to reach
  maxN*: int

  pattern*: proc(d: int): Coloring {.gcSafe.}

  # Output directory
  outloc*: string

  # Human-readable desc
  description*: string

proc toBase(x, b: int): string =
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

proc arithmeticTrialGen*(p: int): TrialSpec =
  result.C = 2

  let patternStr = p.toBase(2)
  result.pattern = proc(d: int): Coloring =
    result = initColoring(2, d * (patternStr.len - 1) + 1)
    for i, c in patternStr:
      if c == '1':
        result[i * d] = 1

  result.coloringCount = 1_000_000
  result.outloc = "data/arithmetic/$#" % $p
  result.description = "arithmetic p=$#, pattern=$#" % [$p, $patternStr]

when isMainModule:
  for i in 0..20:
    echo(($i).align(3), " ", arithmeticTrialGen(i).pattern(1))
