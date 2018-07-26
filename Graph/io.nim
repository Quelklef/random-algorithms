
import strutils
import sequtils
import tables

import misc

# Prints tables

type Tabular*[N] = object
    sizes: array[N, int]
    headings: array[N, string]

func initTabular*[N](headings: array[N, string], sizes: array[N, int]): Tabular[N] =
    var sizes = sizes
    # Expand the column width if necessary to hold the heading
    for i, size in sizes:
        sizes[i] = max(sizes[i], len(headings[i]))
    return Tabular[N](sizes: sizes, headings: headings)

func title*[N](tab: Tabular[N]): string =
    ## Return a 3-tall title
    return "$#\n$#\n$#" % [tab.rule(), tab.head(), tab.rule()]

func rule*[N](tab: Tabular[N]): string =
    ## Return a horizontal rule
    return tab.sizes.mapIt("-" * it).joinSurround("-+-")

func row*[N](tab: Tabular[N], vals: varargs[string, `$`]): string =
    ## Return a row
    return zip(vals, tab.sizes)
               .mapIt(align(it[0], it[1]))
               .joinSurround(" | ")

func head*[N](tab: Tabular[N]): string =
    ## Return a headings row
    return zip(tab.headings, tab.sizes)
               .mapIt(alignCenter(it[0], it[1]))
               .joinSurround(" | ")

# Simple CSV output implementation

# Designed to work with google sheets
# Values are separated by commas
# Quotes are escaped with another quote
# Values that contain commas and newlines are surrounded by quotes

func writeRow*(file: File, vals: varargs[string, `$`]) =
    file.writeLine(
        vals.map(func(s: string): string =
            var s = s.replaceMany({
                "\"": "\"\"",
            }.toTable)
            if '\c' in s or '\L' in s or "," in s:
                s = "\"" & s & "\""
            return s)

            .join(","))

proc concatFile*(fileName: string, f: string): void =
  var file = open(fileName, mode = fmAppend)
  file.write(readFile(f))
  close(file)


proc concatFile*(fileName: string, files: seq[string]): void =
  var file = open(fileName, mode = fmAppend)
  for name in files:
    file.write(readFile(name))
  close(file)

when isMainModule:
    let f = open("test.txt", fmAppend)
    f.writeRow(1, 2, 3)
    f.writeRow(4, 5, 6)
    f.writeRow("a\nb")
    f.writeRow("value before", "hello\non a new line!", "value after")
    f.writeRow("I contain a couple of quotes! \" \" \" :)))")
    f.writeRow("I have a backs\\ash!")
