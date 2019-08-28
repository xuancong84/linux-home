

if [ $# == 0 ]; then
	echo "Usage: $0 key1 [key2 ...]" >&2
	exit 1
fi


for key in $*; do
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $key
done

