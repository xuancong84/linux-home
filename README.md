# Linux/Ubuntu professional home folder configuration files and common toolkits

This is my Linux/Ubuntu home folder:
- configuration files (e.g., .profile, .vimrc, .tmux.conf, .inputrc, etc.)
- common toolkits in $HOME/bin
- a python-based apt-mirror.py that works better than apt-mirror
- CSV previewer using gnumeric
- toggle touchscreen

Common toolkits:
- mp4-\*.sh : MP4 editing toolkits (e.g., add .srt subtitles, reduce file size, trim beginning and end, concatenate, convert to gif, etc.)
- m3u8-download.py : download m3u8 video from a website
- (max/min/mean/median/std).py : compute statistical max/min/mean/median/std from STDIN
- jpegoptim.sh : reduce jpeg file size
- compare-recursive.py : recursively compare two folders taking care of CSV, JSON, etc.
- start-scrcpy4.sh : launching scrcpy for every connected phone for Android development
- show.sh : show the content of all files with the given filename pattern, i.e., filename followed by the content
- srt2txt.py/txt2srt.py : convert srt subtitles to txt and vice versa
- preview-csv.sh : preview the content of possibly large CSV files (for large CSV file, preview only the 1st 200 rows)
- preview-timestamp.sh : preview CSV files with integer timestamp (in sec/msec, converting to datetime)

Toolkits for system administrators:
- copy-cred.py : copy user credentials in passwd/shadow/group from src\_dir to tgt\_dir, keeping system user information
- copy-dependent-so.sh / port-executable.sh : recursively copy out all dependent .so libraries of an executable
- ifswitch.sh : automatically switch gateway if lost Internet connection
- share-wifi-over-ethernet.sh : share Internet from one network interface to another
- start-tmux-services.sh : startup script for launching multiple startup services in a tmux session

