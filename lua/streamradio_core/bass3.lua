StreamRadioLib.Bass = StreamRadioLib.Bass or {}
local LIB = StreamRadioLib.Bass

local g_dll = "bass3"
local g_dllName = string.upper("gm_" .. g_dll)
local g_dllMinVersion = 14

local g_dllSupportedBranches = {
	["dev"] = true,
	["prerelease"] = true,
	["unknown"] = true,
	["none"] = true,
	["live"] = true,
	["main"] = true,
	[""] = true,
}

local g_bass_loaded = nil
local g_bass_dll_required = nil
local g_bass_can_loaded = nil
local g_bass_info_shown = nil

local g_cvar_cl_bass3_enable = nil
local g_cvar_sv_bass3_enable = nil
local g_cvar_sv_bass3_allow_client = nil

local function resetCache(...)
	g_bass_loaded = nil
	g_bass_can_loaded = nil
end

if SERVER then
	CreateConVar(
		"sv_streamradio_bass3_enable",
		"1",
		bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE ),
		"When set to 1, it uses GM_BASS3 on the server if installed. Default: 1",
		0,
		1
	)

	CreateConVar(
		"sv_streamradio_bass3_allow_client",
		"1",
		bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED ),
		"Allows connected clients to use GM_BASS3 when set to 1. Overrides cl_streamradio_bass3_enable. Default: 1",
		0,
		1
	)

	cvars.AddChangeCallback("sv_streamradio_bass3_enable", resetCache, "streamradio_bass3_callback")
end

if CLIENT then
	cvars.AddChangeCallback("cl_streamradio_bass3_enable", resetCache, "streamradio_bass3_callback")
	cvars.AddChangeCallback("sv_streamradio_bass3_allow_client", resetCache, "streamradio_bass3_callback")
end


local function printBass3Info()
	if g_bass_info_shown then
		return
	end

	g_bass_info_shown = true

	local baseString = string.format(
		"%s [color:100,200,100]loaded %s (ver. %s, %s)",
		StreamRadioLib.AddonTitle,
		g_dllName,
		BASS3.ModuleVersion or 0,
		BASS3.Version or 0
	)

	local message = nil

	if SERVER then
		message = "[color:100,200,100]Serverside streaming API for advanced wire outputs active!"
	else
		message = "[color:100,200,100]Clientside streaming API active!"
	end

	message = string.format(
		"%s:\n  %s",
		baseString,
		message
	)

	StreamRadioLib.Print.Wrapped(message)
end

local function onLoadBASS3()
	StreamRadioLib.Error.AddStreamErrorCode({
		id = 102,
		name = "STREAM_ERROR_BASS3_FILESYSTEM",
		description = "Valve Filesystem is missing in " .. g_dllName,
	})

	printBass3Info()
end

local function loadBASS3()
	if g_bass_dll_required ~= nil then
		-- only attempt to load gm_bass3 once
		return
	end

	g_bass_dll_required = false
	require(g_dll)

	if not BASS3 then
		error("Couldn't load '" .. g_dllName .. "'! BASS3 is missing!")
		return false
	end

	if not BASS3.Version then
		error("Couldn't load '" .. g_dllName .. "'! BASS3.Version is missing!")
		return false
	end

	if not BASS3.ModuleVersion then
		error("Couldn't load '" .. g_dllName .. "'! BASS3.ModuleVersion is missing!")
		return false
	end

	if not BASS3.ENUM then
		error("Couldn't load '" .. g_dllName .. "'! BASS3.ENUM is missing!")
		return false
	end

	local BassModuleVersion = tonumber(BASS3.ModuleVersion) or 0

	if BassModuleVersion < g_dllMinVersion then
		error("Couldn't load '" .. g_dllName .. "'! Version is outdated!")
		return false
	end

	g_bass_dll_required = true
	return true
end

function LIB.HasLoadedDLL()
	if not g_bass_dll_required then
		return false
	end

	if not BASS3 then
		return false
	end

	if not BASS3.Version then
		return false
	end

	if not BASS3.ModuleVersion then
		return false
	end

	if not BASS3.ENUM then
		return false
	end

	local BassModuleVersion = tonumber(BASS3.ModuleVersion) or 0

	if BassModuleVersion < g_dllMinVersion then
		return false
	end

	return true
end

function LIB.IsInstalled()
	if g_bass_dll_required == false then
		-- already attempted to load, but failed
		return false
	end

	local branch = tostring(BRANCH or "")

	if not g_dllSupportedBranches[branch] then
		-- GM_BASS3 is broken on some branches
		return false
	end

	if not util.IsBinaryModuleInstalled(g_dll) then
		return false
	end

	return true
end

function LIB.CanLoadDLL()
	if g_bass_loaded ~= nil then
		return g_bass_loaded
	end

	if g_bass_can_loaded ~= nil then
		return g_bass_can_loaded
	end

	g_bass_can_loaded = false

	if not LIB.IsInstalled() then
		return false
	end

	if SERVER then
		if not g_cvar_sv_bass3_enable then
			g_cvar_sv_bass3_enable = GetConVar("sv_streamradio_bass3_enable")
		end

		if g_cvar_sv_bass3_enable and g_cvar_sv_bass3_enable:GetInt() <= 0 then
			return false
		end
	end

	if CLIENT then
		if not g_cvar_cl_bass3_enable then
			g_cvar_cl_bass3_enable = GetConVar("cl_streamradio_bass3_enable")
		end

		if g_cvar_cl_bass3_enable and g_cvar_cl_bass3_enable:GetInt() <= 0 then
			return false
		end

		if not g_cvar_sv_bass3_allow_client then
			g_cvar_sv_bass3_allow_client = GetConVar("sv_streamradio_bass3_allow_client")
		end

		if g_cvar_sv_bass3_allow_client and g_cvar_sv_bass3_allow_client:GetInt() <= 0 then
			return false
		end
	end

	g_bass_can_loaded = true
	return true
end

function LIB.ClearCache()
	resetCache()
end

function LIB.LoadDLL()
	if g_bass_loaded ~= nil then
		return g_bass_loaded
	end

	if not LIB.CanLoadDLL() then
		g_bass_loaded = false
		return g_bass_loaded
	end

	if LIB.HasLoadedDLL() then
		onLoadBASS3()

		g_bass_loaded = true
		return g_bass_loaded
	end

	StreamRadioLib.CatchAndErrorNoHaltWithStack(loadBASS3)

	g_bass_loaded = LIB.HasLoadedDLL()

	if g_bass_loaded then
		onLoadBASS3()
	end

	return g_bass_loaded
end
