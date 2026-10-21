// NearClipFix.asi for the Steam Watch_Dogs build 238247912 (Disrupt_b64.dll). Two patches in the camera
// update (RVA 0x2A1150; Nexus Tools hooks its entry, these sites are further in):
//
// 1. Near plane. Verified 2026-10-20: CCameraGameRenderingComponent +0x70 is the near plane the game renders
//    with (2.0 m hid the bike and rider; 0.05 m removed the car roof cut, no distant flicker). The update
//    ends with a copy of near/far into the render view:
//      2A1202  8B 47 70   mov eax,[rdi+70h]     ; camera near
//      2A1205  89 46 24   mov [rsi+24h],eax     ; view near
//      2A1208  8B 47 74   mov eax,[rdi+74h]     ; camera far
//      2A120B  89 46 28   mov [rsi+28h],eax     ; view far
//    Those 12 bytes jump to a cave that stores the near to use into [rdi+70h]: the configured near, or on the
//    rider view (FOV marker) looking HideAbove degrees or more up, HideNear (default 1 m), so the rider's own
//    head and body are not drawn; otherwise on the rider view the near riderAdjust blended with the tuck
//    ([RiderTuck] Near while moving, held and released like the tuck).
//
// 2. Rider view position. The update copies the camera position (+54/58/5C, world, z up) and rotation
//    (+60 pitch in radians, up positive) to the stack (x,y,z at [rax-38h]) before building the view:
//      2A118C  F3 0F 10 41 5C   movss xmm0,[rcx+5Ch]   ; z
//      2A1191  F3 0F 11 48 CC   movss [rax-34h],xmm1   ; store y
//    The cave stores y and z, calls riderAdjust (C, below) and reloads z. On the rider view (camera FOV +6C
//    equals the marker set in cameracontext.lib, vectorFov of the two bike interior cameras) riderAdjust
//    moves the stack copy: a lift with pitch ([RiderLift]) and a tuck with speed ([RiderTuck]: forward along
//    the direction of travel and down; reached with speed, held until stopped for Hold seconds). Only the
//    copy passed to the view changes; the stored camera position does not.
//
// NearClipFix.ini is re-read every 0.5 s (live tuning). Nothing is patched unless the build marker and the
// exact original bytes match.
#include <windows.h>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <cstdarg>
#include <cmath>

static const uint32_t kBuildMarker = 238247912;   // signed 32 bit value at module RVA 0x100C
static const uintptr_t kMarkerRva = 0x100C;
static const uintptr_t kPatchRva = 0x2A1202;
static const unsigned char kOriginal[12] = {0x8B,0x47,0x70, 0x89,0x46,0x24, 0x8B,0x47,0x74, 0x89,0x46,0x28};
static const uintptr_t kLiftRva = 0x2A118C;
static const unsigned char kLiftOriginal[10] = {0xF3,0x0F,0x10,0x41,0x5C, 0xF3,0x0F,0x11,0x48,0xCC};
static const float kDegToRad = 0.017453292f;

// Cave layout (one page): near code at 0x00 (must end before kNearSlot), near data 0x80.., rider code 0x100.
enum : size_t { kNearSlot = 0x80, kHideNear = 0x84, kHideAbove = 0x88, kMarkBits = 0x8C, kRiderNear = 0x90,
                kRiderCode = 0x100 };

struct Config {
    float nearPlane, fovMark, startDeg, fullDeg, shift, hideAbove, hideNear;
    float tuckForward, tuckDown, tuckStart, tuckFull, tuckHold, tuckReturn, tuckNear, tuckHide, tuckHideNear, debug;
};

static wchar_t g_dir[MAX_PATH];
static FILE* g_log;
static Config g_cfg;   // written by the worker thread, read by riderAdjust (a torn read mixes two settings for one frame)
static volatile float* g_riderNear;   // cave slot read by the near cave on the rider view

static void logf(const char* fmt, ...) {
    if (!g_log) return;
    SYSTEMTIME t; GetLocalTime(&t);
    std::fprintf(g_log, "%02d:%02d:%02d.%03d ", t.wHour, t.wMinute, t.wSecond, t.wMilliseconds);
    va_list a; va_start(a, fmt); std::vfprintf(g_log, fmt, a); va_end(a);
    std::fputc('\n', g_log); std::fflush(g_log);
}

