#!/usr/bin/env bash
#Email all the rotated logs and optionally delete them
#Requires logs to be rotated as file.log.*, or file.log.*.gz

#Create temp folder - https://stackoverflow.com/a/34676160/2403000
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
work_dir=$(mktemp -d -p "$script_dir")
if [[ ! "$work_dir" || ! -d "$work_dir" ]]; then
  echo "Error: Failed to create temp dir."
  exit 1
fi
function cleanup {
  rm -rf "$work_dir"
}
trap cleanup EXIT

email_body="Log backup started at $(date +'%Y-%m-%d %H:%M:%S')."

log_dir="/var/log"
compress_file=true
extension="log"
delete=false
sleep_time=1
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
                -d | --delete )
                        delete=true
                        ;;
                -s | --split | --split-size | --split-file )
                        split_size="$2"
                        shift
                        ;;
                --sleep )
                        sleep_time="$2"
                        shift
                        ;;
                -dir | --directory )
                        log_dir="$2"
                        shift
                        ;;
                -dc | --disable-compression | -uc | --uncompressed )
                        compress_file=false
                        ;;
                -ex | --extension )
                        extension="$2"
                        ;;
                -h | --help )
                        echo "Display some help"
                        exit 0
                        ;;
        esac
        shift
done

#Build array of matching logs
rotated_logs=()
while IFS=  read -r -d $'\0'; do
    rotated_logs+=("$REPLY")
done < <(find "$log_dir" -name "*.$extension.*" -print0)

for file in "${rotated_logs[@]}"
do
    #Get extension and base name from path
    file_name=$(basename "$file")
    file_ext="${file_name##*.}"
    
    #Generate a new path
    last_modified_raw=$(stat -c %y "$file")
    last_modified=$(date --date "$last_modified_raw" +'%Y-%m-%d')
    new_zip="${file_name%%.${extension}*}.log"
    new_file="${file_name%%.${extension}*}.$last_modified.log"
    final_file="$new_file"
    
    #Amend file name if new file is already zipped
    if [ "$file_ext" == "gz" ]; then
        final_file="$new_zip.gz"
    fi
    
    #Copy log file to new location
    new_path="$work_dir/$final_file"
    cp "$file" "$new_path"
    
    #Unzip file and rebuild path if required
    if [ "$file_ext" == "gz" ]; then
        gzip -d "$new_path"
        mv "$work_dir/$new_zip" "$work_dir/$new_file"
        final_file="$new_file"
        new_path="$work_dir/$final_file"
    fi
    
    #Compress file and remove timestamp
    if [ "$compress_file" = true ]; then
        gzip "$new_path"
        mv "$new_path.gz" "$work_dir/$new_zip.gz"
        new_path="$work_dir/$new_zip.gz"
    fi
    
    #Send to backup script
    custom_name="$(expr "$file" : "$log_dir/\(.*\)$file_name")$new_zip"
    echo "Sending $custom_name to backup function..."
    custom_body="$email_body\nFile was saved at $(date --date "$last_modified_raw" +'%Y-%m-%d %H:%M:%S')."
    ./main.sh "$new_path" --email "$email_address" --split "$split_size" --name-override "$custom_name" --message "$custom_body" --uncompressed
    
    #Delete original log file
    if [ "$delete" = true ]; then
        rm "$file"
    fi
    
    sleep "$sleep_time"
    
done
