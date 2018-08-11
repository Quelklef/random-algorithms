import locks
import options
import strutils
import sequtils
import sugar
import os
import times
import terminal

import coloring
import find
import fileio
from ../util import `*`, times
import ../gridio
import ../unifiedStyle

#[
3 command-line params:
C: C
mask: The mask to test for monochromicity
trials: Number of desired trials for each datapoint
]#

when not defined(release):
  echo("WARNING: Not running with -d:release. Press enter to continue.")
  discard readLine(stdin)

# Only supports C=2
assert "2" == paramStr(1)
const C = 2 #paramStr(1).parseInt
let mask = initColoring(C, paramStr(2))
# How many trials we want for each datapoint
let trialCount = paramStr(3).parseInt
const threadCount = 8

# -- #

var threads: array[threadCount, Thread[tuple[i: int, mask: Coloring[2]]]]
var nextN = mask.N

proc numLines(f: string): int =
  return f.readFile.string.countLines - 1

proc createFile(f: string) =
  close(open(f, mode = fmWrite))

func timeFormat(t: float): string =
  var rest = int(t * 1000)

  let hurs = rest div 3600000
  rest = rest mod 3600000

  let mins = rest div 60000
  rest = rest mod 60000

  let secs = rest div 1000
  rest = rest mod 1000

  let mils = rest

  result              = mils.`$`.align(3, ' ') & "ms"
  if secs > 0: result = secs.`$`.align(2, ' ') & "s " & $result
  if mins > 0: result = mins.`$`.align(2, ' ') & "m " & $result
  if hurs > 0: result = hurs.`$`.align(2, ' ') & "h " & $result

func reprInXChars(val: float, n: int, suffix: string): string =
  const prefixes = [
    (""  , 1.0                ),
    ("h" , 100.0              ),
    ("k" , 1_000.0            ),
    ("M" , 1_000_000.0        ),
    ("G" , 1_000_000_000.0    ),
    ("T" , 1_000_000_000_000.0),
    ("_" , Inf                ),
  ]

  for i, prefix in prefixes:
    let (pref, amt) = prefix
    if prefixes[i + 1][1] > val:
      result = (val / amt).formatFloat(ffDecimal, precision = 2)
      if result.len > (n - pref.len - suffix.len):
        result = result[0 ..< (n - pref.len - suffix.len)]
      return align(result & pref & suffix, n)

let titleRow = box(1)
var columnDisplays: array[threadCount, Gridio]
for i in 0 ..< threadCount:
  let N_disp = box(1)
  let summary = box(1)
  let radar = box()
  radar.writeStyle = wsRadar
  let column = rows(@[N_disp, summary, radar])
  columnDisplays[i] = column
let columnDisplaysWrap = cols(@columnDisplays)
let root = rows(@[titleRow, columnDisplaysWrap])
root.fix()
root.drawOutline(stylish({styleDim}))
titleRow.write(
  "Running trials for (C = $#; mask = $#). Press enter to exit.".center(titleRow.width) %
    [$C, $mask], stylish({styleBright}))

var displayChannel: Channel[tuple[i: int, child_i: int, msg: string, stylish: Stylish]]
displayChannel.open()

proc displayN(i: int; N: int, stylish = styleless) =
  displayChannel.send((i: i, child_i: 0, msg: " N = " & $N, stylish: stylish))
proc displayTrialCount(i: int; count: int, stylish = styleless) =
  displayChannel.send((i: i, child_i: 1, msg: " $# / $# trials ($#%)" % [
    count.`$`.align(($trialCount).len),
    $trialCount,
    int(count / trialCount * 100).`$`.align(3),
  ], stylish: stylish))
proc displayTrial(i: int; trial: string, stylish = styleless) =
  displayChannel.send((i: i, child_i: 2, msg: trial, stylish: stylish))

let columnWidth = columnDisplays[0].width
proc doTrials(values: tuple[i: int, mask: Coloring[2]]) {.thread.} =
  let (i, mask) = values
  while true:
    let N = nextN
    inc(nextN)

    let filename = "N_$#.txt" % align($N, 5, '0')
    if not fileExists(filename):
      createFile(fileName)
    let existingTrials = numLines(filename)

    block:
      let file = open(filename, mode = fmRead)
      defer: close(file)

      displayN(i, N)
      displayTrialCount(i, existingTrials)
      for line in file.lines:
        displayTrial(i, line.string.parseInt.float.reprInXChars(columnWidth - 1, "f"))

    let file = open(filename, mode = fmAppend)
    defer: close(file)

    for t in existingTrials + 1 .. trialCount:
      let t0 = epochTime()
      let (flips, _) = find_noMMP_coloring(C, N, mask)
      let duration = epochTime() - t0

      displayTrialCount(i, t)
      let halfWidth = (columnWidth - 2 - 1) div 2
      let trialStr = " $# $# " % [
        timeFormat(duration).align(halfWidth),
        flips.float.reprInXChars(halfWidth - 1, "f"),
      ]
      displayTrial(i, trialStr)

      file.writeRow(flips)

proc main() =
  for i in 0 ..< threadCount:
    threads[i].createThread(doTrials, (i: i, mask: mask))

  var quitThread: Thread[void]
  quitThread.createThread do:
    discard readline(stdin)
    quit()

  while true:
    let (i, child_i, msg, style) = displayChannel.recv
    columnDisplays[i].children[child_i].write(msg, style)

main()
