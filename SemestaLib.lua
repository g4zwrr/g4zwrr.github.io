-- Semesta v2 (SemestaLib.lua) by g4zwr
--  * Settings tab: colours, accent, gradient + opacity, shape, animations, notifications,
--    effects and fonts, all with a live preview. Nothing applies until you press Apply.
--  * Window open / minimize / maximize animation styles, particles, glint sweep, shake.
--  * Notifications: 5 styles x 5 animations, previewed in settings. Touch passes through.
--  * Font changer with a dropdown where every option is drawn in its own font.
--  * Icons: Lucide name, rbxassetid, number or https svg URL. Colour adjustable.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local sqrt, abs, floor, ceil, min, max = math.sqrt, math.abs, math.floor, math.ceil, math.min, math.max
local atan2, rad, deg, cos, sin = math.atan2, math.rad, math.deg, math.cos, math.sin

local Semesta = { Version = "2.0" }
local Icons -- forward declared, defined in the icon section
local ANIM = 1 -- tween time in seconds (Settings > Animation speed)
local EASE = Enum.EasingStyle.Quint

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local function tw(o, props, t, style, dir)
    local tween = TweenService:Create(o, TweenInfo.new(t or ANIM, style or EASE, dir or Enum.EasingDirection.Out), props)
    tween:Play()
    return tween
end

-- ======================= palettes and option lists =======================

local PRESETS = {
    Midnight = { Bg = rgb(17, 17, 23), Panel = rgb(26, 26, 34), Item = rgb(35, 35, 46), Line = rgb(48, 48, 62), Accent = rgb(124, 111, 255), Text = rgb(240, 240, 245), Dim = rgb(145, 145, 160), On = rgb(255, 255, 255) },
    Ocean = { Bg = rgb(10, 22, 34), Panel = rgb(16, 34, 50), Item = rgb(24, 48, 68), Line = rgb(36, 66, 90), Accent = rgb(80, 170, 255), Text = rgb(230, 242, 255), Dim = rgb(128, 160, 186), On = rgb(255, 255, 255) },
    Forest = { Bg = rgb(14, 24, 18), Panel = rgb(22, 36, 27), Item = rgb(31, 50, 38), Line = rgb(45, 70, 54), Accent = rgb(90, 220, 140), Text = rgb(232, 245, 236), Dim = rgb(140, 170, 150), On = rgb(10, 30, 18) },
    Sunset = { Bg = rgb(26, 16, 18), Panel = rgb(38, 24, 27), Item = rgb(54, 34, 38), Line = rgb(78, 50, 56), Accent = rgb(255, 140, 70), Text = rgb(255, 240, 235), Dim = rgb(180, 140, 135), On = rgb(255, 255, 255) },
    Rose = { Bg = rgb(24, 14, 22), Panel = rgb(36, 22, 34), Item = rgb(52, 32, 49), Line = rgb(76, 48, 72), Accent = rgb(255, 110, 160), Text = rgb(255, 238, 246), Dim = rgb(175, 135, 162), On = rgb(255, 255, 255) },
    Mono = { Bg = rgb(12, 12, 12), Panel = rgb(22, 22, 22), Item = rgb(32, 32, 32), Line = rgb(50, 50, 50), Accent = rgb(230, 230, 230), Text = rgb(245, 245, 245), Dim = rgb(150, 150, 150), On = rgb(10, 10, 10) },
}
local PRESET_ORDER = { "Midnight", "Ocean", "Forest", "Sunset", "Rose", "Mono" }

