NVCCFLAGS = -arch
SM_32 = sm_32
SM_35 = sm_35

all: stress_test_K1 stress_test_X1 temperature

stress_test_K1: main.cu
	nvcc $(NVCCFLAGS) $(SM_32)  $? -o $@
stress_test_X1: main.cu
	nvcc $(NVCCFLAGS) $(SM_35)  $? -o $@
temperature: temperature.c
	gcc $? -o $@ 
clean:
	rm -f stress_test_K1 stress_test_X1 temperature
