#!/bin/bash

if [ "$#" != 2 ]; then
  echo "Requires two args: C, K"
  exit
fi

cd data/"C_$(printf %05d $1)__K_$(printf %05d $2)"
while [ 1 ]; do
  wc -l *
  sleep 3
done
