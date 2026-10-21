export = {}
function export:LuaDependencies()
  return {}
end
function export:Create(cbox)
  cbox:RegisterGlobals("Domino/User/windycity/custom_scripts/custom_scripts.globals.lua")
  cbox:RegisterBox("Domino/System/BreakableEntityMonitor_v2.lua")
  cbox:RegisterBox("Domino/System/GetPlayerID.lua")
  cbox:RegisterBox("Domino/System/HackableMonitor.lua")
  cbox:RegisterBox("Domino/System/InputListenerMonitor.lua")
  cbox:RegisterBox("Domino/System/LoadingScreenMonitor_v2.lua")
  cbox:RegisterBox("Domino/System/MissionLayer_v2.lua")
  cbox:RegisterBox("Domino/System/PlaySound_v2.lua")
  cbox:RegisterBox("Domino/System/Timer_v2.lua")
  cbox:RegisterBox("Domino/System/VehicleMonitor_v2.lua")
end
function export:Init(cbox)
  local l0
self.Speedometer_ID = cbox:GetParentEntity()
CDominoManager_GetInstance():RemoveDominoEntity(Globals._CUSTOM_SCRIPTS._Speedometer_ID)
Globals._CUSTOM_SCRIPTS._Speedometer_ID = self.Speedometer_ID
  self.Layer_Name = "custom_speedometer"
  self.Reference_Entity = "2050000000000000000"
  self.Speedometer_Mapicon = "2050000000000000001"
  self.FuelGauge_Mapicon = "2050000000000000002"
  self.Gas_Station = "2050000000000000003"
  self.Gas_Pump_A = "2050000000000000004"
  self.Gas_Pump_B = "2050000000000000005"
  self.Offset_X = 0 -- right/left-
  self.Offset_Y = -0.5 -- forward/backward-
  self.Offset_Z = 1 -- up/down-
  self.Loop_Delay = 0.1
  self.Ignition_Delay = 2.5
  self.Vehicles_Fuel = {}
  self.Fuel_Max = 99
  self.Fuel_Min = 5
  self.Consumption_Rate = 0.01*self.Loop_Delay
  self.Stations_Markers = { "2050000000000000241", "2050000000000000242", "2050000000000000243", "2050000000000000244", "2050000000000000245", "2050000000000000246", "2050000000000000247", "2050000000000000248", "2050000000000000249", "2050000000000000250", "2050000000000000251" }
table.insert(self.Stations_Markers, "2050000000000000252") --pawnee abandoned station
  self.Stations_Breakables = {
    { {52.177441,11.784513,72.255867},{51.943726,17.576965,72.255867} },
    { {-168.259979,-312.230957,70.749527},{-174.071198,-312.408447,70.749527} },
    { {-294.776215,-733.707092,71.734299},{-294.981537,-727.834045,71.734299} },
    { {1523.035278,-487.989594,73.685478},{1523.266113,-493.782806,73.685478} },
    { {1678.839111,623.544312,70.015152},{1679.061035,617.719543,70.015152} },
    { {1710.018066,-1255.609131,95.206955},{1709.713623,-1249.775146,95.206955} },
    { {-1077.994629,-1266.786255,67.530365},{-1078.148193,-1260.959106,67.530365} },
    { {23.136166,-1452.793335,61.147289},{17.248466,-1452.969482,61.147289} },
    { {54.200680,1898.607666,71.999504},{54.348156,1892.731201,71.999504} },
    { {-1202.224731,1852.009521,63.604088},{-1208.155151,1851.887695,63.604088} },
    { {890.420776,1516.551636,62.007576},{893.044983,1521.777222,62.007576} },
  }
