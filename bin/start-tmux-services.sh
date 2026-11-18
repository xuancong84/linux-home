
session_name=startup
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
	tmux split-window -t $session_name
	sleep 0.5
	tmux select-layout -t $session_name tile
	sleep 0.5
	tmux send-keys -t $session_name -l "${cmds[i]}"
	sleep 0.5
	tmux send-keys -t $session_name Enter
done


