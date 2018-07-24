import macros
import sequtils

import coloringDef

from twoColoring import nil
from nColoring import nil

func N*[C](col: Coloring[C]): int =
  when C == 2:
    return col.N
  else:
    return nColoring.N(col)

proc `@`(n: NimNode): seq[NimNode] {.compileTime.} =
  result = @[]
  for son in n:
    result.add(son)

#dumpTree:
#  func initColoring*(C: static[int], N: int): Coloring[C] =
#    when C == 2:
#      return twoColoring.initColoring(C, N)
#    else:
#      return nColoring.initColoring(C, N)

proc dispatchOne(decl: NimNode): NimNode {.compileTime.} =
  var reference = decl[0]
  if reference.kind == nnkPostFix:  # Unwrap from export
    reference = reference[1]

  proc makeCall(n: NimNode): NimNode =
    result = nnkCall.newTree(quote do: `n`.`reference`)
    for formalParam_s in @(decl[3])[1 ..< ^0]:  # Skip the first param, which is return type
      result.add(@formalParam_s[0 ..< ^2])  # Extract reference from param(s)
    result = (quote do: return `result`)

    # Add generic params if appropriate
    let hasGenerics = decl[2].len != 0
    if hasGenerics:
      # Replace naked reference to proc with bracket expr
      result[0] = nnkBracketExpr.newTree(@[result[0]] & @decl[2][0])
    
  var twoColoringCall = makeCall(newIdentNode("twoColoring"))
  var nColoringCall = makeCall(newIdentNode("nColoring"))

  result = decl.copyNimTree
  result[6] = quote do:  # Proc body
    when C == 2: `twoColoringCall`
    else: `nColoringCall`

  echo(result.repr)

macro dispatch(decls: untyped): untyped =
  result = nnkStmtList.newTree(@decls.map(dispatchOne))

dispatch:
  func initColoring*(C: static[int], N: int): Coloring[C]
  func `==`*[C: static[int]](col0, col1: Coloring[C]): bool
  func `[]`*[C: static[int]](col: Coloring[C], i: int): range[0 .. C - 1]
  func `[]=`*[C: static[int]](col: var Coloring[C], i: int, val: range[0 .. C - 1])
  func `+=`*[C: static[int]](col: var Coloring[C], amt: uint64)
  func `$`*[C: static[int]](col: Coloring[C]): string
  func randomize*[C: static[int]](col: var Coloring[C])

iterator items*[C](col: Coloring[C]): range[0 .. C - 1] =
  for i in 0 ..< col.N:
    yield col[i]

iterator pairs*[C](col: Coloring[C]): (int, range[0 .. C - 1]) =
  for i in 0 ..< col.N:
    yield (i, col[i])

func initColoring(C: static[int], s: string): Coloring[C] =
  result = initColoring(C, s.len)
  for i, c in s:
    result[i] = ord(c) - ord('0')



when isMainModule:
  var c2: Coloring[2] = initColoring(2, 100)
  c2[0] = 1
