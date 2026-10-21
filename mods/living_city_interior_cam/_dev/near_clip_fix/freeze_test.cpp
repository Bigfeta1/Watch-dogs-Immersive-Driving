// Offline check of the bike-mounted -> rider frame hold, through the real rider cave.
#include <windows.h>
#include <cstdio>
#include <cstdint>
#include <cstring>
typedef int (*Build)(unsigned char*, uintptr_t);
typedef void (*Input)(int, int);
typedef void (*Thunk)(unsigned char* cam, unsigned char* frame, float unused, float y);
int main() {
    HMODULE m = LoadLibraryA("NearClipFix_test.asi");
    Build build = (Build)GetProcAddress(m, "TestBuildCaves");
    Input input = (Input)GetProcAddress(m, "TestSetInput");
    unsigned char* base = (unsigned char*)VirtualAlloc(nullptr, 0x300000, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    unsigned char* cave = (unsigned char*)VirtualAlloc(base + 0x400000, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    base[0x2A1196] = 0xC3;
    if (!build(cave, (uintptr_t)base)) { std::puts("build refused"); return 1; }
    // thunk: sub rsp,8; mov rax,rdx; movaps xmm1,xmm3; movss xmm6,[rcx+6Ch]-like setup is the game's; call cave; then
    // copy xmm6 out to [rdx+0x40] so the test sees the FOV the game would use; add rsp,8; ret
    unsigned char* th = cave + 0x800;
    // sub rsp,20h; movdqu [rsp],xmm6; mov [rsp+10h],rdx; mov rax,rdx; movaps xmm1,xmm3; call cave+0x100;
    // mov rdx,[rsp+10h]; movss [rdx+40h],xmm6 (FOV the game would use); movdqu xmm6,[rsp]; add rsp,20h; ret
    unsigned char code[] = {0x48,0x83,0xEC,0x20, 0xF3,0x0F,0x7F,0x34,0x24, 0x48,0x89,0x54,0x24,0x10, 0x48,0x89,0xD0,
                            0x0F,0x28,0xCB, 0xE8,0,0,0,0, 0x48,0x8B,0x54,0x24,0x10, 0xF3,0x0F,0x11,0x72,0x40,
                            0xF3,0x0F,0x6F,0x34,0x24, 0x48,0x83,0xC4,0x20, 0xC3};
    int32_t r = (int32_t)((cave + 0x100) - (th + 25)); std::memcpy(code + 21, &r, 4);
    std::memcpy(th, code, sizeof(code));
    unsigned char cam[0x80] = {}, frame[0x100] = {};
    const float D = 0.017453292f;
    auto setCam = [&](float x, float y, float z, float pitch, float yaw, float fovDeg) {
        float p[3] = {x, y, z}, rot[3] = {pitch, 0, yaw}, f = fovDeg * D;
        std::memcpy(cam + 0x54, p, 12); std::memcpy(cam + 0x60, rot, 12); std::memcpy(cam + 0x6C, &f, 4);
    };
    auto frameRun = [&](const char* what) {
        float x; std::memcpy(&x, cam + 0x54, 4); float y; std::memcpy(&y, cam + 0x58, 4);
        std::memcpy(frame + 0x80 - 0x38, &x, 4);
        float before; std::memcpy(&before, frame + 0x80 - 0x38, 4);
        ((Thunk)th)(cam, frame + 0x80, 0.0f, y);
        float after; std::memcpy(&after, frame + 0x80 - 0x38, 4);
        std::printf("   [x in %.2f, view x before %.2f after %.2f]\n", x, before, after);
        float v[3], rot[3], fovUsed; std::memcpy(v, frame + 0x80 - 0x38, 12); std::memcpy(rot, cam + 0x60, 12);
        std::memcpy(&fovUsed, frame + 0x80 + 0x40, 4);
        std::printf("%-34s rendered pos (%.2f, %.2f, %.2f) pitch %.2f yaw %.2f fov %.1f\n", what, v[0], v[1], v[2], rot[0], rot[2], fovUsed / D);
        Sleep(16);
    };
    input(0, 1);
    for (int i = 0; i < 3; ++i) { setCam(100.0f + 0.01f * i, 200.66f, 71.38f, 0.05f, 1.0f, 85.0f); frameRun("bike-mounted view"); }
    input(1, 1);   // C pressed
    setCam(100.03f, 200.50f, 71.40f, 0.04f, 1.0f, 84.0f); frameRun("game starts 3rd person blend");
    input(0, 1);
    setCam(100.03f, 200.20f, 71.45f, 0.03f, 1.0f, 82.0f); frameRun("game 3rd person blend");
    input(0, 0);   // bike_fp.lua sees the change, sets the rider view
    setCam(100.03f, 200.11f, 71.09f, 0.00f, 1.0f, 75.5f); frameRun("rider view active (FOV marker)");
    setCam(100.03f, 200.11f, 71.09f, 0.00f, 1.0f, 75.5f); frameRun("rider view");
    // a press in another view must not hold anything
    setCam(100.0f, 196.0f, 72.5f, 0.1f, 1.0f, 75.0f); frameRun("3rd person");
    input(1, 0); setCam(100.0f, 196.5f, 72.4f, 0.1f, 1.0f, 76.0f); frameRun("3rd person, C pressed (no hold)");
    input(0, 0); setCam(100.0f, 197.0f, 72.3f, 0.1f, 1.0f, 77.0f); frameRun("game switching");
    ExitProcess(0);
}
