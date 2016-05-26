#include <stdio.h>
#include <sys/time.h>


int
main(int argc, char** argv){

	struct timeval t1;
	struct timeval t2;
	unsigned int timeToRun;

	timeToRun = atoi(argv[1]);
	gettimeofday(&t1, 0);
	
	gettimeofday(&t2, 0);
	while(t2.tv_sec - t1.tv_sec < timeToRun){	
		//printf("test\n%d\n",t2.tv_sec - t1.tv_sec);
		//printf("\n");
		//printf("Temperature zone1:\t");
		
		system("echo CPU temp: && cat /sys/devices/virtual/thermal/thermal_zone0/temp");
		

                system("echo GPU temp: && cat /sys/devices/virtual/thermal/thermal_zone1/temp");
		
		/*system("echo Memory temp:\t");
                system("cat /sys/devices/virtual/thermal/thermal_zone2/temp");
				
		system("echo PLL temp:\t");
                system("cat /sys/devices/virtual/thermal/thermal_zone3/temp");
				
		system("echo Thermal zone 5:\t");
                system("cat /sys/devices/virtual/thermal/thermal_zone4/temp");
				
		system("echo Thermal zone 6:\t");
                system("cat /sys/devices/virtual/thermal/thermal_zone5/temp");
		*/
		printf("\n");
		sleep(2);
		gettimeofday(&t2, 0);
	}

}
