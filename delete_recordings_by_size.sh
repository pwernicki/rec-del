#!/bin/bash

size=0
verbose=false
dry_run=false
output=false
out_file="/dev/stdout"

usage() {
  echo "Usage: $(basename $0) [OPTION] DIRECTORY"
  echo "Removes oldest recordings find in DIRECTORY by total size"
  echo
  echo "-s, --size      define max total size"
  echo "--dry-run       display files for deletion and exit"
  echo "-o, --output    specify file to output files list"
  echo "-v, --verbose   be more verbose"
  echo "-h, --help      print this help"
}

conv2bytes() {
  read -r size_opt unit_opt <<< "$(echo $1 | sed -nre 's/([0-9]+)([kKmMgG]{1})/\1 \2/p')"
  case $unit_opt in
    'k'|'K')
      echo "$(($size_opt*1024))";;
    'm'|'M')
      echo "$(($size_opt*1024*1024))";;
    'g'|'G')
      echo "$(($size_opt*1024*1024*1024))";;
  esac
}

check_answer() {
  while true 
  do
    echo
    echo "$1"
    read answer
    if [[ $answer == [Yy] || $answer == [Yy][Ee][Ss] ]]; then
      return 0
    elif [[ $answer == [Nn] || $answer == [Nn][On] ]]; then
      exit 1
    else 
      echo "Please provide valid answer"
    fi
  done
}

display_find() {
  for line in ${DELETE_LIST[@]}
  do
    if $verbose; then
      ls -l $line >> "$out_file"
    else
      echo $line >> "$out_file"
    fi
  done
}

delete_find() {
  for line in ${DELETE_LIST[@]}
  do
    if $verbose; then
      echo "Delete file $line"
      rm $line
    else
      rm $line
    fi
  done
}

OPTS=$(getopt --long 'help,verbose,dry-run,size:,output::' -n "$(basename "$0")" -o 'vhos:' -- "$@")

eval set -- "$OPTS"
unset OPTS

while [[ $# -gt 0 ]]; do
  case "$1" in
    '-s'|'--size')
      if [[ ! $2 =~ ^[0-9]+[kKmMgG]{1}$ ]]; then
        echo "Wrong size format, use digits and unit [k|K|m|M|g|G]"
        exit 1
      fi
      size=$(conv2bytes $2)
      shift 2
      continue
      ;;

    '--dry-run')
      dry_run=true
      shift
      continue
      ;;

    '-o'|'--output')
      output=true
      case $2 in
        '')
          out_file="out.txt" ;;
        *)
          out_file=$2
          [ ! -f $out_file ] && touch $out_file ;;
      esac
      shift 2
      continue
      ;;

    '-v'|'--verbose')
      verbose=true
      shift
      continue
      ;;

    '-h'|'--help')
      usage
      shift
      exit
      ;;

    '--')
        shift
        break
        ;;

    *)
      exit 1
      ;;
  esac
done

DIRECTORY="${!#}"

if [ -z $DIRECTORY ]; then
  echo "You must specify directory"
  exit 1
fi

if [ ! -d $DIRECTORY ]; then
  echo "$DIRECTORY is not a directory"
  exit 1
fi

SIZE=0
DELETE_LIST=()
find_nr=0

if [ $size -eq 0 ]; then
  echo "Value 0 of size is not permitted, or maybe you forget to set option for size"
  exit 1  
fi

#FIND_LIST=( $(find $DIRECTORY -type f -printf '%T+ %p\n' | sort | awk '{print $2}') )
#for file_name in ${FIND_LIST[@]} 
#do
#  file_size=$(stat -c %s $file_name)
#  SIZE=$(($SIZE+$file_size))
#  
#  if [ "$SIZE" -lt "$size" ]; then
#    DELETE_LIST+=($file_name)
#    find_nr=$(($find_nr+1))
#  fi
#done

for file_name in $(find $DIRECTORY -type f)
do
  file_date=$(echo $file_name | sed -nre 's/.*?_([0-9]{14})\(.*/\1/p')
  FIND_LIST+=("$file_date $file_name")

  SORTED_FIND_LIST=($(sort -n -k1 <<< "${FIND_LIST[*]}"))
 
  for line in ${SORTED_FIND_LIST[@]}
  do
    file_name=$(echo $line | awk '{print $2}')
    file_size=$(stat -c %s $file_name)
    SIZE=$(($SIZE+$file_size))

    if [ "$SIZE" -lt "$size" ]; then
      DELETE_LIST+=($file_name)
      find_nr=$(($find_nr+1))
    fi
  done
done

if $output || check_answer "We found $find_nr files for deletion, display the list? [Y/n]"; then
  display_find
fi

if $dry_run; then
  exit 0
fi

if check_answer "Delete files from the list? [Y/n]"; then
  delete_find
fi

