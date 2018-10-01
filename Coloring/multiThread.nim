import locks
import options
import strutils
import sequtils
import sugar
import os
import times
import terminal
import tables

import coloring
import find
import fileio
import pattern as patternModule
from ../util import `*`, times, `{}`, createFile, numLines

#[
4 command-line params:
C: C
pattern-type: the type of the mask pattern
pattern-arg: string argument of the pattern
trials: Number of desired trials for each datapoint
maxN: the highest N to go to before beginning the next coloring
]#

when not defined(release):
  echo("WARNING: Not running with -d:release. Press enter to continue.")
  discard readLine(stdin)

# Only supports C=2
assert "2" == paramStr(1)
const C = 2 #paramStr(1).parseInt
let pattern = Pattern(
  kind: patternKinds[paramStr(2)],
  arg: paramStr(3),
)

let outdirName = "data/C=$#;pattern=$#" % [C.`$`.align(5, '0'), $pattern]
if not existsDir(outdirName):
  createDir(outdirName)

# How many trials we want for each datapoint
let desiredTrialCount = paramStr(4).parseInt
let maxN = paramStr(5).parseInt
const threadCount = 8

var workerThreads: array[threadCount, Thread[tuple[i: int; pattern: Pattern, outdirName: string]]]
var nextN = 1

var terminalLock: Lock
initLock(terminalLock)

proc put(s: string; y = 0) =
  stdout.setCursorPos(0, y)
  stdout.eraseLine()
  stdout.write(s)
  stdout.flushFile()

proc work(values: tuple[i: int, pattern: Pattern, outdirName: string]) {.thread.} =
  let (i, pattern, outdirName) = values

  while true:
    let N = nextN

    if N >= maxN:
      break

    withLock(terminalLock):
      put("## Beginning N=$# on thread $# ##" % [$N, $i], i + 1)
    discard atomicInc(nextN)
    let filename = outdirName / "N=$#.txt" % $N

    if not fileExists(filename):
      createFile(fileName)
    let existingTrials = numLines(filename)

    let file = open(filename, mode = fmAppend)
    defer: file.close()

    for t in existingTrials + 1 .. desiredTrialCount:
      let t0 = epochTime()
      let (flips, _) = find_noMMP_coloring_progressive(C, N, proc(d: int): Coloring[2] = pattern.invoke(d))
      let duration = epochTime() - t0

      withLock(terminalLock):
        put("Found coloring for C=$#, pattern=$# in $# flips, $#s on thread $#" % [$C, $pattern, $flips, $duration, $i])

      file.writeRow(flips)

proc main() =
  eraseScreen()

  put("Desiring $# trials" % $desiredTrialCount, threadCount + 2)
  put("Running through n=$#" % $maxN, threadCount + 3)

  for i in 0 ..< threadCount:
    workerThreads[i].createThread(work, (i: i, pattern: pattern, outdirName: outdirName))
  workerThreads.joinThreads()

main()
