/* WebAssembly side study, frames diagnostic: times leaf functions (frames.S) that save callee-saved
   registers either as a chain of stack-pointer updates (Cranelift's form) or with one stack adjustment and
   offset stores (clang's form), for 0 to 5 saved pairs and two body lengths. CPU time per call. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
typedef uint64_t (*fn)(uint64_t,uint64_t);
extern uint64_t fC0S(uint64_t,uint64_t);
extern uint64_t fO0S(uint64_t,uint64_t);
extern uint64_t fC1S(uint64_t,uint64_t);
extern uint64_t fO1S(uint64_t,uint64_t);
extern uint64_t fC2S(uint64_t,uint64_t);
extern uint64_t fO2S(uint64_t,uint64_t);
extern uint64_t fC3S(uint64_t,uint64_t);
extern uint64_t fO3S(uint64_t,uint64_t);
extern uint64_t fC4S(uint64_t,uint64_t);
extern uint64_t fO4S(uint64_t,uint64_t);
extern uint64_t fC5S(uint64_t,uint64_t);
extern uint64_t fO5S(uint64_t,uint64_t);
extern uint64_t fC0L(uint64_t,uint64_t);
extern uint64_t fO0L(uint64_t,uint64_t);
extern uint64_t fC1L(uint64_t,uint64_t);
extern uint64_t fO1L(uint64_t,uint64_t);
extern uint64_t fC2L(uint64_t,uint64_t);
extern uint64_t fO2L(uint64_t,uint64_t);
extern uint64_t fC3L(uint64_t,uint64_t);
extern uint64_t fO3L(uint64_t,uint64_t);
extern uint64_t fC4L(uint64_t,uint64_t);
extern uint64_t fO4L(uint64_t,uint64_t);
extern uint64_t fC5L(uint64_t,uint64_t);
extern uint64_t fO5L(uint64_t,uint64_t);

static struct {const char*n; fn f;} T[]={{"fC0S",fC0S},{"fO0S",fO0S},{"fC1S",fC1S},{"fO1S",fO1S},{"fC2S",fC2S},{"fO2S",fO2S},{"fC3S",fC3S},{"fO3S",fO3S},{"fC4S",fC4S},{"fO4S",fO4S},{"fC5S",fC5S},{"fO5S",fO5S},{"fC0L",fC0L},{"fO0L",fO0L},{"fC1L",fC1L},{"fO1L",fO1L},{"fC2L",fC2L},{"fO2L",fO2L},{"fC3L",fC3L},{"fO3L",fO3L},{"fC4L",fC4L},{"fO4L",fO4L},{"fC5L",fC5L},{"fO5L",fO5L}};
static double cpu(void){struct timespec t;clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&t);return t.tv_sec+t.tv_nsec*1e-9;}
int main(int argc,char**argv){ fn f=0; for(unsigned i=0;i<sizeof T/sizeof*T;i++) if(!strcmp(T[i].n,argv[1])) f=T[i].f;
  long n=atol(argv[2]); uint64_t acc=1; double t0=cpu();
  for(long i=0;i<n;i++){ acc=f(acc,i); __asm__ volatile("" ::: "x19","x20","x21","x22","x23","x24","x25","x26","x27","x28"); }
  printf("%s %.3f\n",argv[1],(cpu()-t0)*1e9/n); return acc==42; }
