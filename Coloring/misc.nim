import strutils

import ../stylish

proc numLines*(f: string): int =
    return f.readFile.string.countLines - 1

proc createFile*(f: string) =
  close(open(f, mode = fmWrite))

func timeFormat*(t: float): StylishString =
  var rest = int(t * 1000)
  let hurs = rest div 3600000
  rest = rest mod 3600000
  let mins = rest div 60000
  rest = rest mod 60000
  let secs = rest div 1000
  rest = rest mod 1000
  let mils = rest

  return
    (if hurs > 0: (hurs.`$`.align(2) & "h ").withStyle(stylish(fgCyan, {styleBright})) else: "    ".initStylishString) &
    (if mins > 0: (mins.`$`.align(2) & "m ").withStyle(stylish(fgMagenta            )) else: "    ".initStylishString) &
    (if secs > 0: (secs.`$`.align(2) & "s ").withStyle(stylish(fgGreen              )) else: "    ".initStylishString) &
    (             (mils.`$`.align(3) & "ms").withStyle(stylish(fgCyan               ))                             )

func siFix*(val: float, suffix = ""): StylishString =
  # do NOT make this const, it breaks for some reason
  let fixes = [
    (""  , 1.0                , stylish(fgWhite              )),
    ("k" , 1_000.0            , stylish(fgCyan               )),
    ("M" , 1_000_000.0        , stylish(fgGreen              )),
    ("G" , 1_000_000_000.0    , stylish(fgMagenta            )),
    ("T" , 1_000_000_000_000.0, stylish(fgCyan, {styleBright})),
    ("_" , Inf                , stylish(                     )),
  ]

  for i, triplet in fixes:
    let (fix, amt, stylish) = triplet
    if fixes[i + 1][1] > val:
      var res = (val / amt).formatFloat(ffDecimal, precision = 2)
      return (res & fix & suffix).withStyle(stylish)
