AddCSLuaFile()
DEFINE_BASECLASS( "base_streamradio_gui" )

local StreamRadioLib = StreamRadioLib
local LIBNetwork = StreamRadioLib.Network

ENT.Spawnable = false
ENT.AdminOnly = false
ENT.Editable = true

ENT.PrintName = "Stream Radio"
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.WireDebugName = ENT.PrintName

ENT.Sounds_Tune = Sound("buttons/lightswitch2.wav")
ENT.Sounds_Noise = Sound("stream_radio/noise.wav")
ENT.Sounds_Use = Sound("common/wpn_select.wav")

function ENT:SetupDataTables( )
	if not self.__IsLibLoaded then return end
	BaseClass.SetupDataTables(self)

	self:AddDTNetworkVar("Bool", "WireMode")
	self:AddDTNetworkVar("Bool", "ToolMode")
	self:AddDTNetworkVar("Entity", "LastUser")
	self:AddDTNetworkVar("Entity", "LastUsingEntity")
	self:AddDTNetworkVar("Entity", "MasterRadio")

	local adv_wire = nil

	if self.__IsWiremodLoaded then
		adv_wire = {
			KeyName = "DisableAdvancedOutputs",
			Edit = {
				category = "Wiremod",
				title = "Disable advanced outputs",
				type = "Boolean",
				order = 99,
			}
		}
	end

	self:AddDTNetworkVar("Bool", "DisableAdvancedOutputs", adv_wire)

	self:AddDTNetworkVar("Float", "Volume", {
		KeyName = "Volume",
		Edit = {
			category = "Stream",
			title = "Volume",
			type = "Float",
			order = 20,
			min = 0,
			max = 1,
		}
	})

	self:AddDTNetworkVar("Int", "Radius", {
		KeyName = "Radius",
		Edit = {
			category = "Stream",
			title = "Radius",
			type = "Int",
			order = 21,
			min = 0,
			max = 5000,
		}
	})

	self:AddDTNetworkVar("Bool", "Sound3D", {
		KeyName = "Sound3D",
		Edit = {
			category = "Stream",
			title = "Enable 3D sound",
			type = "Boolean",
			order = 22
		}
	})

	self:AddDTNetworkVar("Bool", "Loop", {
		KeyName = "Loop",
		Edit = {
			category = "Loop",
			title = "Enable song loop",
			type = "Boolean",
			order = 30
		}
	})

	self:AddDTNetworkVar( "Bool", "PlaylistLoop", {
		KeyName = "PlaylistLoop",
		Edit = {
			category = "Loop",
			title = "Enable playlist loop",
			type = "Boolean",
			order = 31
		}
	})

	LIBNetwork.SetDTVarCallback(self, "Loop", function(this, name, oldv, newv)
		if not IsValid(self) then return end

		if newv then
			self:SetPlaylistLoop(false)
		end

		self:MarkForUpdatePlaybackLoopMode()
	end)

	LIBNetwork.SetDTVarCallback(self, "PlaylistLoop", function(this, name, oldv, newv)
		if not IsValid(self) then return end

		if newv then
			self:SetLoop(false)
		end

		self:MarkForUpdatePlaybackLoopMode()
	end)
end

function ENT:GetPlaybackLoopMode()
	local loop = self:GetLoop()
	local playlistLoop = self:GetPlaylistLoop()

	if loop then
		return StreamRadioLib.PLAYBACK_LOOP_MODE_SONG
	end

	if playlistLoop then
		return StreamRadioLib.PLAYBACK_LOOP_MODE_PLAYLIST
	end

	return StreamRadioLib.PLAYBACK_LOOP_MODE_NONE
end

function ENT:SetPlaybackLoopMode(loopMode)
	if CLIENT then return end

	self:SetLoop(false)
	self:SetPlaylistLoop(false)

	if loopMode == StreamRadioLib.PLAYBACK_LOOP_MODE_PLAYLIST then
		self:SetPlaylistLoop(true)
	elseif loopMode == StreamRadioLib.PLAYBACK_LOOP_MODE_SONG then
		self:SetLoop(true)
	end

	self:MarkForUpdatePlaybackLoopMode()
end