local ACCENTS = { -- index 1 = use the preset's own accent
    { "Preset", rgb(70, 70, 84) }, { "Violet", rgb(124, 111, 255) }, { "Sky", rgb(80, 170, 255) },
    { "Mint", rgb(90, 220, 160) }, { "Amber", rgb(255, 190, 70) }, { "Coral", rgb(255, 120, 100) },
    { "Pink", rgb(255, 110, 170) }, { "Teal", rgb(60, 210, 210) }, { "Snow", rgb(240, 240, 245) },
}
local GRADS = {
    { "Night", rgb(40, 30, 80) }, { "Deep sea", rgb(10, 50, 90) }, { "Moss", rgb(20, 70, 40) },
    { "Wine", rgb(80, 20, 40) }, { "Ash", rgb(60, 60, 70) }, { "Black", rgb(0, 0, 0) },
}
local ICON_COLORS = {
    { "Snow", rgb(240, 240, 245) }, { "Violet", rgb(124, 111, 255) }, { "Sky", rgb(80, 170, 255) },
    { "Mint", rgb(90, 220, 140) }, { "Amber", rgb(255, 170, 70) }, { "Rose", rgb(255, 110, 150) },
}
local OPEN_ANIMS = { "Scale", "Pop", "Slide", "Drop", "Fade" }
local MIN_ANIMS = { "Collapse", "Fade" }
local NOTIF_ANIMS = { "Slide", "Pop", "Fade", "Drop", "Bounce" }
local NOTIF_STYLES = { "Card", "Minimal", "Outline", "Glass", "Pill" }
local NOTIF_POS = { -- name, anchor, real position (top right sits a bit down)
    { "Top right", Vector2.new(1, 0), UDim2.new(1, -12, 0, 56) },
    { "Top left", Vector2.new(0, 0), UDim2.new(0, 12, 0, 56) },
    { "Bottom right", Vector2.new(1, 1), UDim2.new(1, -12, 1, -20) },
    { "Bottom left", Vector2.new(0, 1), UDim2.new(0, 12, 1, -20) },
}
local FONT_NAMES = {}
for _, f in ipairs(Enum.Font:GetEnumItems()) do FONT_NAMES[#FONT_NAMES + 1] = f.Name end
table.sort(FONT_NAMES)

local DEFAULT = {
    Width = 340, Height = 300, Scale = 100, Radius = 10, Borders = true,
    Theme = "Midnight", Accent = 1, Opacity = 100, Gradient = false, GradColor = 1, GradAngle = 90,
    IconColor = { 240, 240, 245 }, OpenAnim = "Scale", MinAnim = "Collapse", AnimSpeed = 1,
    NotifOn = true, NotifPos = 1, NotifTime = 3, NotifAnim = "Slide", NotifStyle = "Card",
    Particles = 12, Glint = true, Shake = true, Font = "GothamMedium",
}

local function copy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = type(v) == "table" and table.clone(v) or v end
    return c
end

local function pick(list, v, def)
    for _, x in ipairs(list) do if x == v then return v end end
    return def
end

local function sanitize(s)
    s.Width = math.clamp(tonumber(s.Width) or 340, 240, 700)
    s.Height = math.clamp(tonumber(s.Height) or 300, 200, 600)
    s.Scale = math.clamp(tonumber(s.Scale) or 100, 70, 150)
    s.Radius = math.clamp(tonumber(s.Radius) or 10, 0, 18)
    s.Borders = s.Borders ~= false
    s.Theme = pick(PRESET_ORDER, s.Theme, "Midnight")
    s.Accent = math.clamp(floor(tonumber(s.Accent) or 1), 1, #ACCENTS)
    s.Opacity = math.clamp(tonumber(s.Opacity) or 100, 20, 100)
    s.Gradient = s.Gradient == true
    s.GradColor = math.clamp(floor(tonumber(s.GradColor) or 1), 1, #GRADS)
    s.GradAngle = math.clamp(tonumber(s.GradAngle) or 90, 0, 360)
    if type(s.IconColor) ~= "table" or #s.IconColor ~= 3 then s.IconColor = { 240, 240, 245 } end
    s.OpenAnim = pick(OPEN_ANIMS, s.OpenAnim, "Scale")
    s.MinAnim = pick(MIN_ANIMS, s.MinAnim, "Collapse")
    s.AnimSpeed = math.clamp(tonumber(s.AnimSpeed) or 1, 0.2, 2)
    s.NotifOn = s.NotifOn ~= false
    s.NotifPos = math.clamp(floor(tonumber(s.NotifPos) or 1), 1, #NOTIF_POS)
    s.NotifTime = math.clamp(tonumber(s.NotifTime) or 3, 1, 10)
    s.NotifAnim = pick(NOTIF_ANIMS, s.NotifAnim, "Slide")
    s.NotifStyle = pick(NOTIF_STYLES, s.NotifStyle, "Card")
    s.Particles = math.clamp(floor(tonumber(s.Particles) or 12), 0, 40)
    s.Glint = s.Glint ~= false
    s.Shake = s.Shake ~= false
    s.Font = pick(FONT_NAMES, s.Font, "GothamMedium")
    return s
end

local function resolveTheme(s)
    local base = {}
    for k, v in pairs(PRESETS[s.Theme] or PRESETS.Midnight) do base[k] = v end
    if (s.Accent or 1) > 1 then base.Accent = ACCENTS[s.Accent][2] end
    base.GradB = GRADS[s.GradColor or 1][2]
    return base
end

local function col(t) return rgb(t[1], t[2], t[3]) end

-- ======================= theme / font registries =======================

local Active = resolveTheme(DEFAULT)
local bound, fontBound, themeHooks = {}, {}, {}
local rowCorners, rowStrokes = {}, {}
local CurrentFont = Enum.Font.GothamMedium

-- colour that follows the active theme. key = PRESETS colour name
local function paint(o, prop, key)
    bound[#bound + 1] = { o, prop, key }
    o[prop] = Active[key]
    return o
end

-- custom colour function fn(obj, theme)
local function bindFn(o, fn)
    bound[#bound + 1] = { o, "__fn", fn }
    fn(o, Active)
    return o
end

local function applyTheme(T, animated)
    Active = T
    for i = #bound, 1, -1 do
        local b = bound[i]
        local o = b[1]
        if not o.Parent then
            table.remove(bound, i)
        elseif b[2] == "__fn" then
            b[3](o, Active)
        elseif b[2] == "__icon" then
            Icons.SetColor(o, Active[b[3]])
        elseif animated then
            tw(o, { [b[2]] = Active[b[3]] })
        else
            o[b[2]] = Active[b[3]]
        end
    end
    for _, fn in ipairs(themeHooks) do fn(animated) end
end

local function setFontAll(f)
    CurrentFont = f
    for i = #fontBound, 1, -1 do
        local o = fontBound[i]
        if not o.Parent then table.remove(fontBound, i) else o.Font = f end
    end
end

local function applyRowStyle(s)
    local keepC, keepS = {}, {}
    for _, c in ipairs(rowCorners) do
        if c.Parent then c.CornerRadius = UDim.new(0, s.Radius); keepC[#keepC + 1] = c end
    end
    for _, st in ipairs(rowStrokes) do
        if st.Parent then st.Transparency = s.Borders and 0.5 or 1; keepS[#keepS + 1] = st end
    end
    rowCorners, rowStrokes = keepC, keepS
end

-- ======================= instance helpers =======================

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

-- fixed = true keeps the given font (not changed by the font picker)
local function rawText(parent, str, size, font, align, fixed)
    local t = new("TextLabel", {
        Text = str, TextSize = size,
        Font = fixed and (font or Enum.Font.GothamMedium) or CurrentFont,
        TextColor3 = Color3.new(1, 1, 1), TextXAlignment = align or Enum.TextXAlignment.Left,
        BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
    if not fixed then fontBound[#fontBound + 1] = t end
    return t
end

local function label(parent, str, size, key, font, align, fixed)
    return paint(rawText(parent, str, size, font, align, fixed), "TextColor3", key or "Text")
end

local function media(parent, v, size, color)
    if typeof(v) == "number" or (type(v) == "string" and v:match("^%d+$")) then
        v = "rbxassetid://" .. tostring(v)
    end
    if type(v) == "string" and v:find("^rbxasset") then
        return new("ImageLabel", { BackgroundTransparency = 1, Image = v, Size = UDim2.fromOffset(size, size), ScaleType = Enum.ScaleType.Fit }, parent)
    end
    return Icons.Make(parent, v, size, color or Icons.Color, color ~= nil)
end

local function rowIcon(f, v, color, size)
    size = size or 20
    if not v then return 12 end
    local m = media(f, v, size, color)
    m.AnchorPoint = Vector2.new(0, 0.5)
    m.Position = UDim2.new(0, 12, 0.5, 0)
    return 12 + size + 10
end

-- Lucide icon that follows the active theme
local function icon(parent, name, size, key)
    local h = Icons.Make(parent, name, size, Active[key], true)
    bound[#bound + 1] = { h, "__icon", key }
    return h
end

-- ======================= Lucide SVG -> Frames =======================

Icons = { Templates = {}, Loading = {}, Holders = {}, Color = rgb(240, 240, 245) }
local LUCIDE_URL = "https://unpkg.com/lucide-static/icons/%s.svg"

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

Semesta.Icons = Icons

-- ======================= effects =======================

local function floatParticle(p)
    task.spawn(function()
        while p.Parent do
            local x = math.random()
            local dur = 6 + math.random() * 6
            p.Position = UDim2.new(x, 0, 1.05, 0)
            p.BackgroundTransparency = 1
            tw(p, { BackgroundTransparency = 0.4 + math.random() * 0.3 }, 1.2)
            tw(p, { Position = UDim2.new(math.clamp(x + (math.random() - 0.5) * 0.2, 0, 1), 0, -0.05, 0) }, dur, Enum.EasingStyle.Linear)
            task.wait(dur)
        end
    end)
end

-- ======================= notifications =======================
-- st = { Style, Anim, Time, Side }. fill = true for the settings preview box.

local NH = 56
local notifCount = 0

local function buildNotif(holder, o, st, fill)
    notifCount += 1
    local S, A = st.Style or "Card", st.Anim or "Slide"
    local side = st.Side or 1
    local dur = st.Time or 3
    local wrap = new("Frame", {
        Size = fill and UDim2.fromScale(1, 1) or UDim2.new(1, 0, 0, NH),
        BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = -notifCount,
    }, holder)
    local f = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, GroupTransparency = 1 }, wrap)
    corner(f, S == "Pill" and 28 or 10)

    if S == "Outline" then
        paint(f, "BackgroundColor3", "Bg")
        stroke(f, "Accent", 1.5)
    elseif S == "Minimal" then
        f.BackgroundTransparency = 1
    elseif S == "Glass" then
        paint(f, "BackgroundColor3", "Panel")
        f.BackgroundTransparency = 0.45
        stroke(f, "Line", 1, 0.4)
        new("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.95) }),
        }, f)
    elseif S == "Pill" then
        paint(f, "BackgroundColor3", "Panel")
        stroke(f, "Accent", 1, 0.5)
    else -- Card
        paint(f, "BackgroundColor3", "Panel")
        stroke(f, "Line", 1)
    end

    local x = 12
    local iconV = o.Icon or o.Image
    if iconV then
        local m = media(f, iconV, 22, o.IconColor)
        m.AnchorPoint = Vector2.new(0, 0.5)
        m.Position = UDim2.new(0, 12, 0.5, 0)
        x = 44
    end
    if S == "Minimal" then
        paint(new("Frame", { BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(6, 8) }, f), "BackgroundColor3", "Accent")
        x = max(x, 18)
    end
    local t = label(f, o.Title or "Notification", 14, "Text")
    t.Position = UDim2.fromOffset(x, 8)
    t.Size = UDim2.new(1, -x - 12, 0, 18)
    local b = label(f, o.Text or "", 12, "Dim")
    b.Position = UDim2.fromOffset(x, 27)
    b.Size = UDim2.new(1, -x - 12, 0, 16)
    local bar = paint(new("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3) }, f), "BackgroundColor3", "Accent")
    if S == "Pill" then bar.Visible = false end

    -- enter animation
    if A == "Slide" then
        f.Position = UDim2.fromOffset(side * 170, 0)
        tw(f, { Position = UDim2.fromScale(0, 0), GroupTransparency = 0 })
    elseif A == "Pop" or A == "Bounce" then
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.fromScale(0.5, 0.5)
        local sc = new("UIScale", { Scale = 0.4 }, f)
        tw(sc, { Scale = 1 }, nil, A == "Pop" and Enum.EasingStyle.Back or Enum.EasingStyle.Bounce)
        tw(f, { GroupTransparency = 0 })
    elseif A == "Drop" then
        f.Position = UDim2.fromOffset(0, -60)
        tw(f, { Position = UDim2.fromScale(0, 0), GroupTransparency = 0 }, nil, Enum.EasingStyle.Bounce)
    else
        tw(f, { GroupTransparency = 0 })
    end

    -- time bar
    TweenService:Create(bar, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) }):Play()

    if not fill then
        task.delay(dur, function()
            if not wrap.Parent then return end
            tw(f, { GroupTransparency = 1 })
            tw(wrap, { Size = UDim2.new(1, 0, 0, 0) }).Completed:Connect(function() wrap:Destroy() end)
        end)
    end
    return wrap
end

-- ======================= window =======================

function Semesta:CreateWindow(cfg)
    cfg = cfg or {}
    local title = cfg.Title or "Semesta"
    local saveFile = (cfg.SaveName or "Semesta") .. "_settings.json"

    local DEF = copy(DEFAULT)
    if typeof(cfg.Size) == "Vector2" then DEF.Width, DEF.Height = cfg.Size.X, cfg.Size.Y end

    local settings = copy(DEF)
    pcall(function()
        if isfile and isfile(saveFile) then
            local d = HttpService:JSONDecode(readfile(saveFile))
            for k in pairs(DEF) do
                if d[k] ~= nil then settings[k] = d[k] end
            end
        end
    end)
    sanitize(settings)
    Icons.Color = col(settings.IconColor)
    ANIM = settings.AnimSpeed
    applyTheme(resolveTheme(settings), false)
    setFontAll(Enum.Font[settings.Font])

    local Window = { Tabs = {}, Items = {}, Loaded = false, Settings = settings }
    local scale = settings.Scale / 100
    local notifOn = settings.NotifOn
    local notifList = {}
    local minimized = false
    local closeToken = 0
    local particleCount = -1
    local apply, syncUI, updatePreview, playPreview, refreshBackground
    local pend -- settings being edited in the Settings tab (preview only until Apply)

    -- ---------- gui root ----------
    local ok, h = pcall(function() return (gethui and gethui()) or game:GetService("CoreGui") end)
    local host = (ok and h) or Players.LocalPlayer:WaitForChild("PlayerGui")
    local guiName = cfg.GuiName or "Semesta"
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

    -- ---------- main frame (CanvasGroup: fades, clips, Draggable + Active) ----------
    local main = paint(new("CanvasGroup", {
        Name = "Main", Size = UDim2.fromOffset(settings.Width, settings.Height),
        Position = UDim2.new(0.5, -settings.Width / 2, 0.5, -settings.Height / 2),
        BorderSizePixel = 0, Visible = false, ClipsDescendants = true,
        Active = true, Draggable = true,
    }), "BackgroundColor3", "Bg")
    corner(main, 12)
    stroke(main, "Line", 1)
    local grad = new("UIGradient", { Enabled = false, Rotation = 90 }, main)
    local mainScale = new("UIScale", { Scale = 1 }, main)
    main.Parent = gui

    refreshBackground = function()
        main.BackgroundTransparency = 1 - settings.Opacity / 100
        grad.Enabled = settings.Gradient
        grad.Color = ColorSequence.new(Active.Bg, Active.GradB)
        grad.Rotation = settings.GradAngle
    end

    -- particles (behind everything else in the window)
    local particleHolder = new("Frame", { Name = "Particles", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Active = false }, main)
    local function buildParticles(n)
        if n == particleCount then return end
        particleCount = n
        particleHolder:ClearAllChildren()
        for _ = 1, n do
            local p = paint(new("Frame", {
                BorderSizePixel = 0, BackgroundTransparency = 1, Active = false,
                Size = UDim2.fromOffset(math.random(2, 4), math.random(2, 4)),
            }, particleHolder), "BackgroundColor3", "Accent")
            corner(p, UDim.new(0.5, 0))
            floatParticle(p)
        end
    end

    -- ---------- header ----------
    local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, main)
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
    titleLbl.Size = UDim2.new(1, -hx - 80, 1, 0)

    local function headerButton(offsetX)
        local b = new("TextButton", {
            Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Active = true,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, offsetX, 0.5, 0), Size = UDim2.fromOffset(28, 28),
        }, header)
        return b
    end
    local closeBtn = headerButton(-8)
    local cIc = icon(closeBtn, "x", 16, "Dim")
    cIc.AnchorPoint = Vector2.new(0.5, 0.5)
    cIc.Position = UDim2.fromScale(0.5, 0.5)
    local minBtn = headerButton(-38)
    local minIc = icon(minBtn, "minus", 16, "Dim")
    minIc.AnchorPoint = Vector2.new(0.5, 0.5)
    minIc.Position = UDim2.fromScale(0.5, 0.5)
    local maxIc = icon(minBtn, "maximize-2", 16, "Dim")
    maxIc.AnchorPoint = Vector2.new(0.5, 0.5)
    maxIc.Position = UDim2.fromScale(0.5, 0.5)
    maxIc.Visible = false

    -- ---------- search ----------
    local searchBar = paint(new("Frame", { Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 0, 30), BorderSizePixel = 0 }, main), "BackgroundColor3", "Panel")
    corner(searchBar, 8)
    stroke(searchBar, "Line", 1)
    local sIc = icon(searchBar, "search", 16, "Dim")
    sIc.AnchorPoint = Vector2.new(0, 0.5)
    sIc.Position = UDim2.new(0, 9, 0.5, 0)
    local search = paint(paint(new("TextBox", {
        Text = "", PlaceholderText = "Search...", ClearTextOnFocus = false, Font = CurrentFont, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -40, 1, 0),
    }, searchBar), "TextColor3", "Text"), "PlaceholderColor3", "Dim")
    fontBound[#fontBound + 1] = search

    -- ---------- tabs: sliding highlight ----------
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
        Position = UDim2.fromOffset(10, 110), Size = UDim2.new(1, -20, 1, -118), BackgroundTransparency = 1, BorderSizePixel = 0,
    }, main)
    local content = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
    }, page)
    paint(content, "ScrollBarImageColor3", "Line")
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
    local emptyLbl = label(main, "No results", 13, "Dim", nil, Enum.TextXAlignment.Center)
    emptyLbl.Position = UDim2.new(0, 0, 0, 150)
    emptyLbl.Size = UDim2.new(1, 0, 0, 20)
    emptyLbl.Visible = false

    -- ---------- glint sweep ----------
    local glint = new("Frame", {
        Size = UDim2.new(0, 80, 1.6, 0), Position = UDim2.new(-0.6, 0, -0.3, 0), Rotation = 18,
        BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, BorderSizePixel = 0, Active = false,
    }, main)
    new("UIGradient", {
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
    }, glint)

    -- ---------- notifications (pass-through: nothing here is Active) ----------
    local notifHolder = new("Frame", {
        Name = "Notifications", BackgroundTransparency = 1, Size = UDim2.fromOffset(260, 0),
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 10,
    }, gui)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, notifHolder)
    local function placeNotifs(i, instant)
        local p = NOTIF_POS[i] or NOTIF_POS[1]
        notifHolder.AnchorPoint = p[2]
        if instant then notifHolder.Position = p[3] else tw(notifHolder, { Position = p[3] }) end
    end

    -- ---------- refresh (tab + search filter) ----------
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

    -- ---------- rows ----------
    local order = 0
    local function row(tab, name, baseH, fixed)
        order += 1
        local f = paint(new("Frame", {
            Size = UDim2.new(1, -4, 0, fixed and baseH or baseH * scale), BorderSizePixel = 0,
            LayoutOrder = tab.Index * 1000 + order,
        }, content), "BackgroundColor3", "Item")
        local c = corner(f, settings.Radius)
        rowCorners[#rowCorners + 1] = c
        local st = stroke(f, "Line", 1, settings.Borders and 0.5 or 1)
        rowStrokes[#rowStrokes + 1] = st
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

    -- small punch on click (rotation wobble)
    local function punch(f)
        if not settings.Shake then return end
        task.spawn(function()
            tw(f, { Rotation = 2 }, 0.05, Enum.EasingStyle.Sine)
            task.wait(0.05)
            tw(f, { Rotation = -2 }, 0.08, Enum.EasingStyle.Sine)
            task.wait(0.08)
            tw(f, { Rotation = 0 }, 0.1, Enum.EasingStyle.Sine)
        end)
    end

    -- ---------- tabs ----------
    local function refreshTabs(anim)
        for _, t in ipairs(Window.Tabs) do
            local on = t == Window.ActiveTab
            local c = on and Active.On or Active.Dim
            if anim then tw(t.lbl, { TextColor3 = c }) else t.lbl.TextColor3 = c end
            Icons.SetColor(t.ic, c)
        end
    end

    local function moveHighlight(tab, instant)
        if not tab or not tab.btn then return end
        local b, s = tab.btn, mainScale.Scale
        local p = Vector2.new(b.AbsolutePosition.X - main.AbsolutePosition.X, b.AbsolutePosition.Y - main.AbsolutePosition.Y) / s
        local sz = b.AbsoluteSize / s
        local pos, size = UDim2.fromOffset(p.X, p.Y), UDim2.fromOffset(sz.X, sz.Y)
        if instant then
            hl.Position, hl.Size = pos, size
        else
            tw(hl, { Position = pos, Size = size })
        end
    end

    local function selectTab(tab, instant)
        Window.ActiveTab = tab
        refreshTabs(not instant)
        moveHighlight(tab, instant)
        if not instant then
            page.GroupTransparency = 0.5
            tw(page, { GroupTransparency = 0 })
        end
        content.CanvasPosition = Vector2.new(0, 0)
        queueRefresh()
    end

    table.insert(themeHooks, function(anim)
        refreshTabs(anim)
        refreshBackground()
    end)

    -- ---------- tab / element builder ----------
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
        local lbl = rawText(btn, name, 12)
        lbl.AutomaticSize = Enum.AutomaticSize.X
        lbl.Size = UDim2.fromOffset(0, 26)
        lbl.LayoutOrder = 2
        lbl.TextColor3 = Active.Dim
        Tab.btn, Tab.lbl, Tab.ic = btn, lbl, ic
        Window.Tabs[#Window.Tabs + 1] = Tab
        btn.MouseButton1Click:Connect(function() selectTab(Tab) end)

        local cur = Window.ActiveTab
        if cur == nil or (cur.IsSettings and not isSettings) then
            selectTab(Tab, true)
            task.defer(function() moveHighlight(Tab, true) end)
        end

        function Tab:AddLabel(str, iconV)
            local f, item = row(Tab, str, 30)
            local x = rowIcon(f, iconV)
            local l = label(f, str, 13, "Dim")
            l.Position = UDim2.fromOffset(x, 0)
            l.Size = UDim2.new(1, -x - 10, 1, 0)
            item.apply = function(s) l.TextSize = floor(13 * s + 0.5) end
            item.apply(scale)
            local obj = {}
            function obj:Set(v) l.Text = tostring(v) item.name = tostring(v):lower() end
            return obj
        end

        function Tab:AddButton(o)
            local f, item = row(Tab, o.Text or "Button", 46)
            local x = rowIcon(f, o.Icon, o.IconColor)
            local l = label(f, o.Text or "Button", 14, "Text", nil)
            l.Position = UDim2.fromOffset(x, 0)
            l.Size = UDim2.new(1, -x - 10, 1, 0)
            local hit = new("TextButton", {
                Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Active = true, Size = UDim2.fromScale(1, 1),
            }, f)
            item.apply = function(s) l.TextSize = floor(14 * s + 0.5) end
            item.apply(scale)
            hit.MouseButton1Click:Connect(function()
                f.BackgroundColor3 = Active.Accent
                tw(f, { BackgroundColor3 = Active.Item })
                punch(f)
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
            local l = label(f, o.Text or "Toggle", 14, "Text")
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
                tw(track, { BackgroundColor3 = state and Active.Accent or Active.Bg })
                tw(knob, { Position = UDim2.fromOffset(state and 23 or 3, 3) })
                if not silent and o.Callback then task.spawn(o.Callback, state) end
            end
            local hit = new("TextButton", {
                Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Active = true, Size = UDim2.fromScale(1, 1),
            }, f)
            hit.MouseButton1Click:Connect(function()
                punch(f)
                setState(not state)
            end)
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
            local l = label(f, o.Text or "Slider", 14, "Text")
            l.Position = UDim2.fromOffset(x, 6)
            l.Size = UDim2.new(1, -x - 80, 0, 20)
            local function show(v) return o.Format and string.format(o.Format, v) or tostring(v) end
            local vl = label(f, show(value), 13, "Dim", nil, Enum.TextXAlignment.Right)
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
                vl.Text = show(value)
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
            local l = label(f, o.Text or "Textbox", 14, "Text")
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
                Font = CurrentFont, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
                Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0),
            }, boxBg), "TextColor3", "Text")
            paint(box, "PlaceholderColor3", "Dim")
            fontBound[#fontBound + 1] = box
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

        -- Dropdown. FontMode = true draws every option in its own font.
        function Tab:AddDropdown(o)
            local opts = o.Options or {}
            local value = o.Default or opts[1] or ""
            local ROW = 46
            local LIST = min(#opts, 6) * 32 + 8
            local f, item = row(Tab, o.Text or "Dropdown", ROW)
            f.ClipsDescendants = true
            local x = rowIcon(f, o.Icon, o.IconColor)
            local l = label(f, o.Text or "Dropdown", 14, "Text")
            l.Position = UDim2.fromOffset(x, 0)
            l.Size = UDim2.new(0.45, -x, 0, ROW)
            local val = paint(rawText(f, value, 13, nil, Enum.TextXAlignment.Right, o.FontMode), "TextColor3", "Accent")
            val.Position = UDim2.new(0.45, 0, 0, 0)
            val.Size = UDim2.new(0.55, -34, 0, ROW)
            if o.FontMode then val.Font = Enum.Font[value] end
            local chev = icon(f, "chevron-down", 14, "Dim")
            chev.AnchorPoint = Vector2.new(1, 0)
            chev.Position = UDim2.new(1, -10, 0, 16)

            local list = new("ScrollingFrame", {
                BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 8, 0, ROW),
                Size = UDim2.new(1, -16, 0, LIST), ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y,
                CanvasSize = UDim2.new(), Visible = false,
            }, f)
            paint(list, "ScrollBarImageColor3", "Line")
            new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)

            local optBtns = {}
            local function refreshOpts()
                for name, b in pairs(optBtns) do
                    b.BackgroundTransparency = (name == value) and 0.7 or 1
                end
            end
            local opened = false
            local function setOpen(v)
                opened = v
                item.baseH = v and (ROW + LIST + 6) or ROW
                if v then list.Visible = true end
                local t = tw(f, { Size = UDim2.new(1, -4, 0, item.baseH * scale) })
                if not v then t.Completed:Connect(function() if not opened then list.Visible = false end end) end
                tw(chev, { Rotation = v and 180 or 0 })
            end

            for i, name in ipairs(opts) do
                local b = bindFn(new("TextButton", {
                    Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundTransparency = 1,
                    Size = UDim2.new(1, -4, 0, 30), LayoutOrder = i,
                }, list), function(t, A) t.BackgroundColor3 = A.Accent end)
                corner(b, 7)
                local nm = paint(rawText(b, name, 13, nil, nil, o.FontMode), "TextColor3", "Text")
                nm.Position = UDim2.fromOffset(10, 0)
                nm.Size = UDim2.new(0.6, 0, 1, 0)
                if o.FontMode then nm.Font = Enum.Font[name] end
                if o.FontMode then
                    local smp = paint(rawText(b, "Aa Bb 123", 13, nil, Enum.TextXAlignment.Right, true), "TextColor3", "Dim")
                    smp.Font = Enum.Font[name]
                    smp.Position = UDim2.new(0.6, 0, 0, 0)
                    smp.Size = UDim2.new(0.4, -10, 1, 0)
                end
                b.MouseButton1Click:Connect(function()
                    value = name
                    val.Text = name
                    if o.FontMode then val.Font = Enum.Font[name] end
                    refreshOpts()
                    setOpen(false)
                    if o.Callback then task.spawn(o.Callback, name) end
                end)
                optBtns[name] = b
            end
            refreshOpts()

            local hit = new("TextButton", {
                Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Active = true, Size = UDim2.new(1, 0, 0, ROW),
            }, f)
            hit.MouseButton1Click:Connect(function() setOpen(not opened) end)

            item.apply = function(s)
                l.TextSize = floor(14 * s + 0.5)
                val.TextSize = floor(13 * s + 0.5)
            end
            item.apply(scale)

            local obj = {}
            function obj:Set(v, silent)
                value = v
                val.Text = v
                if o.FontMode then val.Font = Enum.Font[v] end
                refreshOpts()
                if not silent and o.Callback then task.spawn(o.Callback, v) end
            end
            function obj:Get() return value end
            return obj
        end

        return Tab
    end

    -- ---------- notifications: public API ----------
    function Window:Notify(o)
        o = o or {}
        if not notifOn and not o.Force then return end
        local st = {
            Style = o.Style or settings.NotifStyle,
            Anim = o.Anim or settings.NotifAnim,
            Time = o.Duration or settings.NotifTime,
            Side = (settings.NotifPos == 2 or settings.NotifPos == 4) and -1 or 1,
        }
        local wrap = buildNotif(notifHolder, o, st, false)
        notifList[#notifList + 1] = wrap
        while #notifList > 5 do
            local old = table.remove(notifList, 1)
            if old then old:Destroy() end
        end
        return wrap
    end

    -- ---------- apply (called by Apply / SetTheme / Reset) ----------
    local function saveSettings()
        pcall(function()
            if writefile then writefile(saveFile, HttpService:JSONEncode(settings)) end
        end)
    end

    apply = function(s, save)
        settings = sanitize(copy(s))
        Window.Settings = settings
        ANIM = settings.AnimSpeed
        scale = settings.Scale / 100
        notifOn = settings.NotifOn
        Icons.SetAll(col(settings.IconColor))
        setFontAll(Enum.Font[settings.Font])
        applyTheme(resolveTheme(settings), true)
        applyRowStyle(settings)
        applyScale()
        local oldW, oldH = main.Size.X.Offset, main.Size.Y.Offset
        local targetH = minimized and 36 or settings.Height
        local p = main.Position
        tw(main, {
            Size = UDim2.fromOffset(settings.Width, targetH),
            Position = UDim2.new(p.X.Scale, p.X.Offset + (oldW - settings.Width) / 2, p.Y.Scale, p.Y.Offset + (oldH - targetH) / 2),
        })
        buildParticles(settings.Particles)
        glint.Visible = settings.Glint
        placeNotifs(settings.NotifPos)
        refreshBackground()
        if save then saveSettings() end
        if updatePreview then updatePreview() end
    end

    function Window:ApplySettings(s, save) apply(s, save) end

    function Window:SetTheme(name)
        local s = copy(settings)
        s.Theme = name
        s.Accent = 1
        apply(s, true)
        if syncUI then
            pend = copy(settings)
            syncUI()
        end
    end

    -- ---------- settings tab ----------
    local SettingsTab = Window:AddTab("Settings", "settings", true)
    pend = copy(settings)
    local C = {}
    local chipRefresh = {}
    local previewHolder

    do -- live preview: window mock + notification preview + font caption
        local pf = row(SettingsTab, "preview", 226, true)
        pf.ClipsDescendants = true
        local cap = label(pf, "", 11, "Dim", Enum.Font.GothamMedium, Enum.TextXAlignment.Center, true)
        cap.AnchorPoint = Vector2.new(0.5, 0)
        cap.Position = UDim2.new(0.5, 0, 0, 140)
        cap.Size = UDim2.new(1, -10, 0, 14)

        local mini = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), BorderSizePixel = 0, ClipsDescendants = true }, pf)
        local mCorner = new("UICorner", {}, mini)
        local mStroke = new("UIStroke", { Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, mini)
        local mGrad = new("UIGradient", { Rotation = 90 }, mini)
        local mHeader = new("Frame", { BorderSizePixel = 0 }, mini)
        local mSearch = new("Frame", { BorderSizePixel = 0 }, mini)
        new("UICorner", { CornerRadius = UDim.new(0, 4) }, mSearch)
        local mRows = {}
        for i = 1, 3 do
            mRows[i] = new("Frame", { BorderSizePixel = 0 }, mini)
            new("UICorner", { CornerRadius = UDim.new(0, 4) }, mRows[i])
        end
        local mDot = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0 }, mRows[1])
        new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, mDot)
        local mBar = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0 }, mRows[2])
        new("UICorner", { CornerRadius = UDim.new(0, 3) }, mBar)

        local nHolder = new("Frame", {
            BackgroundTransparency = 1, ClipsDescendants = true,
            Position = UDim2.new(0, 12, 0, 160), Size = UDim2.new(1, -24, 0, 58),
        }, pf)
        previewHolder = nHolder

        updatePreview = function()
            local T = resolveTheme(pend)
            local pw = pf.AbsoluteSize.X > 40 and pf.AbsoluteSize.X - 24 or 300
            local s = min(pw / pend.Width, 130 / pend.Height)
            local W, H = pend.Width * s, pend.Height * s
            mini.Size = UDim2.fromOffset(W, H)
            mini.BackgroundColor3 = T.Bg
            mini.BackgroundTransparency = 1 - pend.Opacity / 100
            mGrad.Enabled = pend.Gradient
            mGrad.Rotation = pend.GradAngle
            mGrad.Color = ColorSequence.new(T.Bg, T.GradB)
            mCorner.CornerRadius = UDim.new(0, pend.Radius * s)
            mStroke.Color = T.Line
            mStroke.Transparency = pend.Borders and 0 or 1
            mHeader.BackgroundColor3 = T.Panel
            mHeader.Size = UDim2.new(1, 0, 0, 36 * s)
            mSearch.BackgroundColor3 = T.Panel
            mSearch.Position = UDim2.fromOffset(10 * s, 40 * s)
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
            mBar.Size = UDim2.new(0.5, 0, 0, max(2, rowH * 0.15))
            mBar.Position = UDim2.new(0, 8 * s, 0.5, 0)
            cap.Text = ("%dx%d  -  %s  -  %s"):format(pend.Width, pend.Height, pend.Theme, pend.Font)
            cap.Font = Enum.Font[pend.Font]
        end
        pf:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePreview)

        local pWrap
        playPreview = function()
            if pWrap and pWrap.Parent then pWrap:Destroy() end
            pWrap = buildNotif(nHolder, { Title = "On notif title", Text = "This is notif preview" }, {
                Style = pend.NotifStyle, Anim = pend.NotifAnim, Time = pend.NotifTime,
                Side = (pend.NotifPos == 2 or pend.NotifPos == 4) and -1 or 1,
            }, true)
        end
        task.spawn(function()
            while nHolder.Parent do
                playPreview()
                task.wait(3.5)
            end
        end)
        task.defer(updatePreview)
    end

    local function chipRow(title, items, getIdx, setIdx)
        local f = row(SettingsTab, title, 62, true)
        local l = label(f, "", 13, "Text")
        l.Position = UDim2.fromOffset(14, 8)
        l.Size = UDim2.new(1, -28, 0, 18)
        local sc = new("ScrollingFrame", {
            BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 30),
            Size = UDim2.new(1, -24, 0, 26), ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X,
            AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
        }, f)
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
            VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
        }, sc)
        local strokes = {}
        local function refreshChip()
            local sel = getIdx()
            for i, s in ipairs(strokes) do s.Transparency = (i == sel) and 0 or 1 end
            l.Text = title .. ": " .. ((items[sel] and items[sel][1]) or "Custom")
        end
        for i, it in ipairs(items) do
            local c = new("TextButton", {
                Text = "", AutoButtonColor = false, Active = true, BorderSizePixel = 0,
                Size = UDim2.fromOffset(24, 24), BackgroundColor3 = it[2], LayoutOrder = i,
            }, sc)
            corner(c, UDim.new(0.5, 0))
            strokes[i] = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 1 }, c)
            c.MouseButton1Click:Connect(function()
                setIdx(i)
                refreshChip()
                updatePreview()
            end)
        end
        chipRefresh[#chipRefresh + 1] = refreshChip
        refreshChip()
    end

    local function indexOf(list, v)
        for i, x in ipairs(list) do if x == v then return i end end
        return 0
    end

    local themeItems = {}
    for i, n in ipairs(PRESET_ORDER) do themeItems[i] = { n, PRESETS[n].Accent } end

    -- Colours
    SettingsTab:AddLabel("Colours", "palette")
    chipRow("Theme", themeItems,
        function() return indexOf(PRESET_ORDER, pend.Theme) end,
        function(i) pend.Theme = PRESET_ORDER[i] end)
    chipRow("Accent", ACCENTS,
        function() return pend.Accent end,
        function(i) pend.Accent = i end)
    chipRow("Icon colour", ICON_COLORS,
        function()
            for i, c in ipairs(ICON_COLORS) do
                if floor(c[2].R * 255 + 0.5) == pend.IconColor[1] and floor(c[2].G * 255 + 0.5) == pend.IconColor[2] and floor(c[2].B * 255 + 0.5) == pend.IconColor[3] then
                    return i
                end
            end
            return 0
        end,
        function(i)
            local c = ICON_COLORS[i][2]
            pend.IconColor = { floor(c.R * 255 + 0.5), floor(c.G * 255 + 0.5), floor(c.B * 255 + 0.5) }
        end)

    -- Background
    SettingsTab:AddLabel("Background", "layers")
    C.Opacity = SettingsTab:AddSlider({
        Text = "Opacity", Min = 20, Max = 100, Step = 5, Default = pend.Opacity, Format = "%d%%", Icon = "droplet",
        Callback = function(v) pend.Opacity = v updatePreview() end,
    })
    C.Gradient = SettingsTab:AddToggle({
        Text = "Gradient background", Icon = "sparkles", Default = pend.Gradient,
        Callback = function(v) pend.Gradient = v updatePreview() end,
    })
    chipRow("Gradient colour", GRADS,
        function() return pend.GradColor end,
        function(i) pend.GradColor = i end)
    C.Angle = SettingsTab:AddSlider({
        Text = "Gradient angle", Min = 0, Max = 360, Step = 15, Default = pend.GradAngle, Format = "%d deg", Icon = "wand-2",
        Callback = function(v) pend.GradAngle = v updatePreview() end,
    })

    -- Shape & size
    SettingsTab:AddLabel("Window", "sliders-horizontal")
    C.Width = SettingsTab:AddSlider({
        Text = "Window width", Min = 260, Max = 520, Step = 10, Default = pend.Width, Icon = "sliders-horizontal",
        Callback = function(v) pend.Width = v updatePreview() end,
    })
    C.Height = SettingsTab:AddSlider({
        Text = "Window height", Min = 240, Max = 460, Step = 10, Default = pend.Height, Icon = "sliders-horizontal",
        Callback = function(v) pend.Height = v updatePreview() end,
    })
    C.Scale = SettingsTab:AddSlider({
        Text = "Element size", Min = 80, Max = 130, Step = 5, Default = pend.Scale, Format = "%d%%", Icon = "layers",
        Callback = function(v) pend.Scale = v updatePreview() end,
    })
    C.Radius = SettingsTab:AddSlider({
        Text = "Corner radius", Min = 0, Max = 18, Step = 1, Default = pend.Radius, Icon = "layers",
        Callback = function(v) pend.Radius = v updatePreview() end,
    })
    C.Borders = SettingsTab:AddToggle({
        Text = "Element borders", Icon = "layers", Default = pend.Borders,
        Callback = function(v) pend.Borders = v updatePreview() end,
    })

    -- Animations
    SettingsTab:AddLabel("Animations", "wand-2")
    C.OpenAnim = SettingsTab:AddDropdown({
        Text = "Open animation", Icon = "wand-2", Options = OPEN_ANIMS, Default = pend.OpenAnim,
        Callback = function(v) pend.OpenAnim = v end,
    })
    C.Speed = SettingsTab:AddSlider({
        Text = "Animation speed", Min = 0.2, Max = 2, Step = 0.1, Default = pend.AnimSpeed, Format = "%.1fs", Icon = "gauge",
        Callback = function(v) pend.AnimSpeed = v end,
    })
    C.MinAnim = SettingsTab:AddDropdown({
        Text = "Minimize animation", Icon = "minus", Options = MIN_ANIMS, Default = pend.MinAnim,
        Callback = function(v) pend.MinAnim = v end,
    })

    -- Notifications
    SettingsTab:AddLabel("Notifications", "bell")
    C.NotifOn = SettingsTab:AddToggle({
        Text = "Notifications", Icon = "bell", Default = pend.NotifOn,
        Callback = function(v) pend.NotifOn = v end,
    })
    C.PosBtn = SettingsTab:AddButton({
        Text = "Spawn: " .. NOTIF_POS[pend.NotifPos][1], Icon = "move",
        Callback = function()
            pend.NotifPos = pend.NotifPos % #NOTIF_POS + 1
            C.PosBtn:SetText("Spawn: " .. NOTIF_POS[pend.NotifPos][1])
            playPreview()
        end,
    })
    C.NTime = SettingsTab:AddSlider({
        Text = "Duration", Min = 1, Max = 10, Step = 1, Default = pend.NotifTime, Format = "%ds", Icon = "gauge",
        Callback = function(v) pend.NotifTime = v end,
    })
    C.NAnim = SettingsTab:AddDropdown({
        Text = "Notif animation", Icon = "sparkles", Options = NOTIF_ANIMS, Default = pend.NotifAnim,
        Callback = function(v) pend.NotifAnim = v playPreview() end,
    })
    C.NStyle = SettingsTab:AddDropdown({
        Text = "Notif style", Icon = "layers", Options = NOTIF_STYLES, Default = pend.NotifStyle,
        Callback = function(v) pend.NotifStyle = v playPreview() end,
    })
    SettingsTab:AddButton({
        Text = "Replay notification preview", Icon = "bell-ring",
        Callback = function() playPreview() end,
    })

    -- Effects
    SettingsTab:AddLabel("Effects", "sparkles")
    C.Particles = SettingsTab:AddSlider({
        Text = "Particles", Min = 0, Max = 40, Step = 1, Default = pend.Particles, Icon = "droplet",
        Callback = function(v) pend.Particles = v end,
    })
    C.Glint = SettingsTab:AddToggle({
        Text = "Glint sweep", Icon = "sun", Default = pend.Glint,
        Callback = function(v) pend.Glint = v end,
    })
    C.Shake = SettingsTab:AddToggle({
        Text = "Shake on click", Icon = "wand-2", Default = pend.Shake,
        Callback = function(v) pend.Shake = v end,
    })

    -- Font
    SettingsTab:AddLabel("Font", "type")
    C.Font = SettingsTab:AddDropdown({
        Text = "Font", Icon = "type", Options = FONT_NAMES, Default = pend.Font, FontMode = true,
        Callback = function(v) pend.Font = v updatePreview() end,
    })

    -- Buttons
    SettingsTab:AddButton({
        Text = "Apply", Icon = "save", IconColor = rgb(90, 220, 140),
        Callback = function() apply(pend, true) end,
    })
    SettingsTab:AddButton({
        Text = "Discard changes", Icon = "undo-2",
        Callback = function()
            pend = copy(settings)
            syncUI()
        end,
    })
    SettingsTab:AddButton({
        Text = "Reset to default", Icon = "rotate-ccw", IconColor = rgb(255, 170, 70),
        Callback = function()
            pend = sanitize(copy(DEF))
            apply(pend, true)
            syncUI()
        end,
    })

    syncUI = function()
        C.Opacity:Set(pend.Opacity, true)
        C.Gradient:Set(pend.Gradient, true)
        C.Angle:Set(pend.GradAngle, true)
        C.Width:Set(pend.Width, true)
        C.Height:Set(pend.Height, true)
        C.Scale:Set(pend.Scale, true)
        C.Radius:Set(pend.Radius, true)
        C.Borders:Set(pend.Borders, true)
        C.OpenAnim:Set(pend.OpenAnim, true)
        C.Speed:Set(pend.AnimSpeed, true)
        C.MinAnim:Set(pend.MinAnim, true)
        C.NotifOn:Set(pend.NotifOn, true)
        C.PosBtn:SetText("Spawn: " .. NOTIF_POS[pend.NotifPos][1])
        C.NTime:Set(pend.NotifTime, true)
        C.NAnim:Set(pend.NotifAnim, true)
        C.NStyle:Set(pend.NotifStyle, true)
        C.Particles:Set(pend.Particles, true)
        C.Glint:Set(pend.Glint, true)
        C.Shake:Set(pend.Shake, true)
        C.Font:Set(pend.Font, true)
        for _, r in ipairs(chipRefresh) do r() end
        updatePreview()
        playPreview()
    end

    -- ---------- initial visuals ----------
    applyRowStyle(settings)
    refreshBackground()
    buildParticles(settings.Particles)
    glint.Visible = settings.Glint
    placeNotifs(settings.NotifPos, true)

    -- ---------- open / close / minimize ----------
    local function openAnim()
        local A = settings.OpenAnim
        local base = main.Position
        mainScale.Scale = 1
        main.GroupTransparency = 0
        main.Position = base
        if A == "Scale" then
            mainScale.Scale = 0.9
            tw(mainScale, { Scale = 1 })
        elseif A == "Pop" then
            mainScale.Scale = 0.5
            tw(mainScale, { Scale = 1 }, nil, Enum.EasingStyle.Back)
        elseif A == "Slide" then
            main.Position = base + UDim2.fromOffset(0, 90)
            tw(main, { Position = base })
        elseif A == "Drop" then
            main.Position = base - UDim2.fromOffset(0, 140)
            tw(main, { Position = base }, nil, Enum.EasingStyle.Bounce)
        elseif A == "Fade" then
            main.GroupTransparency = 1
            tw(main, { GroupTransparency = 0 })
        end
        if settings.Shake then Window:Shake() end
    end

    function Window:Shake()
        task.spawn(function()
            for _, r in ipairs({ 2, -2, 1, -1, 0 }) do
                tw(main, { Rotation = r }, 0.06, Enum.EasingStyle.Sine)
                task.wait(0.06)
            end
        end)
    end

    function Window:Toggle(state)
        if not Window.Loaded then return end
        if state == nil then state = not main.Visible end
        closeToken += 1
        if state then
            main.Visible = true
            openAnim()
        else
            local token = closeToken
            tw(mainScale, { Scale = 0.92 })
            tw(main, { GroupTransparency = 1 }).Completed:Connect(function()
                if token == closeToken then main.Visible = false end
            end)
        end
    end

    function Window:Minimize(v)
        if v == nil then v = not minimized end
        minimized = v
        minIc.Visible = not v
        maxIc.Visible = v
        if settings.MinAnim == "Collapse" then
            tw(main, { Size = UDim2.fromOffset(settings.Width, v and 36 or settings.Height) })
        else -- Fade
            if v then
                tw(mainScale, { Scale = 0.9 })
                tw(main, { GroupTransparency = 1 }).Completed:Connect(function()
                    if minimized then main.Visible = false end
                end)
            else
                main.Visible = true
                main.GroupTransparency = 1
                mainScale.Scale = 0.9
                tw(main, { GroupTransparency = 0 })
                tw(mainScale, { Scale = 1 })
            end
        end
    end

    minBtn.MouseButton1Click:Connect(function() Window:Minimize() end)

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
        pend.IconColor = { floor(c.R * 255 + 0.5), floor(c.G * 255 + 0.5), floor(c.B * 255 + 0.5) }
        apply(pend, true)
        syncUI()
    end
    function Window:Destroy() gui:Destroy() end

    -- ---------- glint loop ----------
    task.spawn(function()
        while main.Parent do
            if settings.Glint and Window.Loaded and main.Visible then
                glint.Position = UDim2.new(-0.6, 0, -0.3, 0)
                tw(glint, { Position = UDim2.new(1.4, 0, -0.3, 0) }, 1.4)
                task.wait(4)
            else
                task.wait(1)
            end
        end
    end)

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
    icon(spin, "loader", 26, "Accent")
    local spinTween = TweenService:Create(spin, TweenInfo.new(1.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 360 })
    spinTween:Play()
    local lTitle = label(loader, title, 15, "Text", Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    lTitle.Position = UDim2.fromOffset(0, 46)
    lTitle.Size = UDim2.new(1, 0, 0, 20)
    local lStatus = label(loader, "Starting...", 12, "Dim", nil, Enum.TextXAlignment.Center)
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
        local names = {
            "search", "x", "menu", "settings", "save", "undo-2", "rotate-ccw", "loader", "circle", "bell", "bell-ring",
            "move", "minus", "maximize-2", "chevron-down", "sliders-horizontal", "palette", "sparkles", "type", "layers",
            "droplet", "sun", "wand-2", "gauge",
        }
        if cfg.Icon then names[#names + 1] = cfg.Icon end
        if cfg.ToggleIcon then names[#names + 1] = cfg.ToggleIcon end
        for _, extra in ipairs(cfg.Preload or {}) do names[#names + 1] = extra end

        lStatus.Text = "Loading icons..."
        local done = 0
        for _, n in ipairs(names) do
            task.spawn(function()
                Icons.Get(n)
                done += 1
                tw(barFill, { Size = UDim2.fromScale(done / (#names + 1), 1) }, 0.2)
            end)
        end
        local waited = 0
        while done < #names and waited < 8 do
            waited += task.wait(0.05)
        end

        lStatus.Text = "Building UI..."
        if updatePreview then updatePreview() end
        tw(barFill, { Size = UDim2.fromScale(1, 1) }, 0.2)
        local left = 0.9 - (os.clock() - t0)
        if left > 0 then task.wait(left) end

        spinTween:Cancel()
        Window.Loaded = true
        tbtn.Visible = true
        local first = Window.ActiveTab or Window.Tabs[1]
        if first then selectTab(first, true) end
        task.defer(function() moveHighlight(Window.ActiveTab, true) end)
        if cfg.StartOpen ~= false then Window:Toggle(true) end
        tw(loader, { GroupTransparency = 1 }, 0.3)
        task.wait(0.35)
        loader:Destroy()
    end)

    return Window
end

return Semesta

--[[ USAGE
local Semesta = loadstring(game:HttpGet("https://g4zwr.is-a.dev/SemestaLib.lua"))()
local Win = Semesta:CreateWindow({ Title = "My Hub", Icon = "zap", SaveName = "MyHub" })
local Main = Win:AddTab("Main", "house")
Main:AddButton({ Text = "Hello", Icon = "user", Callback = function() Win:Notify({ Title = "Hi", Text = "Clicked" }) end })
Win:Notify({ Title = "Pill", Text = "Custom style", Style = "Pill", Anim = "Pop" })
]]
