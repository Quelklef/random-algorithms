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
from ../util import `*`, times, `{}`
import ../gridio
import ../stylish

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

func timeFormat(t: float, width: int): StylishString =
  var rest = int(t * 1000)
  let hurs = rest div 3600000
  rest = rest mod 3600000
  let mins = rest div 60000
  rest = rest mod 60000
  let secs = rest div 1000
  rest = rest mod 1000
  let mils = rest

  result              = (mils.`$`.align(3) & "ms").withStyle(stylish(fgCyan               ))
  if secs > 0: result = (secs.`$`.align(2) & "s ").withStyle(stylish(fgGreen              )) & result
  else: result = "  ".initStylishString & result
  if mins > 0: result = (mins.`$`.align(2) & "m ").withStyle(stylish(fgMagenta            )) & result
  else: result = "  ".initStylishString & result
  if hurs > 0: result = (hurs.`$`.align(2) & "h ").withStyle(stylish(fgCyan, {styleBright})) & result
  else: result = "  ".initStylishString & result
  result = initStylishString(" " * (width - result.len)) & result

func reprInXChars(val: float, n: int, suffix: string): StylishString =
  # do NOT make this const, it breaks stylish() for some reason
  let prefixes = [
    (""  , 1.0                , stylish(fgWhite              )),
    ("k" , 1_000.0            , stylish(fgCyan               )),
    ("M" , 1_000_000.0        , stylish(fgGreen              )),
    ("G" , 1_000_000_000.0    , stylish(fgMagenta            )),
    ("T" , 1_000_000_000_000.0, stylish(fgCyan, {styleBright})),
    ("_" , Inf                , stylish(                     )),
  ]

  for i, prefix in prefixes:
    let (pref, amt, stylish) = prefix
    if prefixes[i + 1][1] > val:
      var res = (val / amt).formatFloat(ffDecimal, precision = 2){0 ..< (n - pref.len - suffix.len)}
      return align(res & pref & suffix, n).withStyle(stylish)

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
  ("Running trials for (C = $#; mask = $#). Press enter to exit." %
    [$C, $mask]).center(titleRow.width).withStyle(stylish({styleBright})),
)

# TODO: This whole 'DisplayAction' business is really ugly
type DisplayActionKind = enum
  dakClearColumn
  dakWriteMessage
  dakOverlay
type DisplayAction = object
  i: int
  case kind: DisplayActionKind
  of dakClearColumn:
    discard
  of dakWriteMessage:
    write_child_i: int
    write_str: StylishString
  of dakOverlay:
    overlay_child_i: int
    overlay_str: StylishString
    overlay_xOffset: int

var displayChannel: Channel[DisplayAction]
displayChannel.open()

proc displayN(i: int; N: int, stylish = styleless) =
  displayChannel.send(DisplayAction(kind: dakWriteMessage, i: i, write_child_i: 0, write_str: initStylishString(" N = " & $N)))
proc displayTrialCount(i: int; count: int) =
  displayChannel.send(DisplayAction(kind: dakWriteMessage, i: i, write_child_i: 1, write_str: initStylishString(" $# / $# trials ($#%)" % [
    count.`$`.align(($trialCount).len),
    $trialCount,
    int(count / trialCount * 100).`$`.align(3),
  ])))
proc displayTrial(i: int; text: StylishString) =
  displayChannel.send(DisplayAction(kind: dakWriteMessage, i: i, write_child_i: 2, write_str: text))
proc clearColumn(i: int) =
  displayChannel.send(DisplayAction(kind: dakClearColumn, i: i))
proc overlay(i: int; text: StylishString, xOffset: int) =
  displayChannel.send(DisplayAction(kind: dakOverlay, i: i, overlay_str: text, overlay_xOffset: xOffset))

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

      clearColumn(i)
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
      displayTrial(
        i,
        timeFormat(duration, width = halfWidth) &
          " ".initStylishString &
          flips.float.reprInXChars(halfWidth - 1, "f"),
      )
      file.writeRow(flips)

proc main() =
  for i in 0 ..< threadCount:
    threads[i].createThread(doTrials, (i: i, mask: mask))

  var quitThread: Thread[void]
  quitThread.createThread do:
    discard readline(stdin)
    quit()

  while true:
    let action = displayChannel.recv
    case action.kind
    of dakClearColumn:
      columnDisplays[action.i].children[2].clear()
    of dakWriteMessage:
      columnDisplays[action.i].children[action.write_child_i].write(action.write_str)
    of dakOverlay:
      columnDisplays[action.i].children[2].overlay(action.overlay_str, action.overlay_xOffset)

main()
