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

func timeFormat(t: float, size: int): string =
  var rest = int(t * 1000)

  let hurs = rest div 3600000
  rest = rest mod 3600000

  let mins = rest div 60000
  rest = rest mod 60000

  let secs = rest div 1000
  rest = rest mod 1000

  let mils = rest

  result              = "\e[36m" & mils.`$`.align(3, ' ') & "ms"
  if secs > 0: result = "\e[32m" & secs.`$`.align(2, ' ') & "s " & $result
  else:        result = "    " & $result
  if mins > 0: result = "\e[35m" & mins.`$`.align(2, ' ') & "m " & $result
  else:        result = "    " & $result
  if hurs > 0: result = "\e[31m" & hurs.`$`.align(2, ' ') & "h " & $result
  else:        result = "    " & $result
  result &= "\e[0m"

func reprInXChars(val: float, n: int, suffix: string): string =
  const prefixes = [
    (""  , 1.0                , ""),
    ("da", 10.0               , ""),
    ("h" , 100.0              , "\e[36m"),
    ("k" , 1_000.0            , "\e[32m"),
    ("M" , 1_000_000.0        , "\e[35m"),
    ("G" , 1_000_000_000.0    , "\e[1m\e[36m"),
    ("T" , 1_000_000_000_000.0, "\e[1m\e[32m"),
    ("_" , Inf                , ""),
  ]

  for i, prefix in prefixes:
    let (pref, amt, color) = prefix
    if prefixes[i + 1][1] > val:
      result = (val / amt).formatFloat(ffDecimal, precision = 2)
      if result.len > (n - pref.len - suffix.len):
        result = result[0 ..< (n - pref.len - suffix.len)]
      return color & align(result & pref & suffix, n) & "\e[0m"

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
let trialCountStrLen = trialCount.`$`.len
proc trialHeader(i, trialNumber: int) =
  let x = calcX(i)
  # We need to clear the block in the edge case that a previous trial had
  # a wider header, for instance if the program was run with a goal of 1000
  # trials and then rerun later with a goal of 50.
  # The header would be '1000 / 50 trials (500%)' which is larger than we
  # need or want for `XX / 50 trials (XXX%)`.
  stdout.gotoShifted(x, 5)
  stdout.write(blankBlock)
  stdout.gotoShifted(x + 1, 5)
  stdout.write("$# / $# trials ($#%)" % [
    trialNumber.`$`.align(trialCountStrLen),
    $trialCount,
    int(100 * trialNumber / trialCount).`$`.align(3)
  ])
  stdout.flushFile
proc newN(i, N, existingTrials: int) =
  trialHeader(i, existingTrials)
  let x = calcX(i)
  prevYs[i] = 0
  stdout.gotoShifted(x, 3)
  stdout.write(" N = " & $N)
  for i in 0 ..< feedRowCount:
    stdout.gotoShifted(x, topPad + i)
    stdout.write(blankBlock)
  stdout.flushFile
proc reportTrial(i, trialNumber: int, duration: float, flips: int) =
  trialHeader(i, trialNumber)
  let x = calcX(i)
  let curY = prevYs[i]
  let newY = (curY + 1) mod feedRowCount
  prevYs[i] = newY
  stdout.gotoShifted(x, newY + topPad)
  stdout.write(blankBlock)
  stdout.gotoShifted(x + 1, curY + topPad)
  stdout.write("$# $#" % [
    timeFormat(duration, 18),
    flips.float.reprInXChars(12, "f")
  ])
  stdout.flushFile

let rule      = "├" & ("─" * blockWidth & "┼") * (threadCount - 1) & "─" * blockWidth & "┤" & "\n"
let rule2     = "├" & ("─" * blockWidth & "┬") * (threadCount - 1) & "─" * blockWidth & "┤" & "\n"
let dashesTop = "┌" & "─" * (tableWidth - 2) & "┐" & "\n"
let dashesBot = "└" & ("─" * blockWidth & "┴") * (threadCount - 1) & "─" * blockWidth & "┘" & "\n"
let title     = "│\e[1m" & ("Running trials for C = $# K = $#. Press enter to quit." % [$C, $K]).center(tableWidth - 2) & "\e[0m\e[2m│" & "\n"
let blankRow  = "│" & (" " * blockWidth & "│") * threadCount & "\n"
stdout.write("\e[2m")
stdout.writeShifted(dashesTop)
stdout.writeShifted(title)
stdout.writeShifted(rule2)
stdout.writeShifted(blankRow)
stdout.writeShifted(rule)
stdout.writeShifted(blankRow)
stdout.writeShifted(rule)
feedRowCount.times: stdout.writeShifted(blankRow)
stdout.writeShifted(dashesBot)
stdout.write("\e[0m")
stdout.flushFile

proc doTrials(i: int) {.thread.} =
  while true:
    let N = nextN
    inc(nextN)

    let filename = "N_$#.txt" % align($N, 5, '0')
    if not fileExists(filename):
      createFile(fileName)
    let existingTrials = numLines(filename)

    withLock(tLock):
      newN(i, N, existingTrials)

    let file = open(filename, mode = fmAppend)
    defer: close(file)
    for t in existingTrials ..< trialCount:
      let t0 = epochTime()
      let (flips, coloring) = find_noMAS_coloring(C, N, K)
      let duration = epochTime() - t0

      withLock(tLock):
        reportTrial(i, t + 1, duration, flips)

      file.writeRow(flips)

proc main() =
  for i in 0 ..< threadCount:
    threads[i].createThread(doTrials, i)

  var quitThread: Thread[void]
  quitThread.createThread do:
    discard readLine(stdin)

  joinThread(quitThread)

main()
