
import twoColoring
import nColoring

type Coloring[C, N: static[int]] = object
    case isTwoColoring: bool
    of true:
        twoCol: TwoColoring[N]
    of false:
        nCol: Coloring[C, N]

proc initColoring[C, N]: Coloring[C, N] =
    when C == 2:
        return nColoringT[C, N](isTwoColoring: true, twoCol: initTwoColoring[N]())
    else:
        return nColoringT[C, N](isTwoColoring: false, nCol: initNColoring[C, N]())

