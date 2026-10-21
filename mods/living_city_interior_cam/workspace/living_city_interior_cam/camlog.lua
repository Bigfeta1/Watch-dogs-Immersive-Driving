-- living_city_interior_cam: camera logger (debug only, see InteriorCam_CONFIG.txt)
-- Samples once per game tick (self-rescheduling SH_NextTick chain), in a vehicle or on foot.
local CONFIG_PATH = "../data_win64/mods/living_city_interior_cam/InteriorCam_CONFIG.txt"
local LOG_PATH = "../data_win64/mods/living_city_interior_cam/camera_log.csv"
local HEAD_LOG_PATH = "../data_win64/mods/living_city_interior_cam/head_log.csv"

local script = Script("LivingCityInteriorCamLog")

function script:OnLoad()
  InteriorCam_Config = { Log = 0 }
  local file = loadfile(CONFIG_PATH)
  if file ~= nil then
    pcall(file)
  end
  self.enabled = InteriorCam_Config.Log == 1
  self.log = nil
  self.lines = 0
  self.ticks = 0
  self.ticks_seen = -1
  self.head_enabled = InteriorCam_Config.HeadLog == 1
  SH_LOG("[living_city_interior_cam] camera log " .. (self.enabled and "enabled" or "disabled") .. ", head log " .. (self.head_enabled and "enabled" or "disabled"))
end

function script:WriteSample()
  local player = GetLocalPlayerEntityId()
  if player == nil then return end
  local cam = SH_Camera_GetEntityId()
  if cam == nil then return end
  local seat = GetCurrentSeat(player) or 0
  --reference: the vehicle when seated, the player otherwise.
  local ref = player
  if seat ~= 0 then
    ref = GetCurrentVehicleEntityId(player) or player
  end
  local rx, ry, rz = GetEntityPosition(ref, 0), GetEntityPosition(ref, 1), GetEntityPosition(ref, 2)
  local cx, cy, cz = GetEntityPosition(cam, 0), GetEntityPosition(cam, 1), GetEntityPosition(cam, 2)
  if rx == nil or cx == nil then return end
  --camera offset in reference space (x right, y forward, z up), using reference yaw only.
  local yaw = math.rad(GetEntityAngle(ref, 2) or 0)
  local dx, dy, dz = cx-rx, cy-ry, cz-rz
  local lx = dx*math.cos(yaw) + dy*math.sin(yaw)
  local ly = -dx*math.sin(yaw) + dy*math.cos(yaw)
  if self.log == nil then
    self.log = io.open(LOG_PATH, "w")
    if self.log == nil then
      self.enabled = false
      SH_LOG("[living_city_interior_cam] cannot write " .. LOG_PATH)
      return
    end
    self.log:write("tick,time,seat,ref,local_x,local_y,local_z,cam_a0,cam_a1,cam_a2,ref_a0,ref_a1,ref_a2,speed_kmh\n")
  end
  --one call per line, so an error line points at the exact call.
  --no "%d": the game's Lua failed on it ("attempt to call a number value"); "%.0f" instead.
  local time = GetGameTime() or 0
  local name = GetEntityName(ref) or ""
  local c0 = GetEntityAngle(cam, 0) or 0
  local c1 = GetEntityAngle(cam, 1) or 0
  local c2 = GetEntityAngle(cam, 2) or 0
  local r0 = GetEntityAngle(ref, 0) or 0
  local r1 = GetEntityAngle(ref, 1) or 0
  local r2 = GetEntityAngle(ref, 2) or 0
  --same call and unit (km/h) as Living_City's speedometer.
  local speed = 0
  if seat ~= 0 then
    speed = GetVehicleSpeed(player) or 0
  end
  --No GetEntityBonePosition here: calling it every tick crashed the game while loading.
  local row = string.format("%.0f,%.4f,%.0f,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.1f\n", self.ticks, time, seat, name, lx, ly, dz, c0, c1, c2, r0, r1, r2, speed)
  self.log:write(row)
  self.lines = self.lines + 1
  if self.lines % 120 == 0 then
    self.log:flush()
  end
end

function script:Schedule()
  self.pending = true
  self.stalled = 0
  SH_NextTick(function() self:Tick() end)
end

function script:Tick()
  self.pending = false
  if not self.enabled then return end
  self.ticks = self.ticks + 1
  local ok, err = pcall(self.WriteSample, self)
  if not ok then
    self.enabled = false
    SH_LOG("[living_city_interior_cam] camera log stopped: " .. tostring(err))
    return
  end
  self:Schedule()
end

--Head bone sampler (InteriorCam_Config.HeadLog = 1): ~2 per second from OnUpdate, only while seated on
--a bike for 3 s, never while loading (GetEntityBonePosition every tick from game start crashed it).
--Raw world values written as text, no arithmetic on them.
function script:HeadSample()
  local player = GetLocalPlayerEntityId()
  if player == nil or (GetCurrentSeat(player) or 0) == 0 then
    self.bike_since = nil
    return
  end
  local bike = GetCurrentVehicleEntityId(player)
  if bike == nil or string.find(GetEntityName(bike) or "", "Vehicle_Bike", 1, true) == nil then
    self.bike_since = nil
    return
  end
  local now = GetGameTime() or 0
  if self.bike_since == nil then self.bike_since = now end
  if now - self.bike_since < 3 then return end
  local cam = SH_Camera_GetEntityId()
  if cam == nil then return end
  if self.head_log == nil then
    self.head_log = io.open(HEAD_LOG_PATH, "w")
    if self.head_log == nil then
      self.head_enabled = false
      return
    end
    self.head_log:write("time,speed_kmh,head_x,head_y,head_z,cam_x,cam_y,cam_z,cam_a0,cam_a1,cam_a2,bike_x,bike_y,bike_z,bike_a0,bike_a1,bike_a2\n")
  end
  local v = {
    now, GetVehicleSpeed(player),
    GetEntityBonePosition(player, "Head", 0, 0), GetEntityBonePosition(player, "Head", 1, 0), GetEntityBonePosition(player, "Head", 2, 0),
    GetEntityPosition(cam, 0), GetEntityPosition(cam, 1), GetEntityPosition(cam, 2),
    GetEntityAngle(cam, 0), GetEntityAngle(cam, 1), GetEntityAngle(cam, 2),
    GetEntityPosition(bike, 0), GetEntityPosition(bike, 1), GetEntityPosition(bike, 2),
    GetEntityAngle(bike, 0), GetEntityAngle(bike, 1), GetEntityAngle(bike, 2),
  }
  local parts = {}
  for i = 1, 17 do parts[i] = tostring(v[i]) end
  self.head_log:write(table.concat(parts, ",") .. "\n")
  self.head_log:flush()
end

function script:OnUpdate()
  if self.head_enabled then
    local ok, err = pcall(self.HeadSample, self)
    if not ok then
      self.head_enabled = false
      SH_LOG("[living_city_interior_cam] head log stopped: " .. tostring(err))
    end
  end
  if not self.enabled then return end
  --start the per tick chain; restart it only if a scheduled tick never ran (10 updates).
  if not self.pending then
    self:Schedule()
  elseif self.ticks == self.ticks_seen then
    self.stalled = self.stalled + 1
    if self.stalled >= 10 then
      self:Schedule()
    end
  else
    self.stalled = 0
  end
  self.ticks_seen = self.ticks
end

function script:OnUnload()
  self.enabled = false
  self.head_enabled = false
  if self.head_log ~= nil then
    self.head_log:close()
    self.head_log = nil
  end
  if self.log ~= nil then
    self.log:close()
    self.log = nil
  end
end
