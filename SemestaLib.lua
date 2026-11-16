-- Semesta: Roblox hub UI library
--  * Parent: gethui() (falls back to CoreGui / PlayerGui)
--  * Main frame + floating toggle: Draggable = true AND Active = true
--  * Search box on top, tabs with a sliding highlight, everything tweens (1s, Quint Out)
--  * Every element has a framed background; big buttons, toggles, textboxes, sliders
--  * Icons: Lucide name ("house"), rbxassetid, or https://...svg URL. Colour adjustable.
--  * Settings: resize, element size, theme presets (live preview), icon colour,
--    notification on/off, spawn position, duration, preview. Save & Apply writes a file.
--  * Notifications with a time bar. They never block touch (pass-through).

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local sqrt, abs, floor, ceil, min, max = math.sqrt, math.abs, math.floor, math.ceil, math.min, math.max
local atan2, rad, deg, cos, sin = math.atan2, math.rad, math.deg, math.cos, math.sin

local Semesta = { Version = "1.0" }
local ANIM = 1 -- every tween is 1 second, Quint Out (override with cfg.AnimTime)

-- ======================= themes =======================

local THEMES = {
    Midnight = { Bg = Color3.fromRGB(17, 17, 23), Panel = Color3.fromRGB(26, 26, 34), Item = Color3.fromRGB(35, 35, 46), Line = Color3.fromRGB(48, 48, 62), Accent = Color3.fromRGB(124, 111, 255), Text = Color3.fromRGB(240, 240, 245), Dim = Color3.fromRGB(145, 145, 160), On = Color3.new(1, 1, 1) },
    Ocean = { Bg = Color3.fromRGB(10, 22, 34), Panel = Color3.fromRGB(16, 34, 50), Item = Color3.fromRGB(24, 48, 68), Line = Color3.fromRGB(36, 66, 90), Accent = Color3.fromRGB(80, 170, 255), Text = Color3.fromRGB(230, 242, 255), Dim = Color3.fromRGB(128, 160, 186), On = Color3.new(1, 1, 1) },
    Forest = { Bg = Color3.fromRGB(14, 24, 18), Panel = Color3.fromRGB(22, 36, 27), Item = Color3.fromRGB(31, 50, 38), Line = Color3.fromRGB(45, 70, 54), Accent = Color3.fromRGB(90, 220, 140), Text = Color3.fromRGB(232, 245, 236), Dim = Color3.fromRGB(140, 170, 150), On = Color3.fromRGB(10, 30, 18) },
    Sunset = { Bg = Color3.fromRGB(26, 16, 18), Panel = Color3.fromRGB(38, 24, 27), Item = Color3.fromRGB(54, 34, 38), Line = Color3.fromRGB(78, 50, 56), Accent = Color3.fromRGB(255, 140, 70), Text = Color3.fromRGB(255, 240, 235), Dim = Color3.fromRGB(180, 140, 135), On = Color3.new(1, 1, 1) },
    Rose = { Bg = Color3.fromRGB(24, 14, 22), Panel = Color3.fromRGB(36, 22, 34), Item = Color3.fromRGB(52, 32, 49), Line = Color3.fromRGB(76, 48, 72), Accent = Color3.fromRGB(255, 110, 160), Text = Color3.fromRGB(255, 238, 246), Dim = Color3.fromRGB(175, 135, 162), On = Color3.new(1, 1, 1) },
    Mono = { Bg = Color3.fromRGB(12, 12, 12), Panel = Color3.fromRGB(22, 22, 22), Item = Color3.fromRGB(32, 32, 32), Line = Color3.fromRGB(50, 50, 50), Accent = Color3.fromRGB(230, 230, 230), Text = Color3.fromRGB(245, 245, 245), Dim = Color3.fromRGB(150, 150, 150), On = Color3.fromRGB(10, 10, 10) },
}
local THEME_NAMES = { "Midnight", "Ocean", "Forest", "Sunset", "Rose", "Mono" }
local NOTIF_POS = { -- name, anchor, real position (top right sits a bit down from the top edge)
    { "Top right", Vector2.new(1, 0), UDim2.new(1, -12, 0, 56) },
    { "Top left", Vector2.new(0, 0), UDim2.new(0, 12, 0, 56) },
    { "Bottom right", Vector2.new(1, 1), UDim2.new(1, -12, 1, -20) },
    { "Bottom left", Vector2.new(0, 1), UDim2.new(0, 12, 1, -20) },
}

local Icons -- forward declared (applyTheme uses it); defined below
local Active = THEMES.Midnight
local bound, themeHooks = {}, {}