static bool readable(uintptr_t a, size_t n) {
    MEMORY_BASIC_INFORMATION mi{};
    if (VirtualQuery(reinterpret_cast<void*>(a), &mi, sizeof(mi)) != sizeof(mi)) return false;
    if (mi.State != MEM_COMMIT || (mi.Protect & (PAGE_GUARD | PAGE_NOACCESS))) return false;
    return a + n <= reinterpret_cast<uintptr_t>(mi.BaseAddress) + mi.RegionSize;
}

// Executable page within +-2 GB of `target` so rel32 jumps reach both ways.
static unsigned char* allocNear(uintptr_t target) {
    SYSTEM_INFO si; GetSystemInfo(&si);
    const uintptr_t gran = si.dwAllocationGranularity, range = 0x7FF00000;
    uintptr_t lo = target > range ? target - range : gran;
    for (uintptr_t a = (target & ~(gran - 1)) - gran; a > lo; a -= gran) {
        MEMORY_BASIC_INFORMATION mi{};
        if (VirtualQuery(reinterpret_cast<void*>(a), &mi, sizeof(mi)) != sizeof(mi)) continue;
        if (mi.State != MEM_FREE) continue;
        void* p = VirtualAlloc(reinterpret_cast<void*>(a), 4096, MEM_RESERVE | MEM_COMMIT, PAGE_EXECUTE_READWRITE);
        if (p) return static_cast<unsigned char*>(p);
    }
    for (uintptr_t a = (target & ~(gran - 1)) + gran; a < target + range; a += gran) {
        MEMORY_BASIC_INFORMATION mi{};
        if (VirtualQuery(reinterpret_cast<void*>(a), &mi, sizeof(mi)) != sizeof(mi)) continue;
        if (mi.State != MEM_FREE) continue;
        void* p = VirtualAlloc(reinterpret_cast<void*>(a), 4096, MEM_RESERVE | MEM_COMMIT, PAGE_EXECUTE_READWRITE);
        if (p) return static_cast<unsigned char*>(p);
    }
    return nullptr;
}

static int32_t rel32(uintptr_t from_next, uintptr_t to) { return static_cast<int32_t>(static_cast<intptr_t>(to - from_next)); }

static float iniFloat(const wchar_t* ini, const wchar_t* sec, const wchar_t* key, const wchar_t* def,
                      float lo, float hi, float fallback) {
    wchar_t buf[64];
    GetPrivateProfileStringW(sec, key, def, buf, 64, ini);
    float v = static_cast<float>(std::wcstod(buf, nullptr));
    if (!(v >= lo && v <= hi)) {
        static wchar_t lastBad[64];
        if (std::wcscmp(lastBad, buf)) { logf("%ls=%ls out of range %.2f..%.2f; using %.2f", key, buf, lo, hi, fallback); std::wcscpy(lastBad, buf); }
        v = fallback;
    }
    return v;
}

static Config readConfig() {
    wchar_t ini[MAX_PATH];
    std::swprintf(ini, MAX_PATH, L"%lsNearClipFix.ini", g_dir);
    Config c;
    c.nearPlane = iniFloat(ini, L"NearClip", L"Near", L"0.05", 0.01f, 0.25f, 0.05f);
    c.fovMark = iniFloat(ini, L"RiderLift", L"MarkerFov", L"75.5", 1.0f, 170.0f, 75.5f);
    c.startDeg = iniFloat(ini, L"RiderLift", L"Start", L"10", 0.0f, 89.0f, 10.0f);
    c.fullDeg = iniFloat(ini, L"RiderLift", L"Full", L"80", 1.0f, 90.0f, 80.0f);
    c.shift = iniFloat(ini, L"RiderLift", L"Shift", L"0", 0.0f, 1.0f, 0.0f);
    c.hideAbove = iniFloat(ini, L"RiderLift", L"HideAbove", L"13.5", 0.0f, 90.0f, 13.5f);
    c.hideNear = iniFloat(ini, L"RiderLift", L"HideNear", L"1.0", 0.01f, 5.0f, 1.0f);
    if (c.fullDeg <= c.startDeg + 1.0f) c.fullDeg = c.startDeg + 1.0f;
    c.tuckForward = iniFloat(ini, L"RiderTuck", L"Forward", L"0.09", -0.5f, 0.5f, 0.09f);
    c.tuckDown = iniFloat(ini, L"RiderTuck", L"Down", L"0.09", -0.5f, 0.5f, 0.09f);
    c.tuckStart = iniFloat(ini, L"RiderTuck", L"StartSpeed", L"3", 0.0f, 60.0f, 3.0f);
    c.tuckFull = iniFloat(ini, L"RiderTuck", L"FullSpeed", L"10", 0.1f, 80.0f, 10.0f);
    c.tuckHold = iniFloat(ini, L"RiderTuck", L"Hold", L"2", 0.0f, 30.0f, 2.0f);
    c.tuckReturn = iniFloat(ini, L"RiderTuck", L"Return", L"0.6", 0.05f, 10.0f, 0.6f);
    c.tuckNear = iniFloat(ini, L"RiderTuck", L"Near", L"0.25", 0.01f, 2.0f, 0.25f);
    if (c.tuckFull <= c.tuckStart + 0.1f) c.tuckFull = c.tuckStart + 0.1f;
    c.debug = iniFloat(ini, L"RiderTuck", L"Debug", L"0", 0.0f, 1.0f, 0.0f);
    c.tuckHide = iniFloat(ini, L"RiderTuck", L"HideWhenTucked", L"0", 0.0f, 1.0f, 0.0f);
    c.tuckHideNear = iniFloat(ini, L"RiderTuck", L"TuckHideNear", L"0.35", 0.01f, 2.0f, 0.35f);
    return c;
}

