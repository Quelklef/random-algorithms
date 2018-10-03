import locks
import options
import strutils
import sequtils
import sugar
import os
import times
import terminal
import tables
import threadpool

import coloring
import find
import trial
from ../util import `*`, times, `{}`, createFile, numLines, optParam

const threadCount = 8

when not defined(release):
  echo("WARNING: Not running with -d:release. Press enter to continue.")
  discard readLine(stdin)

var ioLock: Lock
initLock(ioLock)

proc put(s: string; y: int) =
  stdout.setCursorPos(0, y)
  stdout.eraseLine()
  stdout.write(s)
  stdout.flushFile()

# As soon as we reach an N with colorings=successes,
# we want to stop doing work
# This flag says to stop doing work
var patternFinished: bool

proc work(vals: (int, int, TrialSpec)) {.thread.} =
  let (i, N, spec) = vals
  var lastUpdate = 0.0  # 0 so that always updates on a new pattern

  # Store a (count, success) tuple as data
  var colorings = 0
  var successes = 0

  let fileloc = spec.outloc / "$#.txt" % $N

  if fileExists(fileloc):
    let file = open(fileloc, mode = fmRead)
    defer: file.close()
    let existingData = file.readAll().splitLines()
    try:
      colorings = parseInt(existingData[0])
      successes = parseInt(existingData[1])
    except ValueError:
      put("WARNING: data in " & fileloc & " corrupt; overwriting", threadCount + 1)
      colorings = 0
      successes = 0

  defer:
    let file = open(fileloc, mode = fmWrite)
    file.write($colorings & "\n" & $successes & "\n")
    file.close()

  var col = initColoring(spec.C, N)
  while colorings < spec.coloringCount:
    col.randomize()
    colorings += 1
    if col.hasMMP_progression(spec.pattern):
      successes += 1

    template formatPercent(x): string = (x * 100).formatFloat(format = ffDecimal, precision = 1).align(5)

    # Because IO is (presumably) such a huge portion of the runtime, only update every now and then
    const pause = 0.3  # minmum time between IO updates (s)
    if epochTime() > lastUpdate + pause:
      lastUpdate = epochTime()
      withLock(ioLock):
        let aN = ($N).align(len($spec.maxN))
        let aTrialCount = ($colorings).align(len($spec.coloringCount))
        put("[Thread $#] [$#] [N=$#] [Trial #$#/$#; $#%] :: $#%" %
          [
            $i,
            spec.description,
            aN,
            aTrialCount,
            $spec.coloringCount,
            (colorings / spec.coloringCount).formatPercent,
            (successes / colorings).formatPercent,
          ],
          i + 1,
        )

  if colorings == successes:
    patternFinished = true

var stop = false
var stopThread: Thread[void]

proc main() =
  eraseScreen()
  put("Press <return> to exit.", 0)

  let trialGen = arithmeticTrialGen
  var p = 0

  stopThread.createThread:
    discard readLine(stdin)
    quit()

  while true:
    let trialSpec = trialGen(p)
    p += 1
    patternFinished = false

    if not dirExists(trialspec.outloc):
      createDir(trialspec.outloc)

    var threads: array[threadCount, Thread[(int, int, TrialSpec)]]

    var N = 1
    while not patternFinished:
      for i in 0 ..< threadCount:
        if not threads[i].running:
          threads[i].createThread(work, (i, N, trialSpec))
          N += 1

   # Wait for work to finish
    threads.joinThreads()

main()
