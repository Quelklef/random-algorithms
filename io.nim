
import strutils
import sequtils
import tables

import misc

# Prints tables

type Tabular*[N] = object
    sizes: array[N, int]
    headings: array[N, string]

func initTabular*[N](headings: array[N, string], sizes: array[N, int]): Tabular[N] =
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
               .mapIt(alignLeft(it[0], it[1]))
               .joinSurround(" | ")

func head*[N](tab: Tabular[N]): string =
    ## Return a headings row
    return zip(tab.headings, tab.sizes)
               .mapIt(alignCenter(it[0], it[1]))
               .joinSurround(" | ")

# Simple CSV output implementation

# Values are separated by commas
# Commas are escaped with \
# Backslahses are escaped with \
# Quoutes are escaped wth \
# If a value contains a newline, it will be surrounded by quotes

func writeRow*(file: File, vals: varargs[string, `$`]) =
    file.writeLine(
        vals.map(func(s: string): string =
            var s = s.replaceMany({
                ",": "\\,",
                "\\": "\\\\",
                "\"": "\\\"",
            }.toTable)
            if '\c' in s or '\L' in s:
                s = "\"" & s & "\""
            return s)

            .join(","))

when isMainModule:
    let f = open("test.txt", fmAppend)
    f.writeRow(1, 2, 3)
    f.writeRow(4, 5, 6)
    f.writeRow("a\nb")
    f.writeRow("value before", "hello\non a new line!", "value after")
    f.writeRow("I contain a couple of quotes! \" \" \" :)))")
    f.writeRow("I have a backs\\ash!")

