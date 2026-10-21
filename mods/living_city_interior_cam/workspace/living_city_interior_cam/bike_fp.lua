-- living_city_interior_cam: bike rider first person (test)
-- The vehicle camera key never selects the "Interior" view on bikes. The engine call used by the
-- game's Domino box SetInVehicleCamera (Normal 0, Classic 1, Bumper 2, Interior 3, Hollywood 4)
-- is tried here once each time the player sits on a bike.
local INTERIOR = 3

local script = Script("LivingCityInteriorCamBike")

function script:OnLoad()
  self.vehicle = nil
  SH_LOG("[living_city_interior_cam] bike first person test loaded")
end

function script:OnUpdate()
  local player = GetLocalPlayerEntityId()
  if player == nil then return end
  local seat = GetCurrentSeat(player) or 0
  if seat == 0 then
    self.vehicle = nil
    return
  end
  local vehicle = GetCurrentVehicleEntityId(player)
  if vehicle == nil or vehicle == self.vehicle then return end
  self.vehicle = vehicle
  local name = GetEntityName(vehicle) or ""
  if string.find(name, "Vehicle_Bike", 1, true) == nil then return end
  local ok, err = pcall(SetInVehicleCamera, player, INTERIOR)
  SH_LOG("[living_city_interior_cam] " .. name .. " SetInVehicleCamera(Interior): " .. (ok and "ok" or tostring(err)))
end