static void applyNear(unsigned char* cave, const Config& c) {
    auto put = [&](size_t off, float v) { *reinterpret_cast<volatile float*>(cave + off) = v; };
    put(kNearSlot, c.nearPlane);
    put(kMarkBits, c.fovMark * kDegToRad);   // compared as integer bits (+-64 ulp) in the near cave
    put(kHideAbove, c.hideAbove * kDegToRad); // compared as signed integer bits: valid for a positive threshold
    put(kHideNear, c.hideNear);
    put(kRiderNear, c.nearPlane);   // riderAdjust overwrites it each update on the rider view
}

// --- rider view position (called from the cave at 2A118C) ---
struct RiderState {
    const unsigned char* cam; double t, tMove, tAnim; float px, py, speed, dx, dy, f, still; bool haveDir; int teleports;
};
static RiderState g_rider;

// Debug trace (Debug=1): one record per rider update, filled on the game thread, written by the worker.
struct Trace { double t; float dt, raw, speed, f, still, dx, dy, x, y; int kind; };   // kind 0 moved, 1 skip, 2 teleport, 3 first, 4 still
static Trace g_trace[8192];
static volatile LONG g_traceHead;
static void trace(double t, float dt, float raw, const RiderState& s, float x, float y, int kind) {
    if (g_cfg.debug < 0.5f) return;
    LONG i = InterlockedIncrement(&g_traceHead) - 1;
    g_trace[i & 8191] = Trace{t, dt, raw, s.speed, s.f, s.still, s.dx, s.dy, x, y, kind};
}

static float clamp01(float v) { return v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v); }