function ENT:MarkForUpdatePlaybackLoopMode()
	self._callUpdatePlaybackLoopMode = true
end

function ENT:UpdatePlaybackLoopMode()
	self._callUpdatePlaybackLoopMode = nil

	local loopMode = self:GetPlaybackLoopMode()

	if IsValid(self.GUI_Main) then
		self.GUI_Main:UpdatePlaybackLoopMode(loopMode)
	end

	self.OnUpdatePlaybackLoopMode(loopMode)
end

function ENT:OnUpdatePlaybackLoopMode(loopMode)
	-- Override me
end

function ENT:GetMasterRadioRecursive()
	if not self.__IsLibLoaded then
		self._supermasterradio = nil
		return nil
	end

	if IsValid(self._supermasterradio) and self._supermasterradio.__IsRadio and IsValid(self._supermasterradio.StreamObj) then
		return self._supermasterradio
	end

	self._supermasterradio = nil

	local nodouble = {}
	local function recursive(radio, count)
		if nodouble[radio] then return nil end
		nodouble[radio] = true

		if count <= 0 then
			return nil
		end

		local masterradio = radio:GetMasterRadio()
		if not IsValid(masterradio) then return radio end
		if not masterradio.__IsRadio then return radio end
		if not IsValid(masterradio.StreamObj) then return radio end

		return recursive(masterradio, count - 1)
	end

	local supermasterradio = recursive(self, 10)
	if supermasterradio == self then return nil end

	if not IsValid(supermasterradio) then return nil end
	if not supermasterradio.__IsRadio then return nil end
	if not IsValid(supermasterradio.StreamObj) then return nil end

	self._supermasterradio = supermasterradio
	return supermasterradio
end

function ENT:GetSlaveRadios()
	local mr = self:GetMasterRadioRecursive()
	if mr then
		self.slavesradios = nil
	end

	self.slavesradios = self.slavesradios or {}

	for slave, v in pairs(self.slavesradios) do
		if not IsValid(slave) then
			self.slavesradios[slave] = nil
			continue
		end

		if not slave.__IsRadio then
			self.slavesradios[slave] = nil
			continue
		end

		if not IsValid(slave.StreamObj) then
			self.slavesradios[slave] = nil
			continue
		end

		if slave == self then
			self.slavesradios[slave] = nil
			continue
		end

		local slavemasterradio = slave:GetMasterRadioRecursive()
		if slavemasterradio ~= self then
			self.slavesradios[slave] = nil
			continue
		end
	end

	return self.slavesradios
end

function ENT:IsMutedForPlayer(ply)
	local muted = BaseClass.IsMutedForPlayer(self, ply)
	if not muted then return false end

	local slaves = self:GetSlaveRadios()

	for slave, v in pairs(slaves) do
		if not IsValid(slave) then continue end
		if not slave:IsMutedForPlayer(ply) then return false end
	end

	return true
end

function ENT:OnGUIShowCheck(ply)
	local masterradio = self:GetMasterRadioRecursive()
	if not masterradio then return true end

	local master_st = masterradio.StreamObj

	if master_st:GetError() ~= 0 then return true end
	if not master_st:IsStopMode() then return true end
	if master_st:GetURL() ~= "" then return true end

	if master_st:IsRunning() then return true end

	return false
end

function ENT:OnGUIInteractionCheck(ply, trace, userEntity)
	local masterradio = self:GetMasterRadioRecursive()
	if not masterradio then return true end

	local master_st = masterradio.StreamObj

	if master_st:GetError() ~= 0 then return true end
	if not master_st:IsStopMode() then return true end
	if master_st:GetURL() ~= "" then return true end

	if master_st:IsRunning() then return true end

	return false
end

