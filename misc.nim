
import random
import tables
import strutils
import math
import options

random.randomize()

var localRand = initRand(rand(int.high))
proc rand_u64*(): uint64 =
    return localRand.next()

# -- #

template times*(n: Natural, code: untyped): untyped =
    for _ in 0 ..< n:
        code

template loopfrom*(ident: untyped, n: int, code: untyped): untyped =
    var ident = n
    while true:
        code
        inc(ident)

# -- #

func getOption*[K, V](tab: Table[K, V], k: K): Option[V] =
    if k in tab:
        return some(tab[k])
    return none(V)

# -- #

func replaceMany*(s: string, repl: Table[string, string]): string =
    ## Behaviour is undefined if duplicate keys exist
    result = ""

    var i = 0
    while i < s.len:
        block continueOuter:
            for term in repl.keys:
                if s.continuesWith(term, i):
                    result.add(repl[term])
                    i += term.len
                    break continueOuter
            result.add(s[i])
            inc(i)

when isMainModule:
    assert("cool wow nice" == "nice cool wow".replaceMany({"nice": "cool", "cool": "wow", "wow": "nice"}.toTable))
    assert("abc" == "123".replaceMany({"1": "a", "2": "b", "3": "c"}.toTable))

