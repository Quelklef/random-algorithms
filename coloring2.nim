
import macros

import twoColoring
import nColoring

macro coloringImpl(N: static[int], S: untyped): untyped =
    if N == 2:
        result = nnkBracketExpr.newTree(
            ident("TwoColoring"), S
        )
    else:
        result = nnkBracketExpr.newTree(
            ident("NColoring"), newIntLitNode(N), S
        )

type Coloring[N, S: static[int]] = object
    data: coloringImpl(N, S)

template exportCol(function: untyped, ResultType: untyped): untyped =
    proc `function`*(x, y: Coloring): ResultType =
        when ResultType is Coloring:
            result.data = function(x.data, y.data)
        else:
            function(x.data, y.data)

proc `+`*(x, y: Coloring): Coloring =
    echo x
    echo y
    return x

exportCol(`+`, Coloring)

var a: Coloring[2, 100]
var b: Coloring[3, 100]

discard a + b

