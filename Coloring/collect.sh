#!/bin/bash

# Call like follows:
# ./script.sh data/myDataFolder
# Will output all data concatenated together with
# corrupted trials removed into a file named
# collected.txt next to this file

raw="$(cat $1/*)"

# Remove corrupted rows
valid="$(echo "$raw" | grep '^[0-9]*,[0-9]*,[0-9]*$')"

# Remove actual colorings
small="$(echo "$valid" | sed 's/,[0-9]*$//g')"

echo "$small" > collected.txt
