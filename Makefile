NVCCFLAGS = -arch
SM_32 = sm_32
SM_35 = sm_35

all: stress_test_32 stress_test_35 temperature

stress_test_32: main.cu
	nvcc $(NVCCFLAGS) $(SM_32)  $? -o $@
stress_test_35: main.cu
	nvcc $(NVCCFLAGS) $(SM_35)  $? -o $@
temperature: temperature.c
	gcc $? -o $@ 
clean:
	rm -f stressTest temperature
