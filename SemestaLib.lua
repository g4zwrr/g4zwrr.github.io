--[[
    Semesta v3.4 - UI Library
    Load: local Semesta = loadstring(game:HttpGet("https://g4zwr.is-a.dev/SemestaLib.lua"))()
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local floor, min, max, abs, sqrt, ceil = math.floor, math.min, math.max, math.abs, math.sqrt, math.ceil
local clamp = math.clamp
local atan2, rad, deg, cos, sin = math.atan2, math.rad, math.deg, math.cos, math.sin

local Semesta = { Version = "3.4" }
local SIDE_W, SIDE_MINI, HEAD_H = 150, 54, 42
local LUARMOR_LIB = "https://sdkapi-public.luarmor.net/library.lua"

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function cornerOf(o, r)
	return new("UICorner", { CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r) }, o)
end

local function safeCall(fn, ...)
	if not fn then return end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[Semesta] " .. tostring(err)) end
end

local function hexOf(c)
	return string.format("#%02X%02X%02X",
		floor(c.R * 255 + 0.5), floor(c.G * 255 + 0.5), floor(c.B * 255 + 0.5))
end

---------------------------------------------------------------------------
-- Animation engine
---------------------------------------------------------------------------
local Anim = { jobs = {}, springs = {}, cyclers = {}, byObj = setmetatable({}, { __mode = "k" }) }
local loopConn

local EASE = {
	Linear = function(t) return t end,
	Out = function(t) local u = 1 - t; return 1 - u * u * u end,
	InOut = function(t)
		if t < 0.5 then return 4 * t * t * t end
		local u = -2 * t + 2
		return 1 - u * u * u / 2
	end,
	Back = function(t)
		local c = 1.70158
		local u = t - 1
		return 1 + (c + 1) * u * u * u + c * u * u
	end,
}

local function lerpAny(a, b, t)
	local ty = typeof(a)
	if ty == "number" then return a + (b - a) * t end
	if ty == "Color3" or ty == "Vector2" then return a:Lerp(b, t) end
	if ty == "UDim2" then
		return UDim2.new(
			a.X.Scale + (b.X.Scale - a.X.Scale) * t, a.X.Offset + (b.X.Offset - a.X.Offset) * t,
			a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t)
	end
	if t >= 1 then return b end
	return a
end

local function animBusy()
	return #Anim.jobs > 0 or next(Anim.springs) ~= nil or #Anim.cyclers > 0
end

local function ensureLoop()
	if loopConn then return end
	loopConn = RunService.Heartbeat:Connect(function(dt)
		dt = min(dt, 1 / 30)
		local now = os.clock()

		local list = Anim.jobs
		Anim.jobs = {}
		for i = 1, #list do
			local j = list[i]
			local alive = not j.cancelled and j.obj.Parent ~= nil
			if alive then
				local t = min(1, (now - j.t0) / j.dur)
				local e = j.ease(t)
				for p, a in pairs(j.from) do j.obj[p] = lerpAny(a, j.to[p], e) end
				if t >= 1 then
					alive = false
					if Anim.byObj[j.obj] == j then Anim.byObj[j.obj] = nil end
					if j.done then j.done() end
				end
			end
			if alive then Anim.jobs[#Anim.jobs + 1] = j end
		end

		for key, s in pairs(Anim.springs) do
			local a = -s.k * (s.x - s.target) - s.c * s.v
			s.v += a * dt
			s.x += s.v * dt
			if abs(s.x - s.target) < 0.0005 and abs(s.v) < 0.005 then
				s.x, s.v = s.target, 0
				Anim.springs[key] = nil
			end
			s.set(s.x)
		end

		local cy, n = Anim.cyclers, 0
		for i = 1, #cy do
			local c = cy[i]
			if not c.dead then
				n += 1; cy[n] = c
				c.acc += dt
				if c.acc >= c.every then c.acc = 0; c.fn(now) end
			end
		end
		for i = #cy, n + 1, -1 do cy[i] = nil end

		if not animBusy() then loopConn:Disconnect(); loopConn = nil end
	end)
end

function Anim.to(obj, props, dur, style, done)
	local prev = Anim.byObj[obj]
	local from = {}
	for p in pairs(props) do
		from[p] = obj[p]
		if prev then prev.from[p] = nil; prev.to[p] = nil end
	end
	if prev and next(prev.from) == nil then prev.cancelled = true end
	local j = {
		obj = obj, from = from, to = props, t0 = os.clock(), dur = max(dur or 0.25, 0.001),
		ease = EASE[style or "Out"] or EASE.Out, done = done,
	}
	Anim.byObj[obj] = j
	Anim.jobs[#Anim.jobs + 1] = j
	ensureLoop()
	return j
end

function Anim.spring(key, target, set, start)
	local s = Anim.springs[key]
	if not s then
		s = { x = start or target, v = 0 }
		Anim.springs[key] = s
	end
	s.target, s.set = target, set
	s.k, s.c = 280, 20
	set(s.x)
	ensureLoop()
end

function Anim.cycle(fn, hz)
	local h = { fn = fn, every = 1 / (hz or 30), acc = 0, dead = false }
	Anim.cyclers[#Anim.cyclers + 1] = h
	ensureLoop()
	return h
end

---------------------------------------------------------------------------
-- Themes
---------------------------------------------------------------------------
local PRESETS = {
	Midnight = { Bg = rgb(17, 17, 23), Panel = rgb(24, 24, 33), Item = rgb(33, 33, 44), Line = rgb(52, 52, 68), Accent = rgb(124, 111, 255), Text = rgb(240, 240, 245), Dim = rgb(150, 150, 166), On = rgb(255, 255, 255) },
	Ocean = { Bg = rgb(10, 22, 34), Panel = rgb(15, 32, 48), Item = rgb(23, 46, 66), Line = rgb(38, 68, 94), Accent = rgb(80, 170, 255), Text = rgb(230, 242, 255), Dim = rgb(130, 160, 186), On = rgb(255, 255, 255) },
	Forest = { Bg = rgb(14, 24, 18), Panel = rgb(20, 34, 26), Item = rgb(30, 50, 38), Line = rgb(46, 72, 56), Accent = rgb(90, 220, 140), Text = rgb(232, 245, 236), Dim = rgb(140, 170, 150), On = rgb(10, 30, 18) },
	Sunset = { Bg = rgb(26, 16, 18), Panel = rgb(36, 23, 26), Item = rgb(52, 33, 37), Line = rgb(80, 52, 58), Accent = rgb(255, 140, 70), Text = rgb(255, 240, 235), Dim = rgb(180, 140, 135), On = rgb(255, 255, 255) },
	Rose = { Bg = rgb(24, 14, 22), Panel = rgb(34, 21, 32), Item = rgb(50, 31, 47), Line = rgb(78, 48, 72), Accent = rgb(255, 110, 160), Text = rgb(255, 238, 246), Dim = rgb(175, 135, 162), On = rgb(255, 255, 255) },
	Mono = { Bg = rgb(12, 12, 12), Panel = rgb(20, 20, 20), Item = rgb(30, 30, 30), Line = rgb(52, 52, 52), Accent = rgb(230, 230, 230), Text = rgb(245, 245, 245), Dim = rgb(150, 150, 150), On = rgb(10, 10, 10) },
	Light = { Bg = rgb(240, 242, 246), Panel = rgb(228, 231, 238), Item = rgb(255, 255, 255), Line = rgb(200, 205, 216), Accent = rgb(80, 110, 255), Text = rgb(30, 32, 40), Dim = rgb(110, 115, 130), On = rgb(255, 255, 255) },
}
local PRESET_ORDER = { "Midnight", "Ocean", "Forest", "Sunset", "Rose", "Mono", "Light" }
local THEME_KEYS = { "Bg", "Panel", "Item", "Line", "Accent", "Text", "Dim", "On" }

local FONT_LIST = {
	-- Classic & Standard Fonts
	"Legacy",
	"Arial",                  -- Removed (maps to Arimo)
	"ArialBold",              -- Removed (maps to Arimo)
	"SourceSans",
	"SourceSansBold",
	"SourceSansLight",
	"SourceSansItalic",
	"SourceSansSemibold",
	
	-- Serif & Traditional Fonts
	"Bodoni",
	"Garamond",
	"Merriweather",
	"Antique",
	
	-- Monospace & Clean
	"Code",                   -- Inconsolata
	"Roboto",
	"RobotoCondensed",
	"RobotoMono",
	
	-- Sans-Serif & Modern Families
	"Ubuntu",
	"Nunito",
	"JosefinSans",
	"Jura",
	"Oswald",
	"TitilliumWeb",
	"Sarpanch",
	"Michroma",
	"Arimo",
	"ArimoBold",
	
	-- Builder Sans Family
	"BuilderSans",
	"BuilderSansMedium",
	"BuilderSansBold",
	"BuilderSansExtraBold",
	
	-- Gotham Family (Removed / maps to Montserrat)
	"Gotham",
	"GothamMedium",
	"GothamBold",
	"GothamBlack",
	
	-- Stylized, Comic & Display Fonts
	"Cartoon",                -- Comic Neue Angular
	"Highway",                -- Highway Gothic
	"SciFi",                  -- Zekton
	"Arcade",                 -- Press Start 2P
	"Fantasy",                -- Balthazar
	"AmaticSC",
	"Bangers",
	"Creepster",
	"DenkOne",
	"Fondamento",
	"FredokaOne",
	"GrenzeGotisch",
	"IndieFlower",
	"Kalam",
	"LuckiestGuy",
	"PatrickHand",
	"PermanentMarker",
	"SpecialElite",
	
	-- Fallback / Edge Case
	"Unknown"                 -- Used when a custom FontFace has no enum equivalent
}


local function resolveTheme(v)
	local baseName = "Midnight"
	if type(v) == "string" and PRESETS[v] then baseName = v
	elseif type(v) == "table" and v.Base and PRESETS[v.Base] then baseName = v.Base end
	local t = {}
	for k, c in pairs(PRESETS[baseName]) do t[k] = c end
	if type(v) == "table" then
		for k, c in pairs(v) do
			if t[k] ~= nil and typeof(c) == "Color3" then t[k] = c end
		end
	end
	return t
end

local Theme = resolveTheme("Midnight")
local groups = {}
local fnGroup = {}
local fontList = {}
local CurrentFont = Enum.Font.GothamMedium
local iconParts = setmetatable({}, { __mode = "k" })

local function prune(list)
	local n = 0
	for i = 1, #list do
		local e = list[i]
		if e[1].Parent ~= nil then n += 1; list[n] = e end
	end
	for i = #list, n + 1, -1 do list[i] = nil end
	return list
end

local function tintIcon(holder, color)
	local p = iconParts[holder]
	if not p then return end
	for _, f in ipairs(p.frames) do f.BackgroundColor3 = color end
	for _, s in ipairs(p.strokes) do s.Color = color end
end

local function applyValue(o, prop, v)
	if prop == "__icon" then tintIcon(o, v) else o[prop] = v end
end

local function bind(obj, prop, key)
	if type(key) == "function" then
		fnGroup[#fnGroup + 1] = { obj, prop, key }
		applyValue(obj, prop, key(Theme))
	else
		local g = groups[key]
		if not g then g = {}; groups[key] = g end
		g[#g + 1] = { obj, prop }
		applyValue(obj, prop, Theme[key])
	end
	return obj
end

local function repaint(keys, animate)
	local budget = 160
	for _, key in ipairs(keys) do
		local g = prune(groups[key] or {})
		groups[key] = g
		local v = Theme[key]
		for i = 1, #g do
			local e = g[i]
			if animate and budget > 0 and e[2] ~= "__icon" then
				budget -= 1
				Anim.to(e[1], { [e[2]] = v }, 0.35)
			else
				applyValue(e[1], e[2], v)
			end
		end
	end
	prune(fnGroup)
	for i = 1, #fnGroup do
		local e = fnGroup[i]
		applyValue(e[1], e[2], e[3](Theme))
	end
end

local function setTheme(t)
	for k, c in pairs(t) do Theme[k] = c end
end

local function text(parent, str, size, key, align)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = str or "", TextSize = size or 13, Font = CurrentFont,
		TextXAlignment = align or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
	fontList[#fontList + 1] = l
	bind(l, "TextColor3", key or "Text")
	return l
end

---------------------------------------------------------------------------
-- Icons
---------------------------------------------------------------------------
local Icons = { cache = {}, dir = "Semesta_icons" }
local ICON_URL = "https://unpkg.com/lucide-static/icons/%s.svg"

local function bezier(pts, x0, y0, x1, y1, x2, y2, x3, y3)
	local l = sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) + sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) + sqrt((x3 - x2) ^ 2 + (y3 - y2) ^ 2)
	local n = clamp(ceil(l / 4), 3, 10)
	for i = 1, n do
		local t, u = i / n, 1 - i / n
		pts[#pts + 1] = {
			u * u * u * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * x3,
			u * u * u * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * y3,
		}
	end
end

local function arc(pts, x1, y1, rx, ry, phi, fa, fs, x2, y2)
	if rx == 0 or ry == 0 or (x1 == x2 and y1 == y2) then pts[#pts + 1] = { x2, y2 }; return end
	rx, ry = abs(rx), abs(ry)
	local p = rad(phi)
	local c, s = cos(p), sin(p)
	local dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
	local x1p, y1p = c * dx + s * dy, -s * dx + c * dy
	local lam = x1p ^ 2 / rx ^ 2 + y1p ^ 2 / ry ^ 2
	if lam > 1 then local k = sqrt(lam); rx, ry = rx * k, ry * k end
	local num = rx ^ 2 * ry ^ 2 - rx ^ 2 * y1p ^ 2 - ry ^ 2 * x1p ^ 2
	local den = rx ^ 2 * y1p ^ 2 + ry ^ 2 * x1p ^ 2
	local co = sqrt(max(0, num / den))
	if fa == fs then co = -co end
	local cxp, cyp = co * rx * y1p / ry, -co * ry * x1p / rx
	local cx = c * cxp - s * cyp + (x1 + x2) / 2
	local cy = s * cxp + c * cyp + (y1 + y2) / 2
	local function ang(ux, uy, vx, vy) return atan2(ux * vy - uy * vx, ux * vx + uy * vy) end
	local th1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
	local dth = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
	if fs == 0 and dth > 0 then dth -= 2 * math.pi
	elseif fs == 1 and dth < 0 then dth += 2 * math.pi end
	local n = clamp(ceil(abs(dth) * sqrt(max(rx, ry))), 4, 24)
	for i = 1, n do
		local t = th1 + dth * i / n
		pts[#pts + 1] = {
			c * rx * cos(t) - s * ry * sin(t) + cx,
			s * rx * cos(t) + c * ry * sin(t) + cy,
		}
	end
end

local function parsePath(d)
	local paths, cur = {}, nil
	local pos, cx, cy, sx, sy, lcx, lcy, prev, cmd = 1, 0, 0, 0, 0, 0, 0, nil, nil
	local function skip() pos = d:find("[^%s,]", pos) or (#d + 1) end
	local function num()
		skip()
		local s, e = d:find("^[-+]?%d*%.?%d+", pos)
		if not s then error("number expected") end
		pos = e + 1
		return tonumber(d:sub(s, e))
	end
	local function flag() skip(); local c = d:sub(pos, pos); pos += 1; return c == "1" end
	local function ensure()
		if not cur then cur = { pts = { { cx, cy } }, closed = false }; paths[#paths + 1] = cur end
		return cur.pts
	end
	while true do
		skip()
		if pos > #d then break end
		local ch = d:sub(pos, pos)
		if ch:match("%a") then cmd = ch; pos += 1 end
		if not cmd then error("no command") end
		if cmd == "Z" or cmd == "z" then
			if cur then cur.closed = true end
			cx, cy, cur, prev, cmd = sx, sy, nil, "Z", nil
		else
			local rel = cmd == cmd:lower()
			local C = cmd:upper()
			local ox, oy = rel and cx or 0, rel and cy or 0
			if C == "M" then
				cx, cy = num() + ox, num() + oy
				sx, sy = cx, cy
				cur = nil; ensure(); prev = "M"
				cmd = rel and "l" or "L"
			elseif C == "L" then
				local p = ensure(); cx, cy = num() + ox, num() + oy
				p[#p + 1] = { cx, cy }; prev = "L"
			elseif C == "H" then
				local p = ensure(); cx = num() + ox
				p[#p + 1] = { cx, cy }; prev = "H"
			elseif C == "V" then
				local p = ensure(); cy = num() + oy
				p[#p + 1] = { cx, cy }; prev = "V"
			elseif C == "C" or C == "S" then
				local p = ensure()
				local x1, y1
				if C == "C" then x1, y1 = num() + ox, num() + oy
				elseif prev == "C" or prev == "S" then x1, y1 = 2 * cx - lcx, 2 * cy - lcy
				else x1, y1 = cx, cy end
				local x2, y2 = num() + ox, num() + oy
				local x, y = num() + ox, num() + oy
				bezier(p, cx, cy, x1, y1, x2, y2, x, y)
				lcx, lcy, cx, cy, prev = x2, y2, x, y, C
			elseif C == "Q" or C == "T" then
				local p = ensure()
				local qx, qy
				if C == "Q" then qx, qy = num() + ox, num() + oy
				elseif prev == "Q" or prev == "T" then qx, qy = 2 * cx - lcx, 2 * cy - lcy
				else qx, qy = cx, cy end
				local x, y = num() + ox, num() + oy
				bezier(p, cx, cy, cx + 2 / 3 * (qx - cx), cy + 2 / 3 * (qy - cy), x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y), x, y)
				lcx, lcy, cx, cy, prev = qx, qy, x, y, C
			elseif C == "A" then
				local p = ensure()
				local rx, ry, phi = num(), num(), num()
				local fa, fs = flag(), flag()
				local x, y = num() + ox, num() + oy
				arc(p, cx, cy, rx, ry, phi, fa and 1 or 0, fs and 1 or 0, x, y)
				cx, cy, prev = x, y, "A"
			else
				error("unsupported command " .. cmd)
			end
		end
	end
	return paths
end

local function simplify(pts, eps)
	local n = #pts
	if n < 3 then return pts end
	local keep = { [1] = true, [n] = true }
	local function rec(i, j)
		local ax, ay, bx, by = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
		local dx, dy = bx - ax, by - ay
		local l2 = dx * dx + dy * dy
		local md, mi = 0, nil
		for k = i + 1, j - 1 do
			local px, py = pts[k][1], pts[k][2]
			local dist
			if l2 == 0 then dist = sqrt((px - ax) ^ 2 + (py - ay) ^ 2)
			else dist = abs(dx * (ay - py) - (ax - px) * dy) / sqrt(l2) end
			if dist > md then md, mi = dist, k end
		end
		if mi and md > eps then keep[mi] = true; rec(i, mi); rec(mi, j) end
	end
	rec(1, n)
	local out = {}
	for i = 1, n do if keep[i] then out[#out + 1] = pts[i] end end
	return out
end

local function buildTemplate(svg)
	local th = tonumber(svg:match('stroke%-width="([%d%.]+)"')) or 2
	local root = new("Frame", { Name = "IconTpl", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(24, 24) })
	local white = Color3.new(1, 1, 1)

	local function seg(ax, ay, bx, by)
		local dx, dy = bx - ax, by - ay
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(sqrt(dx * dx + dy * dy) + th, th),
			Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2), Rotation = deg(atan2(dy, dx)),
			BackgroundColor3 = white, BorderSizePixel = 0, Active = false,
		}, root)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
	end

	local function poly(pts, closed)
		pts = simplify(pts, 0.15)
		if closed and #pts > 2 then
			pts = table.clone(pts); pts[#pts + 1] = pts[1]
		end
		if #pts == 1 then pts = { pts[1], pts[1] } end
		for i = 1, #pts - 1 do seg(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]) end
	end

	local function native(cx, cy, w, h, cr, ellipse)
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
			Size = UDim2.fromOffset(max(w - th, 0), max(h - th, 0)), Position = UDim2.fromOffset(cx, cy),
		}, root)
		if ellipse then new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
		elseif cr - th / 2 > 0.3 then new("UICorner", { CornerRadius = UDim.new(0, cr - th / 2) }, f) end
		local s = new("UIStroke", { Color = white, Thickness = th, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
		s.LineJoinMode = Enum.LineJoinMode.Round
	end

	local function attrsOf(s)
		local t = {}
		for k, v in s:gmatch('([%w%-]+)="([^"]*)"') do t[k] = v end
		return t
	end
	local function nums(s)
		local out = {}
		for n in tostring(s):gmatch("[-+]?%d*%.?%d+") do out[#out + 1] = tonumber(n) end
		return out
	end

	for tag, a in svg:gmatch("<(%a+)%s([^>]-)/?>") do
		local at = attrsOf(a)
		local function n(k, d) return tonumber(at[k]) or d or 0 end
		if tag == "path" and at.d then
			local ok, subs = pcall(parsePath, at.d)
			if ok then for _, s in ipairs(subs) do poly(s.pts, s.closed) end end
		elseif tag == "line" then
			poly({ { n("x1"), n("y1") }, { n("x2"), n("y2") } }, false)
		elseif (tag == "polyline" or tag == "polygon") and at.points then
			local v, pts = nums(at.points), {}
			for i = 1, #v - 1, 2 do pts[#pts + 1] = { v[i], v[i + 1] } end
			poly(pts, tag == "polygon")
		elseif tag == "rect" then
			local w, h = n("width"), n("height")
			native(n("x") + w / 2, n("y") + h / 2, w, h, min(n("rx", n("ry")), w / 2, h / 2), false)
		elseif tag == "circle" then
			local r = n("r"); native(n("cx"), n("cy"), r * 2, r * 2, 0, true)
		elseif tag == "ellipse" then
			native(n("cx"), n("cy"), n("rx") * 2, n("ry") * 2, 0, true)
		end
	end
	new("UIScale", { Scale = 1 }, root)
	return root
end

function Icons.get(name)
	local c = Icons.cache[name]
	if c ~= nil then return c or nil end
	local safe = (name:gsub("[^%w%-_]", "_"))
	local path = Icons.dir .. "/" .. safe .. ".svg"
	local svg
	if isfile and readfile and isfile(path) then
		pcall(function() svg = readfile(path) end)
	end
	if not svg or not svg:find("<svg") then
		local url = name:find("^https?://") and name or ICON_URL:format(name)
		local ok, res = pcall(game.HttpGet, game, url)
		if ok and type(res) == "string" and res:find("<svg") then
			svg = res
			if writefile then
				pcall(function()
					if makefolder and isfolder and not isfolder(Icons.dir) then makefolder(Icons.dir) end
					writefile(path, svg)
				end)
			end
		end
	end
	local tpl = false
	if svg then
		local ok, built = pcall(buildTemplate, svg)
		if ok then tpl = built end
	end
	Icons.cache[name] = tpl
	return tpl or nil
end

function Icons.make(parent, name, size, key)
	local holder = new("Frame", {
		Name = "Icon_" .. tostring(name), BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size), Active = false,
	}, parent)
	bind(holder, "__icon", key or "Dim")
	task.spawn(function()
		local tpl = Icons.get(name)
		if not tpl or not holder.Parent then return end
		local c = tpl:Clone()
		c.UIScale.Scale = size / 24
		c.Parent = holder
		local frames, strokes = {}, {}
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("Frame") and d.BackgroundTransparency < 1 then frames[#frames + 1] = d
			elseif d:IsA("UIStroke") then strokes[#strokes + 1] = d end
		end
		iconParts[holder] = { frames = frames, strokes = strokes }
		local k = key or "Dim"
		tintIcon(holder, type(k) == "function" and k(Theme) or Theme[k])
	end)
	return holder
end

---------------------------------------------------------------------------
-- Key checking
---------------------------------------------------------------------------
local function checkKey(ks, key)
	if not key or key == "" then return false, "Enter a key" end
	if ks.Provider == "luarmor" then
		if not ks.ScriptId then return false, "Missing ScriptId in KeySystem" end
		if not ks._lib then
			local ok, lib = pcall(function() return loadstring(game:HttpGet(LUARMOR_LIB))() end)
			if not ok or type(lib) ~= "table" then return false, "Could not load Luarmor library" end
			lib.script_id = ks.ScriptId
			ks._lib = lib
		end
		local lib = ks._lib
		pcall(function() getgenv().script_key = key end)
		local ok, status = pcall(lib.check_key, key)
		if not ok or type(status) ~= "table" then return false, "Luarmor check failed" end
		if status.code == "KEY_VALID" then
			ks._status = status
			return true, "Key accepted"
		end
		local map = {
			KEY_INCORRECT = "Invalid key",
			KEY_HWID_LOCKED = "Key is locked to another device.",
			KEY_EXPIRED = "This key has expired",
			KEY_BANNED = "This key is banned",
		}
		return false, map[status.code] or status.message or ("Error: " .. tostring(status.code))
	end
	if ks.Validate then
		local ok, res, msg = pcall(ks.Validate, key)
		if not ok then return false, "Validation error" end
		return res == true, msg or (res and "Key accepted" or "Invalid key")
	end
	if ks.Keys then
		for _, k in ipairs(ks.Keys) do
			if k == key then return true, "Key accepted" end
		end
		return false, "Invalid key"
	end
	if ks.Url then
		local okReq, body = pcall(game.HttpGet, game, ks.Url:format(HttpService:UrlEncode(key)))
		if not okReq then return false, "Could not reach key server" end
		if ks.Check then
			local ok, res = pcall(ks.Check, body)
			local good = ok and res == true
			return good, good and "Key accepted" or "Invalid key"
		end
		local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
		if ok and type(data) == "table" then
			local good = data.valid == true or data.success == true
			return good, data.message or (good and "Key accepted" or "Invalid key")
		end
		local good = body == "valid" or body == "true"
		return good, good and "Key accepted" or "Invalid key"
	end
	return false, "No key provider configured"
end

---------------------------------------------------------------------------
-- Row helpers
---------------------------------------------------------------------------
local function makeRow(Tab, h, name, noBg)
	local Win = Tab.Win
	Tab.Count += 1
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, h), BorderSizePixel = 0, LayoutOrder = Tab.Count }, Tab.page)
	if noBg then
		f.BackgroundTransparency = 1
	else
		bind(f, "BackgroundColor3", "Item")
		Win._corners[#Win._corners + 1] = cornerOf(f, Win.Radius)
		local s = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = Win.Borders and 0.3 or 1 }, f)
		bind(s, "Color", "Line")
		Win._strokes[#Win._strokes + 1] = s
	end
	local item = { frame = f, name = (name or ""):lower(), tab = Tab }
	Win.Items[#Win.Items + 1] = item
	Tab.Items[#Tab.Items + 1] = item
	return f, item
end

local function rowIcon(f, name, size, yOff)
	size = size or 18
	if not name then return 12 end
	local ic = Icons.make(f, name, size, "Dim")
	ic.AnchorPoint = Vector2.new(0, 0.5)
	ic.Position = yOff and UDim2.fromOffset(12, yOff) or UDim2.new(0, 12, 0.5, 0)
	return 12 + size + 10
end

local function thumb(f, image, x, y, size)
	local img = new("ImageLabel", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Active = false,
		Image = image, ScaleType = Enum.ScaleType.Crop,
	}, f)
	cornerOf(img, 5)
	bind(img, "BackgroundColor3", "Panel")
	return img
end

local function pressable(f)
	local sc = new("UIScale", {}, f)
	local hit = new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Active = true,
		Size = UDim2.fromScale(1, 1), ZIndex = f.ZIndex,
	}, f)
	local function squish(target)
		Anim.spring(sc, target, function(v) sc.Scale = v end, sc.Scale)
	end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then squish(0.97) end
	end)
	hit.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then squish(1) end
	end)
	return hit
end

local function dragTo(hitFrame, onX)
	hitFrame.InputBegan:Connect(function(i)
		local ut = i.UserInputType
		if ut ~= Enum.UserInputType.MouseButton1 and ut ~= Enum.UserInputType.Touch then return end
		onX(i.Position.X)
		local mv, up
		mv = UIS.InputChanged:Connect(function(m)
			if m.UserInputType == Enum.UserInputType.MouseMovement or m.UserInputType == Enum.UserInputType.Touch then
				onX(m.Position.X)
			end
		end)
		up = UIS.InputEnded:Connect(function(e)
			if e.UserInputType == ut then mv:Disconnect(); up:Disconnect() end
		end)
	end)
end

local function dragXY(hitFrame, onXY)
	hitFrame.InputBegan:Connect(function(i)
		local ut = i.UserInputType
		if ut ~= Enum.UserInputType.MouseButton1 and ut ~= Enum.UserInputType.Touch then return end
		onXY(i.Position.X, i.Position.Y)
		local mv, up
		mv = UIS.InputChanged:Connect(function(m)
			if m.UserInputType == Enum.UserInputType.MouseMovement or m.UserInputType == Enum.UserInputType.Touch then
				onXY(m.Position.X, m.Position.Y)
			end
		end)
		up = UIS.InputEnded:Connect(function(e)
			if e.UserInputType == ut then mv:Disconnect(); up:Disconnect() end
		end)
	end)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
function Semesta:CreateWindow(cfg)
	cfg = cfg or {}
	local W, H = 580, 390
	if typeof(cfg.Size) == "Vector2" then W, H = cfg.Size.X, cfg.Size.Y end
	local title = cfg.Title or "Semesta"
	local saveName = cfg.SaveName or "Semesta"
	local guiName = cfg.GuiName or "Semesta"
	local conns = {}
	local function keep(c) conns[#conns + 1] = c; return c end

	local Win = {
		Tabs = {}, Items = {}, Flags = {}, ActiveTab = nil,
		Layout = cfg.Layout == "Topbar" and "Topbar" or "Sidebar",
		Collapsed = false, Minimized = false, Visible = false, Unlocked = false,
		Radius = cfg.Radius or 12, Borders = cfg.Borders ~= false,
		W = W, H = H, _corners = {}, _strokes = {}, _closers = {},
	}

	if isfile and readfile then
		pcall(function()
			local p = saveName .. ".json"
			if isfile(p) then Win.Flags = HttpService:JSONDecode(readfile(p)) end
		end)
	end
	local function getFlag(name, default)
		if name and Win.Flags[name] ~= nil then return Win.Flags[name] end
		return default
	end
	local saveQueued = false
	local function queueSave()
		if not writefile or saveQueued then return end
		saveQueued = true
		task.delay(0.6, function()
			saveQueued = false
			pcall(writefile, saveName .. ".json", HttpService:JSONEncode(Win.Flags))
		end)
	end
	local function setFlag(name, v)
		if not name then return end
		Win.Flags[name] = v
		queueSave()
	end
	function Win:GetFlag(n, d) return getFlag(n, d) end
	function Win:SetFlag(n, v) setFlag(n, v) end
	function Win:AddCloser(fn) Win._closers[#Win._closers + 1] = fn end

	local host
	local okH, hh = pcall(function() return gethui and gethui() end)
	if okH and hh then host = hh end
	if not host then
		local okC, cg = pcall(function() return game:GetService("CoreGui") end)
		host = okC and cg or LocalPlayer:WaitForChild("PlayerGui")
	end
	local oldGui = host:FindFirstChild(guiName)
	if oldGui then oldGui:Destroy() end
	local gui = new("ScreenGui", {
		Name = guiName, ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
	})
	if not pcall(function() gui.Parent = host end) or not gui.Parent then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
	Win.Gui = gui

	local main = new("CanvasGroup", {
		Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H), BorderSizePixel = 0, Visible = false, GroupTransparency = 0,
	}, gui)
	bind(main, "BackgroundColor3", "Bg")
	Win._corners[#Win._corners + 1] = cornerOf(main, Win.Radius)
	local mainStroke = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = Win.Borders and 0 or 1 }, main)
	bind(mainStroke, "Color", "Line")
	Win._strokes[#Win._strokes + 1] = mainStroke
	local mainScale = new("UIScale", { Scale = 1 }, main)
	Win.Main = main

	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, HEAD_H), BackgroundTransparency = 1, Active = true }, main)
	local hdiv = new("Frame", { Position = UDim2.new(0, 0, 0, HEAD_H), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0 }, main)
	bind(hdiv, "BackgroundColor3", "Line")

	local hx = 14
	if cfg.Icon then
		local ic = Icons.make(header, cfg.Icon, 18, "Text")
		ic.AnchorPoint = Vector2.new(0, 0.5); ic.Position = UDim2.new(0, hx, 0.5, 0)
		hx += 26
	end
	local titleL = text(header, title, 14, "Text")
	titleL.Font = Enum.Font.GothamBold
	titleL.Position = UDim2.fromOffset(hx, 0)
	titleL.Size = UDim2.new(1, -hx - 90, 1, 0)

	local dragging, dragStart, startPos = false, nil, nil
	header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, main.Position
		end
	end)
	keep(UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = (i.Position - dragStart) / mainScale.Scale
			main.Position = startPos + UDim2.fromOffset(d.X, d.Y)
		end
	end))
	keep(UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end))

	local function hbtn(offX, iconName, fn)
		local b = new("TextButton", {
			Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Active = true,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, offX, 0.5, 0), Size = UDim2.fromOffset(28, 28),
		}, header)
		local ic = Icons.make(b, iconName, 16, "Dim")
		ic.AnchorPoint = Vector2.new(0.5, 0.5); ic.Position = UDim2.fromScale(0.5, 0.5)
		b.MouseButton1Click:Connect(fn)
		return b
	end
	hbtn(-10, "x", function() Win:Toggle(false) end)
	hbtn(-40, "minus", function() Win:Minimize() end)

	local body = new("Frame", {
		Name = "Body", Position = UDim2.fromOffset(0, HEAD_H + 1), Size = UDim2.new(1, 0, 1, -(HEAD_H + 1)),
		BackgroundTransparency = 1, BorderSizePixel = 0,
	}, main)
	local sideBg = new("Frame", { Size = UDim2.new(0, SIDE_W, 1, 0), BorderSizePixel = 0 }, body)
	bind(sideBg, "BackgroundColor3", "Panel")
	local indicator = new("Frame", { Size = UDim2.fromOffset(0, 0), BorderSizePixel = 0 }, body)
	bind(indicator, "BackgroundColor3", "Accent")
	cornerOf(indicator, 8)
	local tabHolder = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.XY,
		ScrollingDirection = Enum.ScrollingDirection.XY,
	}, body)
	local tabList = new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabHolder)

	local collapseBtn = new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Active = true, AnchorPoint = Vector2.new(0, 1),
	}, body)
	local colIcL = Icons.make(collapseBtn, "chevron-left", 16, "Dim")
	colIcL.AnchorPoint = Vector2.new(0.5, 0.5); colIcL.Position = UDim2.fromScale(0.5, 0.5)
	local colIcR = Icons.make(collapseBtn, "chevron-right", 16, "Dim")
	colIcR.AnchorPoint = Vector2.new(0.5, 0.5); colIcR.Position = UDim2.fromScale(0.5, 0.5); colIcR.Visible = false

	local sideLine = new("Frame", { Size = UDim2.new(0, 1, 1, 0), BorderSizePixel = 0 }, body)
	bind(sideLine, "BackgroundColor3", "Line")
	local content = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0 }, body)

	local searchBox = new("Frame", { Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 30), BorderSizePixel = 0 }, content)
	bind(searchBox, "BackgroundColor3", "Item")
	cornerOf(searchBox, 8)
	local sStroke = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.3 }, searchBox)
	bind(sStroke, "Color", "Line")
	local sIc = Icons.make(searchBox, "search", 15, "Dim")
	sIc.AnchorPoint = Vector2.new(0, 0.5); sIc.Position = UDim2.new(0, 10, 0.5, 0)
	local search = new("TextBox", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -40, 1, 0),
		Text = "", PlaceholderText = "Search this tab...", TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 13, ClearTextOnFocus = false, Font = CurrentFont,
	}, searchBox)
	bind(search, "TextColor3", "Text")
	bind(search, "PlaceholderColor3", "Dim")
	fontList[#fontList + 1] = search

	local pages = new("Frame", { Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 1, -58), BackgroundTransparency = 1, BorderSizePixel = 0 }, content)

	local IK = { x = {}, y = {}, w = {}, h = {} }
	local function moveIndicator(tab, instant)
		local b = tab and tab.btn
		if not b or not b.Parent then return end
		local o = body.AbsolutePosition
		local x, y = b.AbsolutePosition.X - o.X, b.AbsolutePosition.Y - o.Y
		local w, h = b.AbsoluteSize.X, b.AbsoluteSize.Y
		if instant then
			indicator.Position = UDim2.fromOffset(x, y)
			indicator.Size = UDim2.fromOffset(w, h)
			return
		end
		Anim.spring(IK.x, x, function(v) indicator.Position = UDim2.fromOffset(v, indicator.Position.Y.Offset) end, indicator.Position.X.Offset)
		Anim.spring(IK.y, y, function(v) indicator.Position = UDim2.fromOffset(indicator.Position.X.Offset, v) end, indicator.Position.Y.Offset)
		Anim.spring(IK.w, w, function(v) indicator.Size = UDim2.fromOffset(v, indicator.Size.Y.Offset) end, indicator.Size.X.Offset)
		Anim.spring(IK.h, h, function(v) indicator.Size = UDim2.fromOffset(indicator.Size.X.Offset, v) end, indicator.Size.Y.Offset)
	end

	local function layout(instant)
		local top = Win.Layout == "Topbar"
		local mini = Win.Collapsed and not top
		local sw = mini and SIDE_MINI or SIDE_W
		local function go(o, props)
			if instant then
				for k, v in pairs(props) do o[k] = v end
			else
				Anim.to(o, props, 0.35, "Back")
			end
		end
		go(sideBg, { Size = top and UDim2.new(1, 0, 0, 46) or UDim2.new(0, sw, 1, 0) })
		go(sideLine, {
			Position = top and UDim2.new(0, 0, 0, 46) or UDim2.new(0, sw, 0, 0),
			Size = top and UDim2.new(1, 0, 0, 1) or UDim2.new(0, 1, 1, 0),
		})
		go(tabHolder, {
			Position = top and UDim2.fromOffset(8, 6) or UDim2.fromOffset(6, 6),
			Size = top and UDim2.new(1, -16, 0, 34) or UDim2.new(0, sw - 12, 1, -50),
		})
		go(collapseBtn, { Position = UDim2.new(0, 6, 1, -6), Size = UDim2.new(0, sw - 12, 0, 28) })
		go(content, {
			Position = top and UDim2.new(0, 0, 0, 46) or UDim2.new(0, sw + 1, 0, 0),
			Size = top and UDim2.new(1, 0, 1, -46) or UDim2.new(1, -(sw + 1), 1, 0),
		})
		tabList.FillDirection = top and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
		tabList.VerticalAlignment = top and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top
		collapseBtn.Visible = not top
		colIcL.Visible = not mini
		colIcR.Visible = mini
		for _, t in ipairs(Win.Tabs) do
			local b, lb, ic = t.btn, t.lbl, t.ic
			lb.Position = UDim2.fromOffset(34, 0)
			lb.Size = UDim2.new(1, -38, 1, 0)
			if top then
				local tw = TextService:GetTextSize(t.Name, 13, CurrentFont, Vector2.new(1e4, 1e4)).X
				b.Size = UDim2.fromOffset(tw + 46, 30)
				ic.AnchorPoint = Vector2.new(0, 0.5); ic.Position = UDim2.new(0, 12, 0.5, 0)
				lb.Visible = true
			else
				b.Size = UDim2.new(1, 0, 0, 34)
				lb.Visible = not mini
				if mini then
					ic.AnchorPoint = Vector2.new(0.5, 0.5); ic.Position = UDim2.fromScale(0.5, 0.5)
				else
					ic.AnchorPoint = Vector2.new(0, 0.5); ic.Position = UDim2.new(0, 12, 0.5, 0)
				end
			end
		end
		local h = Anim.cycle(function() moveIndicator(Win.ActiveTab, false) end, 60)
		task.delay(0.5, function() h.dead = true end)
		task.defer(function() moveIndicator(Win.ActiveTab, instant) end)
	end

	local function applyFilter()
		local q = search.Text:lower()
		for _, it in ipairs(Win.Items) do
			if it.tab == Win.ActiveTab then
				it.frame.Visible = (q == "") or (it.name:find(q, 1, true) ~= nil)
			end
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(applyFilter)

	function Win:SelectTab(tab, instant)
		Win.ActiveTab = tab
		for _, t in ipairs(Win.Tabs) do t.page.Visible = (t == tab) end
		repaint({}, false)
		moveIndicator(tab, instant)
		applyFilter()
	end

	function Win:SetCollapsed(v)
		Win.Collapsed = v and true or false
		layout(false)
	end

	function Win:SetLayout(v)
		Win.Layout = v == "Topbar" and "Topbar" or "Sidebar"
		setFlag("Layout", Win.Layout)
		layout(false)
	end

	collapseBtn.MouseButton1Click:Connect(function() Win:SetCollapsed(not Win.Collapsed) end)

	---------------------------------------------------------------------
	-- Tabs and elements
	---------------------------------------------------------------------
	function Win:AddTab(name, iconName)
		local Tab = { Name = name, Items = {}, Count = 0, Win = Win }
		local btn = new("TextButton", {
			Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Active = true,
			Size = UDim2.new(1, 0, 0, 34), LayoutOrder = #Win.Tabs + 1, ZIndex = 2,
		}, tabHolder)
		local ic = Icons.make(btn, iconName or "circle", 16, function(T) return Win.ActiveTab == Tab and T.On or T.Dim end)
		ic.ZIndex = 2
		local lbl = new("TextLabel", {
			BackgroundTransparency = 1, Text = name, TextSize = 13, Font = CurrentFont,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2,
		}, btn)
		fontList[#fontList + 1] = lbl
		bind(lbl, "TextColor3", function(T) return Win.ActiveTab == Tab and T.On or T.Dim end)

		local page = new("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
			Visible = false, ScrollingDirection = Enum.ScrollingDirection.Y,
		}, pages)
		bind(page, "ScrollBarImageColor3", "Line")
		new("UIPadding", {
			PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 8),
		}, page)
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
		Tab.page, Tab.btn, Tab.lbl, Tab.ic = page, btn, lbl, ic

		Win.Tabs[#Win.Tabs + 1] = Tab
		btn.MouseButton1Click:Connect(function() Win:SelectTab(Tab) end)
		layout(true)
		if not Win.ActiveTab then Win:SelectTab(Tab, true) end

		function Tab:AddSection(t)
			local f = makeRow(Tab, 26, t, true)
			local l = text(f, string.upper(t or ""), 11, "Accent")
			l.Position = UDim2.fromOffset(4, 0); l.Size = UDim2.new(1, -8, 1, 0)
			return f
		end

		function Tab:AddLabel(str)
			local f = makeRow(Tab, 30, str)
			local l = text(f, str or "", 12, "Dim")
			l.Position = UDim2.fromOffset(12, 0); l.Size = UDim2.new(1, -24, 1, 0)
			return { Set = function(_, v) l.Text = tostring(v) end }
		end

		function Tab:AddImage(o)
			o = o or {}
			local h = o.Height or 130
			local f, item = makeRow(Tab, h + 8, o.Title or "image")
			local img = new("ImageLabel", {
				Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8),
				BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Active = false,
				Image = o.Image or "", ScaleType = o.ScaleType or Enum.ScaleType.Crop,
			}, f)
			cornerOf(img, 8)
			bind(img, "BackgroundColor3", "Panel")
			return {
				Set = function(_, url) img.Image = tostring(url) end,
				Get = function() return img.Image end,
			}
		end

		function Tab:AddParagraph(o)
			o = o or {}
			local f, item = makeRow(Tab, 0, o.Title)
			f.AutomaticSize = Enum.AutomaticSize.Y
			new("UIPadding", {
				PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
			}, f)
			new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, f)
			local order = 0
			if o.Image then
				order += 1
				local img = new("ImageLabel", {
					Size = UDim2.new(1, 0, 0, o.ImageHeight or 130),
					BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Active = false,
					Image = o.Image, ScaleType = Enum.ScaleType.Crop, LayoutOrder = order,
				}, f)
				cornerOf(img, 8)
				bind(img, "BackgroundColor3", "Panel")
			end
			if o.Title then
				order += 1
				local t = text(f, o.Title, 13, "Text")
				t.Size = UDim2.new(1, 0, 0, 0); t.AutomaticSize = Enum.AutomaticSize.Y
				t.TextWrapped = true; t.TextTruncate = Enum.TextTruncate.None; t.LayoutOrder = order
			end
			order += 1
			local c = text(f, o.Content or "", 12, "Dim")
			c.Size = UDim2.new(1, 0, 0, 0); c.AutomaticSize = Enum.AutomaticSize.Y
			c.TextWrapped = true; c.TextTruncate = Enum.TextTruncate.None; c.LayoutOrder = order
			return {
				SetContent = function(_, v) c.Text = tostring(v) end,
				SetTitle = function(_, v) item.name = tostring(v):lower() end,
			}
		end

		function Tab:AddButton(o)
			o = o or {}
			local f, item = makeRow(Tab, 40, o.Title)
			local x = 12
			if o.Image then
				thumb(f, o.Image, 10, 6, 28)
				x = 48
			elseif o.Icon then
				x = rowIcon(f, o.Icon)
			end
			local l = text(f, o.Title or "Button", 13, "Text")
			l.Position = UDim2.fromOffset(x, 0); l.Size = UDim2.new(1, -x - 36, 1, 0)
			if o.Description then
				l.Size = UDim2.new(1, -x - 36, 0, 16)
				l.Position = UDim2.fromOffset(x, 4)
				local d = text(f, o.Description, 11, "Dim")
				d.Position = UDim2.fromOffset(x, 22); d.Size = UDim2.new(1, -x - 36, 0, 14)
			end
			local arrow = Icons.make(f, "chevron-right", 16, "Dim")
			arrow.AnchorPoint = Vector2.new(1, 0.5); arrow.Position = UDim2.new(1, -12, 0.5, 0)
			local hit = pressable(f)
			hit.MouseButton1Click:Connect(function() safeCall(o.Callback) end)
			return {
				SetTitle = function(_, v) l.Text = tostring(v); item.name = tostring(v):lower() end,
			}
		end

		function Tab:AddToggle(o)
			o = o or {}
			local state = getFlag(o.Flag, o.Default == true) == true
			local f = makeRow(Tab, 40, o.Title)
			local x = rowIcon(f, o.Icon)
			local l = text(f, o.Title or "Toggle", 13, "Text")
			l.Position = UDim2.fromOffset(x, 0); l.Size = UDim2.new(1, -x - 70, 1, 0)

			local track = new("Frame", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(42, 22), BorderSizePixel = 0,
			}, f)
			cornerOf(track, 11)
			bind(track, "BackgroundColor3", function(T) return state and T.Accent or T.Line end)
			local knob = new("Frame", {
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, state and 23 or 3, 0.5, 0),
				Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
			}, track)
			cornerOf(knob, 8)

			local function setState(v, silent)
				state = v and true or false
				setFlag(o.Flag, state)
				Anim.to(track, { BackgroundColor3 = state and Theme.Accent or Theme.Line }, 0.25)
				Anim.spring(knob, state and 23 or 3, function(p) knob.Position = UDim2.new(0, p, 0.5, 0) end, knob.Position.X.Offset)
				repaint({}, false)
				if not silent then safeCall(o.Callback, state) end
			end

			local hit = pressable(f)
			hit.MouseButton1Click:Connect(function() setState(not state) end)
			return {
				Set = function(_, v, silent) setState(v, silent) end,
				Get = function() return state end,
			}
		end

		local function filterText(s, mode, maxLen, dec)
			if mode == "Number" then
				local neg = s:sub(1, 1) == "-"
				s = (s:gsub("[^%d%.]", ""))
				if (dec or 0) == 0 then s = (s:gsub("%.", "")) end
				local a = s:find("%.")
				if a then s = s:sub(1, a) .. (s:sub(a + 1):gsub("%.", "")) end
				if neg then s = "-" .. s end
			elseif mode == "Letters" then
				s = (s:gsub("[^%a]", ""))
			elseif mode == "Alnum" then
				s = (s:gsub("[^%w]", ""))
			end
			if maxLen and #s > maxLen then s = s:sub(1, maxLen) end
			return s
		end

		function Tab:AddSlider(o)
			o = o or {}
			local lo, hi = o.Min or 0, o.Max or 100
			local step = o.Step or 1
			local dec = o.Decimals or 0
			local fmtStr = "%." .. dec .. "f"
			local value = clamp(tonumber(getFlag(o.Flag, o.Default or lo)) or lo, lo, hi)
			local f = makeRow(Tab, 52, o.Title)
			local x = rowIcon(f, o.Icon, 18, 16)
			local l = text(f, o.Title or "Slider", 13, "Text")
			l.Position = UDim2.fromOffset(x, 8); l.Size = UDim2.new(1, -x - 96, 0, 18)

			local wrap = new("Frame", {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6),
				Size = UDim2.fromOffset(76, 22), BorderSizePixel = 0,
			}, f)
			bind(wrap, "BackgroundColor3", "Panel")
			cornerOf(wrap, 6)
			local box = new("TextBox", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -12, 1, 0),
				Text = "", ClearTextOnFocus = false, TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right, Font = CurrentFont,
			}, wrap)
			fontList[#fontList + 1] = box
			bind(box, "TextColor3", "Text")

			local track = new("Frame", { Position = UDim2.new(0, 12, 1, -16), Size = UDim2.new(1, -24, 0, 6), BorderSizePixel = 0 }, f)
			bind(track, "BackgroundColor3", "Bg")
			cornerOf(track, 3)
			local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
			bind(fill, "BackgroundColor3", "Accent")
			cornerOf(fill, 3)
			local knob = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
			}, fill)
			cornerOf(knob, 7)

			local function fmt(v) return string.format(fmtStr, v) .. (o.Suffix or "") end

			local function show(v, animate)
				local frac = (v - lo) / max(hi - lo, 1e-6)
				if not box:IsFocused() then box.Text = fmt(v) end
				if animate then Anim.to(fill, { Size = UDim2.fromScale(frac, 1) }, 0.15)
				else fill.Size = UDim2.fromScale(frac, 1) end
			end
			show(value, false)

			local function setValue(v, silent)
				v = clamp(floor((v - lo) / step + 0.5) * step + lo, lo, hi)
				v = tonumber(string.format(fmtStr, v))
				if v == value then return end
				value = v
				show(v, false)
				setFlag(o.Flag, v)
				if not silent then safeCall(o.Callback, v) end
			end

			local function fromX(px)
				local a = clamp((px - track.AbsolutePosition.X) / max(track.AbsoluteSize.X, 1), 0, 1)
				setValue(lo + (hi - lo) * a)
			end
			local hit = new("TextButton", {
				Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Active = true,
				Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 22),
			}, f)
			dragTo(hit, fromX)

			box:GetPropertyChangedSignal("Text"):Connect(function()
				local c = filterText(box.Text, "Number", nil, dec)
				if c ~= box.Text then box.Text = c end
			end)
			box.FocusLost:Connect(function()
				local n = tonumber(box.Text:match("%-?%d*%.?%d+") or "")
				if n then setValue(n) end
				box.Text = fmt(value)
			end)

			return {
				Set = function(_, v, silent)
					value = clamp(tonumber(v) or value, lo, hi)
					show(value, true)
					setFlag(o.Flag, value)
					if not silent then safeCall(o.Callback, value) end
				end,
				Get = function() return value end,
			}
		end

		function Tab:AddDropdown(o)
			o = o or {}
			local opts = o.Options or {}
			local value = getFlag(o.Flag, o.Default or opts[1])
			local open = false
			local BASE, ITEM_H = 40, 26
			local f = makeRow(Tab, BASE, o.Title)

			local hit = pressable(f)
			hit.Size = UDim2.new(1, 0, 0, BASE)

			-- Anchor icon at the header (y = BASE/2) so it doesn't drop when list opens
			local x = rowIcon(f, o.Icon, 18, BASE / 2)
			local l = text(f, o.Title or "Dropdown", 13, "Text")
			l.Position = UDim2.fromOffset(x, 0); l.Size = UDim2.new(1, -x - 170, 0, BASE)

			local val = text(f, tostring(value or ""), 12, "Dim", Enum.TextXAlignment.Right)
			val.AnchorPoint = Vector2.new(1, 0)
			val.Position = UDim2.new(1, -34, 0, 0)
			val.Size = UDim2.fromOffset(130, BASE)

			local chev = Icons.make(f, "chevron-down", 16, "Dim")
			chev.AnchorPoint = Vector2.new(1, 0); chev.Position = UDim2.new(1, -10, 0, 12)

			local list = new("Frame", {
				Position = UDim2.fromOffset(10, BASE + 4), Size = UDim2.new(1, -20, 0, #opts * (ITEM_H + 4)),
				BackgroundTransparency = 1, Visible = false,
			}, f)
			new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)

			local function setOpen(v)
				open = v
				if v then list.Visible = true end
				local h = v and (BASE + 8 + #opts * (ITEM_H + 4)) or BASE
				Anim.to(f, { Size = UDim2.new(1, 0, 0, h) }, 0.3, "Back")
				Anim.to(chev, { Rotation = v and 180 or 0 }, 0.25)
				if not v then task.delay(0.3, function() if not open then list.Visible = false end end) end
			end

			Win:AddCloser(function() if open then setOpen(false) end end)

			for i, opt in ipairs(opts) do
				local b = new("TextButton", {
					Size = UDim2.new(1, 0, 0, ITEM_H), Text = tostring(opt), TextSize = 12, Font = CurrentFont,
					AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i, Active = true, ZIndex = 3,
				}, list)
				fontList[#fontList + 1] = b
				cornerOf(b, 6)
				bind(b, "BackgroundColor3", "Panel")
				bind(b, "TextColor3", function(T) return value == opt and T.Accent or T.Text end)
				b.MouseButton1Click:Connect(function()
					value = opt
					val.Text = tostring(opt)
					setFlag(o.Flag, opt)
					setOpen(false)
					repaint({}, false)
					safeCall(o.Callback, opt)
				end)
			end

			hit.MouseButton1Click:Connect(function() setOpen(not open) end)
			return {
				Set = function(_, v, silent)
					value = v; val.Text = tostring(v)
					setFlag(o.Flag, v)
					repaint({}, false)
					if not silent then safeCall(o.Callback, v) end
				end,
				Get = function() return value end,
			}
		end

		function Tab:AddTextBox(o)
			o = o or {}
			local mode = o.Mode or "Any"
			local dec = o.Decimals or 0
			local maxLen = o.MaxLength
			local minN, maxN = o.Min, o.Max

			local f = makeRow(Tab, 40, o.Title)
			local x = rowIcon(f, o.Icon)
			local l = text(f, o.Title or "Input", 13, "Text")
			l.Position = UDim2.fromOffset(x, 0); l.Size = UDim2.new(0.5, -x, 1, 0)

			local wrap = new("Frame", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.new(0.5, -6, 0, 26), BorderSizePixel = 0,
			}, f)
			bind(wrap, "BackgroundColor3", "Panel")
			cornerOf(wrap, 6)

			local start = getFlag(o.Flag, o.Default)
			local tb = new("TextBox", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0),
				Text = start ~= nil and tostring(start) or "", PlaceholderText = o.Placeholder or "...",
				ClearTextOnFocus = false, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
				Font = CurrentFont, TextTruncate = Enum.TextTruncate.AtEnd,
			}, wrap)
			fontList[#fontList + 1] = tb
			bind(tb, "TextColor3", "Text")
			bind(tb, "PlaceholderColor3", "Dim")

			tb:GetPropertyChangedSignal("Text"):Connect(function()
				local c = filterText(tb.Text, mode, maxLen, dec)
				if c ~= tb.Text then tb.Text = c end
			end)

			local last = tb.Text
			local function current()
				if mode == "Number" then return tonumber(tb.Text) end
				return tb.Text
			end

			tb.FocusLost:Connect(function()
				if mode == "Number" then
					local n = tonumber(tb.Text)
					if not n then tb.Text = last; return end
					if minN then n = max(n, minN) end
					if maxN then n = min(n, maxN) end
					tb.Text = string.format("%." .. dec .. "f", n)
				end
				last = tb.Text
				setFlag(o.Flag, current())
				safeCall(o.Callback, current())
			end)

			return {
				Set = function(_, v)
					tb.Text = tostring(v)
					last = tb.Text
					setFlag(o.Flag, current())
				end,
				Get = function() return current() end,
			}
		end

		function Tab:AddKeybind(o)
			o = o or {}
			local key = nil
			local stored = getFlag(o.Flag, nil)
			if type(stored) == "string" then key = Enum.KeyCode[stored] end
			key = key or o.Default
			local f = makeRow(Tab, 40, o.Title)
			local x = rowIcon(f, o.Icon)
			local l = text(f, o.Title or "Keybind", 13, "Text")
			l.Position = UDim2.fromOffset(x, 0); l.Size = UDim2.new(1, -x - 120, 1, 0)
			local btn = new("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(100, 26),
				AutoButtonColor = false, BorderSizePixel = 0, TextSize = 12, Font = CurrentFont, Active = true,
			}, f)
			fontList[#fontList + 1] = btn
			cornerOf(btn, 6)
			bind(btn, "BackgroundColor3", "Panel")
			bind(btn, "TextColor3", "Accent")
			local function showKey() btn.Text = key and key.Name or "None" end
			showKey()

			local listening = false
			btn.MouseButton1Click:Connect(function() listening = true; btn.Text = "..." end)
			keep(UIS.InputBegan:Connect(function(i, gpe)
				if listening and i.UserInputType == Enum.UserInputType.Keyboard then
					listening = false
					if i.KeyCode ~= Enum.KeyCode.Escape then
						key = i.KeyCode
						setFlag(o.Flag, key.Name)
					end
					showKey()
					return
				end
				if not gpe and key and i.KeyCode == key then safeCall(o.Callback, key) end
			end))
			return {
				Get = function() return key end,
				Set = function(_, kc) key = kc; setFlag(o.Flag, kc and kc.Name or nil); showKey() end,
			}
		end

		-----------------------------------------------------------------
		-- REAL color picker (SV square + hue strip + alpha strip + hex)
		-----------------------------------------------------------------
		function Tab:AddColorPicker(o)
			o = o or {}
			local color = o.Default or rgb(124, 111, 255)
			local stored = getFlag(o.Flag, nil)
			if type(stored) == "table" and #stored >= 3 then
				color = Color3.fromRGB(stored[1], stored[2], stored[3])
			end
			local h, s, v = color:ToHSV()
			local alpha = (type(stored) == "table" and stored[4]) or o.Alpha or 1
			local BASE = 40
			local BODY_H = 200
			local open = false
			local f, item = makeRow(Tab, BASE, o.Title)

			local x = rowIcon(f, o.Icon, 18, BASE / 2)
			local l = text(f, o.Title or "Color", 13, "Text")
			l.Position = UDim2.fromOffset(x, 0); l.Size = UDim2.new(1, -x - 70, 0, BASE)

			local preview = new("TextButton", {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10),
				Size = UDim2.fromOffset(40, 20), Text = "", AutoButtonColor = false,
				BorderSizePixel = 0, BackgroundColor3 = color, Active = true,
			}, f)
			cornerOf(preview, 6)
			local pStroke = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, preview)
			bind(pStroke, "Color", "Line")

			local body = new("Frame", {
				Position = UDim2.fromOffset(10, BASE + 4),
				Size = UDim2.new(1, -20, 0, BODY_H),
				BackgroundTransparency = 1, Visible = false,
			}, f)

			local SV_W, SV_H = 130, 130

			-- SV square: base hue, then white horizontal gradient, then black vertical gradient
			local sv = new("Frame", {
				Size = UDim2.fromOffset(SV_W, SV_H), BorderSizePixel = 0,
			}, body)
			cornerOf(sv, 6)

			local svWhite = new("Frame", {
				Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
			}, sv)
			cornerOf(svWhite, 6)
			local wGrad = new("UIGradient", { Rotation = 0 }, svWhite)

			local svBlack = new("Frame", {
				Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
			}, sv)
			cornerOf(svBlack, 6)
			local bGrad = new("UIGradient", { Rotation = 90 }, svBlack)
			bGrad.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			})

			local svCursor = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12),
				BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 2, ZIndex = 4,
			}, sv)
			cornerOf(svCursor, 6)
			new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, svCursor)

			-- Hue strip (vertical rainbow)
			local hueStrip = new("Frame", {
				Position = UDim2.fromOffset(SV_W + 10, 0),
				Size = UDim2.new(1, -(SV_W + 10), 0, SV_H), BorderSizePixel = 0,
			}, body)
			cornerOf(hueStrip, 6)
			local hGrad = new("UIGradient", { Rotation = 90 }, hueStrip)
			hGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0 / 6, Color3.fromHSV(0 / 6, 1, 1)),
				ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
				ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
				ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
				ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
				ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
				ColorSequenceKeypoint.new(1.0, Color3.fromHSV(1.0, 1, 1)),
			})
			local hueCursor = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, h, 0),
				Size = UDim2.new(1, 4, 0, 4), BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0, ZIndex = 4,
			}, hueStrip)
			cornerOf(hueCursor, 2)
			new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, hueCursor)

			-- Alpha strip
			local alphaY = SV_H + 10
			local alphaWrap = new("Frame", {
				Position = UDim2.fromOffset(0, alphaY), Size = UDim2.new(1, 0, 0, 16),
				BackgroundColor3 = Color3.new(0.45, 0.45, 0.45), BorderSizePixel = 0,
			}, body)
			cornerOf(alphaWrap, 4)
			local alphaFill = new("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, alphaWrap)
			cornerOf(alphaFill, 4)
			local aGrad = new("UIGradient", { Rotation = 0 }, alphaFill)
			aGrad.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			local alphaCursor = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(alpha, 0, 0.5, 0),
				Size = UDim2.fromOffset(4, 20), BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0, ZIndex = 4,
			}, alphaWrap)
			cornerOf(alphaCursor, 2)
			new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, alphaCursor)

			-- Hex input
			local hexY = alphaY + 26
			local hexWrap = new("Frame", {
				Position = UDim2.fromOffset(0, hexY), Size = UDim2.fromOffset(120, 24), BorderSizePixel = 0,
			}, body)
			bind(hexWrap, "BackgroundColor3", "Panel")
			cornerOf(hexWrap, 6)
			local hexBox = new("TextBox", {
				BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "#FFFFFF",
				ClearTextOnFocus = false, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
				Font = CurrentFont,
			}, hexWrap)
			fontList[#fontList + 1] = hexBox
			bind(hexBox, "TextColor3", "Text")

			-- Preset swatches
			local swatchWrap = new("Frame", {
				Position = UDim2.fromOffset(130, hexY), Size = UDim2.new(1, -130, 0, 24),
				BackgroundTransparency = 1, BorderSizePixel = 0,
			}, body)
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
			}, swatchWrap)
			local palette = {
				rgb(255, 255, 255), rgb(124, 111, 255), rgb(80, 170, 255), rgb(90, 220, 160),
				rgb(255, 190, 70), rgb(255, 120, 100), rgb(255, 110, 170), rgb(60, 210, 210),
			}
			local function setFromColor(c)
				h, s, v = c:ToHSV()
			end
			local refresh
			for i, c in ipairs(palette) do
				local sw = new("TextButton", {
					Size = UDim2.fromOffset(22, 22), Text = "", AutoButtonColor = false,
					BorderSizePixel = 0, BackgroundColor3 = c, LayoutOrder = i, Active = true,
				}, swatchWrap)
				cornerOf(sw, 11)
				sw.MouseButton1Click:Connect(function() setFromColor(c); refresh() end)
			end

			refresh = function(silent)
				color = Color3.fromHSV(h, s, v)
				-- SV base = pure hue
				sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
				wGrad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1)),
				})
				svCursor.Position = UDim2.fromScale(s, 1 - v)
				hueCursor.Position = UDim2.new(0.5, 0, h, 0)
				alphaCursor.Position = UDim2.new(alpha, 0, 0.5, 0)
				alphaFill.BackgroundColor3 = color
				preview.BackgroundColor3 = color
				preview.BackgroundTransparency = 1 - alpha
				if not hexBox:IsFocused() then hexBox.Text = hexOf(color) end
				setFlag(o.Flag, {
					floor(color.R * 255 + 0.5), floor(color.G * 255 + 0.5),
					floor(color.B * 255 + 0.5), alpha,
				})
				if not silent then safeCall(o.Callback, color, alpha) end
			end

			-- Drag handlers
			dragXY(sv, function(px, py)
				local a = sv.AbsolutePosition; local sz = sv.AbsoluteSize
				s = clamp((px - a.X) / max(sz.X, 1), 0, 1)
				v = 1 - clamp((py - a.Y) / max(sz.Y, 1), 0, 1)
				refresh()
			end)
			dragXY(hueStrip, function(_, py)
				local a = hueStrip.AbsolutePosition; local sz = hueStrip.AbsoluteSize
				h = clamp((py - a.Y) / max(sz.Y, 1), 0, 1)
				refresh()
			end)
			dragXY(alphaWrap, function(px)
				local a = alphaWrap.AbsolutePosition; local sz = alphaWrap.AbsoluteSize
				alpha = clamp((px - a.X) / max(sz.X, 1), 0, 1)
				refresh()
			end)

			hexBox.FocusLost:Connect(function()
				local hex = hexBox.Text:gsub("[^%x]", "")
				if #hex >= 6 then
					local r = tonumber(hex:sub(1, 2), 16) or 0
					local g = tonumber(hex:sub(3, 4), 16) or 0
					local b = tonumber(hex:sub(5, 6), 16) or 0
					local c = Color3.fromRGB(r, g, b)
					h, s, v = c:ToHSV()
				end
				refresh()
			end)

			local function setOpen(val2)
				open = val2
				body.Visible = val2
				Anim.to(f, { Size = UDim2.new(1, 0, 0, val2 and (BASE + BODY_H + 8) or BASE) }, 0.3, "Back")
			end
			preview.MouseButton1Click:Connect(function() setOpen(not open) end)
			Win:AddCloser(function() if open then setOpen(false) end end)

			refresh(true)
			return {
				Set = function(_, c, a, silent)
					h, s, v = c:ToHSV()
					if a then alpha = a end
					refresh(silent)
				end,
				Get = function() return color, alpha end,
			}
		end

		-----------------------------------------------------------------
		-- Theme preview picker (horizontal scroll, mini windows)
		-----------------------------------------------------------------
		function Tab:AddThemePreview(o)
			o = o or {}
			local current = getFlag(o.Flag, o.Default or "Midnight")
			local CARD_W, CARD_H = 96, 100
			local f, item = makeRow(Tab, CARD_H + 14, o.Title or "Theme")
			local scroll = new("ScrollingFrame", {
				Position = UDim2.fromOffset(8, 6),
				Size = UDim2.new(1, -16, 0, CARD_H + 4),
				BackgroundTransparency = 1, BorderSizePixel = 0,
				ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X,
				CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.XY,
			}, f)
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
			}, scroll)

			local cards = {}
			local function select(name)
				current = name
				for _, c in pairs(cards) do
					Anim.to(c.stroke, { Transparency = c.name == current and 0 or 1 }, 0.2)
				end
			end

			for i, name in ipairs(PRESET_ORDER) do
				local preset = PRESETS[name]
				local card = new("TextButton", {
					Size = UDim2.fromOffset(CARD_W, CARD_H),
					Text = "", AutoButtonColor = false, BorderSizePixel = 0,
					BackgroundTransparency = 1, LayoutOrder = i, Active = true,
				}, scroll)
				local cardStroke = new("UIStroke", {
					Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Transparency = name == current and 0 or 1,
				}, card)
				bind(cardStroke, "Color", "Accent")

				-- mini window
				local preview = new("Frame", {
					Size = UDim2.new(1, 0, 0, 66), BorderSizePixel = 0, BackgroundColor3 = preset.Bg,
				}, card)
				cornerOf(preview, 6)
				local prevStroke = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = preset.Line }, preview)

				local side = new("Frame", {
					Size = UDim2.new(0, 22, 1, 0), BorderSizePixel = 0, BackgroundColor3 = preset.Panel,
				}, preview)
				cornerOf(side, 6)
				local sideMask = new("Frame", {
					Size = UDim2.new(0, 6, 1, 0), Position = UDim2.new(1, -6, 0, 0),
					BackgroundColor3 = preset.Panel, BorderSizePixel = 0,
				}, side)

				local acc = new("Frame", {
					Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(10, 10),
					BackgroundColor3 = preset.Accent, BorderSizePixel = 0,
				}, preview)
				cornerOf(acc, 5)

				for j = 1, 3 do
					local it = new("Frame", {
						Position = UDim2.fromOffset(28, 8 + (j - 1) * 14),
						Size = UDim2.new(1, -34, 0, 10),
						BackgroundColor3 = preset.Item, BorderSizePixel = 0,
					}, preview)
					cornerOf(it, 3)
					if j == 1 then
						local dot = new("Frame", {
							AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0),
							Size = UDim2.fromOffset(4, 4), BackgroundColor3 = preset.Accent, BorderSizePixel = 0,
						}, it)
						cornerOf(dot, 2)
					end
				end

				local lbl = new("TextLabel", {
					BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 70),
					Size = UDim2.new(1, 0, 0, 16), Text = name, TextSize = 12,
					Font = CurrentFont, TextTruncate = Enum.TextTruncate.AtEnd,
				}, card)
				fontList[#fontList + 1] = lbl
				bind(lbl, "TextColor3", "Dim")

				card.MouseButton1Click:Connect(function()
					select(name)
					setFlag(o.Flag, name)
					Win:SetTheme(name)
					safeCall(o.Callback, name)
				end)

				cards[name] = { name = name, stroke = cardStroke }
			end

			return {
				Set = function(_, name, silent)
					if not cards[name] then return end
					select(name)
					setFlag(o.Flag, name)
					if not silent then safeCall(o.Callback, name) end
				end,
				Get = function() return current end,
			}
		end

		-----------------------------------------------------------------
		-- Font preview picker (horizontal scroll, live samples)
		-----------------------------------------------------------------
		function Tab:AddFontPicker(o)
			o = o or {}
			local current = getFlag(o.Flag, o.Default or "GothamMedium")
			local CARD_W, CARD_H = 88, 100
			local f, item = makeRow(Tab, CARD_H + 14, o.Title or "Font")
			local scroll = new("ScrollingFrame", {
				Position = UDim2.fromOffset(8, 6),
				Size = UDim2.new(1, -16, 0, CARD_H + 4),
				BackgroundTransparency = 1, BorderSizePixel = 0,
				ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X,
				CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.XY,
			}, f)
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
			}, scroll)

			local cards = {}
			local function select(name)
				current = name
				for _, c in pairs(cards) do
					Anim.to(c.stroke, { Transparency = c.name == current and 0 or 1 }, 0.2)
				end
			end

			for i, fname in ipairs(FONT_LIST) do
				local ef = Enum.Font[fname]
				if ef then
					local card = new("TextButton", {
						Size = UDim2.fromOffset(CARD_W, CARD_H),
						Text = "", AutoButtonColor = false, BorderSizePixel = 0,
						BackgroundTransparency = 1, LayoutOrder = i, Active = true,
					}, scroll)
					local stroke = new("UIStroke", {
						Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Transparency = fname == current and 0 or 1,
					}, card)
					bind(stroke, "Color", "Accent")

					local prev = new("Frame", {
						Size = UDim2.new(1, 0, 0, 66), BorderSizePixel = 0,
					}, card)
					bind(prev, "BackgroundColor3", "Item")
					cornerOf(prev, 6)
					local prevStroke = new("UIStroke", {
						Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}, prev)
					bind(prevStroke, "Color", "Line")

					local sample = new("TextLabel", {
						BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
						Text = "Aa", TextSize = 28, Font = ef,
					}, prev)
					bind(sample, "TextColor3", "Text")

					local lbl = new("TextLabel", {
						BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 70),
						Size = UDim2.new(1, 0, 0, 16), Text = fname, TextSize = 11,
						Font = ef, TextTruncate = Enum.TextTruncate.AtEnd,
					}, card)
					bind(lbl, "TextColor3", "Dim")
					-- do NOT add to fontList; this label always shows its own font

					card.MouseButton1Click:Connect(function()
						select(fname)
						setFlag(o.Flag, fname)
						Win:SetFont(fname)
						safeCall(o.Callback, fname)
					end)

					cards[fname] = { name = fname, stroke = stroke }
				end
			end

			return {
				Set = function(_, name, silent)
					if not cards[name] then return end
					select(name)
					setFlag(o.Flag, name)
					if not silent then safeCall(o.Callback, name) end
				end,
				Get = function() return current end,
			}
		end

		return Tab
	end

	---------------------------------------------------------------------
	-- Window methods
	---------------------------------------------------------------------
	local function setAllRadius(r)
		Win.Radius = r
		local n = 0
		for i = 1, #Win._corners do
			local c = Win._corners[i]
			if c.Parent then
				n += 1; Win._corners[n] = c
				c.CornerRadius = UDim.new(0, r)
			end
		end
		for i = #Win._corners, n + 1, -1 do Win._corners[i] = nil end
	end

	local function setAllBorders(on)
		Win.Borders = on
		local n = 0
		for i = 1, #Win._strokes do
			local s = Win._strokes[i]
			if s.Parent then
				n += 1; Win._strokes[n] = s
				Anim.to(s, { Transparency = on and 0.3 or 1 }, 0.25)
			end
		end
		for i = #Win._strokes, n + 1, -1 do Win._strokes[i] = nil end
		mainStroke.Transparency = on and 0 or 1
	end

	function Win:SetTheme(v, animate)
		setTheme(resolveTheme(v))
		repaint(THEME_KEYS, animate ~= false)
		if type(v) == "string" then setFlag("Theme", v) end
	end

	local cyc
	function Win:SetAccentCycle(on, speed)
		if cyc then cyc.dead = true; cyc = nil end
		setFlag("AccentCycle", on and true or false)
		if on then
			cyc = Anim.cycle(function(now)
				Theme.Accent = Color3.fromHSV((now * (speed or 0.08)) % 1, 0.65, 1)
				repaint({ "Accent" }, false)
			end, 30)
		end
	end

	function Win:SetBorders(on) setAllBorders(on and true or false); setFlag("Borders", on and true or false) end
	function Win:SetRadius(r) setAllRadius(clamp(tonumber(r) or 12, 0, 20)); setFlag("Radius", Win.Radius) end
	function Win:SetScale(p)
		local s = clamp((tonumber(p) or 100) / 100, 0.7, 1.4)
		Win._scale = s
		Anim.to(mainScale, { Scale = s }, 0.25)
		setFlag("Scale", s * 100)
	end
	function Win:SetFont(name)
		local f = Enum.Font[name]
		if not f then return end
		CurrentFont = f
		local n = 0
		for i = 1, #fontList do
			local o = fontList[i]
			if o.Parent then n += 1; fontList[n] = o; o.Font = f end
		end
		for i = #fontList, n + 1, -1 do fontList[i] = nil end
		layout(true)
		setFlag("Font", name)
	end

	local bubble
	function Win:Toggle(v)
		if not Win.Unlocked then return end
		if v == nil then v = not Win.Visible end
		if v == Win.Visible then return end
		Win.Visible = v
		if bubble then bubble.Visible = (not v) and cfg.Bubble == true end
		if v then
			main.Visible = true
			main.GroupTransparency = 1
			mainScale.Scale = 0.85
			Anim.to(main, { GroupTransparency = 0 }, 0.25)
			Anim.to(mainScale, { Scale = Win._scale or 1 }, 0.45, "Back")
			if not Win.ActiveTab and Win.Tabs[1] then Win:SelectTab(Win.Tabs[1], true) end
		else
			Anim.to(main, { GroupTransparency = 1 }, 0.2)
			Anim.to(mainScale, { Scale = 0.85 }, 0.2, "InOut", function()
				if not Win.Visible then main.Visible = false end
			end)
		end
	end

	function Win:Minimize(v)
		if v == nil then v = not Win.Minimized end
		if v then
			-- close all expandables instantly
			for _, fn in ipairs(Win._closers) do safeCall(fn) end
		end
		Win.Minimized = v
		body.Visible = not v
		Anim.to(main, { Size = UDim2.fromOffset(W, v and HEAD_H or H) }, 0.3, "Back")
	end

	function Win:SetTitle(t) titleL.Text = tostring(t) end

	function Win:Destroy()
		for _, c in ipairs(conns) do c:Disconnect() end
		table.clear(conns)
		gui:Destroy()
	end

	---------------------------------------------------------------------
	-- Notifications
	---------------------------------------------------------------------
	local notifHolder = new("Frame", {
		Name = "Notifications", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 20,
	}, gui)
	new("UIListLayout", {
		Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}, notifHolder)
	local notifOrder = 0
	local liveNotifs = {}

	function Win:Notify(o)
		o = o or {}
		notifOrder += 1
		local hasImg = o.Image ~= nil
		local notifH = hasImg and 82 or 62
		local wrap = new("Frame", {
			Size = UDim2.new(1, 0, 0, notifH), BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = notifOrder,
		}, notifHolder)
		local card = new("Frame", { Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(1, 40, 0, 0), BorderSizePixel = 0 }, wrap)
		bind(card, "BackgroundColor3", "Panel")
		cornerOf(card, Win.Radius)
		local cs = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
		bind(cs, "Color", "Line")
		local bar = new("Frame", { Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(8, 8), BorderSizePixel = 0 }, card)
		bind(bar, "BackgroundColor3", "Accent")
		cornerOf(bar, 2)

		local x = 18
		if hasImg then
			thumb(card, o.Image, 18, (notifH - 46) / 2, 46)
			x = 74
		elseif o.Icon then
			local ic = Icons.make(card, o.Icon, 18, "Accent")
			ic.Position = UDim2.fromOffset(18, 12)
			x = 46
		end
		local ty = hasImg and 14 or 10
		local t = text(card, o.Title or "Notification", 13, "Text")
		t.Position = UDim2.fromOffset(x, ty); t.Size = UDim2.new(1, -x - 12, 0, 18)
		local c = text(card, o.Content or "", 12, "Dim")
		c.Position = UDim2.fromOffset(x, ty + 20); c.Size = UDim2.new(1, -x - 12, 0, 20)
		local timer = new("Frame", { Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0 }, card)
		bind(timer, "BackgroundColor3", "Accent")

		local function dismiss()
			if not wrap.Parent then return end
			Anim.to(card, { Position = UDim2.new(1, 40, 0, 0) }, 0.25, "InOut", function()
				Anim.to(wrap, { Size = UDim2.new(1, 0, 0, 0) }, 0.2, "InOut", function()
					if wrap.Parent then wrap:Destroy() end
				end)
			end)
		end

		Anim.to(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.4, "Back")
		local dur = o.Duration or 3
		Anim.to(timer, { Size = UDim2.new(0, 0, 0, 2) }, dur, "Linear")
		task.delay(dur, dismiss)

		liveNotifs[#liveNotifs + 1] = wrap
		if #liveNotifs > 5 then
			local old = table.remove(liveNotifs, 1)
			if old and old.Parent then old:Destroy() end
		end
		return wrap
	end

	---------------------------------------------------------------------
	-- Reopen bubble
	---------------------------------------------------------------------
	bubble = new("TextButton", {
		Text = "", AutoButtonColor = false, BorderSizePixel = 0, Active = true, Visible = false,
		Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 16, 0.5, -22),
	}, gui)
	bind(bubble, "BackgroundColor3", "Accent")
	cornerOf(bubble, 22)
	local bi = Icons.make(bubble, cfg.ToggleIcon or "menu", 22, "On")
	bi.AnchorPoint = Vector2.new(0.5, 0.5); bi.Position = UDim2.fromScale(0.5, 0.5)
	do
		local down, moved = nil, 0
		bubble.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				down = i.Position; moved = 0
			end
		end)
		keep(UIS.InputChanged:Connect(function(i)
			if down and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				local d = i.Position - down
				moved = max(moved, d.Magnitude)
				bubble.Position = bubble.Position + UDim2.fromOffset(d.X, d.Y)
				down = i.Position
			end
		end))
		bubble.InputEnded:Connect(function(i)
			if down and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
				if moved < 6 then Win:Toggle() end
				down = nil
			end
		end)
	end

	local defaultToggle = cfg.ToggleKey or Enum.KeyCode.RightShift
	keep(UIS.InputBegan:Connect(function(i, gpe)
		if gpe then return end
		local saved = getFlag("ToggleKey", nil)
		local k = (type(saved) == "string" and Enum.KeyCode[saved]) or defaultToggle
		if i.KeyCode == k then Win:Toggle() end
	end))

	---------------------------------------------------------------------
	-- Key gate
	---------------------------------------------------------------------
	local function showGate(ks)
		local g = new("ScreenGui", { Name = guiName .. "_Key", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000 })
		if not pcall(function() g.Parent = host end) or not g.Parent then g.Parent = LocalPlayer:WaitForChild("PlayerGui") end
		local dim = new("Frame", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1, BorderSizePixel = 0, Active = true,
		}, g)
		Anim.to(dim, { BackgroundTransparency = 0.45 }, 0.3)

		local card = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(340, 240), BorderSizePixel = 0,
		}, g)
		bind(card, "BackgroundColor3", "Bg")
		cornerOf(card, Win.Radius)
		local cst = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
		bind(cst, "Color", "Line")

		local t = text(card, ks.Title or "Key required", 16, "Text")
		t.Font = Enum.Font.GothamBold
		t.Position = UDim2.fromOffset(20, 18); t.Size = UDim2.new(1, -40, 0, 22)
		local note = text(card, ks.Note or "Enter your key to continue.", 12, "Dim")
		note.Position = UDim2.fromOffset(20, 46); note.Size = UDim2.new(1, -40, 0, 40)
		note.TextWrapped = true; note.TextYAlignment = Enum.TextYAlignment.Top

		local boxF = new("Frame", { Position = UDim2.fromOffset(20, 96), Size = UDim2.new(1, -40, 0, 32), BorderSizePixel = 0 }, card)
		bind(boxF, "BackgroundColor3", "Panel")
		cornerOf(boxF, 8)
		local box = new("TextBox", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0),
			Text = "", PlaceholderText = "Paste your key", ClearTextOnFocus = false, TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left, Font = CurrentFont,
		}, boxF)
		fontList[#fontList + 1] = box
		bind(box, "TextColor3", "Text")
		bind(box, "PlaceholderColor3", "Dim")

		local status = text(card, "", 12, "Dim")
		status.Position = UDim2.fromOffset(20, 136); status.Size = UDim2.new(1, -40, 0, 18)
		local function setStatus(msg, ok)
			status.Text = msg or ""
			Anim.to(status, { TextColor3 = ok and rgb(90, 220, 160) or rgb(255, 95, 95) }, 0.2)
		end

		local verify = new("TextButton", {
			Position = UDim2.fromOffset(20, 170),
			Size = UDim2.new(ks.GetKeyUrl and 0.5 or 1, ks.GetKeyUrl and -26 or -40, 0, 38),
			Text = "Verify", TextSize = 14, Font = Enum.Font.GothamBold, AutoButtonColor = false,
			BorderSizePixel = 0, Active = true,
		}, card)
		fontList[#fontList + 1] = verify
		cornerOf(verify, 8)
		bind(verify, "BackgroundColor3", "Accent")
		bind(verify, "TextColor3", "On")

		if ks.GetKeyUrl then
			local getk = new("TextButton", {
				Position = UDim2.new(0.5, 6, 0, 170), Size = UDim2.new(0.5, -26, 0, 38),
				Text = "Get key", TextSize = 14, Font = CurrentFont, AutoButtonColor = false,
				BorderSizePixel = 0, Active = true,
			}, card)
			fontList[#fontList + 1] = getk
			cornerOf(getk, 8)
			bind(getk, "BackgroundColor3", "Item")
			bind(getk, "TextColor3", "Text")
			getk.MouseButton1Click:Connect(function()
				if setclipboard then pcall(setclipboard, ks.GetKeyUrl) end
				setStatus("Key link copied to clipboard", true)
			end)
		end

		local busy = false
		verify.MouseButton1Click:Connect(function()
			if busy then return end
			busy = true
			setStatus("Checking...", true)
			task.spawn(function()
				local ok, msg = checkKey(ks, box.Text)
				busy = false
				setStatus(msg, ok)
				if not ok then return end
				if ks.Remember ~= false and writefile then
					pcall(writefile, saveName .. "_key.txt", box.Text)
				end
				Win.Unlocked = true
				Win:Toggle(true)
				safeCall(ks.OnPass, Win)
				task.delay(0.5, function()
					Anim.to(card, { Position = UDim2.fromScale(0.5, 0.42) }, 0.25)
					Anim.to(dim, { BackgroundTransparency = 1 }, 0.3)
					task.delay(0.35, function() g:Destroy() end)
				end)
			end)
		end)
	end

	if cfg.KeySystem and cfg.KeySystem.Enabled then
		local ks = cfg.KeySystem
		task.spawn(function()
			local remembered
			if isfile and readfile and isfile(saveName .. "_key.txt") then
				pcall(function() remembered = readfile(saveName .. "_key.txt") end)
			end
			if remembered and remembered ~= "" then
				local ok = checkKey(ks, remembered)
				if ok then
					Win.Unlocked = true
					if cfg.StartOpen ~= false then Win:Toggle(true) end
					safeCall(ks.OnPass, Win)
					return
				end
			end
			showGate(ks)
		end)
	else
		Win.Unlocked = true
	end

	---------------------------------------------------------------------
	-- Settings tab
	---------------------------------------------------------------------
	if cfg.Settings then
		local S = Win:AddTab("Settings", "settings")
		S:AddSection("Appearance")
		S:AddThemePreview({
			Title = "Theme", Flag = "Theme",
			Default = type(cfg.Theme) == "string" and cfg.Theme or "Midnight",
			Callback = function(v) Win:SetTheme(v) end,
		})
		S:AddToggle({
			Title = "Animated accent colour", Icon = "sparkles", Flag = "AccentCycle", Default = false,
			Callback = function(v) Win:SetAccentCycle(v) end,
		})
		S:AddToggle({
			Title = "Borders", Icon = "square", Flag = "Borders", Default = Win.Borders,
			Callback = function(v) Win:SetBorders(v) end,
		})
		S:AddSlider({
			Title = "Corner radius", Icon = "circle-dashed", Min = 0, Max = 20, Step = 1, Flag = "Radius",
			Default = Win.Radius, Callback = function(v) Win:SetRadius(v) end,
		})
		S:AddSlider({
			Title = "UI scale", Icon = "maximize-2", Min = 70, Max = 140, Step = 5, Suffix = "%", Flag = "Scale",
			Default = 100, Callback = function(v) Win:SetScale(v) end,
		})
		S:AddSection("Layout")
		S:AddDropdown({
			Title = "Navigation", Icon = "layout-panel-left", Flag = "Layout",
			Options = { "Sidebar", "Topbar" }, Default = Win.Layout,
			Callback = function(v) Win:SetLayout(v) end,
		})
		S:AddFontPicker({
			Title = "Font", Flag = "Font", Default = "GothamMedium",
			Callback = function(v) Win:SetFont(v) end,
		})
		S:AddSection("Window")
		S:AddKeybind({
			Title = "Toggle key", Icon = "keyboard", Flag = "ToggleKey", Default = defaultToggle,
		})
	end

	Win:SetTheme(getFlag("Theme", cfg.Theme or "Midnight"), false)
	if getFlag("AccentCycle", false) then Win:SetAccentCycle(true) end
	if getFlag("Borders", nil) ~= nil then setAllBorders(getFlag("Borders", true) == true) end
	if getFlag("Radius", nil) then setAllRadius(getFlag("Radius", Win.Radius)) end
	local savedFont = getFlag("Font", nil)
	if savedFont and Enum.Font[savedFont] then Win:SetFont(savedFont) end
	Win.Layout = getFlag("Layout", Win.Layout) == "Topbar" and "Topbar" or "Sidebar"
	layout(true)
	local savedScale = getFlag("Scale", nil)
	if savedScale then
		Win._scale = clamp(savedScale / 100, 0.7, 1.4)
		mainScale.Scale = Win._scale
	end

	if cfg.StartOpen ~= false and Win.Unlocked then Win:Toggle(true) end
	return Win
end

return Semesta