table.insert(self.Stations_Breakables, { {1615.994751,-2143.762695,77.721901},{1613.366211,-2146.754883,77.721901} }) --pawnee abandoned station
  self.Radius_Interaction = 7
  self[0] = cbox:CreateBox("Domino/System/LoadingScreenMonitor_v2.lua")
  l0 = self[0]
  l0._graph = self
  l0.Out = DummyFunction
  l0.Enabled = DummyFunction
  l0.Disabled = DummyFunction
  l0.LoadingScreenEnded = self.Initial_Delay
  l0.LoadingScreenStarted = DummyFunction
  self[1000] = cbox:CreateBox("Domino/System/MissionLayer_v2.lua")
  l0 = self[1000]
  l0._graph = self
  l0.Loaded = DummyFunction
  l0.Unloaded = DummyFunction
  l0.Reseted = self.Layer_Loaded
  self[15] = cbox:CreateBox("Domino/System/VehicleMonitor_v2.lua")
  l0 = self[15]
  l0._graph = self
  l0.Enabled = DummyFunction
  l0.Disabled = DummyFunction
  l0.Enter = DummyFunction
  l0.Entered = self.Vehicle_Entered
  l0.Leave = DummyFunction
  l0.Exiting = self.Vehicle_Exiting
  l0.ChangeSeat = DummyFunction
  l0.StateChange = DummyFunction
  l0.BailedOut = self.Vehicle_Exiting
  l0.NoMoveTimer = DummyFunction
  l0.OnMoveTimer = DummyFunction
  l0.IsUnusable = DummyFunction
  l0.BollardTakedown = DummyFunction
  l0.SteamPipeTakedown = DummyFunction
  l0.TrafficLightTakedown = DummyFunction
  l0.FullTakedown = DummyFunction
  l0.PartialTakedown = DummyFunction
  l0.IsSlowEnoughToExit = DummyFunction
  l0.IsUnderwater = self.Vehicle_Exiting
  l0.IsPawnHiding = self.Hiding_Mode
  l0.PawnIsNotHiding = self.Driving_Mode
  self[9] = cbox:CreateBox("Domino/System/Timer_v2.lua")
  l0 = self[9]
  l0._graph = self
  l0.Out = DummyFunction
  l0.Started = DummyFunction
  l0.Stopped = DummyFunction
  l0.Paused = DummyFunction
  l0.Resumed = DummyFunction
  l0.TimeElapsed = self.Update_Speed
  l0.LoopingEnded = DummyFunction
  l0.GotTime = DummyFunction
  self[12] = cbox:CreateBox("Domino/System/Timer_v2.lua")
  l0 = self[12]
  l0._graph = self
  l0.Out = DummyFunction
  l0.Started = DummyFunction
  l0.Stopped = DummyFunction
  l0.Paused = DummyFunction
  l0.Resumed = DummyFunction
  l0.TimeElapsed = self.Check_Pumps
  l0.LoopingEnded = DummyFunction
  l0.GotTime = DummyFunction
  self[13] = cbox:CreateBox("Domino/System/Timer_v2.lua")
  l0 = self[13]
  l0._graph = self
  l0.Out = DummyFunction
  l0.Started = DummyFunction
  l0.Stopped = DummyFunction
  l0.Paused = DummyFunction
  l0.Resumed = DummyFunction
  l0.TimeElapsed = self.Refuel_Loop
  l0.LoopingEnded = DummyFunction
  l0.GotTime = DummyFunction
  self[30] = cbox:CreateBox("Domino/System/HackableMonitor.lua")
  l0 = self[30]
  l0._graph = self
  l0.Enabled = DummyFunction
  l0.Disabled = DummyFunction
  l0.OnIsHackable = DummyFunction
  l0.OnIsNotHackable = DummyFunction
  l0.HackStart = self.Start_Refill
  l0.HackStartListening = DummyFunction
  l0.HackSuccess = self.Stop_Refill
  l0.HackStopListening = DummyFunction
  l0.HackFailed = self.Stop_Refill
  l0.HackedOn = DummyFunction
  l0.HackedOff = DummyFunction
  l0.AllHacked = DummyFunction
  self[11] = cbox:CreateBox("Domino/System/InputListenerMonitor.lua")
  l0 = self[11]
  l0._graph = self
  l0.Out = DummyFunction
  l0.Enabled = DummyFunction
  l0.Disabled = DummyFunction
  l0.InputReceived = self.Force_Fail
  self[17] = cbox:CreateBox("Domino/System/BreakableEntityMonitor_v2.lua")
  l0 = self[17]
  l0._graph = self
  l0.Enabled = DummyFunction
  l0.Disabled = DummyFunction
  l0.Breaking = self.Pump_Broken
  l0.AllBroken = DummyFunction
  self[32] = cbox:CreateBox("Domino/System/PlaySound_v2.lua")
  l0 = self[32]
  l0._graph = self
  l0.Out = DummyFunction
  l0.Started = DummyFunction
  l0.Finished = DummyFunction
