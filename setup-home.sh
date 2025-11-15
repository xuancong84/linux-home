
cd "`dirname $0`"

mkdir -p ~/bak
for f in .inputrc .profile .tmux.conf .vimrc; do
	cp ~/$f ~/bak/
	cp $f ~/
done

