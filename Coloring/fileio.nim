import strutils
import sequtils
import tables

import misc

# Simple CSV output implementation

# Designed to work with google sheets
# Values are separated by commas
# Quotes are escaped with another quote
# Values that contain commas and newlines are surrounded by quotes

func writeRow*(file: File, vals: varargs[string, `$`]) =
  file.writeLine(
    vals
      .map(func(s: string): string =
        result = s.replace("\"", "\"\"")
        if '\c' in s or '\L' in s or "," in s:
          result = "\"" & result & "\"")
      .join(","))
