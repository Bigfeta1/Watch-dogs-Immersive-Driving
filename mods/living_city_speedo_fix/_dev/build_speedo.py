import sys

src, dst = sys.argv[1], sys.argv[2]
code = open(src, 'rb').read().decode('latin1')


def patch(old, new):
    global code
    assert code.count(old) == 1, old
    code = code.replace(old, new)


# 1. load first person settings together with the other settings
patch(
    'Globals._CUSTOM_SCRIPTS._FuelGauge = Globals._CUSTOM_SCRIPTS._FuelGauge or 1\r\n',
    'Globals._CUSTOM_SCRIPTS._FuelGauge = Globals._CUSTOM_SCRIPTS._FuelGauge or 1\r\n'
    '  --first person settings (living_city_speedo_fix)\r\n'
    '  Globals._SPEEDO_FP = { Enabled = 1, Distance = 3.0, Offset_X = -0.95, Offset_Y = 1.5, Offset_Z = -0.54, Gap = 0.07, Profiler_Hide = 1, Debug = 0, Bike_Dash = 1, Bike_X = 0.0, Bike_Y = 0.57, Bike_Z = 0.90, Bike_Gap = 0.03 }\r\n'
    '  local fp_file = loadfile("../data_win64/mods/living_city_speedo_fix/Speedometer_FP_CONFIG.txt")\r\n'
    '  if fp_file ~= nil then\r\n'
    '    fp_file()\r\n'
    '  end\r\n',
)

# 2. reset first person state when entering a vehicle
patch(
    '--initializing indicators\r\n',
    '--initializing indicators\r\n'
    'self.FP_Mode = 0\r\n',
)

# 3. check the camera on every indicators update
patch(
    '    Bind(vehicle or player, self.Reference_Entity, "", 1)\r\n  end\r\n',
    '    Bind(vehicle or player, self.Reference_Entity, "", 1)\r\n  end\r\n'
    '  --first person placement\r\n'
    '  self:FP_Update(vehicle)\r\n',
)

# 4. optional debug readout next to the speed
patch(
    'IndicatorSetName(GetLocalPlayerId(), self.Speedometer_Mapicon, string.format("%.f "..self.Tag, self.Speed))',
    'IndicatorSetName(GetLocalPlayerId(), self.Speedometer_Mapicon, string.format("%.f "..self.Tag, self.Speed)..(self.FP_Debug_Text or ""))',
)

# 5. hide in first person while the profiler (and its minimap) is on, after the fuel gauge visibility logic
patch(
    'elseif self.Vehicles_Fuel[vehicle] > 20 and Globals._CUSTOM_SCRIPTS._FuelGauge == 2 then IndicatorSetIsVisible(GetLocalPlayerId(), self.FuelGauge_Mapicon, 0) end\r\n',
    'elseif self.Vehicles_Fuel[vehicle] > 20 and Globals._CUSTOM_SCRIPTS._FuelGauge == 2 then IndicatorSetIsVisible(GetLocalPlayerId(), self.FuelGauge_Mapicon, 0) end\r\n'
    '  --first person visibility\r\n'
    '  self:FP_Visibility()\r\n',
)

