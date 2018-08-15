#!/bin/bash

# Call like 'run.sh <C> <mask> <trials> [--debug]'

if [ "$4" = "--debug" ]; then
  debug="true"
fi

if [ "$1" -ne "2" ]; then
  echo "Only C=2 is currently supported"
  exit
fi

mkdir -p data
cd data

dirname="C_$(printf %05d $1)__mask_$(printf %05d $2)"
mkdir -p "$dirname"
cd "$dirname"

if [ "$debug" = true ]; then
  nim c --threads:on -r ../../multiThread $1 $2 $3 2> ../../debug.txt
  cat ../../debug.txt
else
  nim c -d:release --threads:on -r ../../multiThread $1 $2 $3
fi
