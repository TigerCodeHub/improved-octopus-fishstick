#!/bin/bash

if [ "$1" == "--help" ]; then
    echo
    echo "This script takes a directory name as an argument. All files in the directory must have names of the following form: <prefix><number>.<extension>. The prefix and extension must be the same across all files. This script renames each file to <prefix><number+1>.<extension>, and auto generates a log file (which is excldued from this operation)."
    echo
    echo "Note: the prefix can contain a number, but it has to have at least 1 non-numerical character."
    echo
    echo "Usage: ./script.sh <directory-name>"
    exit 0
fi

directory=$1

if [ -z "$directory" ]; then
    echo "Directory not found." >&2
    exit 1
else 
    echo "Directory found."
fi

cd "$directory"

#Reading all filenames into an array
files=()
while IFS= read -r file; do
  files+=("$(echo "$file" | sed 's|^\./||')")
done < <(find . -maxdepth 1 -type f -not -name "log.txt")


if [ ${#files[@]} -eq 0 ]; then
    echo "Directory is empty."
    exit 0
fi

prefix=""
ext=""

#Format check to ensure files share the same prefix and ext, to avoid changing unwanted things.

for file in "${files[@]}"; do 
    result=$(gawk '
    match($0, /^(.*[^0-9])[0-9]+\.([a-zA-Z0-9]+)$/, groups) {
      print groups[1] "|" groups[2]
    }
    ' <<< "$file") #filename must match <prefix with at least one character not 0-9><number>.<extension>
    if [ -z "$result" ]; then
        echo "Filename $file is not formatted correctly. The correct format is <prefix><number>.<extension>." >&2
        exit 1
    fi
    pre="${result%%|*}"
    ex="${result##*|}"
    if [ -z "$prefix" ]; then
        prefix="$pre"
        ext="$ex"
    elif [ "$prefix" != "$pre" ]; then
        echo "Invalid prefix: $file (expected $prefix as prefix)." >&2
        exit 1
    elif [ "$ext" != "$ex" ]; then
        echo "Invalid extension: $file (expected .$ext as extension)." >&2
        exit 1
    fi
done

echo "Format check completed successfully."
echo "The files all have prefix $prefix and extenstion $ext."

#Sorting the files in descending order of the number to avoid duplicate file names when incremeting the names

r=$(for file in "${files[@]}"; do
  num=$(sed -E 's/^.*[^0-9]([0-9]+)\.[a-zA-Z0-9]+$/\1/' <<< "$file")
  echo "$num $file"
done | sort -nr | gawk '{print $2}')

sfiles=()
while IFS= read -r line; do
  back="${line#* }"
  sfiles+=("$back")
done <<< "$r"

templog="temp_log.txt"

#Changing the file names

for file in "${sfiles[@]}" ; do
    new_name=$(gawk '
    match($0, /^(.*[^0-9])([0-9]+)\.([a-zA-Z0-9]+)$/, groups) {
      printf groups[1]
      printf groups[2] + 1
      printf "."
      printf groups[3]
    }
    ' <<< "$file")
    old_name="$file"
    mv "$old_name" "$new_name"
    echo "$(date '+%D %H:%M:%S') Renamed $old_name to $new_name." >> "$templog"
done

#Updating the log file

if [ -e "log.txt" ]; then
    :
else
    echo "Log created on $(date '+%D')" >> log.txt
fi
echo >> log.txt
cat "$templog" >> log.txt
rm "$templog"

#Open the log for the user
echo "The operation has been completed. Here is the log:"
sleep 1
less log.txt