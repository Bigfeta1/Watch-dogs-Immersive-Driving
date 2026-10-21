-- living_city_interior_cam: bike rider first person
-- The vehicle camera key never selects the "Interior" view on bikes. The engine call used by the
-- game's Domino box SetInVehicleCamera (Normal 0, Classic 1, Bumper 2, Interior 3, Hollywood 4)
-- sets it each time the player sits on a bike.
-- v0.46: add the rider view to the game's own bike camera cycle without changing the rest of it. Lua has no
-- keyboard access, so NearClipFix.asi counts camera key presses into bin/NearClipFix_camkey.txt. A press made
-- while the bike-mounted view is showing is followed, 0.3 s later (after the game's own switch), by the rider
-- view; every other press is left to the game. (v0.45 answered every press with rider / Normal itself: it
-- replaced the user's 3rd person camera and the game switched straight back.)
-- v0.49: cars too start in first person (Interior = Living_City's in-car camera) when the player gets in; boats
-- (name contains "Boat") are left alone. The camera key handling below is for bikes only.
local INTERIOR = 3
local KEY_FILE = "NearClipFix_camkey.txt"   -- the game runs from bin/, where the plugin writes it
local VIEW_FILE = "NearClipFix_view.txt"     -- v0.48: tells the plugin when the bike-mounted view shows, so it can
                                             -- hold that frame through the game's switch until the rider view is set
local SWITCH_DELAY_TICKS = 18                -- ~0.3 s fallback
local LEAVE_DISTANCE = 0.03                  -- m: the game's own switch has started once the camera moved this far

local script = Script("LivingCityInteriorCamBike")

local function readKeyCount()
  local f = io.open(KEY_FILE, "r")
  if f == nil then return nil end
  local n = tonumber(f:read("*l") or "")
  f:close()
  return n
end

local lastWritten = nil
local function writeView(v)
  if v == lastWritten then return end
  local f = io.open(VIEW_FILE, "w")
  if f == nil then return end
  f:write(v .. "\n")
  f:close()
  lastWritten = v
end

-- Camera position relative to the bike (x right, y forward, z up), as in camlog.lua.
local function cameraLocal(vehicle)
  local cam = SH_Camera_GetEntityId()
  if cam == nil then return nil end
  local rx, ry, rz = GetEntityPosition(vehicle, 0), GetEntityPosition(vehicle, 1), GetEntityPosition(vehicle, 2)
  local cx, cy, cz = GetEntityPosition(cam, 0), GetEntityPosition(cam, 1), GetEntityPosition(cam, 2)
  if rx == nil or cx == nil then return nil end
  local yaw = math.rad(GetEntityAngle(vehicle, 2) or 0)
  local dx, dy, dz = cx - rx, cy - ry, cz - rz
  return dx * math.cos(yaw) + dy * math.sin(yaw), -dx * math.sin(yaw) + dy * math.cos(yaw), dz
end

-- Which view: bike-mounted (0, 0.66, 1.38), rider eye (0, 0.11, 1.09), 3rd person 1.5 m or more away; nil while blending.
local function classify(lx, ly, dz)
  if lx == nil then return nil end
  local flat = math.sqrt(lx * lx + ly * ly)
  if flat >= 1.5 then return "third" end
  if ly > 0.45 and dz > 1.25 and flat < 1.2 then return "mounted" end
  if ly <= 0.45 and dz > 0.85 and dz <= 1.25 and flat < 0.6 then return "rider" end
  return nil
end

function script:OnLoad()
  self.vehicle = nil
  self.onBike = false
  self.view = nil
  self.keyCount = nil
  self.switchIn = nil
  self.pending = false
  self.ticks = 0
  self.ticks_seen = -1
  self.stalled = 0
  SH_LOG("[living_city_interior_cam] bike first person loaded")
end

function script:SetRider(player, why)
  local ok, err = pcall(SetInVehicleCamera, player, INTERIOR)
  SH_LOG("[living_city_interior_cam] first person view (" .. why .. "): " .. (ok and "ok" or tostring(err)))
end

function script:Check()
  local player = GetLocalPlayerEntityId()
  if player == nil then return end
  local seat = GetCurrentSeat(player) or 0
  if seat == 0 then
    self.vehicle = nil
    self.onBike = false
    writeView("other")
    return
  end
  local vehicle = GetCurrentVehicleEntityId(player)
  if vehicle == nil then return end
  if vehicle ~= self.vehicle then
    self.vehicle = vehicle
    local name = GetEntityName(vehicle) or ""
    self.onBike = string.find(name, "Vehicle_Bike", 1, true) ~= nil
    self.view = nil
    self.switchIn = nil
    writeView("other")
    if not self.onBike then
      if string.find(name, "Boat", 1, true) == nil then self:SetRider(player, name) end
      return
    end
    self.keyCount = readKeyCount()   -- presses before getting on do not count
    self:SetRider(player, name)
    return
  end
  if not self.onBike then return end
  local lx, ly, lz = cameraLocal(vehicle)
  local view = classify(lx, ly, lz)
  local count = readKeyCount()
  if count ~= nil and count ~= self.keyCount then
    local first = self.keyCount == nil
    self.keyCount = count
    if not first then
      -- the view at the moment of the press (the last settled one): only the bike-mounted view leads to the rider view
      if self.view == "mounted" and lx ~= nil then
        self.switchIn = SWITCH_DELAY_TICKS
        self.pressPos = {lx, ly, lz}
      else
        self.switchIn = nil
      end
      SH_LOG("[living_city_interior_cam] bike camera key in view " .. tostring(self.view))
    end
  elseif view ~= nil then
    self.view = view
    writeView(view == "mounted" and "mounted" or "other")
  end
  if self.switchIn ~= nil then
    -- switch as soon as the game's own switch has moved the camera off the bike-mounted spot (v0.47: the fixed
    -- 0.3 s wait showed the game's 3rd person briefly), at the latest after the fallback delay
    self.switchIn = self.switchIn - 1
    local moved = false
    if lx ~= nil and self.pressPos ~= nil then
      local ex, ey, ez = lx - self.pressPos[1], ly - self.pressPos[2], lz - self.pressPos[3]
      moved = math.sqrt(ex * ex + ey * ey + ez * ez) > LEAVE_DISTANCE
    end
    if moved or self.switchIn <= 0 then
      self.switchIn = nil
      self:SetRider(player, moved and "game left the bike-mounted view" or "after bike-mounted view, fallback")
    end
  end
end

function script:Schedule()
  self.pending = true
  self.stalled = 0
  SH_NextTick(function() self:Tick() end)
end

function script:Tick()
  self.pending = false
  self.ticks = self.ticks + 1
  local ok, err = pcall(self.Check, self)
  if not ok and not self.errorLogged then   -- log once, keep running
    self.errorLogged = true
    SH_LOG("[living_city_interior_cam] bike first person error: " .. tostring(err))
  end
  self:Schedule()
end

function script:OnUpdate()
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
