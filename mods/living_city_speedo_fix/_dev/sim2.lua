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
Globals = { _CUSTOM_SCRIPTS = { _Speedometer = 2, _FuelGauge = tonumber(arg[3]) }, _SPEEDO_FP = { Enabled = 1, Distance = 3.0, Offset_X = -0.95, Offset_Y = 1.5, Offset_Z = -0.54, Gap = 0.07, Profiler_Hide = 1 } }
assert(loadstring(io.open(arg[1]):read("*a")))()
local g = setmetatable({ Reference_Entity="ref", Speedometer_Mapicon="spd", FuelGauge_Mapicon="fuel", Offset_X=0, Offset_Y=-0.5, Offset_Z=1 }, {__index=export})
VIS.spd, VIS.fuel = 1, 1
ent("car").p = {0,0,0}; ent("cam").p = {0.3, 0.8, 1.2}; UnBind("ref"); Bind("car","ref","",1)
local function step(label) IndicatorSetName(0,"spd","52 MPH"); IndicatorSetName(0,"fuel","29%"); g:FP_Update("car"); g:FP_Visibility(); CHANGED = {};  IndicatorSetName(0,"spd","52 MPH"); IndicatorSetName(0,"fuel","29%"); io.write(string.format("[next tick: fuel label changed while visible=%s] ", tostring(CHANGED.fuel ~= nil))); print(string.format("%-28s mode=%s spd=%s fuel=%s", label, tostring(g.FP_Mode), tostring(VIS.spd), tostring(VIS.fuel))) end
step("FP, profiler off")
Globals._CUSTOM_SCRIPTS._Fox_ProfilerOn = 1; step("FP, profiler on")
Globals._CUSTOM_SCRIPTS._Fox_ProfilerOn = 0; step("FP, profiler off again")
Globals._CUSTOM_SCRIPTS._Fox_ProfilerOn = 1; ent("cam").p = {0,-6,3}; step("3P, profiler on")
local x,y,z = world("spd"); print(string.format("  3P marker offset from car: %.2f %.2f %.2f", x, y, z))
