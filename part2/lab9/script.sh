#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
LOCKFILE=$SCRIPT_DIR/lockfile
TMPFILE=$(date +%s)-tmp
if ( set -o noclobber; echo "$$" > "$LOCKFILE") 2> /dev/null
then
trap 'echo Do not stop the script now' SIGINT
trap 'rm -f "$LOCKFILE"; rm -f /var/tmp/$TMPFILE.*; exit $?' SIGTERM EXIT
if [ ! -f $SCRIPT_DIR/timestamp ]; then t=null; else t=$(cat $SCRIPT_DIR/timestamp); fi
startline=$(grep -n -m 1 -e $t $1 | awk -F":" '{print $1}')
if [ -z "$startline" ]; then startline=1; else startline=$(($startline+1)); fi
stopline=$(wc -l $1 | awk '{print $1}')
sed -n ''$startline','$stopline'p' $1 > /var/tmp/$TMPFILE.log
startdate=$(awk 'NR == 1 {print $4}' /var/tmp/$TMPFILE.log | cut -c 2-)
stopdate=$(awk 'END{print $4}' /var/tmp/$TMPFILE.log | cut -c 2-)

ip=$(awk '{print $1}' /var/tmp/$TMPFILE.log  | sort | uniq -c | sort -nr | grep -m 5 "")
url=$(grep -Eo "\s\/[^[:space:]]*\s" /var/tmp/$TMPFILE.log | sed 's/ //g' | sort | uniq -c | sort -nr | grep -m 5 "")
errors=$(grep -e '"\s5[0-9][0-9]\s' /var/tmp/$TMPFILE.log)
codes=$(grep -Eo "\s[[:digit:]]{3}\s" /var/tmp/$TMPFILE.log | sed 's/ //g' | sort | uniq -c | sort -nr)
cat > /var/tmp/$TMPFILE.msg << EOF
Time interval:
============== 
$startdate - $stopdate
Most active IP's: 
=================
$ip
Most frequently asked URL's:
===========================
$url
Server/app errors: 
==================
$errors
Counters of HTTP answers:
========================
$codes
EOF
cat /var/tmp/$TMPFILE.msg | mail -s "NGINX Log analyze result" -r $2 -S mta=smtp://$3 $4
echo $stopdate > $SCRIPT_DIR/timestamp
rm -f /var/tmp/$TMPFILE.*
else
echo "Failed to acquire lockfile: $LOCKFILE."
echo "Hold by $(cat $LOCKFILE)"
fi