import hashes
import macros
import strutils

import twoColoring
import nColoring

export TwoColoring
export NColoring

macro coloringImpl*(C: static[int]): untyped =
  if C == 2:
    return ident("TwoColoring")
  else:
    return nnkBracketExpr.newTree(ident("NColoring"), newIntLitNode(C))

type Coloring*[C: static[int]] = object
  data*: coloringImpl(C)

func N*[C](col: Coloring[C]): int =
  return col.data.N

func initColoring*(C: static[int], N: int): Coloring[C] =
  when C == 2:
    result.data = initTwoColoring(N)
  else:
    result.data = initNColoring(C, N)


func sons(n: NimNode): seq[NimNode] =
  result = @[]
  for son in n:
    result.add(son)

func len(n: NimNode): int =
  for son in n:
    inc(result)

func `[]`(n: NimNode; sl: Slice[int]): seq[NimNode] =
  return n.sons[sl]

proc removeExportPostfix(expr: NimNode): NimNode =
  if expr.kind == nnkPostfix:
    return expr[1]
  return expr

proc dispatchProc(procDecl: NimNode): NimNode =
  var args: seq[NimNode] = @[]
  for formalParam in procDecl[3][1 ..< procDecl[3].len]:  # Ignore return val
    var params: seq[NimNode]
    case formalParam.kind
    of nnkIdent: params = @[formalParam]
    of nnkIdentDefs: params = formalParam[0 .. formalParam.len - 3]
    else: assert(false)

    for ident in params:
      if ident.strVal.startsWith("col"):
        args.add(nnkDotExpr.newTree(ident, newIdentNode("data")))
      else:
        args.add(ident)

  var procDef = procDecl.copyNimTree

  if procDef[4] == newEmptyNode():
    procDef[4] = nnkPragma.newTree()
  procDef[4].add(newIdentNode("inline"))

  let call = newCall(procDecl[0].removeExportPostfix, args)
  if procDecl[3][0].kind == nnkEmpty:  # No return type
    procDef[6] = call
  else:
    procDef[6] = nnkReturnStmt.newTree(call)

  return procDef

macro dispatchProcs(stmtList: untyped): untyped =
  result = nnkStmtList.newTree()
  for procDecl in stmtList:
    result.add(dispatchProc(procDecl))

dispatchProcs:
  proc randomize*[C](col: var Coloring[C])
  proc downSizeonce*[C](col: var Coloring[C])
  proc `+=`*[C](col: var Coloring[C]; amt: uint64)
  proc `[]`*[C](col: Coloring[C]; i: int): range[0 .. C - 1]
  proc `[]=`*[C](col: var Coloring[C]; i: int; val: range[0 .. C - 1])
  proc `$`*[C](col: Coloring[C]): string
  proc hash*[C](col: Coloring[C]): Hash
  proc `==`*[C](col0, col1: Coloring[C]): bool
  proc `>>=`*[C](col: var Coloring[C]; amt: int)
  proc `<<=`*[C](col: var Coloring[C]; amt: int)
  proc homogenous*[C](col: Coloring[C]; colMask: Coloring[2]): bool

proc `or`*[C](col0, col1: Coloring[C]): Coloring[C] =
  result.data = col0.data or col1.data


iterator items*[C](col: Coloring[C]): range[0 .. C - 1] =
  for i in 0 ..< col.N:
    yield col.data[i]

iterator pairs*[C](col: Coloring[C]): (int, range[0 .. C - 1]) =
  for i in 0 ..< col.N:
    yield (i, col.data[i])

func initColoring*(C: static[int], s: string): Coloring[C] =
  result = initColoring(C, s.len)
  for i, c in s:
    result[i] = ord(c) - ord('0')
