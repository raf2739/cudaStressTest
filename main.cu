#include <stdio.h>
#include <cuda.h>
#include <unistd.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <pthread.h>
#include <sys/time.h>

#define NUM_THREADS 4
#define MEMPER 0.9
#define SIZE 1024ul
#define REQ_UNDEFINED   '-'
#define REQ_IDLE        ';'
#define REQ_START       'A'

#define RSP_FINISH      'Z'
#define RSP_UNDEFINED   '-'

struct thread_arg{
	int id;
	int size;
	double* doubles;
	double* compare;
};

void *Increment(void *args)
{
	struct thread_arg* arg;	
	int tid;
	int size;
	double* d;
	int work;

	arg = (struct thread_arg*) args;
   	tid = arg->id;
	size = arg->size;
	d = arg->doubles;
	work = size / (8 * 8);
	//printf("Tid: %d\tSize: %d\td:%p\n",tid,size,d);	
	for(int i = 0; i < work; i++){
		d[(tid * work) + i] *= 2;
	}
   	pthread_exit(NULL);
}

__global__ void 
intensive_kernel(unsigned int *cmd){
	int threadId = threadIdx.x + (blockDim.x * blockIdx.x);
	int done;
	double* input;
	double* compare;
	
	while (cmd[8]) {

                if (threadIdx.x == 0 && blockIdx.x == 0) {
			done = cmd[8];
                        if (cmd[0] == REQ_START && cmd[1] != RSP_FINISH) {
                                // we've got a request for a new job
                                // initialize
                                cmd[7] = 1;
                                __threadfence();
                        }
                        else {
                                cmd[7] = 0;
                                cmd[1] = RSP_UNDEFINED;
                                __threadfence();
                        }
                }

                __syncthreads();

                if (cmd[7] == 1) {
                        while(cmd[2] == 0);
                   	
			input = (double*) ((long long)cmd[6]<<32 | cmd[5]);
			compare = (double*) ((long long)cmd[4]<<32 | cmd[3]);     
			if(input[threadId] - compare[threadId] > 0.01){
				input[threadId] = (compare[threadId] * 2) + exp(input[threadId]);
			}	

			if (threadIdx.x == 0 && blockIdx.x == 0) {
				// finitto
                                cmd[0] = REQ_IDLE;
                                cmd[1] = RSP_FINISH;
                                cmd[7] = 0;
                                __threadfence();

                                // host will set #threads equal to 0 after obtaining the results                        
                                while (cmd[2] != 0);
                        }
                }
                __syncthreads();
        }
}


size_t
available_memory(){
	size_t mem_total = 0;
	size_t mem_free = 0;

	cudaMemGetInfo(&mem_free, &mem_total);
	printf("Total memory %dMB\tFree Memory %dMB\n",mem_total/(1024*1024),mem_free/(1024*1024));

	return mem_free;	

}


