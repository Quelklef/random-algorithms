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

proc arithmeticTrialGen*(p: int): TrialSpec =
  result.C = 2

  let patternStr = p.toBin(8)
  result.pattern = proc(d: int): Coloring =
      result = initColoring(2, d * (patternStr.len - 1) + 1)
      for i, c in patternStr:
        if c == '1':
          result[i * d] = 1

  result.maxN = 500
  result.coloringCount = 100_000
  result.outloc = "data/arithmetic/$#" % $p
  result.description = "arithmetic p=$#, pattern=$#" % [$p, $patternStr]
