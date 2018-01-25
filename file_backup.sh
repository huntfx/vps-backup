#!/usr/bin/env bash
#Split a file into multiple parts, compress and email
#Usage: ./file_backup.sh input_file, [--split-size 10m] [--email user@email.com] [--disable-compression]
#TODO: Time taken (for email body), maximum_file_limit, fallback if no email in config


#Read config
source config.conf
mkdir ${TEMPDIR} -p
mkdir ${TEMPDIR}/temp -p

#Parse arguments
file_path=$1

compress_file=true

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
                -s | --split-size )
                        split_size="$2"
                        shift
                        ;;
                -dc | --disable-compression )
                        compress_file=false
                        ;;
                -h | --help )
                        echo "Display some help"
                        exit 0
                        ;;
        esac
        shift
done

base_file=$(basename $file_path)

original_file=${base_file}

#Copy and compress
if [ ${compress_file} = true ]; then
    cp ${file_path} ${TEMPDIR}/${original_file}
    gzip ${TEMPDIR}/${original_file}
    file_path=${TEMPDIR}/${original_file}.gz
    original_file=$(basename $file_path)
fi

#Split the file
if [ -z ${split_size} ] || [ ${split_size} = false ];
then
    cp ${file_path} ${TEMPDIR}/${original_file}.0
else
    split --bytes ${split_size} --numeric-suffixes --suffix-length 1 ${file_path} ${TEMPDIR}/${original_file}.
fi

#Clean up
index=1
num_files=$(find ${TEMPDIR} -iname ${original_file}.* -type f -printf '.' | wc -c)
for file in ${TEMPDIR}/${original_file}.*
do  
    next_index=${index}+1
    subject="Backup of ${base_file}"
    if [ ${num_files} -gt 1 ]; 
    then
        subject="${subject} (Part ${index})"
    else
        mv ${file} ${TEMPDIR}/temp/${original_file}
        file=${TEMPDIR}/temp/${original_file}
    fi
    message="Test backup"
    
    #Send email
    if [ ! -z ${email_address} ]; then
        echo "Sending ${file} to ${email_address}... ${index}/${num_files}"
        echo "${message}" | mutt -a ${file} -s "${subject}" -e "my_hdr From:${EMAIL}" -- ${email_address}
    fi
    
    #Delete
    rm $file
    let "index++"
done

#Delete compressed file
if [ ${compress_file} = true ]; then
    rm ${file_path}
fi
