#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
static uint32_t T[256];
static uint32_t tg[4096]; static int ntg;
static char *P[64], *B[64], *W[1024]; static int np, nb, nw;
static uint32_t upd(uint32_t c, const char *s){ while(*s) c = T[(c ^ (uint8_t)*s++) & 0xff] ^ (c >> 8); return c; }
static int hit(uint32_t h){ int lo=0,hi=ntg-1; while(lo<=hi){int m=(lo+hi)/2; if(tg[m]==h) return 1; if(tg[m]<h) lo=m+1; else hi=m-1;} return 0; }
static int cmp(const void*a,const void*b){uint32_t x=*(uint32_t*)a,y=*(uint32_t*)b;return x<y?-1:x>y;}
static int load(const char *f, char **arr){ FILE *fp=fopen(f,"r"); char buf[256]; int n=0; while(fgets(buf,256,fp)){ buf[strcspn(buf,"\r\n")]=0; arr[n++]=strdup(buf);} fclose(fp); return n; }
int main(int argc, char **argv){
  int depth = atoi(argv[5]);
  for(uint32_t i=0;i<256;i++){uint32_t c=i; for(int k=0;k<8;k++) c = c&1 ? 0xEDB88320u^(c>>1) : c>>1; T[i]=c;}
  char *tmp[4096]; ntg = load(argv[1], tmp); for(int i=0;i<ntg;i++) tg[i]=(uint32_t)strtoul(tmp[i],0,16); qsort(tg,ntg,4,cmp);
  np = load(argv[2], P); nb = load(argv[3], B); nw = load(argv[4], W);
  for(int p=0;p<np;p++) for(int b=0;b<nb;b++){
    char *pp = strcmp(P[p],"-")?P[p]:""; char *bb = strcmp(B[b],"-")?B[b]:"";
    uint32_t c0 = upd(upd(0xffffffffu, pp), bb);
    if(hit(~c0)) printf("%08x %s%s\n", ~c0, pp, bb);
    for(int a=0;a<nw;a++){ uint32_t c1=upd(c0,W[a]); if(hit(~c1)) printf("%08x %s%s%s\n",~c1,pp,bb,W[a]);
      if(depth<2) continue;
      for(int d=0;d<nw;d++){ uint32_t c2=upd(c1,W[d]); if(hit(~c2)) printf("%08x %s%s%s%s\n",~c2,pp,bb,W[a],W[d]);
        if(depth<3) continue;
        for(int e=0;e<nw;e++){ uint32_t c3=upd(c2,W[e]); if(hit(~c3)) printf("%08x %s%s%s%s%s\n",~c3,pp,bb,W[a],W[d],W[e]); if(depth<4) continue; for(int g=0;g<nw;g++){ uint32_t c4=upd(c3,W[g]); if(hit(~c4)) printf("%08x %s%s%s%s%s%s\n",~c4,pp,bb,W[a],W[d],W[e],W[g]); } }}}
  }
  return 0;
}
