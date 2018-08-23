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

let outdirName = "data/C=$#;pattern=$#" % [C.`$`.align(5, '0'), $pattern]
if not existsDir(outdirName):
  createDir(outdirName)

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
when defined(auto):
  let footerRow = box(1)
  let root = rows(@[titleRow, columnDisplaysWrap, footerRow])
else:
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

var workerThreads: array[threadCount, Thread[tuple[i, columnWidth: int; pattern: Pattern, outdirName: string]]]
var nextN = 1

when defined(auto):
  # -d:auto terminates the program when we reach a state in which no threads have found a coloring
  # for their given N
  # In order to do that we need to keep track of whether or not a thread has found a coloring for
  # the given N
  # We do that with this array
  var coloringFound: array[threadCount, bool]
  # Min runtime before quitting is allowed (s)
  const minTime = float(5)
  # Max runtime, after which will force quit (s)
  const maxTime = float(2 * 60 * 60)

# Don't put this in ``main``, it causes a compiler bug
var quitChannel: Channel[bool]  # The message itself is meaningless
quitChannel.open()

proc work(values: tuple[i, columnWidth: int, pattern: Pattern, outdirName: string]) {.thread.} =
  let (i, columnWidth, pattern, outdirName) = values
  while true:
    when defined(auto):
      coloringFound[i] = false

    let N = nextN
    let filename = outdirName / "N=$#.txt" % $N
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

      when defined(auto):
        coloringFound[i] = true

      displayTrialCount(i, t)
      let trialStr = flips.float.siFix("f") & " ".initStylishString
      let durStr = " ".initStylishString & timeFormat(duration)
      # ``+ 1`` for 1-space padding between rows
      if durStr.len + trialStr.len + 1 <= columnWidth:
        displayTrial(i, durStr & initStylishString(" " * (columnWidth - durStr.len - trialStr.len)) & trialStr)
      else:
        displayTrial(i, trialStr.align(columnWidth))
      file.writeRow(flips)

let startTime = epochTime()
proc main() =
  for i in 0 ..< threadCount:
    workerThreads[i].createThread(work, (i: i, columnWidth: columnDisplays[0].width, pattern: pattern, outdirName: outdirName))

  var timeLimitThread: Thread[void]
  timeLimitThread.createThread do:
    sleep(int(minTime * 1000))
    while true:
      let t = epochTime()
      if t > startTime + maxTime or coloringFound.all(x => not x):
        quitChannel.send(true)
      sleep(5 * 1000)

  var quitThread: Thread[void]
  quitThread.createThread do:
    discard readLine(stdin)
    quitChannel.send(true)

  stdout.hideCursor()

  let formatMinTime = minTime.timeFormat(true)
  let formatMaxTime = maxTime.timeFormat(true)
  while quitChannel.peek() == 0:
    doDisplayAction()
    when defined(auto):
      let text =
        formatMaxTime & initStylishString(" / ") &
        (epochTime() - float(startTime)).timeFormat & initStylishString(" / ") &
        formatMinTime
      let padLeft = (footerRow.width - text.len) div 2
      footerRow.write(initStylishString(" " * padLeft) & text)

  stdout.showCursor()
  terminal.resetAttributes()
  placeCursorAfter(root)

main()
