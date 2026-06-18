
if [ `whoami` != root ]; then
	echo "This script must be run as root!"
	exit
fi

cd "`dirname $0`"

mkdir -p ~/etc.bak
for f in /etc/inputrc /etc/profile.d/99-moht.sh /etc/tmux.conf; do
	if [ -s $f ]; then
		cp $f ~/etc.bak/
	fi
	cp .$f $f
done

if [ -d /etc/vim ]; then
	cp /etc/vim/vimrc ~/etc.bak/
	cp .vimrc /etc/vim/vimrc
else
	cp /etc/vimrc ~/etc.bak/
	cp .vimrc /etc/vimrc
fi

