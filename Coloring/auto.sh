n=$1

while true; do
  # Convert n to binary
  bin="$( echo "obase=2;$n" | bc )"
  n="$(( n + 1 ))"

  ./run.sh 2 arithmetic $bin 250 --auto
done
