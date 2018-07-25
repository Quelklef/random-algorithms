import locks
import options
import strutils
import sugar
import os

import coloring
import find
import io

#[
4 command-line params:
C: C
K: K
trials: Number of desired trials for each datapoint
N: The N to start at
]#

when not defined(reckless):
  echo("INFO: Not running with -d:reckless.")
when not defined(release):
  echo("WARNING: Not running with -d:release. Press enter to continue.")
  discard readLine(stdin)

# Only supports C=2
assert "2" == paramStr(1)
const C = 2 #paramStr(1).parseInt
let K = paramStr(2).parseInt
# How many trials we want for each datapoint
let trialCount = paramStr(3).parseInt
const threadCount = 8

# -- #

var threads: array[threadCount, Thread[int]]
var nextN = paramStr(4).parseInt  # The next N we want to work on

proc numLines(f: string): int =
  return f.readFile.string.countLines - 1

proc createFile(f: string) =
  close(open(f, mode = fmWrite))

proc doTrials(i: int) {.thread.} =
  let N = nextN
  inc(nextN)

  let filename = "N_$#.txt" % align($N, 5, '0')
  if not fileExists(filename):
    createFile(fileName)
  let existingTrials = numLines(filename)

  let file = open(filename, mode = fmAppend)
  try:
    for _ in existingTrials ..< trialCount:
      let (flips, coloring) = find_noMAS_coloring(C, N, K)
      #file.writeRow(N, flips, $coloring)
      file.writeRow(flips)
  finally:
    close(file)

  doTrials(i)

proc main() =
  for i in 0 ..< threadCount:
    threads[i].createThread(doTrials, i)
  joinThreads(threads)

main()
