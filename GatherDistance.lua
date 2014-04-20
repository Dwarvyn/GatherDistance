-----------------------------------------------------------------------------------------------
-- Client Lua Script for GatherDistance
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "math"
 
-----------------------------------------------------------------------------------------------
-- GatherDistance Module Definition
-----------------------------------------------------------------------------------------------
local GatherDistance = {}

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function GatherDistance:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function GatherDistance:Init(luaUnitFrameSystem)
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		"TargetFrame",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 
function GatherDistance:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("GatherDistance.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function GatherDistance:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
		self.xmlDoc = nil
		Apollo.RegisterEventHandler("TargetUnitChanged", "ReWriteOnUpdate", self)
	end
end

-----------------------------------------------------------------------------------------------
-- GatherDistance Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

function GatherDistance:ReWriteOnUpdate()
	local origAddon = Apollo.GetAddon("TargetFrame")
	if origAddon and origAddon.luaTargetFrame then
		origAddon.luaTargetFrame.OnUpdate = GatherDistance.newOnUpdate
		Apollo.RemoveEventHandler("TargetUnitChanged", self)
	end
end

GatherDistance.newOnUpdate = function (self)
	local bTargetChanged = false
	local unitTarget = self.unitTarget
	local unitPlayer = GameLib.GetPlayerUnit()
	local bShowWindow = true
	local tCluster = nil
	
	self.arClusterFrames[1]:Show(self.arClusterFrames[1]:IsShown())
	
	if self.unitLastTarget == nil then
		bTargetChanged = true
		self:HelperResetTooltips() -- these get redrawn with the unitToT info
	end

	if unitTarget ~= nil and unitLastTarget ~= unitTarget then
		self.unitLastTarget = unitTarget
		bTargetChanged = true
		self:HelperResetTooltips() -- these get redrawn with the unitToT info
	end
	
	if unitTarget ~= nil then
		-- Cluster info
		tCluster = unitTarget:GetClusterUnits()
		
		if unitTarget == unitPlayer then
			--Treat Mount as a Cluster Target
			if unitPlayer:IsMounted() then
				table.insert(tCluster, unitPlayer:GetUnitMount())
			end
		end
		
		--Make the unit a cluster of a vehicle if they're in one.
		if unitTarget:IsInVehicle() then
			local uPlayer = unitTarget
			unitTarget = uPlayer:GetVehicle()
			
			table.insert(tCluster, uPlayer)
		end
		
		-- Treat Pets as Cluster Targets
		self.wndPetFrame:FindChild("PetContainerDespawnBtn"):SetData(nil)
		
		local tPlayerPets = GameLib.GetPlayerPets()
		if #tPlayerPets == 0 then
			self.tPets = {}
		end
		
		local bFillPets = #self.tPets < #tPlayerPets or #tPlayerPets == 0
		for k,v in ipairs(tPlayerPets) do
			if k == 1 then
				if bFillPets then
					table.insert(self.tPets, {v,24})
				end
				
				if v == unitTarget then
					self.wndPetFrame:FindChild("PetContainerDespawnBtn"):SetData(v)
				end
			elseif k == 2 then
				if bFillPets then
					table.insert(self.tPets, {v,36})
				end
				
				if v == unitTarget then
					self.wndPetFrame:FindChild("PetContainerDespawnBtn"):SetData(v)
				end
			end
			
			if k < 3 and unitTarget == unitPlayer then
				table.insert(tCluster, v)
			end
		end
		
		if self.tParams.bDrawClusters ~= true or tCluster == nil or #tCluster < 1 then
			tCluster = nil
		end

		-- Primary frame
		if unitTarget:GetHealth() ~= nil then
			self:UpdatePrimaryFrame(unitTarget, bTargetChanged)
		elseif string.len(unitTarget:GetName()) > 0 then
			self.wndSimpleFrame:Show(true, true)
			bShowWindow = false
			
			--<<Added code start! If this is interfering with/being interfered with by another addon, these lines will need to be>>
			--<<the ones to copy over to retain the funcionality in the new addon>>
			local targetPos = unitTarget:GetPosition()
			local playerPos = unitPlayer:GetPosition()
			local distance
			local strName
			if targetPos.x and targetPos.y and targetPos.z and playerPos.x and playerPos.y and playerPos.z then 
				distance = math.floor(math.sqrt((targetPos.x - playerPos.x) ^ 2 + (targetPos.y - playerPos.y) ^ 2 + (targetPos.z - playerPos.z) ^ 2) + .5)
				strName = unitTarget:GetName().." "..tostring(distance).."m"
			else
				strName = unitTarget:GetName()
			end
			--<<Added code end!>>
			local nLeft, nTop, nRight, nBottom = self.wndSimpleFrame:GetRect()
			local nWidth = nRight - nLeft
			local nCenter = nLeft + nWidth / 2
			nWidth = 30 + string.len(strName) * 10
			nLeft = nCenter - nWidth / 2
			self.wndSimpleFrame:Move(nLeft, nTop, nWidth, nBottom - nTop)
			--<<This line has also been changed from the original: self.wndSimpleFrame:FindChild("targetName"):SetText(unitTarget:GetName())>>
			self.wndSimpleFrame:FindChild("TargetName"):SetText(strName)

			if RewardIcons ~= nil and RewardIcons.GetUnitRewardIconsForm ~= nil then
				RewardIcons.GetUnitRewardIconsForm(self.wndSimpleFrame:FindChild("TargetGoalPanel"), unitTarget, {bVert = true})
			end
		end
	else
		bShowWindow = false
		self.wndSimpleFrame:Show(false)
		self:HideClusterFrames()
	end
	
	if bShowWindow and self.tParams.nConsoleVar ~= nil then
		--Toggle Visibility based on ui preference
		local unitPlayer = GameLib.GetPlayerUnit()
		local nVisibility = Apollo.GetConsoleVariable(self.tParams.nConsoleVar)
		
		if nVisibility == 2 then --always off
			bShowWindow = false
		elseif nVisibility == 3 then --on in combat
			bShowWindow = unitPlayer:IsInCombat()
		elseif nVisibility == 4 then --on out of combat
			bShowWindow = not unitPlayer:IsInCombat()
		else
			bShowWindow = true
		end
	end
	
	if bShowWindow and tCluster ~= nil and #tCluster > 0 then
		self:UpdateClusterFrame(tCluster)
	else
		self:HideClusterFrames()
	end
	
	self.arClusterFrames[1]:Show(bShowWindow)
end

-----------------------------------------------------------------------------------------------
-- GatherDistanceForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function GatherDistance:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function GatherDistance:OnCancel()
	self.wndMain:Close() -- hide the window
end


-----------------------------------------------------------------------------------------------
-- GatherDistance Instance
-----------------------------------------------------------------------------------------------
local GatherDistanceInst = GatherDistance:new()
GatherDistanceInst:Init()
