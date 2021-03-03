#!/bin/bash


if [ "`whoami`" != root ]; then
	echo "This script must be run under root!"
	exit 1
fi

if [ $# -lt 1 ]; then
	echo "Usage: $0 username"
	exit 1
fi

if [ "`id $1 2>/dev/null`" ]; then
	echo "User $1 already exists!"
	exit 1
fi

random_string () 
{ 
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1
}

pswd=`random_string 16`

tmux new-session -s adduser -d -x 240 -y 60
sleep 1

# Add user
echo "Adding user $1 ..."
tmux send-keys -t adduser "adduser $1" Enter
sleep 1

tmux send-keys -t adduser $pswd Enter
sleep 1

tmux send-keys -t adduser $pswd Enter
sleep 1

tmux send-keys -t adduser "$1" Enter
sleep 1

tmux send-keys -t adduser Enter
sleep 1

tmux send-keys -t adduser Enter
sleep 1

tmux send-keys -t adduser Enter
sleep 1

tmux send-keys -t adduser Enter
sleep 1

tmux send-keys -t adduser Enter
sleep 1

tmux send-keys -t adduser Enter
sleep 1


# create ed25519 SSH-KEY
echo "Creating SSH-KEY ..."
tmux send-keys -t adduser "su $1" Enter
sleep 1

tmux send-keys -t adduser "ssh-keygen -t ed25519" Enter
sleep 1

tmux send-keys -t adduser Enter
sleep 1

tmux send-keys -t adduser $pswd Enter
sleep 1

tmux send-keys -t adduser $pswd Enter
sleep 1


# create google-authenticator
echo "Creating 2FA ..."
tmux send-keys -t adduser google-authenticator Enter
sleep 1

tmux send-keys -t adduser y Enter
sleep 1

tmux send-keys -t adduser y Enter
sleep 1

tmux send-keys -t adduser y Enter
sleep 1

tmux send-keys -t adduser n Enter
sleep 1

tmux send-keys -t adduser y Enter
sleep 1

tmux send-keys -t adduser exit Enter
sleep 1

tmux send-keys -t adduser exit Enter
sleep 1

echo Done


cd ~
cp /home/$1/.ssh/id_ed25519.pub /home/$1/.ssh/authorized_keys
cp /home/$1/.ssh/id_ed25519 $1.id_ed25519

ls -al $1.*
echo "The 2FA serial is `head -1 /home/$1/.google_authenticator`"
echo "The temporary password is $pswd"

