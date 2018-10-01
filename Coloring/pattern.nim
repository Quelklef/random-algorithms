import tables
import strutils

import coloring

#[
A pattern reifies complex patterns
This could all be done with a closure, but closures don't
work nicely with multithreading
]#

type PatternKind* = enum
  pkArithmetic
type Pattern* = object
  kind*: PatternKind
  arg*: string

proc invoke*(patt: Pattern, d: int): Coloring =
  case patt.kind
  of pkArithmetic:
    result = initColoring(2, d * (patt.arg.len - 1) + 1)
    for i, c in patt.arg:
      if c == '1':
        result[i * d] = 1

proc `$`*(patt: Pattern): string =
  return "$#($#)" % [
    case patt.kind
    of pkArithmetic: "arithmetic"
    ,
    patt.arg
  ]

let patternKinds* = {
  "arithmetic": pkArithmetic,
}.toTable
