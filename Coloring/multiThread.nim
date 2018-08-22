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
import misc
import pattern as patternModule
from ../util import `*`, times, `{}`
import ../gridio
import ../stylish

#[
4 command-line params:
C: C
pattern-type: the type of the mask pattern
pattern-arg: string argument of the pattern
trials: Number of desired trials for each datapoint
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

# How many trials we want for each datapoint
let desiredTrialCount = paramStr(4).parseInt
const threadCount = 8

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
  ("Running trials for (C = $#; pattern = $#). Press enter to exit." %
    [$C, $pattern]).center(titleRow.width).withStyle(stylish({styleBright})),
)

# IO has to be done on the main thread
type DisplayCommandKind = enum
  dckClearColumn
  dckWrite
type DisplayCommand = object
  case kind: DisplayCommandKind
  of dckClearColumn:
    clear_column_i: int
  of dckWrite:
    write_column_i: int
    write_row_i: int
    write_str: StylishString

var displayChannel: Channel[DisplayCommand]
displayChannel.open()

proc doDisplayAction() =
  let (success, action) = displayChannel.tryRecv()
  if success:
    case action.kind
    of dckClearColumn:
      columnDisplays[action.clear_column_i].children[2].clear()
    of dckWrite:
      discard
      columnDisplays[action.write_column_i].children[action.write_row_i].write(action.write_str)

proc clearColumn(i: int) =
  displayChannel.send(DisplayCommand(kind: dckClearColumn, clear_column_i: i))

proc displayN(i: int; N: int) =
  displayChannel.send(DisplayCommand(
    kind: dckWrite,
    write_column_i: i,
    write_row_i: 0,
    write_str: initStylishString(" N = " & $N),
  ))

proc displayTrialCount(i: int; trials: int) =
  displayChannel.send(DisplayCommand(
    kind: dckWrite,
    write_column_i: i,
    write_row_i: 1,
    write_str: initStylishString(" $# / $# trials ($#%)" % [
      align($trials, len($desiredTrialCount)),
      $desiredTrialCount,
      align($int(trials / desiredTrialCount * 100), 3),
    ])
  ))

proc displayTrial(i: int; trial: StylishString) =
  displayChannel.send(DisplayCommand(
    kind: dckWrite,
    write_column_i: i,
    write_row_i: 2,
    write_str: trial,
  ))

var workerThreads: array[threadCount, Thread[tuple[i, columnWidth: int; pattern: Pattern]]]
var nextN = 1

proc work(values: tuple[i, columnWidth: int, pattern: Pattern]) {.thread.} =
  let (i, columnWidth, pattern) = values
  while true:
    let N = nextN
    let filename = "N=$#.txt" % $N
    inc(nextN)

    if not fileExists(filename):
      createFile(fileName)
    let existingTrials = numLines(filename)

    if existingTrials >= desiredTrialCount:
      continue

    clearColumn(i)
    displayN(i, N)
    displayTrialCount(i, existingTrials)

    block:
      let file = open(filename, mode = fmRead)
      defer: file.close()
      for line in file.lines:
        displayTrial(i, (line.string.parseFloat.siFix("f") & " ".initStylishString).align(columnWidth))

    let file = open(filename, mode = fmAppend)
    defer: file.close()

    for t in existingTrials + 1 .. desiredTrialCount:
      let t0 = epochTime()
      let (flips, _) = find_noMMP_coloring_progressive(C, N, proc(d: int): Coloring[2] = pattern.invoke(d))
      let duration = epochTime() - t0

      displayTrialCount(i, t)
      let trialStr = flips.float.siFix("f") & " ".initStylishString
      let durStr = " ".initStylishString & timeFormat(duration)
      # ``+ 1`` for 1-space padding between rows
      if durStr.len + trialStr.len + 1 <= columnWidth:
        displayTrial(i, durStr & initStylishString(" " * (columnWidth - durStr.len - trialStr.len)) & trialStr)
      else:
        displayTrial(i, trialStr.align(columnWidth))
      file.writeRow(flips)

# Don't put this in ``main``, it causes a compiler bug
var quitChannel: Channel[bool]  # The message itself is meaningless
quitChannel.open()

proc main() =
  for i in 0 ..< threadCount:
    workerThreads[i].createThread(work, (i: i, columnWidth: columnDisplays[0].width, pattern: pattern))

  var quitThread: Thread[void]
  quitThread.createThread do:
    discard readLine(stdin)
    quitChannel.send(true)

  stdout.hideCursor()

  while quitChannel.peek() == 0:
    doDisplayAction()

  stdout.showCursor()
  terminal.resetAttributes()
  placeCursorAfter(root)

main()