// One camera update at time `now` (seconds). `view` = the stack copy x,y,z passed to the view.
static void riderStep(const unsigned char* cam, float* view, double now) {
    const Config c = g_cfg;
    RiderState& s = g_rider;
    float fov; std::memcpy(&fov, cam + 0x6C, 4);
    if (std::fabs(fov - c.fovMark * kDegToRad) > 0.0005f) {   // not the rider view: forget the tuck
        s.f = 0.0f; s.still = 0.0f; s.cam = nullptr;
        return;
    }
    float pos[3], pitch;
    std::memcpy(pos, cam + 0x54, 12); std::memcpy(&pitch, cam + 0x60, 4);
    // The update runs several times per frame but the position changes once per frame (debug trace
    // 2026-10-21: per-call speed swung 0..79 m/s at 30 m/s and tripped the old 80 m/s teleport reset ->
    // stutter). Speed = distance / time since the position last changed; stopped = no change for 0.1 s.
    auto feed = [&](float raw, float dt) {   // speed sample
        const float a = dt < 0.15f ? dt / 0.15f : 1.0f;   // ~0.15 s smoothing
        s.speed += (raw - s.speed) * a;
    };
    if (s.cam != cam || s.t == 0.0) {
        s.cam = cam; s.t = s.tMove = s.tAnim = now; s.px = pos[0]; s.py = pos[1]; s.speed = 0.0f;
        trace(now, 0, 0, s, pos[0], pos[1], 3);
    } else {
        const float mx = pos[0] - s.px, my = pos[1] - s.py, dist = std::sqrt(mx * mx + my * my);
        if (dist > 5.0f) {   // teleport / respawn
            s.speed = 0.0f; s.f = 0.0f; s.still = 0.0f; s.haveDir = false; ++s.teleports;
            s.px = pos[0]; s.py = pos[1]; s.t = s.tMove = now;
            trace(now, 0, dist, s, pos[0], pos[1], 2);
        } else if (dist > 1e-4f && now - s.tMove >= 0.004) {   // moved since the last change
            const float dtMove = static_cast<float>(now - s.tMove), raw = dist / dtMove;
            if (raw > 1.0f) {   // direction of travel, kept while stopped
                const float a = dtMove < 0.15f ? dtMove / 0.15f : 1.0f;
                if (!s.haveDir) { s.dx = mx / dist; s.dy = my / dist; s.haveDir = true; }
                else {
                    s.dx += (mx / dist - s.dx) * a; s.dy += (my / dist - s.dy) * a;
                    const float n = std::sqrt(s.dx * s.dx + s.dy * s.dy);
                    if (n > 1e-4f) { s.dx /= n; s.dy /= n; }
                }
            }
            feed(raw, static_cast<float>(now - s.t));
            s.t = s.tMove = now; s.px = pos[0]; s.py = pos[1];
            trace(now, dtMove, raw, s, pos[0], pos[1], 0);
        } else if (now - s.tMove > 0.1 && now - s.t >= 0.005) {   // no movement for 0.1 s: standing
            feed(0.0f, static_cast<float>(now - s.t));
            s.t = now;
            trace(now, static_cast<float>(now - s.tMove), 0, s, pos[0], pos[1], 4);
        } else trace(now, static_cast<float>(now - s.t), 0, s, pos[0], pos[1], 1);
        // Hold / ease back: advanced on every update by the real time, so the return is continuous (v0.37:
        // it used to advance only on speed samples and stalled while idle jitter reset the 0.1 s still timer).
        const float dtA = static_cast<float>(now - s.tAnim);
        if (dtA >= 0.001f) {
            s.tAnim = now;
            const float target = clamp01((s.speed - c.tuckStart) / (c.tuckFull - c.tuckStart));
            if (target >= s.f) { s.f = target; s.still = 0.0f; }              // speeding up: follow speed
            else if (s.speed < 0.3f) {                                           // stopped: wait, then ease back
                s.still += dtA < 0.1f ? dtA : 0.1f;   // a pause does not count as waiting
                if (s.still > c.tuckHold) { s.f -= (dtA < 0.1f ? dtA : 0.1f) / c.tuckReturn; if (s.f < target) s.f = target; }
            } else s.still = 0.0f;                                               // slowing but moving: hold
        }
    }
    // Fully tucked (incl. the hold after stopping) with HideWhenTucked=1: near = TuckHideNear, short enough to
    // cut the rider's head/shoulders but not the bike (HideNear 1 m also cut the bike, which is in view when
    // looking ahead); the body returns as soon as the camera starts easing back.
    if (g_riderNear) *g_riderNear = (c.tuckHide >= 0.5f && s.f >= 0.999f) ? c.tuckHideNear
                                                                         : c.nearPlane + (c.tuckNear - c.nearPlane) * s.f;
    if (s.haveDir && s.f > 0.0f) {
        view[0] += s.dx * c.tuckForward * s.f;
        view[1] += s.dy * c.tuckForward * s.f;
        view[2] -= c.tuckDown * s.f;
    }
    if (c.shift > 0.0f) {   // lift with pitch: 0 below Start, Shift at Full
        const float startR = c.startDeg * kDegToRad, fullR = c.fullDeg * kDegToRad;
        view[2] += c.shift * clamp01((pitch - startR) / (fullR - startR));
    }
}

static double g_qpcScale;
extern "C" void riderAdjust(const unsigned char* cam, unsigned char* frame) {
    LARGE_INTEGER q; QueryPerformanceCounter(&q);
    riderStep(cam, reinterpret_cast<float*>(frame - 0x38), static_cast<double>(q.QuadPart) * g_qpcScale);
}