int 
main(int argc, char **argv){
	
	size_t available_mem = 0;
	double *doubles_host;
	double *doubles_device;	
	double *compare_host;
	double *compare_device;
	unsigned int* cmd_h;
	unsigned int* cmd_d;
	int threads;
	int blocks;
	int timeToRun;
	int result;
	cudaStream_t stream1;
	cudaStream_t stream2;
	struct timeval t1;
	struct timeval t2;
	pthread_t thread[8];
	struct thread_arg args;

	if(argc < 2){
		printf("Usage: stresstest <duration>\n\tduration\tTime stress will run in seconds\n");
		exit(EXIT_FAILURE);
	}

	timeToRun = atoi(argv[1]);

	cudaSetDevice(0);
	cudaStreamCreate(&stream1);
	cudaStreamCreate(&stream2);
	
	available_mem = available_memory() * 0.9;

	printf("Allocating 90%% of the available memory: (%dMB)\n", available_mem/(1024 * 1024));

	cudaMalloc((void**)&doubles_device, available_mem/4 * sizeof(char));
	cudaMalloc((void**)&compare_device, available_mem/4 * sizeof(char));
	cudaMalloc((void**)&cmd_d, 10 * sizeof(unsigned int));
	
	cudaMallocHost((void **)&cmd_h, 10 * sizeof(unsigned int));
	cudaMallocHost((void**)&doubles_host, available_mem/4 * sizeof(char));
	cudaMallocHost((void**)&compare_host, available_mem/4 * sizeof(char));

	srand(time(NULL));
	printf("Initializing buffers...\n");
	for(int i=0; i < available_mem/32; i++){
		doubles_host[i] = i * rand() * 1.8643;
		compare_host[i] = i * rand() * 1.4903;
	}
	printf("Finished initialization of buffers!\n\n");

	cmd_h[0] = REQ_UNDEFINED;
        cmd_h[1] = RSP_UNDEFINED;
        cmd_h[9] = 0;

	cudaMemcpy(doubles_device, doubles_host, available_mem/4 * sizeof(char), cudaMemcpyHostToDevice);
	cudaMemcpy(compare_device, compare_host, available_mem/4 * sizeof(char), cudaMemcpyHostToDevice);

	cudaMemcpy(cmd_h+3,&(compare_device), sizeof(double*),cudaMemcpyHostToHost);
	cudaMemcpy(cmd_h+5,&(doubles_device), sizeof(double*),cudaMemcpyHostToHost);
	cudaMemcpy(cmd_d, cmd_h, 10 * sizeof(unsigned int), cudaMemcpyHostToDevice);

	threads = 1024;
	blocks = available_mem/(16 * threads);	

	gettimeofday(&t1, 0);
	printf("Start stressing...\n");
	intensive_kernel<<<blocks,threads,0,stream1>>>(cmd_d);	

	pid_t pid = fork();

	if(pid == 0){
		//child
		
		if(execv("./temperature", argv) == -1){
			printf("Execv failed!\n");
			exit(EXIT_FAILURE);
		} 		
	}
	else if(pid > 0){
		//parent
		
	
		gettimeofday(&t2, 0);	
		while(t2.tv_sec - t1.tv_sec < timeToRun){

	                usleep(10);
	                cmd_h[0] = REQ_START;
	                cmd_h[1] = RSP_UNDEFINED;
	                cmd_h[2] = random() % 512;
			for(int i=0; i < 8; i++ ){
                                args.id = i;
                                args.size = available_mem/4;
                                args.doubles = compare_host;
                         	result = pthread_create(&thread[i], NULL,
                                               Increment, (void *)&args);
                              	if (result){
                 	        	printf("Unable to create thread\n");
                        		exit(-1);
         	               	}
                        }
                        for(int i = 0; i < 8; i++){
	                        pthread_join(thread[i], NULL);
                        }

	                cudaMemcpyAsync(doubles_device, doubles_host, available_mem/4 * sizeof(char), cudaMemcpyHostToDevice, stream2);
			cudaMemcpyAsync(compare_device, compare_host, available_mem/4 * sizeof(char), cudaMemcpyHostToDevice, stream2);

	                // first set #threads
	                cudaMemcpyAsync(cmd_d+2, cmd_h+2, 1 * sizeof(unsigned int), cudaMemcpyHostToDevice, stream2);
	                cudaStreamSynchronize(stream2);
	                
	                // set RSP
	                cudaMemcpyAsync(cmd_d+1, cmd_h+1, 1 * sizeof(unsigned int), cudaMemcpyHostToDevice, stream2);
	                cudaStreamSynchronize(stream2);
	
	                // set REQ 
	                cudaMemcpyAsync(cmd_d+0, cmd_h+0, 1 * sizeof(unsigned int), cudaMemcpyHostToDevice, stream2);
	                cudaStreamSynchronize(stream2);
	                
			int ready = 0;
	               	while (((cmd_h[0] == REQ_START) && cmd_h[1] != RSP_FINISH)) {
	                	ready = 1;

	                        // get RSP
	                	cudaMemcpyAsync(&cmd_h[1], &cmd_d[1], 1 * sizeof(unsigned int), cudaMemcpyDeviceToHost, stream2);
	                	cudaStreamSynchronize(stream2);
	                }
	                if (ready == 1) {
	                        // get data
	                        cudaMemcpyAsync(doubles_host,doubles_device, available_mem/4 * sizeof(char), cudaMemcpyDeviceToHost, stream2);
	                        cudaStreamSynchronize(stream2);
                            	printf("Size: %d\tPointer:%p\n",available_mem/4,doubles_host);	
				for(int i=0; i < 8; i++ ){
     					args.id = i;
					args.size = available_mem/4;
					args.doubles = doubles_host;		
      					result = pthread_create(&thread[i], NULL, 
                          			Increment, (void *)&args);
      					if (result){
         					printf("Unable to create thread\n");
         					exit(-1);
      					}
   				}
				for(int i = 0; i < 8; i++){
					//pthread_join(thread[i], NULL);
				}	
				//pthread_exit(NULL);						
				cmd_h[0] = REQ_UNDEFINED;
                                cudaMemcpyAsync(&cmd_d[0], &cmd_h[0], 1 * sizeof(unsigned int), cudaMemcpyHostToDevice, stream2);
                                cudaStreamSynchronize(stream2); 
	                        // notify GPU by setting #threads equal to 0
	                        cmd_h[2] = 0;
	                        cudaMemcpyAsync(&cmd_d[2], &cmd_h[2], 1 * sizeof(unsigned int), cudaMemcpyHostToDevice, stream2);
	                	cudaStreamSynchronize(stream2);
	                }
			gettimeofday(&t2, 0);
	                        //cudaStreamSynchronize(stream2);
	        }
		cmd_h[8] = 1;
		cudaMemcpyAsync(&cmd_d[8], &cmd_h[8], 1 * sizeof(unsigned int), cudaMemcpyHostToDevice, stream2);
        	cudaStreamSynchronize(stream2);

	}
	else{
		//error
		printf("fork() failed!\n");
		exit(EXIT_FAILURE);
	}                                  	

	printf("Finished!\n");
}