function ENT:MasterRadioSyncThink()
	if not IsValid(self.StreamObj) then return end
	if not self.old then return end

	local masterradio = self:GetMasterRadioRecursive()
	local oldmasterradio = self.old.masterradio
	local statechange = false

	if masterradio ~= oldmasterradio then
		statechange = true

		if not masterradio then
			if IsValid(self.GUI_Main) then
				self.GUI_Main:SetSyncMode(false)
			end
		end

		if self._StopInternal then
			self:_StopInternal()
		end

		if IsValid(oldmasterradio) and oldmasterradio.slavesradios then
			oldmasterradio.slavesradios[self] = nil
		end

		if IsValid(masterradio) and masterradio.slavesradios then
			masterradio.slavesradios[self] = true
		end

		if self.OnMasterradioChange then
			self:OnMasterradioChange(masterradio, oldmasterradio)
		end
	end

	self.old.masterradio = masterradio
	if not masterradio then return end

	local this_st = self.StreamObj
	if not IsValid(this_st) then return end

	local master_st = masterradio.StreamObj
	if not IsValid(master_st) then return end

	self:SetPlaybackLoopMode(masterradio:GetPlaybackLoopMode())

	local name = master_st:GetStreamName()
	local url = master_st:GetURL()
	local playingstate = master_st:GetPlayingState()

	if name ~= this_st:GetStreamName() then
		this_st:SetStreamName(name)
		statechange = true
	end

	if url ~= this_st:GetURL() or statechange then
		this_st:SetURL(url)
		this_st:Update()
		statechange = true
	end

	this_st:SetPlayingState(playingstate)

	if statechange and IsValid(self.GUI_Main) then
		self.GUI_Main:SetSyncMode(true)

		self.GUI_Main:EnablePlaylist(false)
		self.GUI_Main:Play(name, url)
	end

	if SERVER then
		if statechange then
			self._lastMasterTime = nil
		end

		local targettime = master_st:GetMasterTime()
		local tickInterval = engine.TickInterval()

		local lastTargetTime = self._lastMasterTime;
		self._lastMasterTime = targettime


		local masterDelta = nil
		if lastTargetTime then
			masterDelta = math.abs(targettime - lastTargetTime)
		end

		local maxThisDelta = tickInterval * 2
		local maxMasterDelta = tickInterval * 4
		local realTime = RealTime()

		if statechange or (self._trySetTimeAgain and realTime > self._trySetTimeAgain) or (not masterDelta or masterDelta > maxMasterDelta) then
			this_st:SetTime(targettime, true)

			local thisCurtime = this_st:GetMasterTime()
			local thisDelta = math.abs(thisCurtime - targettime)

			if thisDelta > maxThisDelta then
				self._trySetTimeAgain = realTime + tickInterval * 8
			else
				self._trySetTimeAgain = nil
			end
		end
	end

	self._supermasterradio = nil
end

function ENT:PlaybackLoopModeThink()
	if not self._callUpdatePlaybackLoopMode then
		return
	end

	self:UpdatePlaybackLoopMode()
end

function ENT:PanelThink()
	if not IsValid(self.GUI_Main) then
		return
	end

	local hasTool = self:GetToolMode()
	local hasWire = self:GetWireMode()

	self.GUI_Main.Browser.ToolButton:SetEnabled(hasTool)
	self.GUI_Main.Browser.WireButton:SetEnabled(hasWire)
end

function ENT:OnToolButtonClick()
	local hasTool = self:GetToolMode()
	if not hasTool then return end
	if not self.OnToolMode then return end

	self:OnToolMode()
end

function ENT:OnWireButtonClick()
	local hasWire = self:GetWireMode()
	if not hasWire then return end
	if not self.__IsWiremodLoaded then return end
	if not self.OnWireMode then return end

	self:OnWireMode()
end

function ENT:StreamStopAnimModel()
	if not self.AnimStopped then
		if CLIENT then
			self:CallModelFunction("Speaker")
			self:CallModelFunction("Beat")
			self:CallModelFunction("FFT")
			self:CallModelFunction("SoundLevel")
		end

		self:CallModelFunction("AnimReset")
	end

	if self.old then
		self.old.beatlevel = nil
	end

	self.AnimStopped = true
end

function ENT:OnSetupModelSetup()
	if IsValid(self.GUI_Main) then
		self.GUI_Main.OnPlaybackLoopModeChange = function(this, newLoopMode)
			if not IsValid(self) then return end
			self:SetPlaybackLoopMode(newLoopMode)
		end
	end

	self.AnimStopped = nil
	self:StreamStopAnimModel()
end

function ENT:OnRemoveShared()
end