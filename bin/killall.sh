# killme.sh :kill my threads

if [ $# -ge 1 ]; then
	pids=(`ps ux | grep $1 | awk '{print $2}'`)
else
	pids=(`ps ux | awk '{print $2}'`)
fi

for i in `seq 1 $[${#pids[*]}-1]`; do
	if [ ${pids[i]} == PID ] || [ ${pids[i]} == $$ ]; then
		pids[i]=
	fi
done

set -x
kill -9 ${pids[*]}
set +x




if [ $# -ge 1 ]; then
	pids=(`ps l | grep $1 | grep defunct | awk '{print $4}'`)
fi

set -x
kill -9 ${pids[*]}
set +x




if [ $# -ge 1 ]; then
	pids=(`ps l | grep defunct | awk '{print $4}'`)
fi

set -x
kill -9 ${pids[*]}
set +x



