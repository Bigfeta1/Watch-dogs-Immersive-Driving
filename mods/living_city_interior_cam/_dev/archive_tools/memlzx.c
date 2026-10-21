/* in-memory LZX frame decoder (libmspack lzxd) for ctypes */
#include <stdlib.h>
#include <string.h>
#include "mspack.h"
#include "system.h"
#include "lzx.h"
struct mf { const unsigned char *buf; unsigned char *obuf; long len, pos; };
static int m_read(struct mspack_file *f, void *b, int n){ struct mf *m=(struct mf*)f; long r=m->len-m->pos; if(r>n) r=n; if(r<0) r=0; memcpy(b,m->buf+m->pos,r); m->pos+=r; return (int)r; }
static int m_write(struct mspack_file *f, void *b, int n){ struct mf *m=(struct mf*)f; if(m->pos+n>m->len) return -1; memcpy(m->obuf+m->pos,b,n); m->pos+=n; return n; }
static void *m_alloc(struct mspack_system *s, size_t n){ return malloc(n); }
static void m_free(void *p){ free(p); }
static void m_copy(void *a, void *b, size_t n){ memmove(b,a,n); }
static void m_msg(struct mspack_file *f, const char *fmt, ...){}
static struct mspack_system msys = { 0, 0, m_read, m_write, 0, 0, m_msg, m_alloc, m_free, m_copy, 0 };
int lzx_frame(const unsigned char *in, long inlen, unsigned char *out, long outlen, int wbits){
  struct mf i = { in, 0, inlen, 0 }, o = { 0, out, outlen, 0 };
  struct lzxd_stream *z = lzxd_init(&msys, (struct mspack_file*)&i, (struct mspack_file*)&o, wbits, 0, 4096, outlen, 0);
  if(!z) return -100;
  int r = lzxd_decompress(z, outlen);
  lzxd_free(z);
  return r ? -r : (int)o.pos;
}
