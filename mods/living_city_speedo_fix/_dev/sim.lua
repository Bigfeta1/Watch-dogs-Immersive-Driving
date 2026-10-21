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
Globals = { _SPEEDO_FP = { Enabled = 1, Distance = 3.0, Offset_X = 0.6, Offset_Y = 1.5, Offset_Z = -0.25, Gap = 0.07 } }
local src = io.open(arg[1]):read("*a")
local chunk = assert(loadstring(src)); chunk()
local g = setmetatable({ Reference_Entity="ref", Speedometer_Mapicon="spd", FuelGauge_Mapicon="fuel", Offset_X=0, Offset_Y=-0.5, Offset_Z=1 }, {__index=export})
for _, yaw in ipairs({0, 37, 90, 200, 315}) do
  local r = math.rad(yaw)
  ent("car").p = {100, 50, 70}; ent("car").a = yaw
  -- camera 0.3 right, 0.8 forward, 1.2 up from car origin (car frame)
  ent("cam").p = {100 + 0.3*math.cos(r) - 0.8*math.sin(r), 50 + 0.3*math.sin(r) + 0.8*math.cos(r), 71.2}
  UnBind("ref"); Bind("car", "ref", "", 1)
  for i = 1, 3 do g:FP_Update("car") end
  local cx, cy = ent("cam").p[1], ent("cam").p[2]
  local ex, ey = cx + 0.6*math.cos(r) - 1.5*math.sin(r), cy + 0.6*math.sin(r) + 1.5*math.cos(r)
  local mx, my, mz = world("spd"); local _,_,fz = world("fuel")
  print(string.format("rot=%s yaw=%3d err=%.3f z=%.2f fuel_dz=%.2f places=%d", tostring(ROT), yaw, math.sqrt((mx-ex)^2+(my-ey)^2), mz, mz-fz, g.FP_Places))
end
-- far camera -> back to original placement
ent("cam").p = {100, 44, 73}; g:FP_Update("car")
local mx, my, mz = world("spd"); print("3P mode", g.FP_Mode, string.format("z above car=%.2f", mz-70))
