
script_name=$( basename ${0#-} )
this_script=$( basename ${BASH_SOURCE} )

if [[ ${script_name} = ${this_script} ]] ; then
	mode=run
else
	mode=source
fi

for i in {0..32}; do
	echo "Trying DISPLAY=localhost:$i.0"
	DISPLAY="localhost:$i.0" xclock
	if [ $? == 0 ]; then
		if [ $mode == run ]; then
			echo -e "Please run:\nexport DISPLAY=localhost:$i.0"
		else
			export DISPLAY=localhost:$i.0
			echo "Display environment set successfully: DISPLAY=localhost:$i.0"
		fi
		break
	fi
done