static bool patch(uintptr_t site, const unsigned char* bytes, size_t n) {
    DWORD old;
    if (!VirtualProtect(reinterpret_cast<void*>(site), n, PAGE_EXECUTE_READWRITE, &old)) return false;
    // Tail first, then the jmp, so a thread mid-sequence never runs a half-written jump.
    std::memcpy(reinterpret_cast<void*>(site + 5), bytes + 5, n - 5);
    std::memcpy(reinterpret_cast<void*>(site), bytes, 5);
    VirtualProtect(reinterpret_cast<void*>(site), n, old, &old);
    FlushInstructionCache(GetCurrentProcess(), reinterpret_cast<void*>(site), n);
    return true;
}

// Writes both caves into `cave`; `base` is the Disrupt_b64.dll base. False if the near code would overlap
// its data (v0.35 bug: the code grew into the near slot and the game read code bytes as the near plane).
static bool buildCaves(unsigned char* cave, uintptr_t base, const Config& cfg) {
    const uintptr_t site = base + kPatchRva, back = site + sizeof(kOriginal);
    // --- near plane cave (0x00); eax and flags are free (the original copy overwrites eax) ---
    // The near values live in the cave's data slots so the ini can be re-read while the game runs.
    applyNear(cave, cfg);
    g_riderNear = reinterpret_cast<volatile float*>(cave + kRiderNear);
    auto ripGpr = [&](unsigned char* c, unsigned char op, size_t dataOff) {   // op eax,[rip+data]
        *c++ = op; *c++ = 0x05;
        int32_t d = rel32(reinterpret_cast<uintptr_t>(c) + 4, reinterpret_cast<uintptr_t>(cave + dataOff));
        std::memcpy(c, &d, 4); return c + 4;
    };
    unsigned char* c = cave;
    *c++ = 0x8B; *c++ = 0x47; *c++ = 0x6C;                                     // mov eax,[rdi+6Ch] (fov)
    c = ripGpr(c, 0x2B, kMarkBits);                                            // sub eax,[markbits]
    *c++ = 0x83; *c++ = 0xC0; *c++ = 0x40;                                     // add eax,64
    *c++ = 0x3D; { uint32_t k = 128; std::memcpy(c, &k, 4); c += 4; }          // cmp eax,128
    *c++ = 0x77; unsigned char* toNormal1 = c++;                               // ja normal (not rider view)
    *c++ = 0x8B; *c++ = 0x47; *c++ = 0x60;                                     // mov eax,[rdi+60h] (pitch)
    c = ripGpr(c, 0x3B, kHideAbove);                                           // cmp eax,[hideabove]
    *c++ = 0x7C; unsigned char* toRider = c++;                                 // jl rider
    c = ripGpr(c, 0x8B, kHideNear);                                            // mov eax,[hidenear]
    *c++ = 0xEB; unsigned char* toStore1 = c++;                                // jmp store
    *toRider = static_cast<unsigned char>(c - (toRider + 1));
    c = ripGpr(c, 0x8B, kRiderNear);                                           // rider: mov eax,[ridernear]
    *c++ = 0xEB; unsigned char* toStore2 = c++;                                // jmp store
    *toNormal1 = static_cast<unsigned char>(c - (toNormal1 + 1));
    c = ripGpr(c, 0x8B, kNearSlot);                                            // normal: mov eax,[slot]
    *toStore1 = static_cast<unsigned char>(c - (toStore1 + 1));
    *toStore2 = static_cast<unsigned char>(c - (toStore2 + 1));
    *c++ = 0x89; *c++ = 0x47; *c++ = 0x70;                                     // store: mov [rdi+70h], eax
    int32_t r;
    std::memcpy(c, kOriginal, sizeof(kOriginal)); c += sizeof(kOriginal);      // original near/far copy
    *c++ = 0xE9; r = rel32(reinterpret_cast<uintptr_t>(c) + 4, back); std::memcpy(c, &r, 4); c += 4;
    if (c > cave + kNearSlot) { logf("near cave code ends at +0x%llx, past its data at +0x%llx; NOT patched",
                                     (unsigned long long)(c - cave), (unsigned long long)kNearSlot); return false; }
    applyNear(cave, cfg);   // again: nothing may have overwritten the data

    // --- rider cave (0x100). rsp is 16-aligned here (the function calls 0xA6E3C0 with the same rsp), so
    //     3 pushes + 0x28 keep the call aligned with shadow space. Live afterwards: rax, rcx, rdx, z (xmm0,
    //     reloaded from the stack copy); y is stored first and xmm1 is reloaded by the game at 2A1196.
    const uintptr_t riderSite = base + kLiftRva, riderBack = riderSite + sizeof(kLiftOriginal);
    c = cave + kRiderCode;
    std::memcpy(c, kLiftOriginal, sizeof(kLiftOriginal)); c += sizeof(kLiftOriginal);   // z -> xmm0; store y
    const unsigned char pre[] = {0xF3,0x0F,0x11,0x40,0xD0,                     // movss [rax-30h],xmm0 (z)
                                 0x50, 0x51, 0x52,                              // push rax, rcx, rdx
                                 0x48,0x83,0xEC,0x28,                           // sub rsp,28h
                                 0x48,0x89,0xC2,                                // mov rdx,rax (frame)
                                 0x48,0xB8};                                    // mov rax, imm64
    std::memcpy(c, pre, sizeof(pre)); c += sizeof(pre);
    uint64_t fn = reinterpret_cast<uint64_t>(&riderAdjust); std::memcpy(c, &fn, 8); c += 8;
    const unsigned char post[] = {0xFF,0xD0,                                   // call rax
                                  0x48,0x83,0xC4,0x28,                          // add rsp,28h
                                  0x5A, 0x59, 0x58,                             // pop rdx, rcx, rax
                                  0xF3,0x0F,0x10,0x40,0xD0};                    // movss xmm0,[rax-30h]
    std::memcpy(c, post, sizeof(post)); c += sizeof(post);
    *c++ = 0xE9; r = rel32(reinterpret_cast<uintptr_t>(c) + 4, riderBack); std::memcpy(c, &r, 4); c += 4;
    if (c > cave + 4096) { logf("rider cave too long; NOT patched"); return false; }
    FlushInstructionCache(GetCurrentProcess(), cave, 4096);
    return true;
}

