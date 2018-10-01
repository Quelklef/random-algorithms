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
from ../util import `*`, times, `{}`, createFile, numLines, optParam

let C = 2
let desiredTrialCount = 100_000
let maxN = 1000
let pattern = Pattern(kind: patternKinds["arithmetic"], arg: "1011")

# If we generate this many unsatisfactory colorings without generating a single
# satisfactory one, abort
let tolerance = 25000

when not defined(release):
  echo("WARNING: Not running with -d:release. Press enter to continue.")
  discard readLine(stdin)

let outdirName = "data/C=$#;pattern=$#" % [C.`$`.align(5, '0'), $pattern]
if not existsDir(outdirName):
  createDir(outdirName)

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
    var tolerable = false

    if N >= maxN:
      break

    withLock(terminalLock):
      put("Thread $# N=$#" % [$i, $N], i)

    discard atomicInc(nextN)
    let filename = outdirName / "N=$#.txt" % $N

    if not fileExists(filename):
      createFile(filename)

    var existingTrialCount: int
    block:
      let file = open(filename, mode = fmRead)
      existingTrialCount = file.getFileSize().int
      if '1' in file.readAll():
        tolerable = true
      file.close()

    let file = open(filename, mode = fmAppend)
    defer: file.close()

    var col = initColoring(C, N)
    for t in 0 ..< desiredTrialCount - existingTrialCount:
      # Note that we're testing against t here, meaning each time we run the program
      # we give the colorings a 'second chance' to be tolerable
      if t >= tolerance and not tolerable:
        break

      col.randomize()
      if col.hasMMP_progression(proc(d: int): Coloring = pattern.invoke(d)):
        file.write(0)
      else:
        tolerable = true
        file.write(1)

      template formatPercent(x): string = x.formatFloat(format = ffDecimal, precision = 1).align(5)

      withLock(terminalLock):
        let trialCount = t + existingTrialCount
        let aN = ($N).align(len($maxN))
        let aTrialCount = ($trialCount).align(len($desiredTrialCount))
        put("[Thread $#] [N=$#/$#; $#%] [Trial #$#/$#; $#%] [$#; $# left]" %
          [
            $i,
            aN,
            $maxN,
            (N / maxN * 100).formatPercent,
            aTrialCount,
            $desiredTrialCount,
            (trialCount / desiredTrialCount * 100).formatPercent,
            if tolerable: "  tolerable" else: "intolerable",
            ($max(0, tolerance - t)).align(len($tolerance)),
          ],
          i,
        )

proc main() =
  eraseScreen()
  for i in 0 ..< threadCount:
    workerThreads[i].createThread(work, (i: i, pattern: pattern, outdirName: outdirName))
  workerThreads.joinThreads()

main()
