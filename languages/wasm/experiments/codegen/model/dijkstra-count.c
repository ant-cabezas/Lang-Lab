// WebAssembly side study, codegen experiment: counting aid for the dijkstra reconcile (never measured).
// Same algorithm as languages/c/dijkstra.c, plus counters for every branch outcome the static model
// (dijkstra-model.py) needs. Prints one JSON line per size; the study ran it at the spec sizes:
//   docker run --rm -i lang-lab-wasm-codegen-o2 sh -c 'cat > /tmp/c.c && gcc -O2 /tmp/c.c -o /tmp/c && /tmp/c 5000 && /tmp/c 20000' \
//     < languages/wasm/experiments/codegen/model/dijkstra-count.c > dijkstra-counts.jsonl
#include <stdio.h>
#include <stdlib.h>
#define INF (1L << 62)
#define DEG 8
#define MAXW 100
#define BASE 2097152L
static long lcg(long s) { return (s * 1103515245L + 12345L) & 0x7fffffffL; }
static long *heap, hsize;
static long P,S,NOE,T,A,B,W,E,I,Z,U,V,Y;
static void hpush(long k) {
    long i = hsize++; heap[i] = k; I++; if (i == 0) Z++;
    while (i > 0) { long p = (i - 1) / 2; U++;
        if (heap[p] <= heap[i]) break;
        long t = heap[p]; heap[p] = heap[i]; heap[i] = t; V++; i = p; if (i == 0) Y++; }
}
static long hpop(void) {
    long top = heap[0]; heap[0] = heap[--hsize]; long i = 0;
    for (;;) { long l = 2*i+1, r = 2*i+2, m = i; T++;
        if (l < hsize) { A++; if (heap[l] < heap[m]) m = l; }
        if (r < hsize) { B++; if (heap[r] < heap[m]) m = r; }
        if (m == i) break; W++;
        long t = heap[m]; heap[m] = heap[i]; heap[i] = t; i = m; }
    return top;
}
int main(int argc, char **argv) {
    int N = atoi(argv[1]); long M = (long)DEG * N;
    int *eu = malloc(M*sizeof(int)), *ev = malloc(M*sizeof(int)), *ew = malloc(M*sizeof(int));
    long s = 42;
    for (long e = 0; e < M; e++) { s = lcg(s); eu[e] = s % N; s = lcg(s); ev[e] = s % N; s = lcg(s); ew[e] = s % MAXW + 1; }
    long *start = calloc(N + 1, sizeof(long));
    for (long e = 0; e < M; e++) start[eu[e] + 1]++;
    for (int i = 0; i < N; i++) start[i + 1] += start[i];
    long *cnt = calloc(N, sizeof(long));
    int *adjV = malloc(M*sizeof(int)), *adjW = malloc(M*sizeof(int));
    for (long e = 0; e < M; e++) { long pos = start[eu[e]] + cnt[eu[e]]++; adjV[pos] = ev[e]; adjW[pos] = ew[e]; }
    long *dist = malloc(N*sizeof(long));
    for (int i = 0; i < N; i++) dist[i] = INF;
    dist[0] = 0; heap = malloc((M+1)*sizeof(long)); hsize = 0;
    hpush(0L); I = Z = U = V = Y = 0;   /* the initial push is outside the loop on both sides */
    while (hsize > 0) { long key = hpop(); P++;
        long d = key / BASE, u = key % BASE;
        if (d > dist[u]) { S++; continue; }
        if (start[u] >= start[u+1]) NOE++;
        for (long e = start[u]; e < start[u + 1]; e++) { E++;
            long v = adjV[e], nd = d + adjW[e];
            if (nd < dist[v]) { dist[v] = nd; hpush(nd * BASE + v); } } }
    printf("{\"N\":%d,\"M\":%ld,\"P\":%ld,\"S\":%ld,\"NOE\":%ld,\"T\":%ld,\"A\":%ld,\"B\":%ld,\"W\":%ld,\"E\":%ld,\"I\":%ld,\"Z\":%ld,\"U\":%ld,\"V\":%ld,\"Y\":%ld}\n",N,M,P,S,NOE,T,A,B,W,E,I,Z,U,V,Y);
    return 0;
}
