#!/bin/bash
function num_stairs {
# this function counts the number of options for building a staircase of $1 cubes
if [ $# -ne 2 ]
then
echo "please run num_stairs function with 2 arguments, 1st equal to number of cubes, 2nd equal to 0"
return 1
else
if [ $1 -eq 0 ] 
then
echo 1
else
ans=0
for ((i = (($2+1)); i <= (($1+1)); i++))
do
((ans+=$(num_stairs $(($1-$i)) $i)))
done
echo "$ans"
fi
fi
}
echo "Number of options for building a staircase of $1 cubes: $(num_stairs $1 0)"