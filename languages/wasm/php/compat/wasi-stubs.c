/* Failing stubs for the POSIX calls declared in wasi-compat.h and the headers in compat/include.
 * Linked into the wasm php only. None is reachable from the benchmarks (no users, sockets, pipes or syslog). */
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <pwd.h>
#include <grp.h>
#include <syslog.h>
#include <stdarg.h>

#define FAIL(v) do { errno = ENOSYS; return (v); } while (0)

uid_t getuid(void)  { return 0; }
uid_t geteuid(void) { return 0; }
gid_t getgid(void)  { return 0; }
gid_t getegid(void) { return 0; }
pid_t getppid(void) { return 1; }
int getdtablesize(void) { return 1024; }
int getgroups(int n, gid_t *g) { (void)n; (void)g; return 0; }
int chown(const char *p, uid_t u, gid_t g)  { (void)p; (void)u; (void)g; FAIL(-1); }
int lchown(const char *p, uid_t u, gid_t g) { (void)p; (void)u; (void)g; FAIL(-1); }
mode_t umask(mode_t m) { (void)m; return 022; }
FILE *popen(const char *c, const char *m) { (void)c; (void)m; errno = ENOSYS; return NULL; }
int pclose(FILE *f) { (void)f; FAIL(-1); }

struct passwd *getpwuid(uid_t u) { (void)u; return NULL; }
struct passwd *getpwnam(const char *n) { (void)n; return NULL; }
int getpwuid_r(uid_t u, struct passwd *p, char *b, size_t l, struct passwd **r) { (void)u; (void)p; (void)b; (void)l; *r = NULL; return ENOENT; }
int getpwnam_r(const char *n, struct passwd *p, char *b, size_t l, struct passwd **r) { (void)n; (void)p; (void)b; (void)l; *r = NULL; return ENOENT; }
struct group *getgrnam(const char *n) { (void)n; return NULL; }
struct group *getgrgid(gid_t g) { (void)g; return NULL; }

void openlog(const char *i, int o, int f) { (void)i; (void)o; (void)f; }
void closelog(void) {}
void syslog(int p, const char *f, ...) { (void)p; (void)f; }
void vsyslog(int p, const char *f, va_list a) { (void)p; (void)f; (void)a; }

int socket(int d, int t, int p) { (void)d; (void)t; (void)p; FAIL(-1); }
int socketpair(int d, int t, int p, int v[2]) { (void)d; (void)t; (void)p; (void)v; FAIL(-1); }
int connect(int s, const struct sockaddr *a, socklen_t l) { (void)s; (void)a; (void)l; FAIL(-1); }
int bind(int s, const struct sockaddr *a, socklen_t l) { (void)s; (void)a; (void)l; FAIL(-1); }
int listen(int s, int b) { (void)s; (void)b; FAIL(-1); }
int getsockname(int s, struct sockaddr *a, socklen_t *l) { (void)s; (void)a; (void)l; FAIL(-1); }
int getpeername(int s, struct sockaddr *a, socklen_t *l) { (void)s; (void)a; (void)l; FAIL(-1); }
ssize_t sendto(int s, const void *b, size_t n, int f, const struct sockaddr *a, socklen_t l) { (void)s; (void)b; (void)n; (void)f; (void)a; (void)l; FAIL(-1); }
ssize_t recvfrom(int s, void *b, size_t n, int f, struct sockaddr *a, socklen_t *l) { (void)s; (void)b; (void)n; (void)f; (void)a; (void)l; FAIL(-1); }
int getsockopt(int s, int lv, int o, void *v, socklen_t *l) { (void)s; (void)lv; (void)o; (void)v; (void)l; FAIL(-1); }
int setsockopt(int s, int lv, int o, const void *v, socklen_t l) { (void)s; (void)lv; (void)o; (void)v; (void)l; FAIL(-1); }

char *mktemp(char *t) { if (t) t[0] = '\0'; return t; }

/* dl() and extension loading: static build, no shared objects on WASI. */
void *dlopen(const char *f, int m) { (void)f; (void)m; return NULL; }
void *dlsym(void *h, const char *n) { (void)h; (void)n; return NULL; }
int dlclose(void *h) { (void)h; return 0; }
char *dlerror(void) { return (char *)"dynamic loading is not available on WASI"; }

/* Name resolution: no network on this target. */
int getaddrinfo(const char *n, const char *s, const struct addrinfo *h, struct addrinfo **r) { (void)n; (void)s; (void)h; *r = NULL; return EAI_FAIL; }
void freeaddrinfo(struct addrinfo *a) { (void)a; }
int getnameinfo(const struct sockaddr *a, socklen_t al, char *h, socklen_t hl, char *s, socklen_t sl, int f) { (void)a; (void)al; (void)h; (void)hl; (void)s; (void)sl; (void)f; return EAI_FAIL; }
const char *gai_strerror(int e) { (void)e; return "name resolution is not available on WASI"; }
struct hostent *gethostbyname(const char *n) { (void)n; return NULL; }
struct hostent *gethostbyaddr(const void *a, socklen_t l, int t) { (void)a; (void)l; (void)t; return NULL; }
struct servent *getservbyname(const char *n, const char *p) { (void)n; (void)p; return NULL; }
struct servent *getservbyport(int p, const char *pr) { (void)p; (void)pr; return NULL; }
struct protoent *getprotobyname(const char *n) { (void)n; return NULL; }
struct protoent *getprotobynumber(int n) { (void)n; return NULL; }

/* zend_alloc.c hints about freed chunks; a no-op where the kernel interface is absent. */
int madvise(void *a, size_t l, int adv) { (void)a; (void)l; (void)adv; FAIL(-1); }
