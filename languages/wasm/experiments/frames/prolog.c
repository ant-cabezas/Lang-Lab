/* WebAssembly side study, frames diagnostic: separates the cost of chained pushes, chained pops and the
   stack-limit check of a Cranelift-style frame (prolog.S). */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
typedef uint64_t (*fn)(uint64_t, uint64_t, void*);
extern uint64_t fE(uint64_t,uint64_t,void*),fF(uint64_t,uint64_t,void*),fG(uint64_t,uint64_t,void*),fA(uint64_t,uint64_t,void*), fB(uint64_t,uint64_t,void*), fC(uint64_t,uint64_t,void*), fD(uint64_t,uint64_t,void*);
static double cpu(void){struct timespec t;clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&t);return t.tv_sec+t.tv_nsec*1e-9;}
int main(int argc,char**argv){
  fn f[]={fA,fB,fC,fD,fE,fF,fG}; int m=atoi(argv[1]); long n=atol(argv[2]);
  static uint64_t lim[8]; static void* rt[8]; rt[1]=lim; /* x2 -> rt; [rt+8] -> lim; [lim+0x18]=0 */
  register uint64_t acc=1; double t0=cpu();
  for(long i=0;i<n;i++){ acc=f[m](acc,i,rt); __asm__ volatile("" ::: "x19","x20","x21","x22","x23","x24","x25","x26","x27","x28"); }
  double t1=cpu(); printf("%c %.3f ns/call %lu\n","ABCDEFG"[m],(t1-t0)*1e9/n,(unsigned long)acc); return 0;
}
