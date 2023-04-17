#!/bin/bash
n1=0
n2=-15
if [ $# -eq 1 ]
then
time nice -n $n1 bash num_stairs.sh $1 && echo "Result for nice = $n1" &
time nice -n $n2 bash num_stairs.sh $1 && echo "Result for nice = $n2" &
else
time nice -n $n1 bash num_stairs.sh 40 && echo "Result for nice = $n1" &
time nice -n $n2 bash num_stairs.sh 40 && echo "Result for nice = $n2" &
fi
echo "Waiting..... Results will be printed"
wait $(jobs -p)