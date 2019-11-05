#!/bin/bash
# This script replaces every occurence of a string with a given
# string in a collection of files.

options=$(getopt --options="hb:" --longoptions="help,backup:" -- "$@")
[ $? == 0 ] || error "Invalid command line. The command line includes one or more invalid command line parameters."

eval set -- "$options"
while true
do
  case "$1" in
    -h | --help)
      cat <<- EOF
Usage: ./substitute.sh [OPTIONS] OLD NEW [FILE ..]

This script replaces every instance of OLD with NEW in the given FILEs.

Options:
  -h|--help
  Displays this message.
  -b|--backup BACKUPDIR
  Create a backup of the original files.

Example
./substitute.sh cat hat example.txt

Authors
Larry Lee
EOF
      exit 0;;
    -b|--backup)
      backup=1
      backup_path=$2
      shift 2;;
    --)
      shift
      break;;
  esac
done
shift $((OPTIND - 1))

old=$1
new=$2
shift 2

[[ -z "$old" ]] && error "Invalid command line. The OLD argument is missing."
[[ -z "$new" ]] && error "Invalid command line. The NEW argument is missing."

echo "replacing "'"'$old'"'" with "'"'$new'"'" in files: $@."
if [[ $backup == 1 ]]
then
  echo "storing original files in $backup_path"
  mkdir $backup_path
fi
for file in $@
do
  if [ -f $file ]
  then
    echo "processing $file";
    awk "{ gsub(/$old/, "'"'"$new"'"'"); print }" $file > $file.tmp
    if [[ $backup == 1 ]]
    then
      cp $file $backup_path
    fi
    mv $file.tmp $file
  fi
done
echo "done"
