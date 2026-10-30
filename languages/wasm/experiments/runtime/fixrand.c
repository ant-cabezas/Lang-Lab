/* Diagnostic only: deterministic getrandom() for the guest, to test whether random hash seeds cause jitter. */
#include <sys/types.h>
#include <stddef.h>
static unsigned long long st = 0x9E3779B97F4A7C15ULL;
ssize_t getrandom(void *buf, size_t len, unsigned int flags) {
  unsigned char *p = buf; (void)flags;
  for (size_t i = 0; i < len; i++) { st = st * 6364136223846793005ULL + 1442695040888963407ULL; p[i] = (unsigned char)(st >> 56); }
  return (ssize_t)len;
}
