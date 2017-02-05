#!/bin/sh

source "/tmp/hd1/test/scripts/ftp_upload/common_lib.sh"

NAME=`basename "$0"`
FTP_MEM_FILE="/tmp/hd1/test/scripts/ftp_upload/ftp_upload.mem"
FTP_LOG="/tmp/hd1/test/scripts/ftp_upload/log.txt"
PID_FILE="/tmp/hd1/test/scripts/ftp_upload/ftp.pid"

FTP_CFG="/tmp/hd1/test/scripts/ftp_upload/ftp_upload.cfg"
FTP_ADD=$(get_config FTP_HOST $FTP_CFG)

mem_store()
{
    echo "${2}A${3}F${4}P${5}T${6}R" > $1
}

mem_retry_next()
{
    tmp_data=$(cat "$1")
    tmp_data=${tmp_data%%T*}
    tmp_data="${tmp_data}TtrueR"
    echo "$tmp_data" > $1
}

mem_get()
{    
    mfile=$1
    data=$(cat "$mfile")
    
    last_folder=${data%%A*}
    data=${data##*A}
    
    last_file=${data%%F*}
    data=${data##*F}
    
    last_ftppid=${data%%P*}
    data=${data##*P}
    
    last_ftptime=${data%%T*}
    data=${data##*T}
    
    last_retry=${data%%R*}
    
    if [ -z "${last_folder}" ] || [ -z "${last_file}" ]; then
        log "[$NAME] Cannot find last folder and file in $mfile" ${FTP_LOG}
        log "[$NAME] The file should content as: 2016Y08M01D13HA23M00S.mp4FPTR" ${FTP_LOG}
        exit 0
    fi
}

ftp_mkd()
{
    (sleep 1;
     echo "USER $(get_config FTP_USER $FTP_CFG)";
     sleep 1;
     echo "PASS $(get_config FTP_PASS $FTP_CFG)";
     sleep 1;
     echo "MKD $(get_config FTP_DIR $FTP_CFG)/$1";
     sleep 1;
     echo "QUIT";
     sleep 1 ) | telnet $FTP_ADD $(get_config FTP_PORT $FTP_CFG) >> $FTP_LOG 2>&1
}

ftp_upload()
{
    from_f=$1
    to_f=$2
    
    return $?
}


main()
{
    last_folder=""
    last_file=""
    last_ftppid=""
    last_ftptime=""
    last_retry=""

    # Here we goooooo!
    
    # If FTP server is unreachable here, just exit
    is_server_live $FTP_ADD
    if [ $? -ne 0 ]; then
        log "[$NAME] $FTP_ADD is unreachable!!!" ${FTP_LOG}
        pid_clear $PID_FILE
        exit 0
    fi
    log "[$NAME] $FTP_ADD is reachable" ${FTP_LOG}

    # Get last copied file
    mem_get $FTP_MEM_FILE
    log "[$NAME] last folder: $last_folder last file: $last_file" ${FTP_LOG}
    log "[$NAME] last ftp: $last_ftppid last ftp time: $last_ftptime" ${FTP_LOG}
    log "[$NAME] retry last: $last_retry" ${FTP_LOG}

    # Calculate the datetime info
    tmp_data=${last_folder}
    last_y=${tmp_data%%Y*}
    tmp_data=${tmp_data##*Y}
    
    last_m=${tmp_data%%M*}
    tmp_data=${tmp_data##*M}
    
    last_d=${tmp_data%%D*}
    tmp_data=${tmp_data##*D}
    
    last_h=${tmp_data%%H*}
    
    tmp_data=${last_file}
    last_i=${tmp_data%%M*}
    tmp_data=${tmp_data##*M}
    last_s=${tmp_data%%S*}
    unset tmp_data
    
    cont_last=1
    is_leap_year last_y
    if [ $? -eq 0 ]; then
        max_d02=29
    fi

    while [ 1 -eq 1 ]; do
        if [ -d "${DEFAULT_RECORD_DIR}${last_folder}" ]; then
            cd "${DEFAULT_RECORD_DIR}${last_folder}"
            list_file=$(ls)
            if [ -n "$list_file" ]; then
                log "[$NAME] Create ${last_folder}" ${FTP_LOG}
                # Make dir of FTP again to ensure it exists
                ftp_mkd ${last_folder}
                if [ $cont_last -eq 1 ]; then
                    # Use current last_i and last_s
                    cont_last=0
                else
                    last_i="00"
                    last_s="00"
                fi

            fi
            for file in $list_file; do
                # If in offline duration then exit
                check_offline_duration
                [ $? -eq 0 ] || (pid_clear $PID_FILE && exit 0)
                
                # If FTP unreachable then exit
                is_server_live $FTP_ADD
                [ $? -eq 0 ] || (pid_clear $PID_FILE && exit 0)
                
                if [ $(expr index "$file" 't') -gt 0 ]; then
                    log "[$NAME] Skip tmp file $file" ${FTP_LOG}
                    continue
                fi
                
                # If last_ftppid existed, check its execution time, terminate after 15min
                # Will set retry_next to reupload on next cron execution
                if [ -n "$last_ftppid" && -n "$last_ftptime" ]; then
                    if [ "$(cat /proc/${last_ftppid}/comm 2>/dev/null)" == "ftpput" ]; then
                        exe_dura=$(($(date '+%s') - $last_ftptime))
                        log "[$NAME] ftpput pid $last_ftppid executed for $exe_dura sec" ${FTP_LOG}
                        if [ "$exe_dura" -gt 900 ]; then
                            log "[$NAME] ftpput pid $last_ftppid executed over 15min. Be killed to exit." ${FTP_LOG}
                            kill -9 "$last_ftppid"
                            mem_retry_next ${FTP_MEM_FILE}
                            pid_clear $PID_FILE
                            exit 0
                        fi
                    fi
                fi
                tmp_data=${file##*M}
                
                comm="\[ ${file%%M*}${tmp_data%%S*} -gt ${last_i}${last_s} \]"
                if [ "$last_retry" == "true" ]; then
                    comm="$comm || \[ ${file%%M*}${tmp_data%%S*} -eq ${last_i}${last_s} \]"
                fi
                
                if eval $comm ; then
                    log "[$NAME] Uploading ${last_folder}/${file}" ${FTP_LOG}
                    ftpput -u $(get_config FTP_USER $FTP_CFG) -p $(get_config FTP_PASS $FTP_CFG) -P $(get_config FTP_PORT $FTP_CFG) \
                           ${FTP_ADD} $(get_config FTP_DIR $FTP_CFG)/${last_folder}/${file} \
                           ${DEFAULT_RECORD_DIR}/${last_folder}/${file} >> $FTP_LOG 2>&1 &
                    upload_res=$?
                    last_ftppid=$!
                    last_ftptime=$(date '+%s')
                    if [ $upload_res -ne 0 ]; then
                        log "[$NAME] FAILED" ${FTP_LOG}
                        [ -n "$last_ftppid" ] && kill -9 $last_ftppid
                        pid_clear ${PID_FILE}
                        exit 0
                    fi
                    mem_store "$FTP_MEM_FILE" "$last_folder" "$file" "$last_ftppid" "$last_ftptime"
                    last_file=$file
                    
                    # Sleep 45s to expect that ftpput will finish its work
                    sleep 45
                fi
                
            done
        fi
        # If last_h between 01 to 09 then remove leading 0 for calculation
        if [ $(expr match "$last_h" '0*') -gt 0 ]; then
            last_h=${last_h:1}
        fi
        last_h=$(printf %02d $((last_h + 1)))
        if [ $last_h -gt 23 ]; then
            last_h=00
            if [ $(expr match "$last_d" '0*') -gt 0 ]; then
                last_d=${last_d:1}
            fi
            last_d=$(printf %02d $((last_d + 1)))
        fi
        eval max_d='$max_d'$last_m
        if [ $last_d -gt $max_d ]; then
            last_d=01
            if [ $(expr match "$last_m" '0*') -gt 0 ]; then
                last_m=${last_m:1}
            fi
            last_m=$(printf %02d $((last_m + 1)))
        fi
        if [ $last_m -gt 12 ]; then
            last_m=01
            last_y=$((last_y + 1))
            is_leap_year $last_y
            if [ $? -eq 0 ]; then
                max_d02=29
            else
                max_d02=28
            fi
        fi
        if [ "${last_y}${last_m}${last_d}${last_h}" -gt "$(date '+%Y%m%d%H')" ]; then
            # Nothing more to do, break the loop
            break
        fi
        last_folder="${last_y}Y${last_m}M${last_d}D${last_h}H"
        log "[$NAME] Next folder: $last_folder" ${FTP_LOG}
    done
    pid_clear $PID_FILE
}

#
# Start the main script
#

# Check offline duration at beginning
check_offline_duration

is_server_live $FTP_ADD
if [ $? -ne 0 ]; then
    log "[$NAME] Unreach FTP server $FTP_ADD" ${FTP_LOG}
    exit 0
fi

# If pass all above check, start the FTP upload
last_pid=$(pid_get $PID_FILE)

if [ -n "$last_pid" ]; then
    is_pid_exist "$last_pid.*ftp_upload" "ftp_upload.sh"
    if [ $? -eq 0 ]; then
        exit 0
    else
        log "[$NAME] $last_pid is not existed. Start new" ${FTP_LOG}
        pid_clear $PID_FILE
    fi
fi

main &

pid_store $! $PID_FILE

