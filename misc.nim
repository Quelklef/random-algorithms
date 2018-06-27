
import random
import tables
import strutils

random.randomize()

var localRand = initRand(rand(int.high))
proc rand_u64*(): uint64 =
    return localRand.next()

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

