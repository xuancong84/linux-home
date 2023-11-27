
opt="-t"

session_name=scrcpy
curr_workspace="`wmctrl -d | grep '*' | awk '{print $1}'`"
win_IDs=(`wmctrl -lpx | awk "{if(\\$2==$curr_workspace)print \\$1}"`)
desktop_width=`wmctrl -d | grep '*' | awk '{print $9}' | sed "s:x.*::g"`
desktop_height=`wmctrl -d | grep '*' | awk '{print $9}' | sed "s:.*x::g"`
devs=(`adb devices | sed '/^$/d' | awk '{if(NR>1)print $1}'`)
cmds=("watch -n 1 adb devices")
for dev in ${devs[@]}; do
	cmds[${#cmds[@]}]="scrcpy $opt -s $dev"
done

if [ "`tmux ls | grep $session_name`" ]; then
	echo "The service already started!" >&2
	exit 1
fi

tmux new-session -s $session_name -d -x 240 -y 60

for i in `seq 0 $[${#cmds[*]}-1]`; do
	sleep 0.2
	tmux split-window
	sleep 0.2
	tmux select-layout tile
	sleep 0.2
	tmux send-keys -l "${cmds[i]}"
	sleep 0.2
	tmux send-keys Enter
done

sleep 1
set -x

names=()
newIDs=()
while IFS= read -r line; do
	wsID=`echo "$line" | awk '{print $2}'`
	if [ "$wsID" != "$curr_workspace" ]; then
		continue
	fi
	winID=`echo "$line" | awk '{print $1}'`
	if ! [[ "${win_IDs[*]}" == *"$winID"* ]]; then
		newIDs[${#names[@]}]="$winID"
		names[${#names[@]}]="`echo $line | awk '{ print substr($0, index($0,$4)) }'`"
	fi
done <<<"`wmctrl -l`"


N=${#names[@]}
cx=$desktop_width
cy=0
if [ $N == 1 ]; then
	wmctrl -r "${names[0]}" -e 0,1430,56,490,963
	cx=1430
else
	w_height=$[desktop_height/2]
	w_width=$[w_height*9/20]
	for i in `seq 0 $[N-1]`; do
		if [ $[i%2] == 0 ]; then
			cx=$[cx-w_width]
			cy=0
		else
			cy=$[cy+w_height]
		fi
		#wmctrl -r "${names[i]}" -e 0,$cx,$cy,$w_width,$w_height
		xdotool windowsize "${newIDs[i]}" $w_width $w_height
		xdotool windowmove "${newIDs[i]}" $cx $cy
	done
fi

for winID in ${win_IDs[*]}; do
	wmctrl -i -r $winID -b remove,maximized_vert,maximized_horz
	sleep 1
	wmctrl -i -r $winID -e 0,0,0,$cx,$desktop_height
	sleep 1
	wmctrl -i -r $winID -b add,maximized_vert
	sleep 1
done


tmux a -t $session_name

for winID in ${win_IDs[*]}; do
	wmctrl -i -r $winID -b add,maximized_vert,maximized_horz
done

tmux kill-session -t $session_name
