#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

// Allow a non-root user to run a specific command as root
// Remember to `chown root:root a.out && chmod +s a.out` before running it

int main(int argc, char *argv[]){
	setuid(0);

	system("ls -al /root");
	
	return 0;
}
