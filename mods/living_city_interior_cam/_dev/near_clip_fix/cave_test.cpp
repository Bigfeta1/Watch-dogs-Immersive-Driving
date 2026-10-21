// Offline check of NearClipFix: dump the caves, run the rider cave for real through a thunk that sets the
// registers like the game (rax = frame, rcx = camera, xmm1 = y, rsp 16-aligned), and simulate a ride.
#include <windows.h>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cmath>
typedef int (*Build)(unsigned char*, uintptr_t);
typedef void (*Step)(const unsigned char*, float*, double);
typedef void (*Thunk)(unsigned char* cam, unsigned char* frame, float unused, float y);
int main() {
    HMODULE m = LoadLibraryA("NearClipFix_test.asi");
    if (!m) { std::puts("load failed"); return 1; }
    Build build = (Build)GetProcAddress(m, "TestBuildCaves");
    Step step = (Step)GetProcAddress(m, "TestRiderStep");
    // fake engine block (ret at the rider cave's jump-back 0x2A1196) and a cave within 2 GB of it
    unsigned char* base = (unsigned char*)VirtualAlloc(nullptr, 0x300000, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    unsigned char* cave = (unsigned char*)VirtualAlloc(base + 0x400000, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    if (!cave) cave = (unsigned char*)VirtualAlloc(nullptr, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    base[0x2A1196] = 0xC3; base[0x2A120E] = 0xC3;
    if (!build(cave, (uintptr_t)base)) { std::puts("buildCaves refused"); return 1; }
    { float* f = (float*)(cave + 0x80);
      std::printf("near data: near %.4f hideNear %.4f hideAbove %.5f mark %.6f riderNear %.4f\n", f[0], f[1], f[2], f[3], f[4]); }
    FILE* o = std::fopen("cave_test.bin", "wb"); std::fwrite(cave, 1, 4096, o); std::fclose(o);
    std::printf("cave=%llx base=%llx\n", (unsigned long long)cave, (unsigned long long)base);
    // thunk: sub rsp,8; mov rax,rdx; movaps xmm1,xmm3; call cave+0x100; add rsp,8; ret
    unsigned char* th = cave + 0x800;
    unsigned char code[] = {0x48,0x83,0xEC,0x08, 0x48,0x89,0xD0, 0x0F,0x28,0xCB, 0xE8,0,0,0,0, 0x48,0x83,0xC4,0x08, 0xC3};
    int32_t r = (int32_t)((cave + 0x100) - (th + 15)); std::memcpy(code + 11, &r, 4);
    std::memcpy(th, code, sizeof(code));
    unsigned char cam[0x80] = {}, frame[0x100] = {};
    float fov = 75.5f * 0.017453292f; std::memcpy(cam + 0x6C, &fov, 4);
    float pos[3] = {1000.0f, 2000.0f, 71.0f}; std::memcpy(cam + 0x54, pos, 12);
    // real cave execution, first call at rest: expect x = 1000 (pre-stored), y = 2000, z = 71 unchanged
    float x0 = 1000.0f; std::memcpy(frame + 0x80 - 0x38, &x0, 4);
    ((Thunk)th)(cam, frame + 0x80, 0.0f, 2000.0f);
    float v[3]; std::memcpy(v, frame + 0x80 - 0x38, 12);
    std::printf("cave run at rest: view = (%.3f, %.3f, %.3f)\n", v[0], v[1], v[2]);
    // ride along +y like the game: the position changes once per 16.7 ms frame, the cave runs 4 times per
    // frame (10 ms, +7 ms, then two immediate repeats). Accelerate 0 -> 40 m/s over 4 s, cruise 2 s, brake to
    // 0 over 4 s, stand 3 s.
    typedef int (*Tel)();
    Tel tel = (Tel)GetProcAddress(m, "TestTeleports");
    LARGE_INTEGER f, q0, q; QueryPerformanceFrequency(&f); QueryPerformanceCounter(&q0);
    float y = 2000.0f; double last = 0, nextPrint = 0; float minFwdFast = 1, prevFw = -1, maxStep = 0;
    for (;;) {
        Sleep(16);
        QueryPerformanceCounter(&q); double ts = double(q.QuadPart - q0.QuadPart) / f.QuadPart;
        if (ts > 13.2) break;
        float speed = ts < 4 ? 10.0f * ts : ts < 6 ? 40.0f : ts < 10 ? 40.0f - 10.0f * (ts - 6) : 0.0f;
        y += speed * float(ts - last); last = ts;
        float jitter = (ts >= 10 && (int(ts * 60) % 7 == 0)) ? 0.0006f : 0.0f;   // idle twitch while stopped
        float p[3] = {1000.0f + jitter, y, 71.0f}; std::memcpy(cam + 0x54, p, 12);
        float view[3];
        for (int k = 0; k < 4; ++k) {
            if (k == 1) Sleep(7);
            std::memcpy(frame + 0x80 - 0x38, &p[0], 4);
            ((Thunk)th)(cam, frame + 0x80, 0.0f, p[1]);
            std::memcpy(view, frame + 0x80 - 0x38, 12);
            if (ts > 1.0 && ts < 10.0 && view[1] - p[1] < minFwdFast) minFwdFast = view[1] - p[1];
            if (ts > 10.0) { float fw = view[1] - p[1]; if (prevFw >= 0 && std::fabs(fw - prevFw) > maxStep) maxStep = std::fabs(fw - prevFw); prevFw = fw; }
        }
        if (ts >= nextPrint) { std::printf("t=%5.2f s  speed %5.1f m/s  forward %+.3f  down %+.3f  rider near %.3f\n", ts, speed, view[1] - p[1], view[2] - p[2], *(float*)(cave + 0x90)); nextPrint += (ts > 10.8 && ts < 11.9) ? 0.1 : 0.5; }
    }
    std::printf("teleport resets: %d; smallest forward between 1 s and 10 s: %+.3f; largest step while stopped: %.4f m\n", tel(), minFwdFast, maxStep);
    ExitProcess(0);
}