end
function export:ShutDown()
  --indicators loop
  l0 = self[9]
  l0:Stop()
  --gaspumps loop
  l0 = self[12]
  l0:Stop()
  --stop refuel
  l0 = self[13]
  l0:Stop()
  --monitor button release
  l0 = self[11]
  l0:Disable()
  --stop vehicle monitor
  l0 = self[15]
  l0:Disable()
  --disabling hack monitor
  l0 = self[30]
  l0:Disable()
  --disabling breakables monitor
  l0 = self[17]
  l0:Disable()
--removing breakables
RemoveEntity(self.Breakable_A)
RemoveEntity(self.Breakable_B)
  --unloading custom layer
  UnBind(self.Reference_Entity)
  UnBind(self.Speedometer_Mapicon)
  UnBind(self.FuelGauge_Mapicon)
  l0 = self[1000]
  l0.LayerName = self.Layer_Name
  l0:Unload()
  for k, v in pairs(self) do
    if type(v) == "table" and v.ShutDown ~= self.ShutDown and v ~= self._graph and v.ShutDown ~= nil then
      v:ShutDown()
    end
  end
end
function export:In()
  local l0
  l0 = self[0]
  l0:Enable()
end
function export:Initial_Delay()
  local l0
  self = self._graph
  l0 = self[0]
  l0:Disable()
  math.randomseed(math.floor((GetEntityPosition(GetLocalPlayerEntityId(), 1)+GetGameTime())*1000))
  math.random(); math.random(); math.random() --pop some random numbers before using them for real
  --skip if none enabled
Globals = Globals or {}
Globals._CUSTOM_SCRIPTS = Globals._CUSTOM_SCRIPTS or {}
Globals._CUSTOM_SCRIPTS._Speedometer = Globals._CUSTOM_SCRIPTS._Speedometer or 1
Globals._CUSTOM_SCRIPTS._FuelGauge = Globals._CUSTOM_SCRIPTS._FuelGauge or 1
  if Globals._CUSTOM_SCRIPTS._Speedometer == 0 and Globals._CUSTOM_SCRIPTS._FuelGauge == 0 then
    return
  end
  if self.Speedometer_ID ~= Globals._CUSTOM_SCRIPTS._Speedometer_ID then return end
  --loading custom layer
  l0 = self[1000]
  l0.LayerName = self.Layer_Name
  l0:Reset() --Layer_Loaded
end
function export:Layer_Loaded()
  local l0
  self = self._graph
  --displaying stations markers
  if Globals._CUSTOM_SCRIPTS._FuelGauge ~= 0 then
    for i=1, #self.Stations_Markers do
      SendMapPointControllerEvent(self.Stations_Markers[i], 1)
    end
  end
  --start vehicle monitor
  l0 = self[15]
  l0:Disable()
  l0.Pawn = GetLocalPlayerEntityId()
  l0.Vehicle = nil
  l0.CheckNow = 1
  l0:Enable() --Vehicle_Entered --Vehicle_Exiting --Hiding_Mode --Driving_Mode
end


function export:Vehicle_Entered()
  local l0
  self = self._graph
  if self.Speedometer_ID ~= Globals._CUSTOM_SCRIPTS._Speedometer_ID then return end
  --skip if passenger or none enabled
  if GetCurrentSeat(GetLocalPlayerEntityId()) ~= 1 or (Globals._CUSTOM_SCRIPTS._Speedometer == 0 and Globals._CUSTOM_SCRIPTS._FuelGauge == 0) then
    return
  end
