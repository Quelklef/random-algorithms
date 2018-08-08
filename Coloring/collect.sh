#!/bin/bash

if [ "$#" != 2 ]; then
  echo "Requires two args: C, mask"
  exit
fi

result=""
pushd data/"C_$(printf %05d $1)__mask_$2"
i=1
for filename in ./*; do
  echo "Collecting from $filename"
  result="$result
$(cat $filename | sed "s/^/$i,/g")"
  i="$(($i + 1))"
done

popd
echo "$result" > "C_${1}__mask_${2}_data.txt"
