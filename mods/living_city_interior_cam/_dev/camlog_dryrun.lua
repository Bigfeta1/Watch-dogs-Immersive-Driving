local src = io.open(arg[1]):read("*a")
src = src:gsub('"%.%./data_win64/mods/living_city_interior_cam/InteriorCam_CONFIG%.txt"', '"' .. arg[2] .. '"')
src = src:gsub('"%.%./data_win64/mods/living_city_interior_cam/camera_log%.csv"', '"' .. arg[3] .. '"')
local S; local queue = {}; local t = 0; local seat = 1
function Script(name) S = { name = name }; return S end
function SH_LOG(m) print("LOG", m) end
function SH_NextTick(fn) table.insert(queue, fn) end
function GetGameTime() return t end
function GetLocalPlayerEntityId() return "player" end
function GetCurrentSeat() return seat end
function GetCurrentVehicleEntityId() return "car" end
function SH_Camera_GetEntityId() return "cam" end
function GetEntityName(e) return e end
function GetVehicleSpeed() return 42.5 end
local P = { car = {100, 50, 70}, cam = {100, 50.1, 71.3}, player = {99.6, 50, 70.4} }
local A = { car = {0, 0, 90}, cam = {-10, 0, 120}, player = {0, 0, 90} }
function GetEntityPosition(e, i) return P[e][i+1] end
function GetEntityAngle(e, i) return A[e][i+1] end
assert(loadstring(src))()
S:OnLoad()
local function frame(n_updates)  -- one game tick: run queued callbacks once, plus some OnUpdates
  local q = queue; queue = {}
  t = t + 0.022
  for _, fn in ipairs(q) do fn() end
  for i = 1, n_updates do S:OnUpdate() end
end
for i = 1, 5 do frame(1) end           -- updates every tick
for i = 1, 20 do frame(0) end          -- many ticks between updates
seat = 0
for i = 1, 5 do frame(3) end           -- several updates per tick (pause-like)
print('pending callbacks in queue:', #queue)
S:OnUnload()