local player = GetLocalPlayerEntityId() or GetInvalidEntityId()
local vehicle = GetCurrentVehicleEntityId(player) or player
local name = GetEntityName(vehicle) or ""
  --initializing fuel
  if string.find(name, "EmergentEvent_CrazyCar") then --personal vehicle
    self.Vehicles_Fuel[vehicle] = self.Vehicles_Fuel[vehicle] or 100
  elseif string.find(name, "Agile_01_MobChaser") then --taxi companion
    self.Vehicles_Fuel[vehicle] = self.Vehicles_Fuel[vehicle] or math.random(70, 99)
  elseif Globals._CUSTOM_SCRIPTS._In_Mission == 1 then
    self.Vehicles_Fuel[vehicle] = self.Vehicles_Fuel[vehicle] or math.random(40, 99)
  elseif string.find(name, "Vehicle_Police") then
    self.Vehicles_Fuel[vehicle] = self.Vehicles_Fuel[vehicle] or math.random(60, 99)
  elseif string.find(name, "Vehicle_Boat") or string.find(name, "Vehicle_Helicopter") then
    self.Vehicles_Fuel[vehicle] = self.Vehicles_Fuel[vehicle] or math.random(50, 99)
  else
    if Globals._CUSTOM_SCRIPTS._Index_Faction == 1 then --madmile
      self.Vehicles_Fuel[vehicle] = self.Vehicles_Fuel[vehicle] or math.random(40, 99)
    elseif Globals._CUSTOM_SCRIPTS._Index_Faction == 2 then --wards
      self.Vehicles_Fuel[vehicle] = self.Vehicles_Fuel[vehicle] or math.random(2, 70)
    elseif Globals._CUSTOM_SCRIPTS._Index_Faction == 4 then --pawnee
      self.Vehicles_Fuel[vehicle] = self.Vehicles_Fuel[vehicle] or math.random(2, 70)
    else
      self.Vehicles_Fuel[vehicle] = self.Vehicles_Fuel[vehicle] or math.random(self.Fuel_Min, self.Fuel_Max)
    end
  end
--initializing indicators
UnBind(self.Reference_Entity)
SetEntityPosition(self.Reference_Entity, -2000, -2500, 1)
SetEntityAngle(self.Reference_Entity, 0, 0, 0)
UnBind(self.Speedometer_Mapicon)
SetEntityPosition(self.Speedometer_Mapicon, GetEntityPosition(self.Reference_Entity, 0)+self.Offset_X, GetEntityPosition(self.Reference_Entity, 1)+self.Offset_Y, GetEntityPosition(self.Reference_Entity, 2)+self.Offset_Z)
Bind(self.Reference_Entity, self.Speedometer_Mapicon, "", 0)
if GetCurrentSeat(player) == 1 and Globals._CUSTOM_SCRIPTS._Speedometer ~= 0 then IndicatorSetIsVisible(GetLocalPlayerId(), self.Speedometer_Mapicon, 1) end --skip if passenger or disabled
UnBind(self.FuelGauge_Mapicon)
SetEntityPosition(self.FuelGauge_Mapicon, GetEntityPosition(self.Speedometer_Mapicon, 0), GetEntityPosition(self.Speedometer_Mapicon, 1), GetEntityPosition(self.Speedometer_Mapicon, 2)-0.2)
Bind(self.Reference_Entity, self.FuelGauge_Mapicon, "", 0)
if GetCurrentSeat(player) == 1 and (Globals._CUSTOM_SCRIPTS._FuelGauge == 1 or (self.Vehicles_Fuel[vehicle] <= 20 and Globals._CUSTOM_SCRIPTS._FuelGauge == 2)) then IndicatorSetIsVisible(GetLocalPlayerId(), self.FuelGauge_Mapicon, 1) end --skip if passenger or disabled
  --indicators loop
  l0 = self[9]
  l0:ClearCallback()
  l0.Seconds = self.Loop_Delay
  l0:Start() --Update_Speed
--skip if passenger or disabled
if GetCurrentSeat(player) ~= 1 or Globals._CUSTOM_SCRIPTS._FuelGauge == 0 then return end
  --gaspumps loop
  l0 = self[12]
  l0:ClearCallback()
  l0.Seconds = 0.35
  l0:Start() --Check_Pumps
  --enabling hack monitor
  l0 = self[30]
  l0:Disable()
  l0.HackableEntityList = { self.Gas_Pump_A, self.Gas_Pump_B }
  l0:Enable() --Start_Refill --Stop_Refill
end
function export:Update_Speed()
  local l0
  self = self._graph
