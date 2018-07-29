#!/bin/bash

if [ "$#" != 2 ]; then
  echo "Requires two args: C, K"
  exit
fi

N="$(ls | wc -l)"
result=""
pushd data/"C_$(printf %05d $1)__K_$(printf %05d $2)"
i=1
for filename in ./*; do
  echo "Collecting from $filename"
  result="$result
$(cat $filename | sed "s/^/$i,/g")"
  i="$(($i + 1))"
done

popd
echo "$result" > "C${1}_K${2}_data.txt"
