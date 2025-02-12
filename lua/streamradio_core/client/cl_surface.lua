local StreamRadioLib = StreamRadioLib

StreamRadioLib.Surface = StreamRadioLib.Surface or {}
local LIB = StreamRadioLib.Surface

local cam = cam
local surface = surface
local string = string
local math = math
local draw = draw
local render = render
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local Color = Color

local g_font_template = {
	font = "Arial",
	size = 0,
	weight = 0,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false
}

local LoadingMat = StreamRadioLib.GetCustomPNG("loading")

local pi = math.pi
local color_white = color_white

function LIB.Loading( x, y, w, h, color, cycles )
	surface.SetMaterial( LoadingMat )
	color = color or color_white
	cycles = math.floor( cycles or 0 )

	if ( cycles < 5 ) then
		cycles = 5
	end

	local time = RealTime( )
	local midw = w / 2
	local midh = h / 2
	local cw = w / cycles * 2
	local ch = h / cycles * 2

	for i = 1, cycles do
		--local posang = pi * 2 / cycles * i + time
		local cx = math.cos( pi * 2 / cycles * i + time ) * ( midw - cw / 2 ) + x - cw / 2 + midw
		local cy = math.sin( pi * 2 / cycles * i + time ) * ( midh - cw / 2 ) + y - ch / 2 + midh
		surface.SetDrawColor( color:Unpack() )
		surface.DrawTexturedRect( cx, cy, cw, ch )
	end
end

LIB._CreatedFonts = LIB._CreatedFonts or {}

function LIB.AddFont(size, weight, base, additional_data)
	local ft = g_font_template

	size = tonumber(size) or ft.size
	weight = tonumber(weight) or ft.weight
	base = tostring(base or ft.font)

	local additional_data_name = ""

	for k, v in pairs(additional_data or {}) do
		additional_data_name = additional_data_name .. string.format("[%s=%s]", tostring(k), tostring(v))
	end

	local ID = string.format("3DStreamRadio_Font_{[%d][%d][%s]}{%s}", size, weight, base, additional_data_name)

	if LIB._CreatedFonts[ID] then
		return ID
	end

	local font = table.Copy(ft)

	for k, v in pairs(additional_data or {}) do
		font[k] = v
	end

	font.size = size
	font.weight = weight
	font.font = base

	surface.CreateFont( ID, font )

	LIB._CreatedFonts[ID] = true
	return ID
end

return true

