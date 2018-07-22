import locks
import options
import strutils
import sugar

import coloring
import find
import io

when not defined(reckless):
  echo("INFO: Not running with -d:reckless.")
when not defined(release):
  echo("WARNING: Not running with -d:release. Press enter to continue.")
  discard readLine(stdin)

const C = 2
const K = 5
const outFileLoc = "data.txt"
const threadCount = 8

# How many trials we want for each datapoint
const trialCount = 10_000

# -- #

block:
  let metaFile = open("meta.txt", mode = fmWrite)
  metaFile.writeLine("C = $#" % $C)
  metaFile.writeLine("K = $#" % $K)
  close(metaFile)

var threads: array[threadCount, Thread[int]]
var nextN = K  # The next N we want to work on

#const tabular = initTabular(
#  ["C", "K", "N", "Flips"               , "Coloring"],
#  [2  , 3  , 4  , len($high(BiggestInt)), 100       ],
#)
#echo(tabular.title())

proc doTrials(i: int) {.thread.} =
  let N = nextN
  inc(nextN)

  let file = open("N_$#.txt" % align($N, 5, '0'), mode = fmWrite)
  for i in 0 ..< trialCount:
    let (flips, coloring) = find_noMAS_coloring(C, N, K)
    file.writeRow(N, flips, coloring.map(x => $x).get("-"))
  close(file)

  doTrials(i)

for i in 0 ..< threadCount:
  threads[i].createThread(doTrials, i)
joinThreads(threads)
