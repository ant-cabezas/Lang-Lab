/* WebAssembly side study, frames diagnostic: load latency of the [x, w, uxtw] addressing mode wasm memory
   accesses use against [x, x]. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
/* pointer chase over 32-bit byte offsets in a 4 KiB ring (L1-resident): load latency per hop */
#define N 1024
static uint32_t buf[N];
static double now(void){struct timespec t;clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&t);return t.tv_sec+t.tv_nsec*1e-9;}
int main(int argc,char**argv){
  long iters=atol(argv[2]); int mode=atoi(argv[1]);
  /* random cyclic permutation */
  int *p=malloc(N*sizeof(int)); for(int i=0;i<N;i++)p[i]=i;
  srand(1); for(int i=N-1;i>0;i--){int j=rand()%(i+1);int t=p[i];p[i]=p[j];p[j]=t;}
  for(int i=0;i<N;i++) buf[p[i]]=p[(i+1)%N]*4;
  uint64_t off=0; uint8_t*base=(uint8_t*)buf; double t0=now();
  if(mode==0){ /* Cranelift style: ldr w, [x, w, uxtw] */
    for(long i=0;i<iters;i++){ __asm__ volatile(
      "ldr %w0, [%1, %w0, uxtw]\n ldr %w0, [%1, %w0, uxtw]\n ldr %w0, [%1, %w0, uxtw]\n ldr %w0, [%1, %w0, uxtw]\n"
      :"+r"(off):"r"(base):"memory");}
  } else if(mode==1){ /* V8 style: ldr w, [x, x] (offset already zero-extended) */
    for(long i=0;i<iters;i++){ __asm__ volatile(
      "ldr %w0, [%1, %0]\n ldr %w0, [%1, %0]\n ldr %w0, [%1, %0]\n ldr %w0, [%1, %0]\n"
      :"+r"(off):"r"(base):"memory");}
  } else if(mode==2){ /* native style: plain 64-bit pointer + imm */
    uint64_t q=(uint64_t)base+off;
    for(long i=0;i<iters;i++){ __asm__ volatile(
      "ldr %w0, [%0]\n add %0, %0, %1\n ldr %w0, [%0]\n add %0, %0, %1\n ldr %w0, [%0]\n add %0, %0, %1\n ldr %w0, [%0]\n add %0, %0, %1\n"
      :"+r"(q):"r"(base):"memory");}
    off=q;
  } else { /* mode 3: add then plain load (Cranelift 'add x1, x6, w4, uxtw' + ldr [x1,#4]) */
    uint64_t t;
    for(long i=0;i<iters;i++){ __asm__ volatile(
      "add %1, %2, %w0, uxtw\n ldr %w0, [%1]\n add %1, %2, %w0, uxtw\n ldr %w0, [%1]\n add %1, %2, %w0, uxtw\n ldr %w0, [%1]\n add %1, %2, %w0, uxtw\n ldr %w0, [%1]\n"
      :"+r"(off),"=&r"(t):"r"(base):"memory");}
  }
  double t1=now(); printf("mode %d: %.3f ns/hop (sink %lu)\n",mode,(t1-t0)*1e9/(iters*4.0),(unsigned long)off);
  return 0;
}
