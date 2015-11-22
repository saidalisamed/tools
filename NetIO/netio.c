#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

double *get_netio() {
	FILE *fp;
	char net_bytes[1024];
	double *rxtx = malloc(2);

	/* Open the command for reading. */
	fp = popen("netstat -I en0 -ib |grep -e \"en0\" -m 1", "r");
	if (fp == NULL) {
		printf("Failed to run command\n" );
		exit(1);
	}

	/* Read the output a line at a time - output it. */
	char *token;
	while (fgets(net_bytes, sizeof(net_bytes)-1, fp) != NULL) {
		token = strtok(net_bytes, " ");
		for (int i=0; token != NULL; i++) {
			if (i == 6) {
				rxtx[0] = atof(token);
			} else if (i == 9) {
				rxtx[1] = atof(token);
			} 
			token = strtok(NULL, " ");
		}
	}
	pclose(fp);
	
	return rxtx;
}

char *readable_s(double size, char *buf) {
    int i = 0;
    const char* units[] = {"b", "kb", "mb", "gb", "tb"};
    while (size > 1024) {
        size /= 1024;
        i++;
    }
    sprintf(buf, "%.*f %s", i, size, units[i]);
    return buf;
}

int main( int argc, char *argv[] ) {
	
	double *rxtx_one = get_netio();
	sleep(1);
	double *rxtx_two = get_netio();
	
	char buf[10];
	printf("⋀ %s/s\n", readable_s((rxtx_two[1]-rxtx_one[1])*8, buf));
	printf("⋁ %s/s\n", readable_s((rxtx_two[0]-rxtx_one[0])*8, buf));
	
	return 0;
}

