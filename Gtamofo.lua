local _G = getfenv(0)
GtamofoDB = GtamofoDB or {}
local defaults = {
  ["Complete"] = true,
  ["Objective"] = true,
  ["Progress"] = false
}
local soundBits = {
  ["Alliance"] = {
    ["Progress"] = "Interface\\AddOns\\Gtamofo\\Q.mp3", -- more work?
    ["Objective"] = "Interface\\AddOns\\Gtamofo\\Q.mp3", -- ready to work
    ["Complete"] = "Interface\\AddOns\\Gtamofo\\Peasant_job_done.mp3", -- job's done
  },
  ["Horde"] = {
  --["Progress"] = "Sound\\Creature\\Peon\\PeonWhat4.wav", -- something need doing?
    ["Progress"] = "Interface\\AddOns\\Gtamofo\\Q.mp3", -- work work
    ["Objective"] = "Interface\\AddOns\\Gtamofo\\Q.mp3", -- ready to work
    ["Complete"] = "Interface\\AddOns\\Gtamofo\\Peasant_job_done.mp3", -- work complete
  }
}
local prio = {
  ["Complete"] = 3,
  ["Objective"] = 2,
  ["Progress"] = 1
}
local verbose = {
  ["Complete"] = "Quest Completion: ",
  ["Objective"] = "Objective Completion: ",
  ["Progress"] = "Objective Progress: "
}
local media_5 = "Interface\\Addons\\Gtamofo\\media\\missionpassed.tga"
local DeadDS = CreateFrame("Frame", nil, UIParent)
local timeElapsed =0
local tempo =0
-- Deformat the global announce patterns to turn them into captures, anchor start / end
local tProgress = {}
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_ADD_FOUND_SII,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_ADD_ITEM_SII,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_ADD_KILL_SII,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
local tObjective = {}
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_OBJECTIVE_COMPLETE_S,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_UNKNOWN_COMPLETE,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
-- useless for our purpose at this point, only CHAT_MSG_SYSTEM at quest turn-in uses this pattern
local qComplete = "^"..string.gsub(string.gsub(ERR_QUEST_COMPLETE_S,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$"

local CopyTable
local completedCache, queueMessage, p_faction = {}, nil, nil
local Speak = function(self,elapsed)
  self.sinceLast = self.sinceLast + elapsed
  if self.sinceLast > self.interval then
    p_faction = p_faction or (UnitFactionGroup("player"))
    self.sinceLast = 0
    if queueMessage and prio[queueMessage] then
      PlaySoundFile(soundBits[p_faction][queueMessage])
      queueMessage = nil
    end
    self:Hide()
  end
end
CopyTable = function(t,copied)
  copied = copied or {}
  local copy = {}
  copied[t] = copy
  for k,v in pairs(t) do
    if type(v) == "table" then
      if copied[v] then
        copy[k] = copied[v]
      else
        copy[k] = CopyTable(v,copied)
      end
    else
      copy[k] = v
    end
  end
  return copy
end|
local Print = function(msg)
  if not DEFAULT_CHAT_FRAME:IsVisible() then
    FCF_SelectDockFrame(DEFAULT_CHAT_FRAME)
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cffE59400Gtamofo: |r"..msg)
end
local help = function()
  Print("/qsb complete")
  Print("    toggles Quest Completion sound")
  Print("/qsb objective")
  Print("    toggles Objective Completion sound")
  Print("/qsb progress")
  Print("    toggles Objective Progress sound")
  Print("/qsb status")
  Print("    print current settings")
end
local timer = CreateFrame("Frame")
timer:Hide()
timer.sinceLast, timer.interval = 0, 1
timer:SetScript("OnUpdate", function()
  Speak(this,arg1)
  end)
local Listen = function(alertType)
  if not timer:IsVisible() then
    timer:Show()
  end
  if queueMessage == nil or (prio[queueMessage] < prio[alertType]) then
    queueMessage = alertType
  end
end
local events = CreateFrame("Frame")
events:SetScript("OnEvent",function() 
    if events[event]~=nil then return events[event](this,event,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) end
  end)
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events.PLAYER_ALIVE = function(self,event)
  p_faction = (UnitFactionGroup("player"))
  self:RegisterEvent("UI_INFO_MESSAGE")
  self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
end
events.PLAYER_ENTERING_WORLD = events.PLAYER_ALIVE
events.UI_INFO_MESSAGE = function(self,event,message)
  if self.variablesLoaded == nil then return end
  -- completion doesn't fire a UI_INFO_MESSAGE in 1.12.1 but keep it because "who knows" maybe down the road
  if self.config["Complete"] and string.find(message,qComplete) then 
    Listen("Complete")
    return
  else
    for _,objPattern in ipairs(tObjective) do
      if self.config["Objective"] and string.find(message,objPattern) then
        Listen("Objective")
        return
      end
    end
    for _,pgPattern in ipairs(tProgress) do
      local s,e,objective,have,need = string.find(message,pgPattern)
      if s then
        have,need = tonumber(have),tonumber(need)
        if have == need then
          if self.config["Objective"] then Listen("Objective") end
          return
        elseif have < need then
          if self.config["Progress"] then Listen("Progress") end
          return
        end
      end
    end
  end
end
events.UNIT_QUEST_LOG_CHANGED = function(self,event,unitid)
  if unitid and unitid == "player" then
    self.numQuests = GetNumQuestLogEntries()
    self:RegisterEvent("QUEST_LOG_UPDATE")
  end
end
events.QUEST_LOG_UPDATE = function(self,event)
  if self.variablesLoaded == nil then return end
  self:UnregisterEvent("QUEST_LOG_UPDATE")
  local numQuests = GetNumQuestLogEntries()
  if self.numQuests and (numQuests ~= self.numQuests) then return end -- we just picked up or abandoned a quest, skip this update
  local questLogTitleText, questLevel, questTag, isHeader, isCollapsed, isComplete 
  if numQuests > 0 then
    local newComplete = false
    for i=1,numQuests,1 do 
      questLogTitleText, questLevel, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
      if (isComplete and isComplete > 0) and not isHeader then
        if completedCache[questLogTitleText] == nil then
          completedCache[questLogTitleText] = true
          newComplete = true
        end
      end
    end
    if newComplete and self.config["Complete"] then 
      Listen("Complete") 
      DeadDS:SetPoint('Top', UIParent, 'Top', 0, 0)
      DeadDS:SetHeight(147)
      DeadDS:SetWidth(630)
      DeadDS.bar = DeadDS:CreateTexture(nil, 'ARTWORK')
      DeadDS.bar:SetAllPoints(DeadDS)
      DeadDS.bar:SetTexture(media_5)
      UIFrameFadeIn(DeadDS,2,0,1)
      DeadDS:SetScript("OnUpdate", function(self, elapsed)
        timeElapsed = timeElapsed + 0.001
        if timeElapsed > 0.05 then
          timeElapsed = 0
          if tempo <13 then
          tempo=tempo + 2    
          end	
          if tempo >=14 then
            if tempo ==15 then
              
              DeadDS:Hide()
            end
            tempo=tempo+1
            UIFrameFadeOut(DeadDS,1,0,1)
            DeadDS:Hide()
          end
        end
      end)
    end
  end
end
events.VARIABLES_LOADED = function(self,event)
  if not next(GtamofoDB) then
    Gtamofo = CopyTable(defaults)
  end
  self.config = GtamofoDB
  self.variablesLoaded = true
end
SlashCmdList["GTAMOFO"] = function(msg)
  if msg==nil or msg=="" then
    help()
  else
    local msg_l = strlower(msg)
    local ON, OFF = "|cff008000ON|r", "|cffFF1919OFF|r"
    if msg_l == "complete" then

      GtamofoDB["Complete"] = not GtamofoDB["Complete"]
      Print(verbose["Complete"]..(GtamofoDB["Complete"] and ON or OFF))
    elseif msg_l == "objective" then
      GtamofoDB["Objective"] = not GtamofoDB["Objective"]
      Print(verbose["Objective"]..(GtamofoDB["Objective"] and ON or OFF))
    elseif msg_l == "progress" then
      GtamofoDB["Progress"] = not GtamofoDB["Progress"]
      Print(verbose["Progress"]..(GtamofoDB["Progress"] and ON or OFF))
    elseif msg_l == "status" then
      for k,v in pairs(GtamofoDB) do
        Print(verbose[k]..(v and ON or OFF))
      end
    else
      help()
    end
  end
end
SLASH_QUESTSOUNDBITS1 = "/questsoundbits"
SLASH_QUESTSOUNDBITS2 = "/questsounds"
SLASH_QUESTSOUNDBITS3 = "/qsb"