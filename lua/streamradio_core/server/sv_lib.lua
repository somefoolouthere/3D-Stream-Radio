local pairs = pairs
local IsValid = IsValid
local CreateConVar = CreateConVar

local LIBNet = StreamRadioLib.Net

local MaxServerSpectrum = CreateConVar( "sv_streamradio_max_spectrums", "5", bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_GAMEDLL ), "Sets the maximum count of radios that can have advanced wire outputs such as FFT spectrum or song tags. -1 = Infinite, 0 = Off, Default: 5" )
local AllowCustomURLs = CreateConVar( "sv_streamradio_allow_customurls", "1", bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_GAMEDLL ), "Allow or disallow custom URLs to be played. 1 = Allow, 0 = Disallow, Default: 1" )
local RebuildCommunityPlaylists = CreateConVar( "sv_streamradio_rebuildplaylists_community_auto", "2", bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_GAMEDLL ), "Set how the community playlists are rebuild on server start. 0 = Off, 1 = Rebuild only, 2 = Delete and rebuild, Default: 2" )

function StreamRadioLib.AllowSpectrum()
	if not WireAddon then return false end
	if not StreamRadioLib.Bass.CanLoadDLL() then return false end

	local max = MaxServerSpectrum:GetInt()
	if max == 0 then return false end
	if max < 0 then return true end
	if game.SinglePlayer() then return true end

	return StreamRadioLib.GetStreamingRadioCount() < max
end

function StreamRadioLib.IsCustomURLsAllowed()
	if ( game.SinglePlayer( ) ) then return true end
	if ( not StreamRadioLib.BlockedURLCode ) then return true end
	if ( StreamRadioLib.BlockedURLCode == "" ) then return true end

	return AllowCustomURLs:GetBool( )
end

function StreamRadioLib.IsBlockedCustomURL(url)
	url = url or ""

	if url == "" then
		return false
	end

	if StreamRadioLib.IsBlockedURLCode(url) then
		return false
	end

	if StreamRadioLib.IsOfflineURL(url) then
		return false
	end

	if not StreamRadioLib.IsCustomURLsAllowed() then
		return true
	end

	return false
end

function StreamRadioLib.FilterCustomURL(url)
	if StreamRadioLib.IsBlockedCustomURL(url) then
		return StreamRadioLib.BlockedURLCode
	end

	return url
end

function StreamRadioLib.GetRebuildCommunityPlaylistsMode()
	local mode = RebuildCommunityPlaylists:GetInt()

	if ( mode <= 0 ) then return 0 end
	if ( mode > 2 ) then return 0 end

	return mode
end

LIBNet.Receive("Control", function( len, ply )
	local trace = StreamRadioLib.Trace( ply )
	StreamRadioLib.Control(ply, trace, net.ReadBool())
end)
