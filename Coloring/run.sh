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

if [ -z "$(ls)" ]; then
  lastN=1
else
  # Get list of files with line counts
  # Exclude the last line (sums)
  files="$(wc -l * | sed \$d)"
  filesCount="$(echo $files | wc -l)"
  # Get count of files that have the desired number of trials
  finishedCount="$(echo $files | grep '^ *$trials' | wc -l)"
  # The first N we want to work on is one after that
  lastN="$(($finishedCount + 1))"
fi

nim c -d:reckless -d:release --threads:on -r ../../multiThread $1 $2 $3 $lastN
#nohup nim c -d:reckless -d:release --threads:on -r ../../multiThread $1 $2 $3 $lastN > /dev/null &

#while [ 1 ]; do
#  [ -z "$(ls)" ] || wc -l *
#  echo "Working on C=$1 K=$2 ($3 trials). Press any key to exit."
#  read -t 3 -n 1
#  if [ "$?" = 0 ]; then  # If user inputted
#    pgrep multiThread | xargs kill -9
#    exit
#  fi
#done
