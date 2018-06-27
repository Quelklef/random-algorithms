
import random

random.randomize()

var localRand = initRand(rand(int.high))
proc rand_u64*(): uint64 =
    return localRand.next()

