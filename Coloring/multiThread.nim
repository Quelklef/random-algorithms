import locks
import options
import strutils
import sequtils
import sugar
import os
import times
import terminal
import locks

import coloring
import find
import io
from misc import `*`, times

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

var tLock: Lock
initLock(tLock)
# termWidth and termHeight must be constants for the threads to work properly
# Besides, some of the formatting is hardcoded, so it won't work with other sizes. lol.
const termWidth = 271
const termHeight = 68 - 1
const topPad = 7  # How much the top rows take up
const blockWidth = (termWidth - 1) div threadCount - 1
const tableWidth = threadCount * (blockWidth + 1) + 1
const tableLeftMargin = int((termWidth - tableWidth) / 2)
const tableLeftMarginString = " " * tableLeftMargin
template writeShifted(f: File, s: string) = f.write(tableLeftMarginString & s)
template gotoShifted(f: File, x, y: int) = f.setCursorPos(x + tableLeftMargin, y)
const blankBlock = " " * blockWidth
const feedRowCount = termHeight - topPad - 1
var prevYs: array[threadCount, int]
template calcX(i: int): int = 1 + (blockWidth + 1) * i
proc newN(i, N: int) =
  let x = calcX(i)
  prevYs[i] = 0
  stdout.gotoShifted(x, 3)
  stdout.write(" N = " & $N)
  stdout.gotoShifted(x, 5)
  stdout.write(blankBlock)
  for i in 0 ..< feedRowCount:
    stdout.gotoShifted(x, topPad + i)
    stdout.write(blankBlock)
  stdout.flushFile
let trialCountStrLen = trialCount.`$`.len
proc reportTrial(i, trialNumber: int, v: string) =
  let x = calcX(i)
  stdout.gotoShifted(x + 1, 5)
  stdout.write("$# / $# trials ($#%)" % [
    trialNumber.`$`.align(trialCountStrLen),
    $trialCount,
    int(100 * trialNumber / trialCount).`$`.align(3)
  ])

  let curY = prevYs[i]
  let newY = (curY + 1) mod feedRowCount
  prevYs[i] = newY
  stdout.gotoShifted(x, newY + topPad)
  stdout.write(blankBlock)
  stdout.gotoShifted(x + 1, curY + topPad)
  stdout.write(v)
  stdout.flushFile

let rule      = "+" & ("-" * blockWidth & "+") * threadCount & "\n"
let dashes    = "+" & "-" * (tableWidth - 2) & "+" & "\n"
let title     = "|" & ("Running trials for C = $# K = $#" % [$C, $K]).center(tableWidth- 2) & "|" & "\n"
let blankRow  = "|" & (" " * blockWidth & "|") * threadCount & "\n"
stdout.writeShifted(dashes)
stdout.writeShifted(title)
stdout.writeShifted(rule)
stdout.writeShifted(blankRow)
stdout.writeShifted(rule)
stdout.writeShifted(blankRow)
stdout.writeShifted(rule)
feedRowCount.times: stdout.writeShifted(blankRow)
stdout.writeShifted(rule)
stdout.flushFile

proc doTrials(i: int) {.thread.} =
  while true:
    let N = nextN
    inc(nextN)
    withLock(tLock):
      newN(i, N)

    let filename = "N_$#.txt" % align($N, 5, '0')
    if not fileExists(filename):
      createFile(fileName)
    let existingTrials = numLines(filename)

    let file = open(filename, mode = fmAppend)
    try:
      for t in existingTrials ..< trialCount:
        let t0 = epochTime()
        let (flips, coloring) = find_noMAS_coloring(C, N, K)
        let duration = epochTime() - t0

        withLock(tLock):
          var p = ("$#s $#f" % [
            align(duration.formatFloat(ffDecimal, precision = 4), 13),
            align($flips, 14),
          ])
          reportTrial(i, t + 1, p)

        file.writeRow(flips)
    finally:
      close(file)

proc main() =
  for i in 0 ..< threadCount:
    threads[i].createThread(doTrials, i)
  joinThreads(threads)

main()
