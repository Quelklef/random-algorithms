#!/bin/bash

# Call like 'run.sh <C> <mask> <trials>'

if [ "$#" != 3 ]; then
  echo "Requires three args: C, mask, trials"
  exit
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

nim c -d:release --threads:on -r ../../multiThread $1 $2 $3