#ifdef NEARCLIP_TEST
extern "C" __declspec(dllexport) int TestBuildCaves(unsigned char* cave, uintptr_t base) { g_cfg = readConfig(); return buildCaves(cave, base, g_cfg); }
extern "C" __declspec(dllexport) void TestRiderStep(const unsigned char* cam, float* view, double now) { riderStep(cam, view, now); }
extern "C" __declspec(dllexport) void* TestRiderAdjust() { return reinterpret_cast<void*>(&riderAdjust); }
extern "C" __declspec(dllexport) int TestTeleports() { return g_rider.teleports; }
#endif

static DWORD WINAPI worker(void*) {
    Config cfg = readConfig();
    g_cfg = cfg;
    logf("NearClipFix loaded; near=%.4f m; rider hidden (near %.2f) from %.1f deg; lift %.3f m %.1f-%.1f deg; "
         "tuck fwd %.3f down %.3f near %.3f at %.1f-%.1f m/s, hold %.1f s, return %.2f s; FOV marker %.2f",
         cfg.nearPlane, cfg.hideNear, cfg.hideAbove, cfg.shift, cfg.startDeg, cfg.fullDeg, cfg.tuckForward,
         cfg.tuckDown, cfg.tuckNear, cfg.tuckStart, cfg.tuckFull, cfg.tuckHold, cfg.tuckReturn, cfg.fovMark);
    // Disrupt_b64.dll is packed on disk: wait until it is loaded and its code is unpacked.
    uintptr_t base = 0;
    bool mismatchLogged = false;
    for (int i = 0; i < 1200; ++i) {   // up to 120 s
        base = reinterpret_cast<uintptr_t>(GetModuleHandleW(L"Disrupt_b64.dll"));
        if (base && readable(base + kMarkerRva, 4) && readable(base + kPatchRva, sizeof(kOriginal)) &&
            readable(base + kLiftRva, sizeof(kLiftOriginal))) {
            int32_t marker; std::memcpy(&marker, reinterpret_cast<void*>(base + kMarkerRva), 4);
            if (marker == static_cast<int32_t>(kBuildMarker) &&
                !std::memcmp(reinterpret_cast<void*>(base + kPatchRva), kOriginal, sizeof(kOriginal)) &&
                !std::memcmp(reinterpret_cast<void*>(base + kLiftRva), kLiftOriginal, sizeof(kLiftOriginal))) break;
            if (!mismatchLogged && marker != static_cast<int32_t>(kBuildMarker)) {
                logf("Build marker %d (want %u) at i=%d; still waiting", marker, kBuildMarker, i);
                mismatchLogged = true;
            }
        }
        base = 0;
        Sleep(100);
    }
    if (!base) { logf("Disrupt_b64.dll not found, wrong build, or code at 0x2A1202/0x2A118C differs; NOT patched"); return 0; }

    const uintptr_t site = base + kPatchRva;
    unsigned char* cave = allocNear(site);
    if (!cave) { logf("No executable memory within 2 GB; NOT patched"); return 0; }

    if (!buildCaves(cave, base, cfg)) return 0;
    const uintptr_t riderSite = base + kLiftRva;
    int32_t r;
    unsigned char p1[12];
    p1[0] = 0xE9; r = rel32(site + 5, reinterpret_cast<uintptr_t>(cave)); std::memcpy(p1 + 1, &r, 4);
    std::memset(p1 + 5, 0x90, sizeof(p1) - 5);
    unsigned char p2[10];
    p2[0] = 0xE9; r = rel32(riderSite + 5, reinterpret_cast<uintptr_t>(cave + kRiderCode)); std::memcpy(p2 + 1, &r, 4);
    std::memset(p2 + 5, 0x90, sizeof(p2) - 5);
    if (!patch(site, p1, sizeof(p1))) { logf("VirtualProtect failed (%lu); NOT patched", GetLastError()); return 0; }
    logf("Patched Disrupt_b64.dll+0x%llx (base 0x%llx) -> cave 0x%llx; near now %.4f m",
         (unsigned long long)kPatchRva, (unsigned long long)base, (unsigned long long)(uintptr_t)cave, cfg.nearPlane);
    if (!patch(riderSite, p2, sizeof(p2))) logf("Rider view: VirtualProtect failed (%lu); NOT patched", GetLastError());
    else logf("Patched Disrupt_b64.dll+0x%llx -> cave 0x%llx (rider view)", (unsigned long long)kLiftRva,
              (unsigned long long)(uintptr_t)(cave + kRiderCode));

    // Live tuning: apply edits to NearClipFix.ini within half a second.
    LONG traced = 0;
    FILE* dbg = nullptr;
    for (;;) {
        Sleep(500);
        LONG head = g_traceHead;
        if (head != traced) {
            if (!dbg) {
                wchar_t path[MAX_PATH];
                std::swprintf(path, MAX_PATH, L"%lsNearClipFix_debug.csv", g_dir);
                dbg = _wfopen(path, L"w");
                if (dbg) std::fputs("t,dt,raw,speed,f,still,dx,dy,x,y,kind\n", dbg);
            }
            if (head - traced > 8192) traced = head - 8192;
            for (; dbg && traced != head; ++traced) {
                const Trace& r = g_trace[traced & 8191];
                std::fprintf(dbg, "%.4f,%.4f,%.2f,%.2f,%.3f,%.2f,%.3f,%.3f,%.3f,%.3f,%d\n",
                             r.t, r.dt, r.raw, r.speed, r.f, r.still, r.dx, r.dy, r.x, r.y, r.kind);
            }
            if (dbg) std::fflush(dbg);
        }
        Config n = readConfig();
        if (std::memcmp(&n, &cfg, sizeof(n))) {
            g_cfg = n;
            applyNear(cave, n);
            logf("ini changed: near %.4f; hide (near %.2f) from %.1f deg; lift %.3f m %.1f-%.1f deg; tuck fwd %.3f "
                 "down %.3f near %.3f at %.1f-%.1f m/s, hold %.1f s, return %.2f s; FOV marker %.2f", n.nearPlane,
                 n.hideNear, n.hideAbove, n.shift, n.startDeg, n.fullDeg, n.tuckForward, n.tuckDown, n.tuckNear,
                 n.tuckStart, n.tuckFull, n.tuckHold, n.tuckReturn, n.fovMark);
            cfg = n;
        }
    }
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(inst);
        LARGE_INTEGER f; QueryPerformanceFrequency(&f);
        g_qpcScale = 1.0 / static_cast<double>(f.QuadPart);
        DWORD n = GetModuleFileNameW(inst, g_dir, MAX_PATH);
        while (n && g_dir[n - 1] != L'\\' && g_dir[n - 1] != L'/') --n;
        g_dir[n] = 0;
        wchar_t logPath[MAX_PATH];
        std::swprintf(logPath, MAX_PATH, L"%lsNearClipFix.log", g_dir);
        g_log = _wfopen(logPath, L"w");
        HANDLE t = CreateThread(nullptr, 0, worker, nullptr, 0, nullptr);
        if (t) CloseHandle(t);
    }
    return TRUE;
}
