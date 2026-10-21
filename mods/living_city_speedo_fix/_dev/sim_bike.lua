-- stub world: entities with pos/yaw; Bind(parent, child, _, flag) stores child offset in parent frame (rotating or not)
local ROT = tonumber(arg[2]) == 1
local E = {}
local function ent(id) E[id] = E[id] or {p={0,0,0}, a=0}; return E[id] end
local function world(id)
  local e = ent(id)
  if not e.parent then return e.p[1], e.p[2], e.p[3], e.a end
  local px, py, pz, pa = world(e.parent)
  local r = ROT and math.rad(pa) or 0
  local ox, oy = e.off[1], e.off[2]
  return px + ox*math.cos(r) - oy*math.sin(r), py + ox*math.sin(r) + oy*math.cos(r), pz + e.off[3], ROT and pa or 0
end
function GetEntityPosition(id, i) local x,y,z = world(id); return ({x,y,z})[i+1] end
function GetEntityAngle(id, i) local _,_,_,a = world(id); return i == 2 and a or 0 end
function SetEntityPosition(id, x, y, z) ent(id).p = {x,y,z} end
function SetEntityAngle(id, a, b, c) ent(id).a = c end
function UnBind(id) local x,y,z,a = world(id); local e = ent(id); e.parent = nil; e.p = {x,y,z}; e.a = a end
function Bind(parent, child, _, flag)
  local e = ent(child)
  if flag == 1 then e.off = {0,0,0} else
    local px,py,pz,pa = world(parent); local r = ROT and math.rad(pa) or 0
    local dx, dy = e.p[1]-px, e.p[2]-py
    e.off = { dx*math.cos(r) + dy*math.sin(r), -dx*math.sin(r) + dy*math.cos(r), e.p[3]-pz }
  end
  e.parent = parent
end
function GetLocalPlayerEntityId() return "player" end
function GetCurrentSeat() return 1 end
function SH_Camera_GetEntityId() return "cam" end
local VIS, NAME = {}, {}
function IndicatorSetName(_, id, n) if VIS[id] == 1 and NAME[id] ~= n then CHANGED[id] = (CHANGED[id] or 0) + 1 end NAME[id] = n end
CHANGED = {}
function IndicatorSetIsVisible(_, id, v) VIS[id] = v end
function GetLocalPlayerId() return 0 end
local NAMES = { bike = "Vehicle_Bike.Bike.Bike_03", car = "Vehicle_Agile.Agile.Agile_04" }
function GetEntityName(id) return NAMES[id] end
Globals = { _CUSTOM_SCRIPTS = { _Speedometer = 2, _FuelGauge = 1 }, _SPEEDO_FP = { Enabled = 1, Distance = 3.0, Offset_X = -0.95, Offset_Y = 1.5, Offset_Z = -0.54, Gap = 0.07, Profiler_Hide = 1, Bike_Dash = 1, Bike_X = 0.0, Bike_Y = 0.57, Bike_Z = 0.90, Bike_Gap = 0.03 } }
assert(loadstring(io.open(arg[1]):read("*a")))()
local function localpos(v, id)
  local vx, vy, vz, va = world(v); local x, y, z = world(id); local r = math.rad(va)
  local dx, dy = x-vx, y-vy
  return dx*math.cos(r) + dy*math.sin(r), -dx*math.sin(r) + dy*math.cos(r), z-vz
end
local function setcam(v, lx, ly, lz)
  local vx, vy, vz, va = world(v); local r = math.rad(va)
  ent("cam").p = { vx + lx*math.cos(r) - ly*math.sin(r), vy + lx*math.sin(r) + ly*math.cos(r), vz + lz }
end
for _, case in ipairs({ {"bike", "rider view", 0, 0.07, 1.09}, {"bike", "bike-mounted view", 0, 0.66, 1.38}, {"bike", "rider view again", 0, 0.07, 1.09}, {"car", "car interior", -0.27, -0.35, 1.0} }) do
  local v = case[1]
  ent(v).p = {100, 200, 10}; ent(v).a = 30
  local g = setmetatable({ Reference_Entity="ref", Speedometer_Mapicon="spd", FuelGauge_Mapicon="fuel", Offset_X=0, Offset_Y=-0.5, Offset_Z=1, FP_Mode = 0 }, {__index=export})
  _G.G = _G.G or g
  local gg = (v == "bike") and _G.G or g
  UnBind("ref"); Bind(v, "ref", "", 1)
  setcam(v, case[3], case[4], case[5])
  gg:FP_Update(v)
  local sx, sy, sz = localpos(v, "spd"); local fx, fy, fz = localpos(v, "fuel")
  print(string.format("%-18s cam y %.2f -> speed at (%.2f, %.2f, %.2f) fuel at (%.2f, %.2f, %.2f)", case[2], case[4], sx, sy, sz, fx, fy, fz))
end
