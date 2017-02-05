copy_to_ftp.sh
==============

This script can help you to copy some files to a ftp server (on a NAS for example).

Configure the script : 

* ftp_dir value, just put there the path where you want to copy videos.
* ftp_host value, indicate the IP of the NAS
* ftp_port value, indicate the port of the FTP server (like 21)
* ftp_login value, indicate the user or login to connect to the ftp folder in the nas server.
* ftp_pass value, indicate the password of the user before for permision to save in the folder.

Add the script to the crontab of your yi camera

Source of the script : 

* https://github.com/fritz-smh/yi-hack/pull/24
* http://4pda.ru/forum/index.php?showtopic=638230&st=2780#entry44208114

delete_old_videos.sh
====================

This script searchs and deletes videos older than 15 days. (You can change this value if you configure the script)
You have to run it manually or add it to crontab for running it autmatically.
The camera might throw an error if you try to run "crontab -e":
```sh
          crontab -e
          crontab: chdir(/var/spool/cron/crontabs): No such file or directory
```
If that's the case just create that dir manually and you can edit the crontab with "crontab -e"
Example configuration of crontab (runs the script the 15th of each month):
```sh
# Edit this file to introduce tasks to be run by cron.
#
# Each task to run has to be defined through a single line
# indicating with different fields when the task will be run
# and what command to run for the task
#
# To define the time you can provide concrete values for
# minute (m), hour (h), day of month (dom), month (mon),
# and day of week (dow) or use '*' in these fields (for 'any').#
# Notice that tasks will be started based on the cron's system
# daemon's notion of time and timezones.
#
# Output of the crontab jobs (including errors) is sent through
# email to the user the crontab file belongs to (unless redirected).
#
# For example, you can run a backup of all your user accounts
# at 5 a.m every week with:
# 0 5 * * 1 tar -zcf /var/backups/home.tgz /home/
#
# For more information see the manual pages of crontab(5) and cron(8)
#
# m h  dom mon dow   command
0 0 15 * * /home/hd1/test/scripts/delete_old_videos.sh
```

ftp_upload script
=================

This script uploads all current mp4 files to FTP server, the last finished file is used to continue uploading in next execution.
The PID of script is recorded into a file to avoid multi-execution.
This script uses `ftpput` to upload files to FTP server

**1. Files explanation:**
Folder `/tmp/hd1/test/scripts/ftp_upload`
- `common_lib.sh`: shared functions and default variable (with other script tools, e.g: housekeeper)
- `ftp_upload.cfg`: configuration file
- `ftp_upload.mem`: remember the last finished file and its folders. Also last `ftpput` PID, and its related info.
- `ftp_upload.pid`: remember the PID of current executing script, avoid multi-execution
- `log.txt`: execution log
- `ftp_upload.sh`: execution shell script

**2. How to use:**
- Set FTP server parameter in `/tmp/hd1/test/script/ftp_upload/ftp_upload.cfg`
- Open cron jobs editor: 
```
# crontab -e
```
- Add a job to call the script. E.g: below is a job to call the script each 7 minutes
```
# For more information see the manual pages of crontab(5) and cron(8)
#
# m h  dom mon dow   command

# Call ftp_upload.sh script each 7 minutes
*/7 * * * * /tmp/hd1/test/scripts/ftp_upload/ftp_upload.sh >/dev/null 2>&1
```
- Close cron jobs editor: Press `ESC` -> Press `:wq` -> Press `Enter`

**3. If you have gateway offline:**
In some cases, your gateway to route the traffic to your FTP server is offline. E.g: In my case, I power off my router from 2am to 3am for its cooldown. 
The gateway offline parameter in `/tmp/hd1/test/yi-hack.cfg` should be set so that `ftp_upload` script will avoid uploading in the gateway offline duration.
```
### Gateway offline duaration
# If you schedule your router to offline (during midnight for example).
# - GW_OFF_START: Start time of offline duration. Ex: 23:00
# - GW_OFF_END: End time of offline duration. Ex: 02:00
#
# Please use 24h format. In your timezone.
# Let them blank if not use.
GW_OFF_START=
GW_OFF_END=
```

housekeeper script
==================

This script help to delete old recording videos according how many days you want to keep videos
This script also check the status of gateway to reboot the camera. My situation is that, there was a power cut, then when power was back, camera had finished startup before my gateway (modem/ router). Then, camera cannot reach my router and it kept failure.

**How to use**
- Set parameters in `/tmp/hd1/test/script/housekeeper/housekeeper.cfg`
- Open cron jobs editor: 
```
# crontab -e
```
- Add a job to call the script. E.g: below is a job to call the script each 7 minutes
```
# For more information see the manual pages of crontab(5) and cron(8)
#
# m h  dom mon dow   command

# Call housekeeper.sh script each 11 minutes
*/11 * * * * /tmp/hd1/test/scripts/housekeeper/housekeeper.sh >/dev/null 2>&1
```
- Close cron jobs editor: Press `ESC` -> Press `:wq` -> Press `Enter`
- **_Gateway Offline Duration_** is also applied for `housekeeper` script (see above guide)

**Note about cron job interval and RETRY_TO_ALERT**
If you set cron job to call housekeeper.sh in each `11 minutes`, and `RETRY_TO_ALERT is 10` the script will check and increase counter each 11 minutes.
Until counter reaches 10 script will reboot/alert. It will take at least 10 x 11 = 110 minutes
When script is able to `ping` the router/gateway IP once, it **RESETS** the counter to 0 and increases in next time.

