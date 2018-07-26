#!/bin/bash

# Call like 'run.sh <C> <K> <trials>'
# Where C is C, K is K, and trials is the number
# of trials to get for each datapoint.

if [ "$#" != 3 ]; then
  echo "Requires three args: C, K, trials"
  exit
fi

if [ "$1" -ne "2" ]; then
  echo "Only C=2 is currently supported"
  exit
fi

mkdir -p data
cd data

dirname="C_$(printf %05d $1)__K_$(printf %05d $2)"
mkdir -p "$dirname"
cd "$dirname"

nim c -d:release --threads:on -r ../../multiThread $1 $2 $3
