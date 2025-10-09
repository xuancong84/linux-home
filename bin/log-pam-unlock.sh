#!/bin/sh
# How to install: insert the following line (with correct path and without comment) at the correct position in /etc/pam.d/common-auth
# auth  optional  pam_exec.so /usr/local/bin/log-pam-unlock.sh
echo "`date --rfc-3339=seconds` PAM_TTY=$PAM_TTY PAM_USER=$PAM_USER PAM_TYPE=$PAM_TYPE" >>/var/log/pam-unlock.log
