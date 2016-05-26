NVCCFLAGS = -arch sm_32 -G -g

all: stress_test temperature

stress_test: main.cu
	nvcc $(NVCCFLAGS) $? -o $@
temperature: temperature.c
	gcc $? -o $@ 
clean:
	rm -f stressTest temperature
