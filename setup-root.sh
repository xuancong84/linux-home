
if [ `whoami` != root ]; then
	echo "This script must be run as root!"
	exit
fi

cd "`dirname $0`"

mkdir -p ~/etc.bak
for f in inputrc profile tmux.conf; do
	cp /etc/$f ~/etc.bak/
	cp .$f /etc/
done

if [ -d /etc/vim ]; then
	cp /etc/vim/vimrc ~/etc.bak/
	cp .vimrc /etc/vim/vimrc
else
	cp /etc/vimrc ~/etc.bak/
	cp .vimrc /etc/vimrc
fi

