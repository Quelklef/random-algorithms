
import twoColoring
import nColoring

export TwoColoring
export NColoring

import hashes
import macros

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

template export_varColoring_void(function: untyped): untyped =
    proc `function`*(col: var Coloring) {.inline.} =
        function(col.data)

export_varColoring_void(randomize)

template export_varColoring_uint64_void(function: untyped): untyped =
    func `function`*(col: var Coloring, amt: uint64) {.inline.} =
        function(col.data, amt)

export_varColoring_uint64_void(`+=`)

template export_Coloring_range_0S_range_0C(function: untyped): untyped =
    func `function`*[C](col: Coloring[C], i: int): range[0 .. C - 1] {.inline.} =
        return function(col.data, i)

export_Coloring_range_0S_range_0C(`[]`)

template export_varColoring_range_0S_range_0C_void(function: untyped): untyped =
    func `function`*[C](col: var Coloring[C], i: int, val: range[0 .. C - 1]) {.inline.} =
        function(col.data, i, val)

export_varColoring_range_0S_range_0C_void(`[]=`)

template export_Coloring_string(function: untyped): untyped =
    func `function`*[C](col: Coloring[C]): string {.inline.} =
        return function(col.data)

export_Coloring_string(`$`)

template export_Coloring_Hash(function: untyped): untyped =
    func `function`*[C](col: Coloring[C]): Hash {.inline.} =
        return function(col.data)

export_Coloring_Hash(hash)

template export_Coloring_Coloring_bool(function: untyped): untyped =
    func `function`*[C](colA, colB: Coloring[C]): bool {.inline.} =
        return function(colA.data, colB.data)

export_Coloring_Coloring_bool(`==`)

template export_varColoring_int_void(function: untyped): untyped =
    func `function`*[C](col: var Coloring[C], amt: int): void =
        function(col.data, amt)

export_varColoring_int_void(extend)


iterator items*[C](col: Coloring[C]): range[0 .. C - 1] =
    for i in 0 ..< col.N:
        yield col.data[i]

iterator pairs*[C](col: Coloring[C]): (int, range[0 .. C - 1]) =
    for i in 0 ..< col.N:
        yield (i, col.data[i])