# 6. new functions
FP_FUNCTIONS = r'''
function export:FP_Place(vehicle, ox, oy, oz, gap)
  --same sequence as Vehicle_Entered, with custom offsets.
  UnBind(self.Reference_Entity)
  SetEntityPosition(self.Reference_Entity, -2000, -2500, 1)
  SetEntityAngle(self.Reference_Entity, 0, 0, 0)
  UnBind(self.Speedometer_Mapicon)
  SetEntityPosition(self.Speedometer_Mapicon, GetEntityPosition(self.Reference_Entity, 0)+ox, GetEntityPosition(self.Reference_Entity, 1)+oy, GetEntityPosition(self.Reference_Entity, 2)+oz)
  Bind(self.Reference_Entity, self.Speedometer_Mapicon, "", 0)
  UnBind(self.FuelGauge_Mapicon)
  SetEntityPosition(self.FuelGauge_Mapicon, GetEntityPosition(self.Speedometer_Mapicon, 0), GetEntityPosition(self.Speedometer_Mapicon, 1), GetEntityPosition(self.Speedometer_Mapicon, 2)-gap)
  Bind(self.Reference_Entity, self.FuelGauge_Mapicon, "", 0)
  Bind(vehicle, self.Reference_Entity, "", 1)
  self.FP_Places = (self.FP_Places or 0) + 1
end
function export:FP_Update(vehicle)
  local cfg = Globals._SPEEDO_FP or {}
  local player = GetLocalPlayerEntityId()
  self.FP_Debug_Text = nil
  --skip if disabled, passenger or no camera access.
  if cfg.Enabled ~= 1 or type(SH_Camera_GetEntityId) ~= "function" or vehicle == nil or vehicle == player or GetCurrentSeat(player) ~= 1 then
    return
  end
  local cam = SH_Camera_GetEntityId()
  if cam == nil then return end
  local vx, vy, vz = GetEntityPosition(vehicle, 0), GetEntityPosition(vehicle, 1), GetEntityPosition(vehicle, 2)
  local cx, cy, cz = GetEntityPosition(cam, 0), GetEntityPosition(cam, 1), GetEntityPosition(cam, 2)
  if vx == nil or vy == nil or vz == nil or cx == nil or cy == nil or cz == nil then return end
  --camera close to the vehicle means first person.
  local dx, dy, dz = cx-vx, cy-vy, cz-vz
  local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
  local first_person = dist < (cfg.Distance or 3.0)
  if cfg.Debug == 1 then
    self.FP_Debug_Text = string.format(" | cam %.1fm %s #%d", dist, first_person and "FP" or "3P", self.FP_Places or 0)
  end
  if not first_person then
    --back to the original placement.
    if self.FP_Mode == 1 then
      self.FP_Mode = 0
      self:FP_Place(vehicle, self.Offset_X, self.Offset_Y, self.Offset_Z, 0.2)
    end
    return
  end
  --target in vehicle space: camera position plus configured offsets (x right, y forward, z up).
  local yaw = math.rad(GetEntityAngle(vehicle, 2) or 0)
  local cam_y = -dx*math.sin(yaw) + dy*math.cos(yaw)
  local lx = dx*math.cos(yaw) + dy*math.sin(yaw) + (cfg.Offset_X or 0)
  local ly = cam_y + (cfg.Offset_Y or 0)
  local lz = dz + (cfg.Offset_Z or 0)
  local gap = cfg.Gap or 0.07
  --bikes: on the dashboard instead, a fixed point on the bike, while the camera is behind it
  --(rider view; the bike-mounted view sits ahead of the dashboard and keeps the corner placement).
  if cfg.Bike_Dash == 1 and string.find(GetEntityName(vehicle) or "", "Vehicle_Bike", 1, true) ~= nil and cam_y < (cfg.Bike_Y or 0.57) - 0.2 then
    lx, ly, lz = cfg.Bike_X or 0, cfg.Bike_Y or 0.57, cfg.Bike_Z or 0.90
    gap = cfg.Bike_Gap or 0.03
  end
  --skip if already in place.
  local tx = vx + lx*math.cos(yaw) - ly*math.sin(yaw)
  local ty = vy + lx*math.sin(yaw) + ly*math.cos(yaw)
  local mx, my = GetEntityPosition(self.Speedometer_Mapicon, 0), GetEntityPosition(self.Speedometer_Mapicon, 1)
  if self.FP_Mode == 1 and mx ~= nil and my ~= nil and math.sqrt((mx-tx)*(mx-tx) + (my-ty)*(my-ty)) < 0.3 then
    return
  end
  --offsets relative to the reference entity, whether or not it follows the vehicle rotation.
  local rel = yaw - math.rad(GetEntityAngle(self.Reference_Entity, 2) or 0)
  local ox = lx*math.cos(rel) - ly*math.sin(rel)
  local oy = lx*math.sin(rel) + ly*math.cos(rel)
  self.FP_Mode = 1
  self:FP_Place(vehicle, ox, oy, lz, gap)
end
function export:FP_Visibility()
  local cfg = Globals._SPEEDO_FP or {}
  --The Fox Mod shows the minimap only while the profiler is on.
  if self.FP_Mode == 1 and cfg.Profiler_Hide == 1 and (Globals._CUSTOM_SCRIPTS._Fox_ProfilerOn or 0) == 1 then
    --placeholder names like Vehicle_Exiting, so the real values are a change once shown again.
    IndicatorSetName(GetLocalPlayerId(), self.Speedometer_Mapicon, "-")
    IndicatorSetName(GetLocalPlayerId(), self.FuelGauge_Mapicon, "-%")
    IndicatorSetIsVisible(GetLocalPlayerId(), self.Speedometer_Mapicon, 0)
    IndicatorSetIsVisible(GetLocalPlayerId(), self.FuelGauge_Mapicon, 0)
    self.FP_Hidden = 1
  elseif self.FP_Hidden == 1 then
    self.FP_Hidden = 0
    --restoring, same rules as Vehicle_Entered (fuel mode 2 is handled by Update_Speed).
    if Globals._CUSTOM_SCRIPTS._Speedometer ~= 0 then IndicatorSetIsVisible(GetLocalPlayerId(), self.Speedometer_Mapicon, 1) end
    if Globals._CUSTOM_SCRIPTS._FuelGauge == 1 then IndicatorSetIsVisible(GetLocalPlayerId(), self.FuelGauge_Mapicon, 1) end
    --real names are set again by the next Update_Speed, after being shown (same order as Vehicle_Entered).
    IndicatorSetName(GetLocalPlayerId(), self.Speedometer_Mapicon, "-")
    IndicatorSetName(GetLocalPlayerId(), self.FuelGauge_Mapicon, "-%")
  end
end
'''.lstrip('\n').replace('\n', '\r\n')

patch('_compilerVersion = 4\r\n', FP_FUNCTIONS + '_compilerVersion = 4\r\n')

open(dst, 'wb').write(code.encode('latin1'))
print('written', len(code))
