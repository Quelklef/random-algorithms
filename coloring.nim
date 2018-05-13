
import twoColoring
import nColoring

import macros

macro coloringImpl(C: static[int], S: untyped): untyped =
    if C == 2:
        return nnkBracketExpr.newTree(ident("TwoColoring"), S)
    else:
        return nnkBracketExpr.newTree(ident("NColoring"), newIntLitNode(C), S)

type Coloring[C, S: static[int]] = object
    data: coloringImpl(C, S)

proc initColoring[C, S](): Coloring[C, S] =
    discard

template export_varColoring_uint64_void(function: untyped): untyped =
    proc `function`*(col: var Coloring, amt: uint64) {.inline.} =
        function(col.data, amt)

export_varColoring_uint64_void(`+=`)

template export_Coloring_range_0S_range_0C(function: untyped): untyped =
    proc `function`*[C, S](col: Coloring[C, S], i: range[0 .. S - 1]): range[0 .. C - 1] {.inline.} =
        return function(col.data, i)

export_Coloring_range_0S_range_0C(`[]`)

template export_varColoring_range_0S_range_0C_void(function: untyped): untyped =
    proc `function`*[C, S](col: Coloring[C, S], i: range[0 .. S - 1], val: range[0 .. C - 1]) {.inline.} =
        return function(col.data, i, val)

export_varColoring_range_0S_range_0C_void(`[]=`)

template export_Coloring_string(function: untyped): untyped =
    proc `function`*[C, S](col: Coloring[C, S]): string {.inline.} =
        return function(col.data)

export_Coloring_string(`$`)

when isMainModule:
    import typetraits

    # Test merging types

    var tc = initColoring[2, 128]()
    var nc = initColoring[5, 128]()

    tc += 2
    nc += 5

    echo tc
    echo nc

    echo tc.data.type.name
    echo nc.data.type.name

    # Test creating new proc

    proc test[C, S](col: Coloring[C, S]) =
        echo($C, " ", $S)

    test(tc)
    test(nc)

