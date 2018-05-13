import macros

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
    proc `function`*(x, y: Col): ResultType {.inline.} =
        when ResultType is Col:
            result.data = function(x.data, y.data)
        else:
            function(x.data, y.data)

proc `+`[N, S](x, y: Coloring[N, S]): Coloring[N, S] =
    echo x
    echo y
    return x
exportCol(x, y)


