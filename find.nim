
import options

import coloring

iterator skip*[T](a, step: T, n: int): T =
    ## Yield a, a + T, a + 2T, etc., n times
    var x = a
    for _ in 0 ..< n:
        yield x
        x += step

#TODO Eli check this please
#idea is that if i pass 1011 into pattern it will look for "a     a+2d a+3d" type patterns
#4 MAS could be changed to 1111 etc removing need for the other skip iterator
#would probably need to rename things
iterator skip*[T](a, step: T, pattern: string): T =
    var x = a
    for index, chr in pattern:
      if chr == '1':
        yield x
      x += step

func has_MAS*[C](coloring: Coloring[C], K: int): bool =
    ## Find monochromatic arithmetic subseq of size K
    var col = coloring
    # Iterate over step sizes, which is the distance between each item in the MAS
    for stepSize in 1 .. (col.N - 1) div (K - 1):
        for startLoc in 0 .. col.N - (K - 1) * stepSize - 1:
            block skipping:
                let expectedColor = col[startLoc] # The expected color for the sequence
                for i in skip(startLoc, stepSize, K):
                    if col[i] != expectedColor:
                        break skipping # Go to next start loc
                return true
    return false

proc find_noMAS_coloring*(C: static[int], N, K: int, iterThreshold: BiggestInt): tuple[flipCount: int, coloring: Option[Coloring[C]]] =
    var col = initColoring(C, N)
    var flips = 0

    while true:
        if flips > iterThreshold:
            return (flipCount: flips, coloring: none(Coloring[C]))

        col.randomize()
        inc(flips)

        if not col.has_MAS(K):
            return (flipCount: flips, coloring: some(col))