local player = GetLocalPlayerEntityId() or GetInvalidEntityId()
local vehicle = GetCurrentVehicleEntityId(player) or player
local name = GetEntityName(vehicle) or ""
  --updating indicators
  if math.ceil(GetEntityPosition(self.Reference_Entity, 2)) ~= math.ceil(GetEntityPosition(vehicle or player, 2)) then
    UnBind(self.Reference_Entity)
    Bind(vehicle or player, self.Reference_Entity, "", 1)
  end
  self.Tag = "km/h"
  self.Speed = GetVehicleSpeed(player) or 0
  if string.find(name, "Vehicle_Boat") or string.find(name, "Vehicle_Helicopter") then
    self.Tag = "knots"
    self.Speed = self.Speed * 0.539957
  elseif Globals._CUSTOM_SCRIPTS._Speedometer == 2 then
    self.Tag = "MPH"
    self.Speed = self.Speed * 0.621371
  end
  IndicatorSetName(GetLocalPlayerId(), self.Speedometer_Mapicon, string.format("%.f "..self.Tag, self.Speed))
  IndicatorSetName(GetLocalPlayerId(), self.FuelGauge_Mapicon, string.format("%.f%%", self.Vehicles_Fuel[vehicle]))
  --checking fuel level
  if self.Vehicles_Fuel[vehicle] <= 0 or GetVehicleIsDriveable(vehicle) == 0 then
    if GetCurrentSeat(player) == 1 and Globals._CUSTOM_SCRIPTS._FuelGauge ~= 0 then ShutdownVehicleEngine(vehicle, 1) end
  end
--burning fuel
self.Vehicles_Fuel[vehicle] = math.max(0, self.Vehicles_Fuel[vehicle] - self.Consumption_Rate * math.sqrt(GetVehicleSpeed(player)))
--display only if low level or refueling
l0 = self[13]
if (self.Vehicles_Fuel[vehicle] <= 20 or l0.m_delayId ~= nil) and Globals._CUSTOM_SCRIPTS._FuelGauge == 2 then IndicatorSetIsVisible(GetLocalPlayerId(), self.FuelGauge_Mapicon, 1)
elseif self.Vehicles_Fuel[vehicle] > 20 and Globals._CUSTOM_SCRIPTS._FuelGauge == 2 then IndicatorSetIsVisible(GetLocalPlayerId(), self.FuelGauge_Mapicon, 0) end
  --indicators loop
  l0 = self[9]
  l0.Seconds = self.Loop_Delay
  l0:Start() --Update_Speed
end
function export:Check_Pumps()
  local l0
  self = self._graph
  --finding nearest pump
  self.Selected_Pump = self.Stations_Markers[1]
  local Distance_Last = 9999
  for i=1, #self.Stations_Markers do
    if GetDistance3D(GetCurrentVehicleEntityId(GetLocalPlayerEntityId()), self.Stations_Markers[i]) < Distance_Last then
      Distance_Last = GetDistance3D(GetCurrentVehicleEntityId(GetLocalPlayerEntityId()), self.Stations_Markers[i])
	  self.Selected_Pump = self.Stations_Markers[i] or GetInvalidEntityId()
	  self.Selected_Breakables = self.Stations_Breakables[i] or {{GetEntityPosition(self.Selected_Pump, 0),GetEntityPosition(self.Selected_Pump, 1),GetEntityPosition(self.Selected_Pump, 2)},{-2000,-2500,1}}
    end
  end
--positioning interaction
SetEntityPosition(self.Gas_Pump_A, self.Selected_Breakables[1][1], self.Selected_Breakables[1][2], self.Selected_Breakables[1][3]+0.75)
SetEntityPosition(self.Gas_Pump_B, self.Selected_Breakables[2][1], self.Selected_Breakables[2][2], self.Selected_Breakables[2][3]+0.75)
  --check breakables
  l0 = Boxes[PathID("Domino/System/GetPlayerID.lua")]
  l0._graph = self
  l0.Out = self.Check_Breakables
  l0:In()
  --interaction visibility
  if GetEntityPosition(self.Breakable_A or GetInvalidEntityId(), 2) ~= 1 and GetLocalPlayerCash() > 0 and self.Vehicles_Fuel[GetCurrentVehicleEntityId(GetLocalPlayerEntityId())] <= 99 and GetDistance3D(GetCurrentVehicleEntityId(GetLocalPlayerEntityId()), self.Selected_Pump) < self.Radius_Interaction and GetCurrentSeat(GetLocalPlayerEntityId()) == 1 and GetVehicleSpeed(GetLocalPlayerEntityId()) < 1 then
    SetHackable(self.Gas_Pump_A, 1)
    SetHackable(self.Gas_Pump_B, 1)
  else
    SetHackable(self.Gas_Pump_A, 0)
    SetHackable(self.Gas_Pump_B, 0)
  end
  --gaspumps loop
  l0 = self[12]
  l0.Seconds = math.max(0.35, GetDistance3D(GetCurrentVehicleEntityId(GetLocalPlayerEntityId()), self.Selected_Pump)/35)
  l0:Start() --Check_Pumps
