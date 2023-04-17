#!/bin/bash
n1=2
n2=1
if [ $# -eq 1 ]
then
echo "Creating two random files of $1 Mb size"
dd if=/dev/urandom of=file1 bs=1M count=$1 iflag=fullblock &> /dev/null &
dd if=/dev/urandom of=file2 bs=1M count=$1 iflag=fullblock &> /dev/null &
else
echo "Creating two random files of 128 Mb size"
dd if=/dev/urandom of=file1 bs=1M count=128 iflag=fullblock &> /dev/null &
dd if=/dev/urandom of=file2 bs=1M count=128 iflag=fullblock &> /dev/null &
fi
wait $(jobs -p)
echo "Copying generated files with different ionice classes"
time ionice -c $n1 dd if=file1 of=file11 &> /dev/null && echo "Result for ionice c=$n1" &
time ionice -c $n2 dd if=file2 of=file22 &> /dev/null && echo "Result for ionice c=$n2" &
echo "Waiting..... Results will be printed"
wait $(jobs -p)
rm file*