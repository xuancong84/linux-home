
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
for winID in ${win_IDs[*]}; do
	wmctrl -i -r $winID -b remove,maximized_vert,maximized_horz
	sleep 0.2
	wmctrl -i -r $winID -e 0,0,0,$[desktop_width-251-240],$desktop_height
	sleep 0.2
	wmctrl -i -r $winID -b add,maximized_vert
	sleep 0.2
done

names=()
while IFS= read -r line; do
	wsID=`echo "$line" | awk '{print $2}'`
	if [ "$wsID" != "$curr_workspace" ]; then
		continue
	fi
	winID=`echo "$line" | awk '{print $1}'`
	if ! [[ "${win_IDs[*]}" == *"$winID"* ]]; then
		names[${#names[@]}]="`echo $line | awk '{ print substr($0, index($0,$4)) }'`"
	fi
done <<<"`wmctrl -l`"

N=${#names[@]}
if [ $N == 1 ]; then
	wmctrl -r "${names[0]}" -e 0,1430,56,490,963
elif [ $N == 2 ]; then
	wmctrl -r "${names[0]}" -e 0,1546,0,270,482
	wmctrl -r "${names[1]}" -e 0,1546,482,270,529
elif [ $N == 3 ]; then
	wmctrl -r "${names[0]}" -e 0,1546,0,270,482
	wmctrl -r "${names[1]}" -e 0,1429,482,251,529
	wmctrl -r "${names[2]}" -e 0,1680,482,240,529
elif [ $N == 4 ]; then
	wmctrl -r "${names[0]}" -e 0,1429,0,251,482
	wmctrl -r "${names[1]}" -e 0,1429,482,251,529
	wmctrl -r "${names[2]}" -e 0,1680,482,240,529
	wmctrl -r "${names[3]}" -e 0,1680,0,240,482
fi

tmux a -t $session_name

for winID in ${win_IDs[*]}; do
	wmctrl -i -r $winID -b add,maximized_vert,maximized_horz
done

tmux kill-session -t $session_name
