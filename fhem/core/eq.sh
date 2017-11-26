#!/bin/bash
echo "adress" $1 "temp" $2 
typeset -i temp
temp=$2
temp=$temp*2
printf -v temp_hex "%x" "$temp"

gatttool -b $1 --char-write-req --char-write-req --handle=0x0411 --value="41"$temp_hex"E"