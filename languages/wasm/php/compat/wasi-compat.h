/* Force-included (-include) into every php-src translation unit of the wasm build, at make time only.
 * Declares the POSIX calls that wasi-libc hides on wasm32-wasip1 and that php-src's core still references
 * (users/groups, popen, sockets, syslog). They are implemented as failing stubs in wasi-stubs.c: no benchmark
 * touches any of them. The headers in compat/include are taken from mpyw/gophper-wasm (MIT, see
 * patches/LICENSE.gophper-wasm). Dead code on the native build, which does not include this file. */
#ifndef LANGLAB_WASI_COMPAT_H
#define LANGLAB_WASI_COMPAT_H
#ifdef __wasi__

/* LLVM's wasm setjmp lowering only knows setjmp()/longjmp(); wasi-libc declares sigsetjmp() without defining it.
 * WASI has no signal masks to save, so the two are the same call. Defined before <setjmp.h> is included. */
#define sigsetjmp(env, savemask) setjmp(env)
#define siglongjmp(env, val) longjmp(env, val)

#include <sys/types.h>
#include <stdio.h>
#include <sys/socket.h>
#include <grp.h>
#include <pwd.h>
#include <syslog.h>

uid_t getuid(void);
uid_t geteuid(void);
gid_t getgid(void);
gid_t getegid(void);
int getgroups(int, gid_t[]);
int chown(const char *, uid_t, gid_t);
int lchown(const char *, uid_t, gid_t);
mode_t umask(mode_t);
pid_t getppid(void);
int getdtablesize(void);
FILE *popen(const char *, const char *);
int pclose(FILE *);
char *mktemp(char *);

#ifndef PF_UNIX
#define PF_UNIX AF_UNIX
#endif
#ifndef SOMAXCONN
#define SOMAXCONN 128
#endif
#ifndef SOL_IP
#define SOL_IP 0
#define SOL_TCP 6
#define SOL_UDP 17
#define SOL_IPV6 41
#endif
#ifndef SO_ERROR
#define SO_ERROR 4
#define SO_REUSEADDR 2
#define SO_BROADCAST 6
#define SO_SNDBUF 7
#define SO_RCVBUF 8
#define SO_KEEPALIVE 9
#define SO_LINGER 13
#define SO_RCVTIMEO 66
#define SO_SNDTIMEO 67
#endif
#ifndef MSG_OOB
#define MSG_OOB 0x0001
#endif
#ifndef MSG_DONTWAIT
#define MSG_DONTWAIT 0x0040
#endif

#endif /* __wasi__ */
#endif
