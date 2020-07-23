--[[

   DFM-GRat.lua - computes and announces glide ratio

   ---------------------------------------------------------
   Released under MIT-license by DFM 2020
   ---------------------------------------------------------
   
   Version 0.1 - July 22, 2020
   
--]]

-- Locals for application

local GRatVersion= 0.1

local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }
local spdSe, spdSeId, spdSePa
local varSe, varSeId, varSePa
local annSwitch
local shortAnn
local shortAnnIndex
local glideRatio
local lastAnnTime
local maxRatio = 1000
local speed = 0
local vario = 0

local function annSwitchChanged(value)
   annSwitch = value
   system.pSave("annSwitch", annSwitch)
end

local function spdSensorChanged(value)
   spdSe = value
   spdSeId = sensorIdlist[spdSe]
   spdSePa = sensorPalist[spdSe]
   if (spdSeId == "...") then
      spdSeId = 0
      spdSePa = 0 
   end
   system.pSave("spdSe", spdSe)
   system.pSave("spdSeId", spdSeId)
   system.pSave("spdSePa", spdSePa)
end

local function varSensorChanged(value)
   varSe = value
   varSeId = sensorIdlist[varSe]
   varSePa = sensorPalist[varSe]
   if (varSeId == "...") then
      varSeId = 0
      varSePa = 0 
   end
   system.pSave("varSe", varSe)
   system.pSave("varSeId", varSeId)
   system.pSave("varSePa", varSePa)
end

local function shortAnnClicked(value)
   shortAnn = not value
   form.setValue(shortAnnIndex, shortAnn)
   system.pSave("shortAnn", tostring(shortAnn))
end

-- Draw the main form (Application inteface)

local function initForm()

   form.addRow(2)
   form.addLabel({label="Airspeed", width=177})
   form.addSelectbox(sensorLalist, spdSe, true, spdSensorChanged, {alignRight=true})
   
   form.addRow(2)
   form.addLabel({label="Vario"})
   form.addSelectbox(sensorLalist, varSe, true, varSensorChanged, {alignRight=true})
   
   form.addRow(2)
   form.addLabel({label="Announcement Switch", width=220})
   form.addInputbox(annSwitch, true, annSwitchChanged)
   
   form.addRow(2)
   form.addLabel({label="Short Announcements", width=270})
   shortAnnIndex = form.addCheckbox(shortAnn, shortAnnClicked)
   
   form.addRow(1)
   form.addLabel({label="DFM-GRat.lua Version "..GRatVersion.." ",
		  font=FONT_MINI, alignRight=true})
end

local dev = ""
local function readSensors()
   local sensors = system.getSensors()
   for _, sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 if sensor.param == 0 then
	    dev = sensor.label
	 else
	    table.insert(sensorLalist, dev.."-->"..sensor.label)
	    table.insert(sensorIdlist, sensor.id)
	    table.insert(sensorPalist, sensor.param)
	 end
      end
      
   end
end

local function loop()

   local swa
   local roundRat
   local spdSensor
   local varSensor
   local now
   local arg
   
   swa= system.getInputsVal(annSwitch)
   now = system.getTimeCounter()

   if spdSeId ~= 0 then
      spdSensor = system.getSensorByID(spdSeId, spdSePa)
   end
   
   if varSeId ~= 0 then
      varSensor = system.getSensorByID(varSeId, varSePa)
   end

   if spdSensor and varSensor and spdSensor.valid and varSensor.valid then
      speed = spdSensor.value
      vario = varSensor.value
      if math.abs(spdSensor.value / varSensor.value) < maxRatio then
	 arg = spdSensor.value*spdSensor.value - varSensor.value*varSensor.value
	 if arg > 0 then
	    glideRatio = math.sqrt(arg) / varSensor.value
	 else
	    glideRatio = spdSensor.value / varSensor.value
	 end
      else
	 glideRatio = maxRatio -- not sure best thing to do here - set to large #,don't announce
	 return
      end
   else
      return
   end
   
   if glideRatio and swa == 1 and (system.getTimeCounter() - lastAnnTime > 2000) then
      lastAnnTime = now
      roundRat = math.floor(glideRatio + 0.5)
      if (shortAnn) then
	 print("Short ann: ", roundRat)
	 system.playNumber(roundRat, 0)
      else
	 print("Long ann: ", roundRat)
	 system.playFile('/Apps/DFM-GRat/Ratio.wav', AUDIO_IMMEDIATE)	       
	 system.playNumber(roundRat, 0)
      end
   end
end

local function glideLog()
   local logval
   if not glideRatio then logval = 0 else logval = glideRatio end
   return logval, 1
end

local function teleWindow(w,h)
   local gtext, stext, vtext
   if glideRatio and math.abs(glideRatio) < 1000 then
      text = string.format("%.1f", math.floor(glideRatio + 0.5))
   else
      text = "---"
   end
   stext = string.format(" S %.1f ", speed)
   vtext = string.format(" V %.1f", vario)
   lcd.drawText(5,3,text..stext..vtext,FONT_BOLD)
end

local function init()

   annSwitch   = system.pLoad("annSwitch")
   shortAnn    = system.pLoad("shortAnn", "false")
   spdSe       = system.pLoad("spdSe", 0)
   spdSeId     = system.pLoad("spdSeId", 0)
   spdSePa     = system.pLoad("spdSePa", 0)
   varSe       = system.pLoad("varSe", 0)
   varSeId     = system.pLoad("varSeId", 0)
   varSePa     = system.pLoad("varSePa", 0)
   
   readSensors()

   shortAnn = (shortAnn == "true") -- convert back to boolean here
   lastAnnTime = 0
   
   system.registerLogVariable("GlideRatio", "", glideLog)
   system.registerForm(1, MENU_APPS, "Glide Ratio Announcer", initForm)
   system.registerTelemetry(1, "Glide Ratio", 0, teleWindow)

end

return {init=init, loop=loop, author="DFM", version=tostring(GRatVersion),
	name="Glide Ratio Announcer"}
