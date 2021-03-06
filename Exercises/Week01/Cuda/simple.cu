#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <sys/time.h>
#include <time.h>
#include <cuda_runtime.h>

__global__ void square(float * d_out, float * d_in) {
    const unsigned int lid = threadIdx.x;
    const unsigned int gid = blockIdx.x*blockDim.x + lid;
    float f = d_in[gid];
    d_out[gid] = f * f;
}

__global__ void special(float * d_out, float * d_in, int size) {
    const unsigned int lid = threadIdx.x;
    const unsigned int gid = blockIdx.x*blockDim.x + lid;
    if(gid < size) {
        float x = d_in[gid];
        d_out[gid] = powf(x / (x - 2.3), 3);
    }
}

void specialCPU(float * d_out, float * d_in, int size) {
    for(int i = 0; i<size; i++) {
        float x = d_in[i];
        d_out[i] = pow(x / (x - 2.3), 3);
    }
}


int timeval_subtract( struct timeval* result, struct timeval* t2, struct timeval* t1) {
    unsigned int resolution=1000000;
    long int diff = (t2->tv_usec + resolution * t2->tv_sec) - (t1->tv_usec + resolution * t1->tv_sec);
    result->tv_sec = diff / resolution;
    result->tv_usec = diff % resolution;
    return (diff<0);
}

int main(int argc, char **argv) {
    unsigned long int elapsedGPU;
    unsigned long int elapsedCPU;
    struct timeval t_start, t_end, t_diff;
    
	const int ARRAY_SIZE = 32757;
    const int ARRAY_BYTES = ARRAY_SIZE * sizeof(float);

    const int block_size = 256;    
    const int num_blocks = ((ARRAY_SIZE + (block_size -1)) / block_size);
	
	// Generate the input array on the host
	float * h_in = (float*) malloc(ARRAY_BYTES);
    float * h_out = (float*) malloc(ARRAY_BYTES);
    float * cpu_out = (float*) malloc(ARRAY_BYTES);
    
    for(int i = 0; i<ARRAY_SIZE; i++){
        h_in[i] = float(i);
    }

    // declare GPU memory pointers
    float * d_in;
    float * d_out;

    // allocate GPU memory
    cudaMalloc((void **) &d_in, ARRAY_BYTES);
    cudaMalloc((void **) &d_out, ARRAY_BYTES);

        
    // copy CPU memory to GPU memory
    cudaMemcpy(d_in, h_in, ARRAY_BYTES, cudaMemcpyHostToDevice);


    // Launch the kernel
    gettimeofday(&t_start, NULL);     
    special<<<num_blocks, block_size>>>(d_out, d_in, ARRAY_SIZE);
    cudaThreadSynchronize();

    gettimeofday(&t_end, NULL);  
    timeval_subtract(&t_diff, &t_end, &t_start);
    elapsedGPU = t_diff.tv_sec*1e6+t_diff.tv_usec;
    // copy back the result
    cudaMemcpy(h_out, d_out, ARRAY_BYTES, cudaMemcpyDeviceToHost);

    // run CPU
    gettimeofday(&t_start, NULL);  
    specialCPU(cpu_out, h_in, ARRAY_SIZE);    
    gettimeofday(&t_end, NULL);
    timeval_subtract(&t_diff, &t_end, &t_start);
    elapsedCPU = t_diff.tv_sec*1e6+t_diff.tv_usec;

    // print result
    bool valid = true;
    for(int i = 0; i < ARRAY_SIZE; i++) {
        if (abs(cpu_out[i] - h_out[i]) > 0.0001f) {
            printf("cpu: %f : gpu %f\n", cpu_out[i], h_out[i]);
            valid = false;
            break;
        }
        //printf("%f", h_out[i]);
        //printf((i % 4 != 3) ? "\t" : "\n");
    }
    if(valid)
        printf("VALID\n");
    else
        printf("INVALID\n");
    

    printf("CPU Took %d microseconds (%.2fms)\n", elapsedCPU, elapsedCPU/1000.0);
    printf("GPU Took %d microseconds (%.2fms)\n", elapsedGPU, elapsedGPU/1000.0);

    // free cpu memory
    free(h_in);
    free(h_out);
    // free up GPU memory
    cudaFree(d_in);
    cudaFree(d_out);

    return 0;
}