-- ShowMissionTextMessageLocalPlayer("MissionDebug", "DefaultIcon", tostring(Distance_Last), tostring(l0.Seconds), "", "", l0.Seconds-0.1, 0, self, "OnFinished", "OnDisplayed")
end
function export:Check_Breakables()
  local l0
  self = self._graph
  --disable if away
  if GetDistance3D(GetCurrentVehicleEntityId(GetLocalPlayerEntityId()), self.Selected_Pump) > self.Radius_Interaction and GetEntityPosition(self.Breakable_A or GetInvalidEntityId(), 2) ~= 0 then
    --disabling breakables monitor
    l0 = self[17]
    l0:Disable()
    --removing breakables
    RemoveEntity(self.Breakable_A)
    RemoveEntity(self.Breakable_B)
  --if near and not broken already
  elseif GetDistance3D(GetCurrentVehicleEntityId(GetLocalPlayerEntityId()), self.Selected_Pump) < self.Radius_Interaction and GetEntityPosition(self.Breakable_A or GetInvalidEntityId(), 2) ~= 1 then
    --disabling breakables monitor
    l0 = self[17]
    l0:Disable()
    --removing breakables
    RemoveEntity(self.Breakable_A)
    RemoveEntity(self.Breakable_B)
    --spawning breakables
    self.Breakable_A = SpawnEntityFromArchetype("{81861B76-2EE9-C079-D65A-A5990E5ECEAC}", self.Selected_Breakables[1][1], self.Selected_Breakables[1][2], self.Selected_Breakables[1][3]+0.5, 0, 0, 0) --Breakable.Interrior.BeerGlass_01
    self.Breakable_B = SpawnEntityFromArchetype("{81861B76-2EE9-C079-D65A-A5990E5ECEAC}", self.Selected_Breakables[2][1], self.Selected_Breakables[2][2], self.Selected_Breakables[2][3]+0.5, 0, 0, 0) --Breakable.Interrior.BeerGlass_01
    HideEntity(self.Breakable_A)
    HideEntity(self.Breakable_B)
    --enabling breakables monitor
    l0 = self[17]
    l0.BreakableEntitiesList = { self.Breakable_A, self.Breakable_B }
    l0:Enable() --Pump_Broken
  end
end
function export:Pump_Broken()
  local l0
  self = self._graph
  --disabling station
  l0 = self[17]
  l0:Disable()
  SetEntityPosition(self.Breakable_A, GetEntityPosition(self.Breakable_A, 0), GetEntityPosition(self.Breakable_A, 1), 1)
  SetEntityPosition(self.Breakable_B, GetEntityPosition(self.Breakable_B, 0), GetEntityPosition(self.Breakable_B, 1), 1)
  SetHackable(self.Gas_Pump_A, 0)
  SetHackable(self.Gas_Pump_B, 0)
-- ShowMissionTextMessageLocalPlayer("MissionDebug", "DefaultIcon", "Pump_Broken", tostring(self.Selected_Pump), "", "", 3, 0, self, "OnFinished", "OnDisplayed")
end


function export:Start_Refill()
  local l0
  self = self._graph
  --refuel loop
  l0 = self[13]
  l0:ClearCallback()
  l0.Seconds = self.Loop_Delay
  l0.Loop = 1
  local hacktime = 6.0 --MissionSpecific.A05_M01_CityNodes
  local holdtime = 0.35 --hack start detection delay
  l0.nbLoop = math.floor((hacktime-holdtime)/l0.Seconds)
  l0:Start() --Refuel_Loop
  --monitor button release
  l0 = self[11]
  l0:Disable()
  l0.Player = GetLocalPlayerEntityId()
  l0.Input = "release_software"
  l0:Enable() --Force_Fail
