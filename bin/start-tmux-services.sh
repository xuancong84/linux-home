
session_name=beiwe
cmds=("top"
"# command-line 1"
"# command-line 2"
"# command-line 3"
)

if [ "`tmux ls | grep $session_name`" ]; then
	echo "The service already started!" >&2
	exit 1
fi

tmux new-session -s $session_name -d -x 240 -y 60

for i in `seq 0 $[${#cmds[*]}-1]`; do
	sleep 0.5
	tmux split-window
	sleep 0.5
	tmux select-layout tile
	sleep 0.5
	tmux send-keys -l "${cmds[i]}"
	sleep 0.5
	tmux send-keys Enter
done


