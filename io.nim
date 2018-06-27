
import strutils
import sequtils
import tables

import misc

# Prints tables

proc `*`(s: string, n: int): string =
    result = ""
    n.times:
        result.add(s)

proc joinSurround(s: seq[string], v: string): string =
    ## Like `join`, but also includes the delimiter at the beginning and end
    return v & s.join(v) & v

proc rule*(sizes: seq[int]): string =
    return sizes.map(proc(x: int): string = "-" * x)
                .joinSurround("-+-")

proc row*(sizes: seq[int], vals: varargs[string, `$`]): string =
    return zip(sizes, vals).map(proc(pair: (int, string)): string =
                               alignLeft(pair[1], pair[0]))
                           .joinSurround(" | ")

proc alignCenter(val: string, width: int): string =
    return alignLeft(
        " " * ((width - val.len) div 2) & val,
        width,
    )

proc headers*(sizes: seq[int], vals: varargs[string, `$`]): string =
    return zip(sizes, vals).map(proc(pair: (int, string)): string =
                               alignCenter(pair[1], pair[0]))
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

