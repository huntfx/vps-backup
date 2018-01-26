#!/usr/bin/env bash
#Split a file into multiple parts, compress and email
#Usage: ./file_backup.sh input_file, [--split 10m] [--email user@email.com] [--uncompressed]
#[--time-start] can be given as "$(date +%s%N)/1000000" from another script to get a more accuate time.
#TODO: Time taken (for email body), maximum_file_limit


source config.conf

#Create temp folder - https://stackoverflow.com/a/34676160/2403000
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
work_dir=$(mktemp -d -p "$script_dir")
if [[ ! "$work_dir" || ! -d "$work_dir" ]]; then
  echo "Could not create temp dir"
  exit 1
fi

#Parse arguments
file_path=$1

compress_file=true
(( time_start=$(date +%s%N)/1000000 ))
while [ $# -ge 1 ]; do
        case "$1" in
                -- )
                    shift
                    break
                   ;;
                -e | --email )
                        email_address="$2"
                        shift
                        ;;
                -s | --split | --split-size | --split-file )
                        split_size="$2"
                        shift
                        ;;
                -ts | --time-start )
                        time_start="$2"
                        shift
                        ;;
                -dc | --disable-compression | -uc | --uncompressed )
                        compress_file=false
                        ;;
                -h | --help )
                        echo "Display some help"
                        exit 0
                        ;;
        esac
        shift
done

if [ ! -z "$email_address" ] && [ -z "$SEND_ADDRESS" ]; then
    echo "Sending address (SEND_ADDRESS) not specified in config."
fi

base_file=$(basename "$file_path")

original_file="$base_file"

new_location="$work_dir/$original_file"

#Copy and compress
if [ "$compress_file" = true ]; then
    cp "$file_path" "$new_location"
    gzip "$new_location"
    file_path="$new_location.gz"
    original_file=$(basename "$file_path")
    new_location="$work_dir/$original_file"
fi

#Split the file
if [ -z "$split_size" ] || [ "$split_size" = false ];
then
    cp "$file_path" "$new_location.0"
else
    split --bytes "$split_size" --numeric-suffixes --suffix-length 1 "$file_path" "$new_location."
fi

#End timer
(( time_end=$(date +%s%N)/1000000 ))
(( time_elapsed=time_end-time_start ))

#Clean up
index=1
num_files=$(find "$work_dir" -iname "$original_file.*" -type f -printf '.' | wc -c)
for file in $new_location.*
do  
    echo "Processing: $file"

    #Remove .0 if there is only 1 part
    if [ "$num_files" -le 1 ]; then
        mv "$file" "$new_location"
        file="$new_location"
    fi
    
    #Send email
    if [ ! -z "$email_address" ]; then
        echo "Sending $(basename "$file") to $email_address... $index/$num_files"
        
        #Generate email subject and body
        subject="Backup of $base_file"
        if [ "$num_files" -gt 1 ]; then
            subject="$subject (Part $index)"
        fi
        message="Preparation of the file took ${time_elapsed}ms."
        
        #Get email from config if possible, otherwise fallback to default
        if [ ! -z "$SEND_ADDRESS" ]; then
            header="my_hdr From:$SEND_ADDRESS"
        fi
        
        echo "$message" | mutt -a "$file" -s "$subject" -e "$header" -- "$email_address"
    fi
    
    (( index++ ))
done

#Delete temp directory
rm -rf "$work_dir"