end
function export:Refuel_Loop()
  local l0
  self = self._graph
  --increasing fuel
  l0 = self[13]
  self.Vehicles_Fuel[GetCurrentVehicleEntityId(GetLocalPlayerEntityId())] = math.min(100, self.Vehicles_Fuel[GetCurrentVehicleEntityId(GetLocalPlayerEntityId())] + 100/l0.nbLoop)
  --failing hack
  if self.Vehicles_Fuel[GetCurrentVehicleEntityId(GetLocalPlayerEntityId())] >= 100 then
    l0 = Boxes[PathID("Domino/System/GetPlayerID.lua")]
    l0._graph = self
    l0.Out = self.Force_Fail
    l0:In()
  end
end
function export:Force_Fail()
  local l0
  self = self._graph
--failing hack
SetHackable(self.Gas_Pump_A, 0)
SetHackable(self.Gas_Pump_B, 0)
end
function export:Stop_Refill()
  local l0
  self = self._graph
  --stop refuel
  l0 = self[13]
  l0:Stop()
  l0:ShutDown()
  --monitor button release
  l0 = self[11]
  l0:Disable()
  --display price
  l0 = self[13]
  PushTokenString("[#VALUE]", string.format("%d",math.ceil(l0.currentLoop*100/l0.nbLoop)))
  SendMissionChannelMessageToLocalPlayersId(Globals._CUSTOM_SCRIPTS._Mission_ID, "PlayerCentric", "59496", 3) --"Cost: $[#VALUE]"
  ForceSetCash(math.max(0,GetLocalPlayerCash()-math.ceil(l0.currentLoop*100/l0.nbLoop)))
  --playing buy sound
  l0 = self[32]
  l0.SoundId = "0x00002ef2" --sndShopPurchaseSound
  l0:Play()
end


function export:Hiding_Mode()
  local l0
  self = self._graph
  if self.Speedometer_ID ~= Globals._CUSTOM_SCRIPTS._Speedometer_ID then return end
  --hiding indicators
UnBind(self.Reference_Entity)
SetEntityPosition(self.Reference_Entity, GetEntityPosition(GetLocalPlayerEntityId(), 0), GetEntityPosition(GetLocalPlayerEntityId(), 1), 1)
  l0 = self[9]
  l0:Stop()
  l0:ShutDown()
end
function export:Driving_Mode()
  local l0
  self = self._graph
  if self.Speedometer_ID ~= Globals._CUSTOM_SCRIPTS._Speedometer_ID then return end
  --indicators loop
  l0 = self[9]
  l0.Seconds = self.Ignition_Delay
  l0:Start() --Update_Speed
end


function export:Vehicle_Exiting()
  local l0
  self = self._graph
  --hiding indicators
  l0 = self[9]
  l0:Stop()
  l0:ShutDown()
IndicatorSetName(GetLocalPlayerId(), self.Speedometer_Mapicon, "-")
IndicatorSetName(GetLocalPlayerId(), self.FuelGauge_Mapicon, "-%")
UnBind(self.Reference_Entity)
SetEntityPosition(self.Reference_Entity, -2000, -2500, 1)
SetEntityAngle(self.Reference_Entity, 0, 0, 0)
UnBind(self.Speedometer_Mapicon)
IndicatorSetIsVisible(GetLocalPlayerId(), self.Speedometer_Mapicon, 0)
UnBind(self.FuelGauge_Mapicon)
IndicatorSetIsVisible(GetLocalPlayerId(), self.FuelGauge_Mapicon, 0)
  l0 = self[12]
  l0:Stop()
  l0:ShutDown()
SetHackable(self.Gas_Pump_A, 0)
SetHackable(self.Gas_Pump_B, 0)
  -- --unloading custom layer
  -- l0 = self[1000]
  -- l0.LayerName = self.Layer_Name
  -- l0:Unload()
end
_compilerVersion = 4
