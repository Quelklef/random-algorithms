#!/bin/bash
dispresult() {
  echo "$(echo "$1" | sed '/^CC.*/d')"
}

echo "# -- Plain -- #"
dispresult "$(nim c -r -d:release -d:benchmark --hints:off tests)"

for arg in "$@"; do
  echo
  echo "# -- -d:$arg -- #"
  dispresult "$(nim c -r -d:release -d:benchmark --hints:off -d:$arg tests)"
done
