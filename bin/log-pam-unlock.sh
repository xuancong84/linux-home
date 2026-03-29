#!/bin/sh
# How to install:
# A. insert the following line (with correct path and without comment) at the correct position in /etc/pam.d/common-auth
# auth  optional  pam_exec.so /usr/local/bin/log-pam-unlock.sh
# B. add to /etc/vnc/xstartup*
echo "`date --rfc-3339=seconds` PAM_USER=$PAM_USER USER=$USER" >>/var/log/pam-unlock.log