local function tween(o, props, t)
    local tw = TweenService:Create(o, TweenInfo.new(t or ANIM, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

-- register a property so it follows the active theme
local function paint(o, prop, key)
    bound[#bound + 1] = { o, prop, key }
    o[prop] = Active[key]
    return o
end

-- register a custom colour function (fn(obj, theme))
local function bindFn(o, fn)
    bound[#bound + 1] = { o, "__fn", fn }
    fn(o, Active)
    return o
end

local function applyTheme(name, animated)
    Active = THEMES[name] or THEMES.Midnight
    for i = #bound, 1, -1 do
        local b = bound[i]
        if not b[1].Parent then
            table.remove(bound, i)
        elseif b[2] == "__fn" then
            b[3](b[1], Active)
        elseif b[2] == "__icon" then
            Icons.SetColor(b[1], Active[b[3]])
        elseif animated then
            tween(b[1], { [b[2]] = Active[b[3]] })
        else
            b[1][b[2]] = Active[b[3]]
        end
    end
    for _, fn in ipairs(themeHooks) do fn(animated) end
end

-- ======================= helpers =======================

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local function corner(o, r)
    return new("UICorner", { CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r) }, o)
end

local function stroke(o, key, th, tr)
    return paint(new("UIStroke", { Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o), "Color", key or "Line")
end

local function rawText(parent, str, size, font, align)
    return new("TextLabel", {
        Text = str, TextSize = size, Font = font or Enum.Font.Gotham, TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = align or Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end

local function label(parent, str, size, key, font, align)
    return paint(rawText(parent, str, size, font, align), "TextColor3", key or "Text")
end

local function col(t) return Color3.fromRGB(t[1], t[2], t[3]) end

-- ======================= Lucide SVG -> Frames =======================
-- Each icon is fetched once, built at 24x24, then Clone()d and sized with UIScale.
-- Circles/rects/lines are single Frames (UIStroke), paths are segment chains.

Icons = { Templates = {}, Loading = {}, Holders = {}, Color = Color3.fromRGB(240, 240, 245) }
local LUCIDE_URL = "https://unpkg.com/lucide-static/icons/%s.svg"

local function attrsOf(s)
    local t = {}
    for k, v in s:gmatch('([%w%-]+)="([^"]*)"') do t[k] = v end
    return t
end

local function bezier(pts, x0, y0, x1, y1, x2, y2, x3, y3)
    local l = sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) + sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) + sqrt((x3 - x2) ^ 2 + (y3 - y2) ^ 2)
    local n = math.clamp(ceil(l / 3), 3, 14)
    for i = 1, n do
        local t, u = i / n, 1 - i / n
        pts[#pts + 1] = {
            u * u * u * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * x3,
            u * u * u * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * y3,
        }
    end
end

local function arc(pts, x1, y1, rx, ry, phi, fa, fs, x2, y2)
    if rx == 0 or ry == 0 or (x1 == x2 and y1 == y2) then
        pts[#pts + 1] = { x2, y2 }
        return
    end
    rx, ry = abs(rx), abs(ry)
    local p = rad(phi)
    local c, s = cos(p), sin(p)
    local dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    local x1p, y1p = c * dx + s * dy, -s * dx + c * dy
    local lam = x1p ^ 2 / rx ^ 2 + y1p ^ 2 / ry ^ 2
    if lam > 1 then
        local k = sqrt(lam)
        rx, ry = rx * k, ry * k
    end
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
    if fs == 0 and dth > 0 then dth = dth - 2 * math.pi
    elseif fs == 1 and dth < 0 then dth = dth + 2 * math.pi end
    local n = math.clamp(ceil(abs(dth) * sqrt(max(rx, ry)) * 1.2), 4, 32)
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
    local pos = 1
    local cx, cy, sx, sy, lcx, lcy, prev = 0, 0, 0, 0, 0, 0, ""
    local function skip() pos = d:find("[^%s,]", pos) or (#d + 1) end
    local function num()
        skip()
        local m = d:match("^[-+]?%d+%.?%d*", pos) or d:match("^[-+]?%.%d+", pos)
        if not m then error("bad number") end
        pos = pos + #m
        return tonumber(m)
    end
    local function flag()
        skip()
        local ch = d:sub(pos, pos)
        pos += 1
        return tonumber(ch)
    end
    local function ensure()
        if not cur then
            cur = { points = { { cx, cy } }, closed = false }
            paths[#paths + 1] = cur
        end
        return cur.points
    end
    local cmd
    while true do
        skip()
        if pos > #d then break end
        local ch = d:sub(pos, pos)
        if ch:match("%a") then
            cmd = ch
            pos += 1
            if cmd == "Z" or cmd == "z" then
                if cur then cur.closed = true end
                cx, cy, cur, prev = sx, sy, nil, "Z"
                continue
            end
        end
        if not cmd then error("no command") end
        local rel = cmd:lower() == cmd
        local ox, oy = rel and cx or 0, rel and cy or 0
        local c = cmd:upper()
        if c == "M" then
            cx, cy = num() + ox, num() + oy
            sx, sy = cx, cy
            cur = { points = { { cx, cy } }, closed = false }
            paths[#paths + 1] = cur
            cmd = rel and "l" or "L"
            prev = "M"
        elseif c == "L" then
            local pts = ensure()
            cx, cy = num() + ox, num() + oy
            pts[#pts + 1] = { cx, cy }
            prev = "L"
        elseif c == "H" then
            local pts = ensure()
            cx = num() + ox
            pts[#pts + 1] = { cx, cy }
            prev = "H"
        elseif c == "V" then
            local pts = ensure()
            cy = num() + oy
            pts[#pts + 1] = { cx, cy }
            prev = "V"
        elseif c == "C" then
            local pts = ensure()
            local x1, y1, x2, y2 = num() + ox, num() + oy, num() + ox, num() + oy
            local x, y = num() + ox, num() + oy
            bezier(pts, cx, cy, x1, y1, x2, y2, x, y)
            lcx, lcy, cx, cy, prev = x2, y2, x, y, "C"
        elseif c == "S" then
            local pts = ensure()
            local x1, y1 = cx, cy
            if prev == "C" or prev == "S" then x1, y1 = 2 * cx - lcx, 2 * cy - lcy end
            local x2, y2 = num() + ox, num() + oy
            local x, y = num() + ox, num() + oy
            bezier(pts, cx, cy, x1, y1, x2, y2, x, y)
            lcx, lcy, cx, cy, prev = x2, y2, x, y, "S"
        elseif c == "Q" or c == "T" then
            local pts = ensure()
            local qx, qy
            if c == "Q" then
                qx, qy = num() + ox, num() + oy
            else
                qx, qy = cx, cy
                if prev == "Q" or prev == "T" then qx, qy = 2 * cx - lcx, 2 * cy - lcy end
            end
            local x, y = num() + ox, num() + oy
            bezier(pts, cx, cy, cx + 2 / 3 * (qx - cx), cy + 2 / 3 * (qy - cy), x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y), x, y)
            lcx, lcy, cx, cy, prev = qx, qy, x, y, c
        elseif c == "A" then
            local pts = ensure()
            local rx, ry, phi = num(), num(), num()
            local fa, fs = flag(), flag()
            local x, y = num() + ox, num() + oy
            arc(pts, cx, cy, rx, ry, phi, fa, fs, x, y)
            cx, cy, prev = x, y, "A"
        else
            error("unsupported command " .. cmd)
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
            if l2 == 0 then
                dist = sqrt((px - ax) ^ 2 + (py - ay) ^ 2)
            else
                dist = abs(dx * (ay - py) - (ax - px) * dy) / sqrt(l2)
            end
            if dist > md then md, mi = dist, k end
        end
        if mi and md > eps then
            keep[mi] = true
            rec(i, mi)
            rec(mi, j)
        end
    end
    rec(1, n)
    local out = {}
    for i = 1, n do if keep[i] then out[#out + 1] = pts[i] end end
    return out
end

local function nums(s)
    local out = {}
    for n in tostring(s):gmatch("[-+]?%d*%.?%d+") do out[#out + 1] = tonumber(n) end
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
            BackgroundColor3 = white, BorderSizePixel = 0,
        })
        corner(f, UDim.new(0.5, 0))
        f.Parent = root
    end

    local function poly(pts, closed)
        pts = simplify(pts, 0.1)
        if closed and #pts > 2 then
            pts = table.clone(pts)
            pts[#pts + 1] = pts[1]
        end
        if #pts == 1 then pts = { pts[1], pts[1] } end
        for i = 1, #pts - 1 do seg(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]) end
    end

    local function native(cx, cy, w, h, cr, ellipse)
        local f = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.fromOffset(max(w - th, 0), max(h - th, 0)), Position = UDim2.fromOffset(cx, cy),
        })
        if ellipse then
            corner(f, UDim.new(0.5, 0))
        elseif cr - th / 2 > 0.3 then
            corner(f, cr - th / 2)
        end
        local s = new("UIStroke", { Color = white, Thickness = th, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
        s.LineJoinMode = Enum.LineJoinMode.Round
        f.Parent = root
    end

    for tag, a in svg:gmatch("<(%a+)%s([^>]-)/?>") do
        local at = attrsOf(a)
        local function n(k, d) return tonumber(at[k]) or d or 0 end
        if tag == "path" and at.d then
            local ok, subs = pcall(parsePath, at.d)
            if ok then
                for _, s in ipairs(subs) do poly(s.points, s.closed) end
            end
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
            local r = n("r")
            native(n("cx"), n("cy"), r * 2, r * 2, 0, true)
        elseif tag == "ellipse" then
            native(n("cx"), n("cy"), n("rx") * 2, n("ry") * 2, 0, true)
        end
    end
    new("UIScale", { Scale = 1 }, root)
    return root
end

function Icons.Get(name)
    local t = Icons.Templates[name]
    if t ~= nil then return t or nil end
    if Icons.Loading[name] then
        while Icons.Loading[name] do task.wait() end
        return Icons.Templates[name] or nil
    end
    Icons.Loading[name] = true
    local url = name:find("^https?://") and name or LUCIDE_URL:format(name)
    local tpl = false
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and type(res) == "string" and res:find("<svg") then
        local ok2, built = pcall(buildTemplate, res)
        if ok2 then tpl = built end
    end
    Icons.Templates[name] = tpl
    Icons.Loading[name] = nil
    return tpl or nil
end

local function tint(frame, color)
    for _, d in ipairs(frame:GetDescendants()) do
        if d:IsA("Frame") then
            if d.BackgroundTransparency < 1 then d.BackgroundColor3 = color end
        elseif d:IsA("UIStroke") then
            d.Color = color
        end
    end
end

function Icons.SetColor(holder, color)
    holder:SetAttribute("Tint", color)
    local c = holder:FindFirstChild("IconTpl")
    if c then tint(c, color) end
end

-- returns a holder Frame immediately; the SVG is drawn in the background
function Icons.Make(parent, name, size, color, custom)
    local holder = new("Frame", {
        Name = "Icon_" .. tostring(name), BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromOffset(size, size),
    })
    holder:SetAttribute("Tint", color or Icons.Color)
    holder:SetAttribute("Custom", custom and true or false)
    holder.Parent = parent
    Icons.Holders[#Icons.Holders + 1] = holder
    task.spawn(function()
        local tpl = Icons.Get(name)
        if not tpl or not holder.Parent then return end
        local c = tpl:Clone()
        c.UIScale.Scale = size / 24
        c.Parent = holder
        tint(c, holder:GetAttribute("Tint"))
    end)
    return holder
end

-- Lucide icon that follows the active theme (key = theme colour name)
local function icon(parent, name, size, key)
    local h = Icons.Make(parent, name, size, Active[key], true)
    bound[#bound + 1] = { h, "__icon", key }
    return h
end

function Icons.SetAll(color)
    Icons.Color = color
    for i = #Icons.Holders, 1, -1 do
        local h = Icons.Holders[i]
        if not h.Parent then
            table.remove(Icons.Holders, i)
        elseif not h:GetAttribute("Custom") then
            Icons.SetColor(h, color)
        end
    end
end

-- Lucide name / rbxassetid / number / https svg -> visual
local function media(parent, v, size, color)
    if typeof(v) == "number" or (type(v) == "string" and v:match("^%d+$")) then
        v = "rbxassetid://" .. tostring(v)
    end
    if type(v) == "string" and v:find("^rbxasset") then
        return new("ImageLabel", { BackgroundTransparency = 1, Image = v, Size = UDim2.fromOffset(size, size), ScaleType = Enum.ScaleType.Fit }, parent)
    end
    return Icons.Make(parent, v, size, color or Icons.Color, color ~= nil)
end

-- left-side media in a row; returns the text x offset
local function rowIcon(f, v, color, size)
    size = size or 20
    if not v then return 12 end
    local m = media(f, v, size, color)
    m.AnchorPoint = Vector2.new(0, 0.5)
    m.Position = UDim2.new(0, 12, 0.5, 0)
    return 12 + size + 10
end

Semesta.Icons = Icons
Semesta.Themes = THEMES

-- ======================= window =======================

function Semesta:CreateWindow(cfg)
    cfg = cfg or {}
    if cfg.AnimTime then ANIM = cfg.AnimTime end
    local title = cfg.Title or "Semesta"
    local saveFile = (cfg.SaveName or "Semesta") .. "_settings.json"

    local DEFAULT = {
        Width = 340, Height = 300, Scale = 100, IconColor = { 240, 240, 245 },
        Theme = "Midnight", NotifPos = 1, NotifTime = 3, NotifOn = true,
    }
    if typeof(cfg.Size) == "Vector2" then DEFAULT.Width, DEFAULT.Height = cfg.Size.X, cfg.Size.Y end

    local function copy(t)
        local c = {}
        for k, v in pairs(t) do c[k] = type(v) == "table" and table.clone(v) or v end
        return c
    end
    local function sanitize(s)
        s.Width = math.clamp(tonumber(s.Width) or DEFAULT.Width, 240, 700)
        s.Height = math.clamp(tonumber(s.Height) or DEFAULT.Height, 200, 600)
        s.Scale = math.clamp(tonumber(s.Scale) or 100, 70, 150)
        if not THEMES[s.Theme] then s.Theme = "Midnight" end
        s.NotifPos = math.clamp(tonumber(s.NotifPos) or 1, 1, #NOTIF_POS)
        s.NotifTime = math.clamp(tonumber(s.NotifTime) or 3, 1, 10)
        s.NotifOn = s.NotifOn ~= false
        if type(s.IconColor) ~= "table" or #s.IconColor ~= 3 then s.IconColor = { 240, 240, 245 } end
        return s
    end

    local settings = copy(DEFAULT)
    pcall(function()
        if isfile and isfile(saveFile) then
            local d = HttpService:JSONDecode(readfile(saveFile))
            for k in pairs(DEFAULT) do
                if d[k] ~= nil then settings[k] = d[k] end
            end
        end
    end)
    sanitize(settings)
    Icons.Color = col(settings.IconColor)
    applyTheme(settings.Theme, false)

    local Window = { Tabs = {}, Items = {}, Loaded = false, Settings = settings }
    local scale = settings.Scale / 100
    local notifOn = settings.NotifOn
    local notifs, notifN = {}, 0
    local userPicked = false

    -- ---------- gui root (gethui) ----------
    local guiName = cfg.GuiName or "Semesta"
    local ok, h = pcall(function() return (gethui and gethui()) or game:GetService("CoreGui") end)
    local host = (ok and h) or Players.LocalPlayer:WaitForChild("PlayerGui")
    pcall(function()
        local old = host:FindFirstChild(guiName)
        if old then old:Destroy() end
    end)
    local gui = new("ScreenGui", {
        Name = guiName, ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
    })
    local parented = pcall(function() gui.Parent = host end)
    if not parented or not gui.Parent then gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
    Window.Gui = gui

    -- ---------- main frame (Draggable + Active) ----------
    local main = paint(new("Frame", {
        Name = "Main", Size = UDim2.fromOffset(settings.Width, settings.Height),
        Position = UDim2.new(0.5, -settings.Width / 2, 0.5, -settings.Height / 2),
        BorderSizePixel = 0, Visible = false,
    }), "BackgroundColor3", "Bg")
    main.Active = true
    main.Draggable = true
    corner(main, 12)
    stroke(main, "Line", 1)
    local mainScale = new("UIScale", { Scale = 1 }, main)
    main.Parent = gui

    -- ---------- header: optional Lucide icon, custom image, title ----------
    local header = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, main)
    local hx = 12
    local function headerItem(v, sz)
        local m = media(header, v, sz)
        m.AnchorPoint = Vector2.new(0, 0.5)
        m.Position = UDim2.new(0, hx, 0.5, 0)
        hx += sz + 6
    end
    if cfg.Icon then headerItem(cfg.Icon, 18) end
    if cfg.Image then headerItem(cfg.Image, 20) end
    local titleLbl = label(header, title, 15, "Text", Enum.Font.GothamBold)
    titleLbl.Position = UDim2.fromOffset(hx, 0)
    titleLbl.Size = UDim2.new(1, -hx - 44, 1, 0)

    local closeBtn = new("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Active = true,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(28, 28),
    }, header)
    local cIc = icon(closeBtn, "x", 16, "Dim")
    cIc.AnchorPoint = Vector2.new(0.5, 0.5)
    cIc.Position = UDim2.fromScale(0.5, 0.5)

    -- ---------- search (top) ----------
    local searchBar = paint(new("Frame", { Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 0, 30), BorderSizePixel = 0 }, main), "BackgroundColor3", "Panel")
    corner(searchBar, 8)
    stroke(searchBar, "Line", 1)
    local sIc = icon(searchBar, "search", 16, "Dim")
    sIc.AnchorPoint = Vector2.new(0, 0.5)
    sIc.Position = UDim2.new(0, 9, 0.5, 0)
    local search = paint(paint(new("TextBox", {
        Text = "", PlaceholderText = "Search...", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -40, 1, 0),
    }, searchBar), "TextColor3", "Text"), "PlaceholderColor3", "Dim")

    -- ---------- tab highlight (created before the tab bar so it sits behind it) ----------
    local hl = paint(new("Frame", { Size = UDim2.fromOffset(0, 26), BorderSizePixel = 0 }, main), "BackgroundColor3", "Accent")
    corner(hl, 8)

    local tabBar = new("ScrollingFrame", {
        Position = UDim2.fromOffset(10, 76), Size = UDim2.new(1, -20, 0, 28), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X,
        AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
    }, main)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
    }, tabBar)

    -- ---------- content (CanvasGroup so a tab switch can fade it) ----------
    local page = new("CanvasGroup", {
        Position = UDim2.fromOffset(10, 110), Size = UDim2.new(1, -20, 1, -118),
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, main)
    local content = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
    }, page)
    paint(content, "ScrollBarImageColor3", "Line")
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
    local emptyLbl = label(main, "No results", 13, "Dim", Enum.Font.Gotham, Enum.TextXAlignment.Center)
    emptyLbl.Position = UDim2.new(0, 0, 0, 150)
    emptyLbl.Size = UDim2.new(1, 0, 0, 20)
    emptyLbl.Visible = false

    -- ---------- notifications (pass-through: no Active, nothing blocks touch) ----------
    local notifHolder = new("Frame", {
        Name = "Notifications", BackgroundTransparency = 1, Size = UDim2.fromOffset(260, 0),
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 10,
    }, gui)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, notifHolder)
    local function placeNotifs(i, instant)
        local p = NOTIF_POS[i] or NOTIF_POS[1]
        notifHolder.AnchorPoint = p[2]
        if instant then notifHolder.Position = p[3] else tween(notifHolder, { Position = p[3] }) end
    end
    placeNotifs(settings.NotifPos, true)

    -- ---------- refresh (tab + search) ----------
    local refreshQueued = false
    local function refresh()
        refreshQueued = false
        local q = search.Text:lower()
        local any = false
        for _, item in ipairs(Window.Items) do
            local show
            if q ~= "" then
                show = item.name:find(q, 1, true) ~= nil
            else
                show = item.tab == Window.ActiveTab
            end
            item.frame.Visible = show
            if show then any = true end
        end
        emptyLbl.Visible = not any
    end
    local function queueRefresh()
        if refreshQueued then return end
        refreshQueued = true
        task.defer(refresh)
    end
    search:GetPropertyChangedSignal("Text"):Connect(queueRefresh)

    -- ---------- items ----------
    local order = 0
    local function row(tab, name, baseH, fixed)
        order += 1
        local f = paint(new("Frame", {
            Size = UDim2.new(1, -4, 0, fixed and baseH or baseH * scale), BorderSizePixel = 0,
            LayoutOrder = tab.Index * 1000 + order,
        }, content), "BackgroundColor3", "Item")
        corner(f, 10)
        stroke(f, "Line", 1, 0.5)
        local item = { frame = f, name = tostring(name):lower(), tab = tab, baseH = baseH, fixed = fixed }
        Window.Items[#Window.Items + 1] = item
        queueRefresh()
        return f, item
    end

    local function applyScale()
        for _, item in ipairs(Window.Items) do
            if not item.fixed then item.frame.Size = UDim2.new(1, -4, 0, item.baseH * scale) end
            if item.apply then item.apply(scale) end
        end
    end

    -- ---------- tabs ----------
    local function refreshTabs(anim)
        for _, t in ipairs(Window.Tabs) do
            local on = t == Window.ActiveTab
            local c = on and Active.On or Active.Dim
            if anim then tween(t.lbl, { TextColor3 = c }) else t.lbl.TextColor3 = c end
            Icons.SetColor(t.ic, c)
        end
    end
    table.insert(themeHooks, function(anim) refreshTabs(anim) end)

    local function moveHighlight(tab, instant)
        if not tab or not tab.btn then return end
        local b, s = tab.btn, mainScale.Scale
        local p = Vector2.new(b.AbsolutePosition.X - main.AbsolutePosition.X, b.AbsolutePosition.Y - main.AbsolutePosition.Y) / s
        local sz = b.AbsoluteSize / s
        local pos, size = UDim2.fromOffset(p.X, p.Y), UDim2.fromOffset(sz.X, sz.Y)
        if instant then
            hl.Position, hl.Size = pos, size
        else
            tween(hl, { Position = pos, Size = size })
        end
    end

    local function selectTab(tab, instant)
        Window.ActiveTab = tab
        refreshTabs(not instant)
        moveHighlight(tab, instant)
        if not instant then
            page.GroupTransparency = 0.5
            tween(page, { GroupTransparency = 0 })
        end
        content.CanvasPosition = Vector2.new(0, 0)
        queueRefresh()
    end

    function Window:AddTab(name, iconName, isSettings)
        local Tab = { Name = name, Index = isSettings and 99 or (#Window.Tabs + 1), IsSettings = isSettings and true or false }
        local btn = new("TextButton", {
            Text = "", AutoButtonColor = false, Active = true, BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), LayoutOrder = Tab.Index,
        }, tabBar)
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
            VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
        }, btn)
        new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, btn)
        local ic = Icons.Make(btn, iconName or "circle", 14, Active.Dim, true)
        ic.LayoutOrder = 1
        local lbl = rawText(btn, name, 12, Enum.Font.GothamMedium)
        lbl.AutomaticSize = Enum.AutomaticSize.X
        lbl.Size = UDim2.fromOffset(0, 26)
        lbl.LayoutOrder = 2
        lbl.TextColor3 = Active.Dim
        Tab.btn, Tab.lbl, Tab.ic = btn, lbl, ic
        Window.Tabs[#Window.Tabs + 1] = Tab
        btn.MouseButton1Click:Connect(function()
            userPicked = true
            selectTab(Tab)
        end)

        local cur = Window.ActiveTab
        if cur == nil or (cur.IsSettings and not isSettings) then
            selectTab(Tab, true)
            task.defer(function() moveHighlight(Tab, true) end)
        end

        -- ----- elements -----
        function Tab:AddLabel(str, iconV)
            local f, item = row(Tab, str, 30)
            local x = rowIcon(f, iconV)
            local l = label(f, str, 13, "Dim", Enum.Font.GothamMedium)
            l.Position = UDim2.fromOffset(x, 0)
            l.Size = UDim2.new(1, -x - 10, 1, 0)
            item.apply = function(s) l.TextSize = floor(13 * s + 0.5) end
            item.apply(scale)
            return { Set = function(_, v) l.Text = tostring(v) item.name = tostring(v):lower() end }
        end

        function Tab:AddButton(o)
            local f, item = row(Tab, o.Text or "Button", 46)
            local x = rowIcon(f, o.Icon, o.IconColor)
            local l = label(f, o.Text or "Button", 14, "Text", Enum.Font.GothamMedium)
            l.Position = UDim2.fromOffset(x, 0)
            l.Size = UDim2.new(1, -x - 10, 1, 0)
            local hit = new("TextButton", {
                Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Active = true, Size = UDim2.fromScale(1, 1),
            }, f)
            item.apply = function(s) l.TextSize = floor(14 * s + 0.5) end
            item.apply(scale)
            hit.MouseButton1Click:Connect(function()
                f.BackgroundColor3 = Active.Accent
                tween(f, { BackgroundColor3 = Active.Item })
                if o.Callback then task.spawn(o.Callback) end
            end)
            local obj = {}
            function obj:SetText(v) l.Text = v item.name = v:lower() end
            return obj
        end

        function Tab:AddToggle(o)
            local state = o.Default == true
            local f, item = row(Tab, o.Text or "Toggle", 46)
            local x = rowIcon(f, o.Icon, o.IconColor)
            local l = label(f, o.Text or "Toggle", 14, "Text", Enum.Font.GothamMedium)
            l.Position = UDim2.fromOffset(x, 0)
            l.Size = UDim2.new(1, -x - 70, 1, 0)
            local track = bindFn(new("Frame", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.fromOffset(44, 24), BorderSizePixel = 0,
            }, f), function(t, A) t.BackgroundColor3 = state and A.Accent or A.Bg end)
            corner(track, 12)
            local knob = new("Frame", {
                Position = UDim2.fromOffset(state and 23 or 3, 3), Size = UDim2.fromOffset(18, 18),
                BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
            }, track)
            corner(knob, UDim.new(0.5, 0))

            local function setState(v, silent)
                state = v and true or false
                tween(track, { BackgroundColor3 = state and Active.Accent or Active.Bg })
                tween(knob, { Position = UDim2.fromOffset(state and 23 or 3, 3) })
                if not silent and o.Callback then task.spawn(o.Callback, state) end
            end
            local hit = new("TextButton", {
                Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Active = true, Size = UDim2.fromScale(1, 1),
            }, f)
            hit.MouseButton1Click:Connect(function() setState(not state) end)
            item.apply = function(s) l.TextSize = floor(14 * s + 0.5) end
            item.apply(scale)

            local obj = {}
            function obj:Set(v, silent) setState(v, silent) end
            function obj:Get() return state end
            return obj
        end

        function Tab:AddSlider(o)
            local lo, hi, step = o.Min or 0, o.Max or 100, o.Step or 1
            local value = math.clamp(o.Default or lo, lo, hi)
            local f, item = row(Tab, o.Text or "Slider", 56)
            local x = rowIcon(f, o.Icon, o.IconColor)
            local l = label(f, o.Text or "Slider", 14, "Text", Enum.Font.GothamMedium)
            l.Position = UDim2.fromOffset(x, 6)
            l.Size = UDim2.new(1, -x - 80, 0, 20)
            local vl = label(f, tostring(value), 13, "Dim", Enum.Font.GothamMedium, Enum.TextXAlignment.Right)
            vl.Position = UDim2.new(1, -78, 0, 6)
            vl.Size = UDim2.fromOffset(66, 20)
            local track = paint(new("Frame", {
                AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 1, -14),
                Size = UDim2.new(1, -24, 0, 8), BorderSizePixel = 0,
            }, f), "BackgroundColor3", "Bg")
            corner(track, 4)
            local fill = paint(new("Frame", { Size = UDim2.fromScale((value - lo) / (hi - lo), 1), BorderSizePixel = 0 }, track), "BackgroundColor3", "Accent")
            corner(fill, 4)
            local knob = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(16, 16),
                BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
            }, fill)
            corner(knob, UDim.new(0.5, 0))
            local hit = new("TextButton", {
                Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Active = true,
                Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0.5, 0),
            }, f)

            local function setValue(v, silent)
                v = math.clamp(floor((v - lo) / step + 0.5) * step + lo, lo, hi)
                if v == value and not silent then return end
                value = v
                fill.Size = UDim2.fromScale((value - lo) / (hi - lo), 1)
                vl.Text = tostring(value)
                if not silent and o.Callback then task.spawn(o.Callback, value) end
            end
            local dragging = false
            local function fromX(px)
                local a = math.clamp((px - track.AbsolutePosition.X) / max(track.AbsoluteSize.X, 1), 0, 1)
                setValue(lo + (hi - lo) * a)
            end
            hit.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    fromX(i.Position.X)
                end
            end)
            UIS.InputChanged:Connect(function(i)
                if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                    fromX(i.Position.X)
                end
            end)
            UIS.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
            item.apply = function(s)
                l.TextSize = floor(14 * s + 0.5)
                vl.TextSize = floor(13 * s + 0.5)
            end
            item.apply(scale)

            local obj = {}
            function obj:Set(v, silent) setValue(v, silent) end
            function obj:Get() return value end
            return obj
        end

        function Tab:AddTextbox(o)
            local f, item = row(Tab, o.Text or "Textbox", 46)
            local x = rowIcon(f, o.Icon, o.IconColor)
            local l = label(f, o.Text or "Textbox", 14, "Text", Enum.Font.GothamMedium)
            l.Position = UDim2.fromOffset(x, 0)
            l.Size = UDim2.new(0.45, -x, 1, 0)
            local boxBg = paint(new("Frame", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.new(0.5, 0, 0, 28), BorderSizePixel = 0,
            }, f), "BackgroundColor3", "Bg")
            corner(boxBg, 7)
            stroke(boxBg, "Line", 1)
            local box = paint(new("TextBox", {
                Text = o.Default or "", PlaceholderText = o.Placeholder or "Type...", ClearTextOnFocus = false,
                Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
                Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0),
            }, boxBg), "TextColor3", "Text")
            paint(box, "PlaceholderColor3", "Dim")
            box.FocusLost:Connect(function(enter)
                if o.Callback then task.spawn(o.Callback, box.Text, enter) end
            end)
            item.apply = function(s) box.TextSize = floor(13 * s + 0.5) end
            item.apply(scale)
            local obj = {}
            function obj:Set(v) box.Text = tostring(v) end
            function obj:Get() return box.Text end
            return obj
        end

        return Tab
    end

    -- ---------- notification spawn ----------
    local function spawnNotif(o, force)
        if not notifOn and not force then return end
        notifN += 1
        local dur = o.Duration or settings.NotifTime or 3
        local f = paint(new("CanvasGroup", {
            Size = UDim2.new(1, 0, 0, 62), BorderSizePixel = 0, GroupTransparency = 1, LayoutOrder = -notifN,
        }, notifHolder), "BackgroundColor3", "Panel")
        corner(f, 10)
        stroke(f, "Line", 1)
        local x = 12
        local iconV = o.Icon or o.Image
        if iconV then
            local m = media(f, iconV, 22, o.IconColor)
            m.AnchorPoint = Vector2.new(0, 0.5)
            m.Position = UDim2.new(0, 12, 0.5, -3)
            x = 44
        end
        local t = label(f, o.Title or "Notification", 14, "Text", Enum.Font.GothamBold)
        t.Position = UDim2.fromOffset(x, 9)
        t.Size = UDim2.new(1, -x - 12, 0, 18)
        local b = label(f, o.Text or "", 12, "Dim")
        b.Position = UDim2.fromOffset(x, 28)
        b.Size = UDim2.new(1, -x - 12, 0, 16)
        local bar = paint(new("Frame", {
            Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3), BorderSizePixel = 0,
        }, f), "BackgroundColor3", "Accent")

        tween(f, { GroupTransparency = 0 })
        TweenService:Create(bar, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) }):Play()

        notifs[#notifs + 1] = f
        while #notifs > 5 do
            local old = table.remove(notifs, 1)
            if old then old:Destroy() end
        end
        task.delay(dur, function()
            if not f.Parent then return end
            local tw = tween(f, { GroupTransparency = 1 })
            tw.Completed:Connect(function() f:Destroy() end)
        end)
    end

    function Window:Notify(o)
        spawnNotif(o or {}, false)
    end

    -- ---------- settings tab (resize, themes, icon colour, notifications, preview) ----------
    local SettingsTab = Window:AddTab("Settings", "settings", true)
    local pend = copy(settings)
    local sliders = {}
    local posBtn, notifToggle, updatePreview, syncUI
    local chipStrokes, swatchStrokes = {}, {}

    -- live preview of the window, element size, theme and notification spawn spot
    do
        local pf = row(SettingsTab, "preview", 150, true)
        pf.ClipsDescendants = true
        local cap = label(pf, "", 11, "Dim", Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
        cap.AnchorPoint = Vector2.new(0.5, 1)
        cap.Position = UDim2.new(0.5, 0, 1, -4)
        cap.Size = UDim2.new(1, -10, 0, 14)

        local mini = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -8),
            BorderSizePixel = 0, ClipsDescendants = true,
        }, pf)
        corner(mini, 6)
        local mStroke = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, mini)
        local mHeader = new("Frame", { BorderSizePixel = 0 }, mini)
        local mSearch = new("Frame", { BorderSizePixel = 0 }, mini)
        corner(mSearch, 4)
        local mRows = {}
        for i = 1, 4 do
            mRows[i] = new("Frame", { BorderSizePixel = 0 }, mini)
            corner(mRows[i], 4)
        end
        local mDot = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0 }, mRows[1])
        corner(mDot, UDim.new(0.5, 0))
        local mBar = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0 }, mRows[3])
        corner(mBar, 3)
        local mNotif = new("Frame", { BorderSizePixel = 0 }, mini)
        corner(mNotif, 4)

        updatePreview = function()
            local T = THEMES[pend.Theme] or THEMES.Midnight
            local pw = pf.AbsoluteSize.X > 20 and pf.AbsoluteSize.X - 16 or 300
            local ph = pf.AbsoluteSize.Y > 20 and pf.AbsoluteSize.Y - 28 or 120
            local s = min(pw / pend.Width, ph / pend.Height)
            mini.Size = UDim2.fromOffset(pend.Width * s, pend.Height * s)
            mini.BackgroundColor3 = T.Bg
            mStroke.Color = T.Line
            mHeader.BackgroundColor3 = T.Panel
            mHeader.Size = UDim2.new(1, 0, 0, 36 * s)
            mSearch.BackgroundColor3 = T.Panel
            mSearch.Position = UDim2.fromOffset(10 * s, 42 * s)
            mSearch.Size = UDim2.new(1, -20 * s, 0, 30 * s)
            local rowH = 46 * (pend.Scale / 100) * s
            local y = 110 * s
            for _, r in ipairs(mRows) do
                r.BackgroundColor3 = T.Item
                r.Position = UDim2.fromOffset(10 * s, y)
                r.Size = UDim2.new(1, -20 * s, 0, rowH)
                y += rowH + 8 * s
            end
            mDot.BackgroundColor3 = col(pend.IconColor)
            mDot.Size = UDim2.fromOffset(rowH * 0.4, rowH * 0.4)
            mDot.Position = UDim2.new(0, rowH * 0.3, 0.5, 0)
            mBar.BackgroundColor3 = T.Accent
            mBar.Size = UDim2.new(0.55, 0, 0, max(2, rowH * 0.15))
            mBar.Position = UDim2.new(0, 8 * s, 0.5, 0)
            local np = NOTIF_POS[pend.NotifPos] or NOTIF_POS[1]
            mNotif.BackgroundColor3 = T.Accent
            mNotif.AnchorPoint = np[2]
            mNotif.Size = UDim2.fromOffset(pend.Width * s * 0.5, 16)
            mNotif.Position = UDim2.new(np[2].X, np[2].X == 1 and -6 or 6, np[2].Y, np[2].Y == 1 and -6 or 6)
            cap.Text = ("%d x %d  -  elements %d%%  -  %s"):format(pend.Width, pend.Height, pend.Scale, pend.Theme)
        end
        pf:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePreview)
        task.defer(updatePreview)
    end

    sliders.Width = SettingsTab:AddSlider({
        Text = "Window width", Min = 260, Max = 520, Step = 10, Default = pend.Width,
        Callback = function(v) pend.Width = v updatePreview() end,
    })
    sliders.Height = SettingsTab:AddSlider({
        Text = "Window height", Min = 240, Max = 460, Step = 10, Default = pend.Height,
        Callback = function(v) pend.Height = v updatePreview() end,
    })
    sliders.Scale = SettingsTab:AddSlider({
        Text = "Element size %", Min = 80, Max = 130, Step = 5, Default = pend.Scale,
        Callback = function(v) pend.Scale = v updatePreview() end,
    })

    -- theme presets: applied live to the whole UI, saved with Save & Apply
    do
        local f = row(SettingsTab, "theme", 62, true)
        local l = label(f, "", 14, "Text", Enum.Font.GothamMedium)
        l.Position = UDim2.fromOffset(14, 8)
        l.Size = UDim2.new(1, -28, 0, 20)
        local chipRow = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 32), Size = UDim2.new(1, -28, 0, 22) }, f)
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
            VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
        }, chipRow)
        local function refreshChips()
            l.Text = "Theme: " .. pend.Theme
            for name, s in pairs(chipStrokes) do s.Transparency = name == pend.Theme and 0 or 1 end
        end
        for _, name in ipairs(THEME_NAMES) do
            local c = new("TextButton", {
                Text = "", AutoButtonColor = false, Active = true, BorderSizePixel = 0,
                Size = UDim2.fromOffset(22, 22), BackgroundColor3 = THEMES[name].Accent,
            }, chipRow)
            corner(c, UDim.new(0.5, 0))
            local s = new("UIStroke", { Color = THEMES[name].Text, Thickness = 2, Transparency = 1 }, c)
            chipStrokes[name] = s
            c.MouseButton1Click:Connect(function()
                pend.Theme = name
                applyTheme(name, true)
                refreshChips()
                updatePreview()
            end)
        end
        refreshChips()
        Window._refreshChips = refreshChips
    end

    -- icon colour swatches
    do
        local f = row(SettingsTab, "icon color", 70, true)
        local l = label(f, "Icon color", 14, "Text", Enum.Font.GothamMedium)
        l.Position = UDim2.fromOffset(14, 8)
        l.Size = UDim2.new(1, -28, 0, 20)
        local swRow = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 34), Size = UDim2.new(1, -28, 0, 24) }, f)
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
            VerticalAlignment = Enum.VerticalAlignment.Center,
        }, swRow)
        local SWATCHES = { { 240, 240, 245 }, { 124, 111, 255 }, { 80, 170, 255 }, { 90, 220, 140 }, { 255, 170, 70 }, { 255, 110, 150 } }
        local function refreshSwatches()
            for i, s in ipairs(swatchStrokes) do
                local c = SWATCHES[i]
                s.Transparency = (c[1] == pend.IconColor[1] and c[2] == pend.IconColor[2] and c[3] == pend.IconColor[3]) and 0 or 1
            end
        end
        for i, c in ipairs(SWATCHES) do
            local b = new("TextButton", {
                Text = "", AutoButtonColor = false, Active = true, BorderSizePixel = 0,
                Size = UDim2.fromOffset(24, 24), BackgroundColor3 = col(c),
            }, swRow)
            corner(b, UDim.new(0.5, 0))
            swatchStrokes[i] = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 1 }, b)
            b.MouseButton1Click:Connect(function()
                pend.IconColor = { c[1], c[2], c[3] }
                refreshSwatches()
                updatePreview()
            end)
        end
        Window._refreshSwatches = refreshSwatches
        refreshSwatches()
    end

    -- notification settings
    notifToggle = SettingsTab:AddToggle({
        Text = "Notifications", Icon = "bell", Default = pend.NotifOn,
        Callback = function(v) pend.NotifOn = v notifOn = v end,
    })
    posBtn = SettingsTab:AddButton({
        Text = "Spawn: " .. NOTIF_POS[pend.NotifPos][1], Icon = "move",
        Callback = function()
            pend.NotifPos = pend.NotifPos % #NOTIF_POS + 1
            posBtn:SetText("Spawn: " .. NOTIF_POS[pend.NotifPos][1])
            placeNotifs(pend.NotifPos)
            updatePreview()
        end,
    })
    sliders.Notif = SettingsTab:AddSlider({
        Text = "Notif duration (s)", Min = 1, Max = 10, Step = 1, Default = pend.NotifTime,
        Callback = function(v) pend.NotifTime = v end,
    })
    SettingsTab:AddButton({
        Text = "Preview notification", Icon = "bell-ring",
        Callback = function()
            spawnNotif({ Title = "Semesta", Text = "This is how notifications look.", Icon = "bell", Duration = pend.NotifTime }, true)
        end,
    })

    syncUI = function()
        sliders.Width:Set(pend.Width, true)
        sliders.Height:Set(pend.Height, true)
        sliders.Scale:Set(pend.Scale, true)
        sliders.Notif:Set(pend.NotifTime, true)
        notifToggle:Set(pend.NotifOn, true)
        posBtn:SetText("Spawn: " .. NOTIF_POS[pend.NotifPos][1])
        Window._refreshChips()
        Window._refreshSwatches()
        updatePreview()
    end

    SettingsTab:AddButton({
        Text = "Save & Apply", Icon = "save", IconColor = Color3.fromRGB(90, 220, 140),
        Callback = function() Window:ApplySettings(pend, true) end,
    })
    SettingsTab:AddButton({
        Text = "Discard changes", Icon = "undo-2",
        Callback = function()
            pend = copy(settings)
            notifOn = settings.NotifOn
            applyTheme(settings.Theme, true)
            placeNotifs(settings.NotifPos)
            syncUI()
        end,
    })
    SettingsTab:AddButton({
        Text = "Reset to default", Icon = "rotate-ccw", IconColor = Color3.fromRGB(255, 170, 70),
        Callback = function()
            pend = sanitize(copy(DEFAULT))
            Window:ApplySettings(pend, true)
            syncUI()
        end,
    })

    -- ---------- apply + save ----------
    local saveFn = function()
        pcall(function()
            if writefile then writefile(saveFile, HttpService:JSONEncode(settings)) end
        end)
    end

    function Window:ApplySettings(s, save)
        settings = sanitize(copy(s))
        Window.Settings = settings
        scale = settings.Scale / 100
        local oldW, oldH = main.Size.X.Offset, main.Size.Y.Offset
        local p = main.Position
        tween(main, {
            Size = UDim2.fromOffset(settings.Width, settings.Height),
            Position = UDim2.new(p.X.Scale, p.X.Offset + (oldW - settings.Width) / 2, p.Y.Scale, p.Y.Offset + (oldH - settings.Height) / 2),
        })
        applyScale()
        applyTheme(settings.Theme, true)
        Icons.SetAll(col(settings.IconColor))
        notifOn = settings.NotifOn
        placeNotifs(settings.NotifPos)
        updatePreview()
        if save then saveFn() end
    end

    function Window:SetTheme(name)
        pend = copy(settings)
        pend.Theme = name
        Window:ApplySettings(pend, true)
        syncUI()
    end

    -- ---------- settings: load saved state into the UI ----------
    applyTheme(settings.Theme, false)
    Icons.SetAll(col(settings.IconColor))

    -- ---------- floating toggle (Draggable + Active) ----------
    local tbtn = paint(new("TextButton", {
        Name = "Toggle", Text = "", AutoButtonColor = false, Active = true, Draggable = true,
        Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 16, 0.5, -22), BorderSizePixel = 0,
    }), "BackgroundColor3", "Accent")
    corner(tbtn, UDim.new(0.5, 0))
    stroke(tbtn, "On", 1, 0.6)
    tbtn.Parent = gui
    local tIc = icon(tbtn, cfg.ToggleIcon or "menu", 22, "On")
    tIc.AnchorPoint = Vector2.new(0.5, 0.5)
    tIc.Position = UDim2.fromScale(0.5, 0.5)

    function Window:Toggle(state)
        if not Window.Loaded then return end
        if state == nil then state = not main.Visible end
        if state then
            main.Visible = true
            mainScale.Scale = 0.9
            tween(mainScale, { Scale = 1 })
        else
            main.Visible = false
        end
        if state then task.defer(function() moveHighlight(Window.ActiveTab, true) end) end
    end

    local downPos
    tbtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            downPos = i.Position
        end
    end)
    tbtn.InputEnded:Connect(function(i)
        if downPos and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            if (i.Position - downPos).Magnitude < 8 then Window:Toggle() end
            downPos = nil
        end
    end)
    closeBtn.MouseButton1Click:Connect(function() Window:Toggle(false) end)

    local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
    UIS.InputBegan:Connect(function(i, gpe)
        if not gpe and i.KeyCode == toggleKey then Window:Toggle() end
    end)

    function Window:SetTitle(t) titleLbl.Text = t end
    function Window:SetIconColor(c)
        pend.IconColor = { floor(c.R * 255), floor(c.G * 255), floor(c.B * 255) }
        Window:ApplySettings(pend, true)
    end
    function Window:Destroy() gui:Destroy() end

    -- ---------- loading screen ----------
    tbtn.Visible = false
    local loader = paint(new("CanvasGroup", {
        Name = "Loading", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(250, 118), BorderSizePixel = 0,
    }, gui), "BackgroundColor3", "Bg")
    corner(loader, 14)
    stroke(loader, "Line", 1)
    local spin = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(26, 26),
        BackgroundTransparency = 1,
    }, loader)
    local spinIc = Icons.Make(spin, "loader", 26, Active.Accent, true)
    bound[#bound + 1] = { spinIc, "__icon", "Accent" }
    local spinTween = TweenService:Create(spin, TweenInfo.new(1.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 360 })
    spinTween:Play()
    local lTitle = label(loader, title, 15, "Text", Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    lTitle.Position = UDim2.fromOffset(0, 46)
    lTitle.Size = UDim2.new(1, 0, 0, 20)
    local lStatus = label(loader, "Starting...", 12, "Dim", Enum.Font.Gotham, Enum.TextXAlignment.Center)
    lStatus.Position = UDim2.fromOffset(0, 68)
    lStatus.Size = UDim2.new(1, 0, 0, 16)
    local barBg = paint(new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 94), Size = UDim2.new(1, -40, 0, 6), BorderSizePixel = 0,
    }, loader), "BackgroundColor3", "Panel")
    corner(barBg, 3)
    local barFill = paint(new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, barBg), "BackgroundColor3", "Accent")
    corner(barFill, 3)

    task.spawn(function()
        local t0 = os.clock()
        local names = { "search", "x", "menu", "settings", "save", "undo-2", "rotate-ccw", "loader", "circle", "bell", "bell-ring", "move" }
        if cfg.Icon then names[#names + 1] = cfg.Icon end
        if cfg.ToggleIcon then names[#names + 1] = cfg.ToggleIcon end
        for _, extra in ipairs(cfg.Preload or {}) do names[#names + 1] = extra end

        lStatus.Text = "Loading icons..."
        local done = 0
        for _, n in ipairs(names) do
            task.spawn(function()
                Icons.Get(n)
                done += 1
                tween(barFill, { Size = UDim2.fromScale(done / (#names + 1), 1) }, 0.2)
            end)
        end
        local waited = 0
        while done < #names and waited < 8 do
            waited += task.wait(0.05)
        end

        lStatus.Text = "Building UI..."
        applyScale()
        updatePreview()
        tween(barFill, { Size = UDim2.fromScale(1, 1) }, 0.2)
        local left = 0.9 - (os.clock() - t0)
        if left > 0 then task.wait(left) end

        spinTween:Cancel()
        Window.Loaded = true
        tbtn.Visible = true
        selectTab(Window.ActiveTab or Window.Tabs[1], true)
        task.defer(function() moveHighlight(Window.ActiveTab, true) end)
        if cfg.StartOpen ~= false then Window:Toggle(true) end
        tween(loader, { GroupTransparency = 1 }, 0.3)
        task.wait(0.35)
        loader:Destroy()
    end)

    return Window
end

return Semesta

--[[ USAGE
local Semesta = loadstring(game:HttpGet("YOUR_RAW_URL/Semesta.lua"))()

local Win = Semesta:CreateWindow({
    Title = "My Hub",              -- customizable title (Win:SetTitle("...") later)
    Icon = "zap",                  -- Lucide icon beside the title (optional)
    Image = "rbxassetid://123456", -- custom image beside the title (optional)
    ToggleIcon = "menu",           -- icon on the floating button
    SaveName = "MyHub",            -- settings file name
    -- Size = Vector2.new(340, 300), StartOpen = true, AnimTime = 1,
    -- Preload = { "map-pin", "swords" },
})

local Main = Win:AddTab("Main", "house")
Main:AddButton({ Text = "Teleport", Icon = "map-pin", IconColor = Color3.fromRGB(255, 170, 70), Callback = function() print("tp") end })
Main:AddToggle({ Text = "Speed", Icon = "gauge", Default = false, Callback = print })
Main:AddTextbox({ Text = "Player", Placeholder = "Type name...", Icon = "rbxassetid://987654", Callback = print })
Main:AddSlider({ Text = "WalkSpeed", Min = 16, Max = 200, Default = 50, Icon = "footprints", Callback = print })
Main:AddLabel("Some info", "info")

Win:Notify({ Title = "Loaded", Text = "Welcome back!", Icon = "bell", Duration = 3 })
-- Icon / Image accept: a Lucide name, "rbxassetid://...", a number, or an https .svg URL.
]]
