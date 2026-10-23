local function dbg(msg) pcall(function() print("[UGC Anim Studio] " .. tostring(msg)) end) end

local plrs = game:GetService("Players")
local as = game:GetService("AssetService")
local aes = game:GetService("AvatarEditorService")
local rs = game:GetService("RunService")
local hs = game:GetService("HttpService")
local cp = game:GetService("ContentProvider")
local uis = game:GetService("UserInputService")
local mps = game:GetService("MarketplaceService")
local lp = plrs.LocalPlayer

local env = (typeof(getgenv) == "function" and getgenv()) or _G
if type(env.UgcAnimStudioCleanup) == "function" then pcall(env.UgcAnimStudioCleanup) end

local connections = {}
local function track(c) connections[#connections + 1] = c; return c end

local toast
local onMetaChanged
local onHistoryChanged

local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera", 10)
local vpSize = camera and camera.ViewportSize or Vector2.new(1280, 720)
local W0, H0 = 700, 450
local baseScale = math.clamp(math.min(vpSize.X / 1920, vpSize.Y / 1080), 0.55, 3) * 1.35
local scale = math.min(baseScale, (vpSize.X * 0.97) / W0, (vpSize.Y * 0.95) / H0)
if scale <= 0 or scale ~= scale then scale = 1 end
local function s(n) return math.round(n * scale) end

local C = {
	bg = Color3.fromRGB(38, 38, 40),
	panel = Color3.fromRGB(46, 46, 48),
	surface = Color3.fromRGB(58, 58, 60),
	surfaceHi = Color3.fromRGB(74, 74, 76),
	stroke = Color3.fromRGB(96, 96, 98),
	accent = Color3.fromRGB(150, 150, 152),
	accent2 = Color3.fromRGB(180, 180, 182),
	text = Color3.fromRGB(232, 232, 234),
	textDim = Color3.fromRGB(178, 178, 180),
	textMuted = Color3.fromRGB(130, 130, 132),
	overlay = Color3.fromRGB(24, 24, 26),
	green = Color3.fromRGB(150, 150, 152),
	red = Color3.fromRGB(190, 120, 120),
	gold = Color3.fromRGB(210, 190, 140),
	orange = Color3.fromRGB(190, 160, 120),
	pillBg = Color3.fromRGB(72, 72, 76),
	pillTx = Color3.fromRGB(210, 210, 212),
	badBg = Color3.fromRGB(90, 60, 60),
	badTx = Color3.fromRGB(220, 170, 170),
	wearBg = Color3.fromRGB(88, 88, 92),
}
local WHITE = Color3.new(1, 1, 1)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

-- Custom tween engine (single RenderStepped loop, no TweenService)
local EASE = {
	Linear = function(x) return x end,
	Quad = function(x) return 1 - (1 - x) * (1 - x) end,
	Quint = function(x) local y = 1 - x; return 1 - y * y * y * y * y end,
	Back = function(x)
		local c1 = 1.70158
		local y = x - 1
		return 1 + (c1 + 1) * y * y * y + c1 * y * y
	end,
}
local function lerpValue(a, b, e)
	local ty = typeof(a)
	if ty == "number" then return a + (b - a) * e end
	return a:Lerp(b, e)
end

local activeTweens, tweenSlots = {}, setmetatable({}, {__mode = "k"})
local tweenConn
local TweenObj = {}
TweenObj.__index = TweenObj
function TweenObj:Cancel() self.cancelled = true end
TweenObj.Destroy = TweenObj.Cancel

local function releaseTween(rec)
	local slots = tweenSlots[rec.obj]
	if slots then
		for prop in pairs(rec.p) do
			if slots[prop] == rec then slots[prop] = nil end
		end
	end
end

local function tweenStep()
	local now = os.clock()
	local n = #activeTweens
	local i = 1
	while i <= n do
		local rec = activeTweens[i]
		local o = rec.obj
		local done = rec.cancelled or o.Parent == nil or next(rec.p) == nil
		if not done then
			local x = (now - rec.t0) / rec.dur
			if rec.loop then
				x = x - math.floor(x)
			elseif x >= 1 then
				x = 1
				done = true
			end
			local e = rec.ease(x)
			for prop, pr in pairs(rec.p) do
				if done and not rec.loop then
					o[prop] = pr[2]
				else
					o[prop] = lerpValue(pr[1], pr[2], e)
				end
			end
		end
		if done then
			releaseTween(rec)
			activeTweens[i] = activeTweens[n]
			activeTweens[n] = nil
			n -= 1
		else
			i += 1
		end
	end
	if n == 0 and tweenConn then
		tweenConn:Disconnect()
		tweenConn = nil
	end
end

local function tw(o, time, props, style, dir, loop)
	local slots = tweenSlots[o]
	if not slots then slots = {}; tweenSlots[o] = slots end
	local rec = setmetatable({
		obj = o, p = {}, t0 = os.clock(), dur = math.max(time, 0.001), loop = loop and true or false,
		ease = EASE[style and style.Name or "Quad"] or EASE.Quad,
	}, TweenObj)
	if dir == Enum.EasingDirection.In and rec.loop == false and style and style.Name ~= "Linear" then
		local out = rec.ease
		rec.ease = function(x) return 1 - out(1 - x) end
	end
	for prop, goal in pairs(props) do
		local old = slots[prop]
		if old then old.p[prop] = nil end
		local ok, from = pcall(function() return o[prop] end)
		if ok and from ~= nil then
			rec.p[prop] = {from, goal}
			slots[prop] = rec
		end
	end
	if next(rec.p) == nil then return rec end
	activeTweens[#activeTweens + 1] = rec
	if not tweenConn then tweenConn = rs.RenderStepped:Connect(tweenStep) end
	return rec
end
local function tweenShutdown()
	if tweenConn then tweenConn:Disconnect(); tweenConn = nil end
	table.clear(activeTweens)
end

local function collectFade(root)
	local list = {}
	local function collect(obj)
		local isText = obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")
		list[#list + 1] = {obj = obj, bgT = obj.BackgroundTransparency, txtT = isText and obj.TextTransparency or nil}
		for _, c in ipairs(obj:GetChildren()) do
			if c:IsA("GuiObject") then collect(c) end
		end
	end
	collect(root)
	return list
end

local function corner(p, r) return new("UICorner", {CornerRadius = UDim.new(0, r or s(8))}, p) end
local function round(p) return new("UICorner", {CornerRadius = UDim.new(1, 0)}, p) end
local function stroke(p, color, th, tr)
	return new("UIStroke", {Color = color or C.stroke, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, p)
end
local function pad(p, l, r, t, b)
	return new("UIPadding", {PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0), PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0)}, p)
end

local shimmers = {}
local function applyShimmer(obj, c1, c2, speed)
	if shimmers[obj] then return end
	local grad = new("UIGradient", {
		Name = "ShimmerGrad", Rotation = 25, Offset = Vector2.new(-1, 0),
		Color = ColorSequence.new({ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(0.5, c2), ColorSequenceKeypoint.new(1, c1)}),
	}, obj)
	local tween = tw(grad, speed or 1.3, {Offset = Vector2.new(1, 0)}, Enum.EasingStyle.Linear, Enum.EasingDirection.In, true)
	shimmers[obj] = {grad, tween}
end
local function stopShimmer(obj)
	local d = shimmers[obj]
	if d then
		pcall(function() d[2]:Cancel() end)
		pcall(function() d[1]:Destroy() end)
		shimmers[obj] = nil
	end
end

local btnState = setmetatable({}, {__mode = "k"})
local function bindHover(b)
	b.MouseEnter:Connect(function()
		local st = btnState[b]; if not st then return end
		st.hover = true
		tw(b, 0.12, {BackgroundColor3 = st.bg:Lerp(WHITE, 0.1)})
	end)
	b.MouseLeave:Connect(function()
		local st = btnState[b]; if not st then return end
		st.hover = false
		tw(b, 0.15, {BackgroundColor3 = st.bg})
	end)
	b.MouseButton1Down:Connect(function()
		local st = btnState[b]; if not st then return end
		tw(b, 0.08, {BackgroundColor3 = st.bg:Lerp(Color3.new(0, 0, 0), 0.15)})
	end)
	b.MouseButton1Up:Connect(function()
		local st = btnState[b]; if not st then return end
		tw(b, 0.12, {BackgroundColor3 = st.hover and st.bg:Lerp(WHITE, 0.1) or st.bg})
	end)
end
local function mkBtn(parent, props, bg, bgT, txt)
	props = props or {}
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextSize = props.TextSize or s(15)
	props.BackgroundColor3 = bg
	props.BackgroundTransparency = bgT or 0
	props.TextColor3 = txt or C.text
	local b = new("TextButton", props, parent)
	btnState[b] = {bg = bg, hover = false}
	bindHover(b)
	return b
end
local function setBtn(b, bg, bgT, txt)
	local st = btnState[b]; if not st then return end
	st.bg = bg
	tw(b, 0.15, {
		BackgroundColor3 = st.hover and bg:Lerp(WHITE, 0.1) or bg,
		BackgroundTransparency = bgT or 0,
		TextColor3 = txt or b.TextColor3,
	})
end

local function commas(n)
	local str = tostring(math.floor(tonumber(n) or 0))
	local out = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then out = out:sub(2) end
	return out
end

local function enumItem(enumName, itemName)
	local ok, v = pcall(function() return Enum[enumName][itemName] end)
	if ok and typeof(v) == "EnumItem" then return v end
	return nil
end
local function setParam(p, name, value) return (pcall(function() p[name] = value end)) end

local m = {
	["runanimation"] = "run", ["climbanimation"] = "climb", ["jumpanimation"] = "jump", ["fallanimation"] = "fall",
	["idleanimation"] = "idle", ["swimidleanimation"] = "swimidle", ["swimanimation"] = "swim", ["walkanimation"] = "walk",
}
local shortNames = {
	["idleanimation"] = "Idle", ["walkanimation"] = "Walk", ["runanimation"] = "Run", ["jumpanimation"] = "Jump",
	["fallanimation"] = "Fall", ["climbanimation"] = "Climb", ["swimidleanimation"] = "S.Idle", ["swimanimation"] = "Swim",
}
local buttonOrder = {"idleanimation", "walkanimation", "runanimation", "jumpanimation", "fallanimation", "climbanimation", "swimidleanimation", "swimanimation"}
local CARD_ORDER = {"idleanimation", "walkanimation", "runanimation", "jumpanimation", "fallanimation", "climbanimation", "swimanimation"}
local DESC_FOLDERS = {
	IdleAnimation = {"idle"}, WalkAnimation = {"walk"}, RunAnimation = {"run"}, JumpAnimation = {"jump"},
	FallAnimation = {"fall"}, ClimbAnimation = {"climb"}, SwimAnimation = {"swim", "swimidle"},
}
local ASSET_TYPE_IDS = {
	[48] = "climbanimation", [50] = "fallanimation", [51] = "idleanimation", [52] = "jumpanimation",
	[53] = "runanimation", [54] = "swimanimation", [55] = "walkanimation",
}

local CACHE_FILE_NAME = "animation_bundle_data_cache.json"
local ANIM_CACHE_URL = "https://raw.githubusercontent.com/TribalFootball/TuffTeto/main/animation_bundle_data_cache.json"
local EQUIPPED_FILE = "FeUgcAnim.json"
local SAVED_BUNDLES_FILE = "FeUgcAnim_Bookmarks.json"
local HISTORY_FILE = "FeUgcAnim_History.json"
local HISTORY_MAX = 30
local PRESETS_FILE = "FeUgcAnim_Presets.json"

local function loadJSON(file)
	local ok, content = pcall(function()
		if isfile and not isfile(file) then return nil end
		return readfile(file)
	end)
	if ok and type(content) == "string" and content ~= "" then
		local suc, decoded = pcall(function() return hs:JSONDecode(content) end)
		if suc and type(decoded) == "table" then return decoded end
	end
	return {}
end
local function saveJSON(file, data)
	pcall(function() writefile(file, hs:JSONEncode(data)) end)
end
local queued = {}
local function queueSave(file, data)
	if queued[file] then return end
	queued[file] = true
	task.delay(1.5, function()
		queued[file] = nil
		saveJSON(file, data)
	end)
end

local assetCache, inflight, detailsCache, metaCache = {}, {}, {}, {}
local fileCache = loadJSON(CACHE_FILE_NAME)
local equippedAnims = loadJSON(EQUIPPED_FILE)
local savedBookmarks = loadJSON(SAVED_BUNDLES_FILE)
local historyList = loadJSON(HISTORY_FILE)
local presetList = loadJSON(PRESETS_FILE)
if next(presetList) ~= nil and presetList[1] == nil then presetList = {} end
if next(historyList) ~= nil and historyList[1] == nil then historyList = {} end

task.spawn(function()
	local ok, body = pcall(function() return game:HttpGet(ANIM_CACHE_URL) end)
	if ok and type(body) == "string" then
		local ok2, data = pcall(function() return hs:JSONDecode(body) end)
		if ok2 and type(data) == "table" then
			for k, v in pairs(data) do if not fileCache[k] then fileCache[k] = v end end
			queueSave(CACHE_FILE_NAME, fileCache)
		end
	end
end)

local function normType(t) return (string.lower(tostring(t or "")):gsub("[%s_%-]", "")) end

local function classifyItem(item)
	local n = tonumber(item.AssetType)
	if n and ASSET_TYPE_IDS[n] then return ASSET_TYPE_IDS[n] end
	local lt = normType(item.AssetType)
	if lt == "swimanimation" or shortNames[lt] then return lt end
	local nm = string.lower(tostring(item.Name or ""))
	if nm:find("swim") then return "swimanimation" end
	if nm:find("idle") then return "idleanimation" end
	if nm:find("walk") then return "walkanimation" end
	if nm:find("run") then return "runanimation" end
	if nm:find("jump") then return "jumpanimation" end
	if nm:find("fall") then return "fallanimation" end
	if nm:find("climb") then return "climbanimation" end
	return nil
end

local function mapBundleItems(items)
	local map = {}
	for _, item in ipairs(items or {}) do
		local slot = classifyItem(item)
		if slot then
			local payload = {Id = item.Id, Name = item.Name, AssetType = slot}
			if slot == "swimanimation" then
				map.swimanimation = payload
				map.swimidleanimation = payload
			else
				map[slot] = payload
			end
		end
	end
	return map
end

local function slotToDescProp(assetType)
	local lt = normType(assetType)
	if lt:find("idle") and not lt:find("swim") then return "IdleAnimation"
	elseif lt:find("walk") then return "WalkAnimation"
	elseif lt:find("run") then return "RunAnimation"
	elseif lt:find("jump") then return "JumpAnimation"
	elseif lt:find("fall") then return "FallAnimation"
	elseif lt:find("climb") then return "ClimbAnimation"
	elseif lt:find("swim") then return "SwimAnimation"
	end
	return "IdleAnimation"
end

local function fetchAnimations(id, bundleId, assetType)
	local t, ser = {}, {}
	local descProp = slotToDescProp(assetType)
	pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc[descProp] = tonumber(id)
		local dummy = plrs:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		local animate = dummy:FindFirstChild("Animate")
		if animate then
			for _, folderName in ipairs(DESC_FOLDERS[descProp] or {}) do
				local folder = animate:FindFirstChild(folderName)
				if folder then
					for _, child in ipairs(folder:GetChildren()) do
						if child:IsA("Animation") and child.AnimationId ~= "" then
							local clone = child:Clone()
							t[#t + 1] = clone
							ser[#ser + 1] = {Name = clone.Name, AnimationId = clone.AnimationId, BundleId = tostring(bundleId)}
						end
					end
				end
			end
		end
		dummy:Destroy()
	end)
	if #t == 0 then
		pcall(function()
			local objs = game:GetObjects("rbxassetid://" .. tostring(id))
			if objs and #objs > 0 then
				local function processItem(item)
					if item:IsA("Animation") then
						t[#t + 1] = item:Clone()
						ser[#ser + 1] = {Name = item.Name, AnimationId = item.AnimationId, BundleId = tostring(bundleId)}
					end
				end
				processItem(objs[1])
				for _, c in ipairs(objs[1]:GetDescendants()) do processItem(c) end
			end
		end)
	end
	return t, ser
end

local function get(id, bundleId, assetType)
	local sid = tostring(id)
	if assetCache[sid] then return assetCache[sid] end
	local cached = fileCache[sid]
	if type(cached) == "table" and #cached > 0 then
		local rebuilt = {}
		for _, d in ipairs(cached) do
			if d.AnimationId and d.AnimationId ~= "" then
				local a = Instance.new("Animation")
				a.Name = d.Name or "Anim"
				a.AnimationId = d.AnimationId
				rebuilt[#rebuilt + 1] = a
			end
		end
		if #rebuilt > 0 then assetCache[sid] = rebuilt; return rebuilt end
	end
	if inflight[sid] then
		local t0 = os.clock()
		while inflight[sid] and os.clock() - t0 < 20 do task.wait(0.05) end
		return assetCache[sid] or {}
	end
	inflight[sid] = true
	local ok, t, ser = pcall(fetchAnimations, id, bundleId, assetType)
	inflight[sid] = nil
	if not ok or type(t) ~= "table" then return {} end
	if #t > 0 then
		assetCache[sid] = t
		fileCache[sid] = ser
		queueSave(CACHE_FILE_NAME, fileCache)
	end
	return t
end

local function clearAssetCache(id)
	local sid = tostring(id)
	assetCache[sid], fileCache[sid] = nil, nil
	queueSave(CACHE_FILE_NAME, fileCache)
end

local function getSpecificTrack(fetchedTracks, targetType)
	if #fetchedTracks == 0 then return nil end
	if targetType == "swimidleanimation" then
		for _, tr in ipairs(fetchedTracks) do
			if string.lower(tr.Name):find("idle") then return tr end
		end
		return fetchedTracks[2] or fetchedTracks[1]
	elseif targetType == "swimanimation" then
		for _, tr in ipairs(fetchedTracks) do
			if string.lower(tr.Name) == "swim" then return tr end
		end
	end
	return fetchedTracks[1]
end

local function getTracksFor(payload, slot)
	if payload.Direct then
		if not payload.Tracks then
			local out = {}
			for _, d in ipairs(payload.Direct) do
				if d.AnimationId and d.AnimationId ~= "" then
					local a = Instance.new("Animation")
					a.Name = d.Name or "Anim"
					a.AnimationId = d.AnimationId
					out[#out + 1] = a
				end
			end
			payload.Tracks = out
		end
		return payload.Tracks
	end
	local list = get(payload.Id, nil, payload.AssetType)
	if #list == 0 then return {} end
	if slot == "idleanimation" then return list end
	local spec = getSpecificTrack(list, slot)
	return spec and {spec} or {}
end

local function preloadAnimations(list)
	if #list > 0 then pcall(function() cp:PreloadAsync(list) end) end
end

local function findStoredEntry(key)
	local e = savedBookmarks[key]
	if type(e) == "table" and e.Items then return e end
	for _, h in ipairs(historyList) do
		if tostring(h.Id) == key and h.Items then return h end
	end
	return nil
end

local function getDetails(id)
	local key = tostring(id)
	if detailsCache[key] then return detailsCache[key] end
	local stored = findStoredEntry(key)
	if stored then
		local res = {Items = stored.Items}
		detailsCache[key] = res
		return res
	end
	local ok, res = pcall(function() return as:GetBundleDetailsAsync(id) end)
	if ok and type(res) == "table" and res.Items then
		detailsCache[key] = res
		return res
	end
	return nil
end

local function equipMap(character, slotMap, persist)
	if not character then return 0 end
	local animate = character:FindFirstChild("Animate") or character:WaitForChild("Animate", 5)
	local human = character:FindFirstChildOfClass("Humanoid")
	if not animate or not human then return 0 end
	for _, tr in ipairs(human:GetPlayingAnimationTracks()) do
		pcall(function() tr:AdjustWeight(0, 0); tr:Stop(0) end)
	end
	animate.Disabled = true
	local count = 0
	for slot, anims in pairs(slotMap) do
		local folderName = m[slot]
		local folder = folderName and animate:FindFirstChild(folderName)
		if folder and #anims > 0 then
			for _, o in ipairs(folder:GetChildren()) do
				if o:IsA("Animation") then o:Destroy() end
			end
			local saved = {}
			for _, a in ipairs(anims) do
				local na = Instance.new("Animation")
				na.Name = a.Name
				na.AnimationId = a.AnimationId
				na.Parent = folder
				saved[#saved + 1] = {Name = a.Name, AnimationId = a.AnimationId}
			end
			if persist then equippedAnims[slot] = saved end
			count = count + 1
		end
	end
	if persist then saveJSON(EQUIPPED_FILE, equippedAnims) end
	task.wait(0.05)
	animate.Disabled = false
	return count
end

local function applyBundleItemsToCharacter(items)
	local char = lp.Character
	if not char then return 0 end
	local slotMap, toLoad = {}, {}
	for _, slot in ipairs(buttonOrder) do
		local payload = items[slot]
		if payload then
			local list = getTracksFor(payload, slot)
			if #list > 0 then
				slotMap[slot] = list
				for _, a in ipairs(list) do toLoad[#toLoad + 1] = a end
			end
		end
	end
	preloadAnimations(toLoad)
	return equipMap(char, slotMap, true)
end

local capturing = {}
local function captureBundleData(id)
	local key = tostring(id)
	if capturing[key] then return end
	capturing[key] = true
	task.spawn(function()
		local ok = pcall(function()
			local details = getDetails(id)
			if not (details and details.Items) then return end
			local items = {}
			for _, it in ipairs(details.Items) do
				items[#items + 1] = {Id = it.Id, Name = it.Name, AssetType = it.AssetType, Type = it.Type}
			end
			local anims, seen = {}, {}
			for slot, payload in pairs(mapBundleItems(details.Items)) do
				local pid = tostring(payload.Id)
				if not seen[pid] then
					seen[pid] = true
					get(payload.Id, id, payload.AssetType)
				end
				local list = fileCache[pid]
				if type(list) == "table" and #list > 0 then
					local copy = {}
					for _, a in ipairs(list) do copy[#copy + 1] = {Name = a.Name, AnimationId = a.AnimationId} end
					anims[slot] = {Id = payload.Id, List = copy}
				end
			end
			local function store(e)
				if type(e) == "table" then e.Items, e.Anims = items, anims end
			end
			store(savedBookmarks[key])
			for _, h in ipairs(historyList) do
				if tostring(h.Id) == key then store(h) end
			end
			saveJSON(SAVED_BUNDLES_FILE, savedBookmarks)
			saveJSON(HISTORY_FILE, historyList)
		end)
		capturing[key] = nil
	end)
end

task.spawn(function()
	local function seed(e)
		if type(e) == "table" and type(e.Anims) == "table" then
			for _, a in pairs(e.Anims) do
				if type(a) == "table" and a.Id and type(a.List) == "table" and not fileCache[tostring(a.Id)] then
					fileCache[tostring(a.Id)] = a.List
				end
			end
		end
	end
	for _, e in pairs(savedBookmarks) do seed(e) end
	for _, h in ipairs(historyList) do seed(h) end
	task.wait(3)
	local todo = {}
	for _, e in pairs(savedBookmarks) do
		if type(e) == "table" and e.Id and not e.Anims then todo[#todo + 1] = e.Id end
	end
	for _, h in ipairs(historyList) do
		if h.Id and not h.Anims then todo[#todo + 1] = h.Id end
	end
	for _, id in ipairs(todo) do
		captureBundleData(id)
		task.wait(1)
	end
end)

local function recordHistory(id, name)
	if not id then return end
	local key = tostring(id)
	local oldItems, oldAnims
	for i = #historyList, 1, -1 do
		if tostring(historyList[i].Id) == key then
			oldItems, oldAnims = historyList[i].Items, historyList[i].Anims
			table.remove(historyList, i)
		end
	end
	local sv = savedBookmarks[key]
	if not oldItems and type(sv) == "table" then oldItems, oldAnims = sv.Items, sv.Anims end
	local mt = metaCache[key] or {}
	table.insert(historyList, 1, {
		Id = id, Name = name or "Unknown", Time = os.time(), Kind = mt.kind, Amount = mt.amount, Creator = mt.creator,
		Items = oldItems, Anims = oldAnims,
	})
	while #historyList > HISTORY_MAX do table.remove(historyList) end
	saveJSON(HISTORY_FILE, historyList)
	if not oldAnims then captureBundleData(id) end
	if onHistoryChanged then onHistoryChanged() end
end

local function wearBundle(bundleId, bundleName, onDone)
	task.spawn(function()
		local details = getDetails(bundleId)
		if details and lp.Character then
			local n = applyBundleItemsToCharacter(mapBundleItems(details.Items))
			if n > 0 then recordHistory(bundleId, bundleName) end
			if toast then toast(n > 0 and ("Equipped " .. n .. " animations") or "Nothing could be equipped", n > 0 and "ok" or "bad") end
		elseif toast then
			toast("Couldn't load that bundle", "bad")
		end
		if onDone then onDone() end
	end)
end

local function initAutoEquip(char)
	if not char then return end
	task.spawn(function()
		local animate = char:WaitForChild("Animate", 5)
		local human = char:WaitForChild("Humanoid", 5)
		if animate and human then
			local idleFolder = animate:WaitForChild("idle", 5)
			if idleFolder then idleFolder:WaitForChild("Animation1", 3) end
			task.wait(0.1)
			if next(equippedAnims) ~= nil then equipMap(char, equippedAnims, false) end
		end
	end)
end
if lp.Character then initAutoEquip(lp.Character) end
track(lp.CharacterAdded:Connect(initAutoEquip))

local badgeRefs, fetchingMeta = {}, {}

-- FIX: read both PriceStatus and ItemStatus, treat Price == 0 as free
local function seedMeta(entry)
	if type(entry) ~= "table" or not entry.Id then return nil end
	local key = tostring(entry.Id)
	local mt = metaCache[key] or {}
	if mt.kind == nil then
		local rawStatus = entry.PriceStatus or entry.ItemStatus or ""
		local status = string.lower(tostring(rawStatus))
		local price = tonumber(entry.Price)
		if price == nil then price = tonumber(entry.LowestPrice) end
		if status:find("free") or price == 0 then
			mt.kind, mt.amount = "free", 0
		elseif status:find("off") or status:find("reseller") then
			mt.kind = "off"
		elseif price then
			mt.kind, mt.amount = "paid", price
		end
	end
	if entry.CreatorName and not mt.creator then mt.creator = tostring(entry.CreatorName) end
	metaCache[key] = mt
	return mt
end

local function ensureMeta(id, needCreator)
	local key = tostring(id)
	local mt = metaCache[key]
	if mt and (mt.fetched or (mt.kind and (not needCreator or mt.creator))) then return end
	if fetchingMeta[key] then return end
	fetchingMeta[key] = true
	task.spawn(function()
		local ok, info = pcall(function() return mps:GetProductInfo(tonumber(id), Enum.InfoType.Bundle) end)
		fetchingMeta[key] = nil
		local mm = metaCache[key] or {}
		mm.fetched = true
		if ok and type(info) == "table" then
			local price = tonumber(info.PriceInRobux)
			if mm.kind == nil then
				if price == 0 then mm.kind, mm.amount = "free", 0
				elseif price then mm.kind, mm.amount = "paid", price
				else mm.kind = (info.IsForSale == false) and "off" or "unknown" end
			end
			if not mm.creator and type(info.Creator) == "table" and info.Creator.Name then
				mm.creator = tostring(info.Creator.Name)
			end
		elseif mm.kind == nil then
			mm.kind = "unknown"
		end
		metaCache[key] = mm
		if onMetaChanged then onMetaChanged(key) end
	end)
end

local function applyBadge(label, meta)
	local kind = meta and meta.kind
	local text, bg, fg
	if kind == "paid" then text, bg, fg = "R$ " .. commas(meta.amount), C.green, Color3.fromRGB(20, 20, 22)
	elseif kind == "free" then text, bg, fg = "FREE", C.accent2, Color3.fromRGB(20, 20, 22)
	elseif kind == "off" then text, bg, fg = "OFFSALE", C.surfaceHi, C.textDim
	elseif kind == "unknown" then text, bg, fg = "N/A", C.surfaceHi, C.textDim
	else text, bg, fg = "…", C.surfaceHi, C.textMuted end
	label.Text = text
	tw(label, 0.2, {BackgroundColor3 = bg, TextColor3 = fg})
end

local function bindBadge(label, id)
	local key = tostring(id)
	badgeRefs[key] = badgeRefs[key] or {}
	table.insert(badgeRefs[key], label)
	applyBadge(label, metaCache[key])
end

local function mkBadge(parent, props)
	props = props or {}
	props.BackgroundColor3 = C.surfaceHi
	props.AutomaticSize = Enum.AutomaticSize.X
	props.Size = UDim2.fromOffset(0, s(22))
	props.Font = Enum.Font.GothamBlack
	props.TextSize = s(13)
	props.TextColor3 = C.textMuted
	props.Text = "…"
	props.BorderSizePixel = 0
	local b = new("TextLabel", props, parent)
	round(b); pad(b, s(10), s(10))
	return b
end

-- FIX: min/max are aliases for price_min/price_max
local KEY_ALIASES = {
	cat = "category", cats = "category",
	min = "price_min", max = "price_max",
	pricemin = "price_min", pricemax = "price_max",
	minprice = "price_min", maxprice = "price_max",
}
local VALID_KEYS = {sort = true, price_min = true, price_max = true, price = true, creator = true, sale = true, category = true, has = true, sales = true, period = true, limit = true, is = true}
local SORT_ALIASES = {
	mostfavorited = "MostFavorited", pricelowtohigh = "PriceLowToHigh", pricehightolow = "PriceHighToLow", recentlycreated = "RecentlyCreated",
	rel = "Relevance", relevance = "Relevance", relevant = "Relevance",
	new = "RecentlyCreated", newest = "RecentlyCreated", recent = "RecentlyCreated", latest = "RecentlyCreated",
	fav = "MostFavorited", favorite = "MostFavorited", favorited = "MostFavorited", popular = "MostFavorited", top = "MostFavorited",
	best = "Bestselling", bestselling = "Bestselling", sales = "Bestselling", seller = "Bestselling",
	low = "PriceLowToHigh", asc = "PriceLowToHigh", cheap = "PriceLowToHigh", cheapest = "PriceLowToHigh",
	high = "PriceHighToLow", desc = "PriceHighToLow", expensive = "PriceHighToLow",
}
local SAVED_SORT = {
	new = "new", newest = "new", recent = "new", latest = "new", old = "old", oldest = "old",
	name = "name", az = "name", alpha = "name", recentlycreated = "new", pricelowtohigh = "low", pricehightolow = "high", mostfavorited = "fav",
	low = "low", asc = "low", cheap = "low", cheapest = "low", high = "high", desc = "high", expensive = "high",
	fav = "fav", favorite = "fav", favorites = "fav",
}
local CAT_ALIASES = {
	none = "None", all = "None", featured = "Featured", collectibles = "Collectibles", collectible = "Collectibles",
	community = "CommunityCreations", communitycreations = "CommunityCreations", ugc = "CommunityCreations", premium = "Premium", recommended = "Recommended",
}
local SALES_ALIASES = {all = "All", collectibles = "Collectibles", collectible = "Collectibles", premium = "Premium"}
local PERIOD_ALIASES = {
	["12h"] = "Past12Hours", day = "PastDay", ["1d"] = "PastDay", ["24h"] = "PastDay", ["3d"] = "Past3Days",
	week = "PastWeek", ["7d"] = "PastWeek", month = "PastMonth", ["30d"] = "PastMonth", all = "AllTime", alltime = "AllTime",
}
local LIMITS = {10, 28, 30, 60, 120}
local HAS_ALIASES = {
	idle = "idleanimation", walk = "walkanimation", run = "runanimation", jump = "jumpanimation",
	fall = "fallanimation", climb = "climbanimation", swim = "swimanimation",
}

local function parseQuery(text)
	text = text or ""
	local tags, words = {}, {}
	local function addTag(k, v)
		k = string.lower(k)
		k = KEY_ALIASES[k] or k
		if not VALID_KEYS[k] then return false end
		for i = #tags, 1, -1 do
			if tags[i].key == k then table.remove(tags, i) end
		end
		tags[#tags + 1] = {key = k, val = v}
		return true
	end
	local rest = text:gsub('([%a_]+):"([^"]*)"', function(k, v)
		if addTag(k, v) then return " " end
		return nil
	end)
	for word in rest:gmatch("%S+") do
		local k, v = word:match("^([%a_]+):(.+)$")
		if k and addTag(k, v) then
			-- consumed
		else
			words[#words + 1] = word
		end
	end
	return {keyword = table.concat(words, " "), tags = tags}
end

local function buildQuery(q)
	local parts = {}
	if q.keyword ~= "" then parts[#parts + 1] = q.keyword end
	for _, tg in ipairs(q.tags) do
		local v = tg.val
		if v:find("%s") then v = '"' .. v .. '"' end
		parts[#parts + 1] = tg.key .. ":" .. v
	end
	return table.concat(parts, " ")
end

local function interpretTag(tab, key, val)
	key = KEY_ALIASES[key] or key
	local v = (string.lower(val):gsub("_", ""))
	local saved = (tab ~= "Discover")
	if tab == "Presets" then
		if key == "sort" then
			local x = ({new = "new", newest = "new", recent = "new", old = "old", oldest = "old", name = "name", az = "name", alpha = "name"})[v]
			return x ~= nil, x
		end
		return false
	end
	if key == "sort" then
		local x = (saved and SAVED_SORT or SORT_ALIASES)[v]
		return x ~= nil, x
	elseif key == "price_min" or key == "price_max" then
		local n = tonumber(v)
		if n and n >= 0 then return true, math.floor(n) end
		return false
	elseif key == "price" then
		if v == "free" then return true, {min = 0, max = 0} end
		local a, b = v:match("^(%d+)%-(%d+)$")
		if a then
			a, b = tonumber(a), tonumber(b)
			if a > b then a, b = b, a end
			return true, {min = a, max = b}
		end
		local n = v:match("^(%d+)$")
		if n then n = tonumber(n); return true, {min = n, max = n} end
		return false
	elseif key == "creator" then
		return val ~= "", val
	elseif key == "is" then
		if tab == "Saved" and (v == "fav" or v == "favorite" or v == "favorites" or v == "starred") then return true, "fav" end
		if saved and (v == "free" or v == "paid" or v == "offsale" or v == "off") then return true, (v == "off" and "offsale" or v) end
		return false
	elseif key == "has" then
		if not saved then return false end
		local slot = HAS_ALIASES[v]
		return slot ~= nil, slot
	elseif saved then
		return false
	elseif key == "sale" then
		if v == "on" or v == "only" then return true, "on" end
		if v == "all" or v == "any" then return true, "all" end
		return false
	elseif key == "category" then
		local x = CAT_ALIASES[v]; return x ~= nil, x
	elseif key == "sales" then
		local x = SALES_ALIASES[v]; return x ~= nil, x
	elseif key == "period" then
		local x = PERIOD_ALIASES[v]; return x ~= nil, x
	elseif key == "limit" then
		local n = tonumber(v)
		if not n then return false end
		local best = LIMITS[1]
		for _, l in ipairs(LIMITS) do
			if math.abs(l - n) < math.abs(best - n) then best = l end
		end
		return true, best
	end
	return false
end

local function compileQuery(tab, q)
	local spec = {keyword = q.keyword, issues = {}}
	for _, tg in ipairs(q.tags) do
		local ok, v = interpretTag(tab, tg.key, tg.val)
		if not ok then
			spec.issues[#spec.issues + 1] = tg.key .. ":" .. tg.val
		elseif tg.key == "sort" then spec.sort = v
		elseif tg.key == "price_min" then spec.min = v
		elseif tg.key == "price_max" then spec.max = v
		elseif tg.key == "price" then spec.min, spec.max = v.min, v.max
		elseif tg.key == "creator" then spec.creator = v
		elseif tg.key == "sale" then spec.saleOnly = (v == "on")
		elseif tg.key == "category" then spec.cat = v
		elseif tg.key == "sales" then spec.sales = v
		elseif tg.key == "period" then spec.period = v
		elseif tg.key == "limit" then spec.limit = v
		elseif tg.key == "is" then spec.is = v
		elseif tg.key == "has" then spec.has = v
		end
	end
	return spec
end

-- FIX: don't send 0 to MinPrice / MaxPrice (Roblox treats 0 as "no filter")
local function buildParams(spec)
	local p = CatalogSearchParams.new()
	setParam(p, "SearchKeyword", spec.keyword or "")
	setParam(p, "BundleTypes", {Enum.BundleType.Animations})
	setParam(p, "IncludeOffSale", not spec.saleOnly)
	setParam(p, "Limit", spec.limit or 120)
	local sortName = spec.sort or (((spec.keyword or "") == "") and "RecentlyCreated" or "Relevance")
	local e = enumItem("CatalogSortType", sortName)
	if e then setParam(p, "SortType", e) end
	if spec.min and spec.min > 0 then setParam(p, "MinPrice", spec.min) end
	if spec.max and spec.max > 0 then setParam(p, "MaxPrice", spec.max) end
	if spec.creator then setParam(p, "CreatorName", spec.creator) end
	if spec.cat then
		local ce = enumItem("CatalogCategoryFilter", spec.cat)
		if ce then setParam(p, "CategoryFilter", ce) end
	end
	local se = enumItem("SalesTypeFilter", spec.sales or "All")
	if se then setParam(p, "SalesTypeFilter", se) end
	if spec.period then
		local pe = enumItem("CatalogSortAggregation", spec.period)
		if pe then setParam(p, "SortAggregation", pe) end
	end
	return p
end

-- FIX: strict filter when a price filter is active; exclude items with unknown price
local function passesClientFilter(entry, spec)
	if type(entry) ~= "table" or not entry.Id then return false end
	local mt = seedMeta(entry)
	local wantPrice = spec and (spec.min ~= nil or spec.max ~= nil)
	if wantPrice then
		local kind = mt and mt.kind
		local amt
		if kind == "free" then amt = 0
		elseif kind == "paid" then amt = mt.amount end
		if amt == nil then return false end
		if spec.min and amt < spec.min then return false end
		if spec.max and amt > spec.max then return false end
	end
	return true
end

local function savedAmount(v)
	local mt = metaCache[tostring(v.Id)]
	local kind = (mt and mt.kind) or v.Kind
	local amount = (mt and mt.amount) or v.Amount
	if kind == "free" then return 0 end
	if kind == "paid" then return amount end
	return nil
end

local function extraFilter(v, spec)
	if spec.is == "fav" and not v.Fav then return false end
	if spec.is == "free" or spec.is == "paid" or spec.is == "offsale" then
		local mt = metaCache[tostring(v.Id)]
		local kind = (mt and mt.kind) or v.Kind
		local want = spec.is == "offsale" and "off" or spec.is
		if kind ~= want then return false end
	end
	if spec.has then
		if not v.Items then return false end
		if not mapBundleItems(v.Items)[spec.has] then return false end
	end
	return true
end

local function buildSavedList(spec)
	local list = {}
	local kw = string.lower(spec.keyword or "")
	local cr = spec.creator and string.lower(spec.creator) or nil
	for key, v in pairs(savedBookmarks) do
		if type(v) == "table" and v.Id then
			if not metaCache[key] and v.Kind then
				metaCache[key] = {kind = v.Kind, amount = v.Amount, creator = v.Creator}
			end
			local ok = true
			if kw ~= "" and not string.find(string.lower(v.Name or ""), kw, 1, true) then ok = false end
			if ok and cr then
				local mt = metaCache[key]
				local c = string.lower((mt and mt.creator) or v.Creator or "")
				if not string.find(c, cr, 1, true) then ok = false end
			end
			if ok and not extraFilter(v, spec) then ok = false end
			if ok and (spec.min ~= nil or spec.max ~= nil) then
				local a = savedAmount(v)
				if a == nil then ok = false end
				if ok and spec.min and a < spec.min then ok = false end
				if ok and spec.max and a > spec.max then ok = false end
			end
			if ok then list[#list + 1] = v end
		end
	end
	local function cmpTime(a, b)
		local ta, tb = a.Time or 0, b.Time or 0
		if ta ~= tb then return ta > tb end
		return tostring(a.Id) < tostring(b.Id)
	end
	local mode = spec.sort or "fav"
	table.sort(list, function(a, b)
		if mode == "new" then return cmpTime(a, b)
		elseif mode == "old" then
			local ta, tb = a.Time or 0, b.Time or 0
			if ta ~= tb then return ta < tb end
			return tostring(a.Id) < tostring(b.Id)
		elseif mode == "name" then
			local na, nb = string.lower(a.Name or ""), string.lower(b.Name or "")
			if na ~= nb then return na < nb end
			return cmpTime(a, b)
		elseif mode == "low" or mode == "high" then
			local x, y = savedAmount(a), savedAmount(b)
			if x == y then return cmpTime(a, b) end
			if x == nil then return false end
			if y == nil then return true end
			if mode == "low" then return x < y end
			return x > y
		end
		local fa, fb = a.Fav and true or false, b.Fav and true or false
		if fa ~= fb then return fa end
		return cmpTime(a, b)
	end)
	return list
end

local function buildHistoryList(spec)
	local list = {}
	local kw = string.lower(spec.keyword or "")
	local cr = spec.creator and string.lower(spec.creator) or nil
	for _, v in ipairs(historyList) do
		local key = tostring(v.Id)
		if not metaCache[key] and v.Kind then
			metaCache[key] = {kind = v.Kind, amount = v.Amount, creator = v.Creator}
		end
		local ok = true
		if kw ~= "" and not string.find(string.lower(v.Name or ""), kw, 1, true) then ok = false end
		if ok and cr then
			local mt = metaCache[key]
			local c = string.lower((mt and mt.creator) or v.Creator or "")
			if not string.find(c, cr, 1, true) then ok = false end
		end
		if ok and (spec.min ~= nil or spec.max ~= nil) then
			local a = savedAmount(v)
			if a == nil then ok = false end
			if ok and spec.min and a < spec.min then ok = false end
			if ok and spec.max and a > spec.max then ok = false end
		end
		if ok and not extraFilter(v, spec) then ok = false end
		if ok then list[#list + 1] = v end
	end
	if spec.sort == "old" then
		local rev = {}
		for i = #list, 1, -1 do rev[#rev + 1] = list[i] end
		list = rev
	elseif spec.sort == "name" then
		table.sort(list, function(a, b) return string.lower(a.Name or "") < string.lower(b.Name or "") end)
	end
	return list
end

local uiOk, uiErr = pcall(function()

local PAD, TOPH = s(12), s(50)
local W, H = s(W0), s(H0)
local BODY_H = H - TOPH - PAD
local LW, GAP = s(420), s(12)
local RW = W - PAD * 2 - LW - GAP
local CHIP_Y, CHIP_H, TAG_Y, TAG_H, GRID_Y, FOOT_H = s(42), s(28), s(76), s(44), s(126), s(34)
local GRID_H = BODY_H - GRID_Y - FOOT_H - s(4)
local COLS, ROWS = 3, 1
local PER_PAGE = 3

local CPAD = s(8)
local CW = math.floor((LW - CPAD * (COLS + 1)) / COLS)
local GRID_AVAIL_H = GRID_H - CPAD * (ROWS + 1)
local CH = math.min(math.floor(GRID_AVAIL_H / ROWS), s(200))
local AH = s(28)

local playerGui = lp:WaitForChild("PlayerGui", 10) or lp:FindFirstChildOfClass("PlayerGui")
local parentCandidates = {}
if playerGui then parentCandidates[#parentCandidates + 1] = playerGui end
pcall(function()
	if typeof(gethui) == "function" then
		local h = gethui()
		if h then parentCandidates[#parentCandidates + 1] = h end
	end
end)
pcall(function() parentCandidates[#parentCandidates + 1] = game:GetService("CoreGui") end)

pcall(function()
	if playerGui and playerGui:FindFirstChild("StudioAnimStudio") then playerGui.StudioAnimStudio:Destroy() end
	local cg = game:GetService("CoreGui")
	if cg and cg:FindFirstChild("StudioAnimStudio") then cg.StudioAnimStudio:Destroy() end
end)

local g = Instance.new("ScreenGui")
g.Name = "StudioAnimStudio"
g.ResetOnSpawn = false
g.IgnoreGuiInset = true
g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
g.DisplayOrder = 999

local parented = false
for _, p in ipairs(parentCandidates) do
	local okP = pcall(function() g.Parent = p end)
	if okP and g.Parent == p then parented = true; break end
end
if not parented then
	pcall(function() g.Parent = lp:WaitForChild("PlayerGui") end)
end

local mf = new("Frame", {
	Name = "Main",
	Size = UDim2.fromOffset(W, H),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = C.bg,
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Active = true,
	Visible = true,
}, g)
corner(mf, s(16))
stroke(mf, C.stroke, 1, 0.35)

local topLine = new("Frame", {Size = UDim2.new(1, 0, 0, s(2)), BackgroundColor3 = C.accent2, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 3}, mf)

local top = new("Frame", {Name = "Top", Size = UDim2.new(1, 0, 0, TOPH), BackgroundTransparency = 1, Active = true}, mf)
local logo = new("Frame", {Size = UDim2.fromOffset(s(30), s(30)), Position = UDim2.new(0, PAD, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = C.surfaceHi, BackgroundTransparency = 0.1, BorderSizePixel = 0}, top)
corner(logo, s(9))
new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "A", Font = Enum.Font.GothamBlack, TextSize = s(18), TextColor3 = C.text}, logo)
new("TextLabel", {Position = UDim2.fromOffset(PAD + s(42), s(8)), Size = UDim2.fromOffset(s(170), s(20)), BackgroundTransparency = 1, Text = "Animation Studio", Font = Enum.Font.GothamBlack, TextSize = s(18), TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left}, top)
new("TextLabel", {Position = UDim2.fromOffset(PAD + s(42), s(28)), Size = UDim2.fromOffset(s(170), s(16)), BackgroundTransparency = 1, Text = "FE UGC bundles", Font = Enum.Font.Gotham, TextSize = s(13), TextColor3 = C.textMuted, TextXAlignment = Enum.TextXAlignment.Left}, top)

local seg = new("Frame", {Position = UDim2.fromOffset(PAD + s(212), math.floor((TOPH - s(34)) / 2)), Size = UDim2.fromOffset(s(300), s(34)), BackgroundColor3 = C.surface, BackgroundTransparency = 0.2, BorderSizePixel = 0}, top)
corner(seg, s(10))
local tabIndicator = new("Frame", {Position = UDim2.new(0, s(2), 0, s(2)), Size = UDim2.new(1 / 4, -s(3), 1, -s(4)), BackgroundColor3 = C.surfaceHi, BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 1}, seg)
corner(tabIndicator, s(8))
local tabDiscover = mkBtn(seg, {Text = "Discover", Size = UDim2.fromScale(1 / 4, 1), ZIndex = 2, TextSize = s(13)}, C.surface, 1, C.text)
local tabSaved = mkBtn(seg, {Text = "Saved", Size = UDim2.fromScale(1 / 4, 1), Position = UDim2.fromScale(1 / 4, 0), ZIndex = 2, TextSize = s(13)}, C.surface, 1, C.textMuted)
local tabRecent = mkBtn(seg, {Text = "Recent", Size = UDim2.fromScale(1 / 4, 1), Position = UDim2.fromScale(2 / 4, 0), ZIndex = 2, TextSize = s(13)}, C.surface, 1, C.textMuted)
local tabPresets = mkBtn(seg, {Text = "Presets", Size = UDim2.fromScale(1 / 4, 1), Position = UDim2.fromScale(3 / 4, 0), ZIndex = 2, TextSize = s(13)}, C.surface, 1, C.textMuted)

local closeBtn = mkBtn(top, {Text = "×", Size = UDim2.fromOffset(s(30), s(30)), Position = UDim2.new(1, -PAD - s(30), 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextSize = s(20)}, C.surface, 0.2, C.textDim)
corner(closeBtn, s(8))
local minBtn = mkBtn(top, {Text = "–", Size = UDim2.fromOffset(s(30), s(30)), Position = UDim2.new(1, -PAD - s(66), 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextSize = s(18)}, C.surface, 0.2, C.textDim)
corner(minBtn, s(8))

local left = new("Frame", {Position = UDim2.fromOffset(PAD, TOPH), Size = UDim2.fromOffset(LW, BODY_H), BackgroundTransparency = 1}, mf)

local helpW, searchW, gap4 = s(38), s(86), s(6)
local sbW = LW - helpW - searchW - gap4 * 2
local sbBox = new("Frame", {Size = UDim2.fromOffset(sbW, s(38)), BackgroundColor3 = C.surface, BackgroundTransparency = 0.25, BorderSizePixel = 0}, left)
corner(sbBox, s(10))
stroke(sbBox, C.stroke, 1, 0.55)
local sb = new("TextBox", {
	Size = UDim2.new(1, -s(44), 1, 0), Position = UDim2.fromOffset(s(14), 0), BackgroundTransparency = 1, Text = "",
	PlaceholderText = "Search…  try sort:price_high_to_low price_max:500",
	ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = s(15),
	TextColor3 = C.text, PlaceholderColor3 = C.textMuted, TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true,
}, sbBox)
local clearBtn = mkBtn(sbBox, {Text = "×", Size = UDim2.fromOffset(s(26), s(26)), Position = UDim2.new(1, -s(30), 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextSize = s(17), Visible = false}, C.surfaceHi, 0.35, C.textDim)
round(clearBtn)
local searchBtn = mkBtn(left, {Text = "Search", Size = UDim2.fromOffset(searchW, s(38)), Position = UDim2.fromOffset(sbW + gap4, 0), TextSize = s(15)}, C.surfaceHi, 0.15, C.text)
corner(searchBtn, s(10))
local helpBtn = mkBtn(left, {Text = "?", Size = UDim2.fromOffset(helpW, s(38)), Position = UDim2.fromOffset(sbW + gap4 * 2 + searchW, 0), TextSize = s(16)}, C.surface, 0.25, C.textDim)
corner(helpBtn, s(10))

local function mkRow(y, h)
	local row = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(LW, h), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 2,
	}, left)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, s(6)), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center}, row)
	return row
end
local chipsRow = mkRow(CHIP_Y, CHIP_H)
local tagsRow = mkRow(TAG_Y, TAG_H)

local tagHint = new("TextLabel", {
	Name = "TagHint",
	Position = UDim2.fromOffset(0, TAG_Y),
	Size = UDim2.fromOffset(LW, TAG_H),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "No filters  ·  press  ?  to see all search tags",
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = C.textDim,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextWrapped = true,
	ZIndex = 6,
}, left)
new("UITextSizeConstraint", {MaxTextSize = s(28), MinTextSize = s(14)}, tagHint)

local gridHolder = new("Frame", {Position = UDim2.fromOffset(0, GRID_Y), Size = UDim2.fromOffset(LW, GRID_H), BackgroundColor3 = C.panel, BackgroundTransparency = 0.55, BorderSizePixel = 0, ClipsDescendants = true}, left)
corner(gridHolder, s(12)); stroke(gridHolder, C.stroke, 1, 0.7)
new("UIGridLayout", {
	CellSize = UDim2.fromOffset(CW, CH),
	CellPadding = UDim2.fromOffset(CPAD, CPAD),
	SortOrder = Enum.SortOrder.LayoutOrder,
	FillDirectionMaxCells = COLS,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, gridHolder)
local gridMsg = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamSemibold, TextSize = s(15), TextColor3 = C.textMuted, Visible = false, ZIndex = 2}, left)
gridMsg.Position = UDim2.fromOffset(0, GRID_Y)
gridMsg.Size = UDim2.fromOffset(LW, GRID_H)

local helpPanel = new("Frame", {Position = UDim2.fromOffset(0, GRID_Y), Size = UDim2.fromOffset(LW, GRID_H), BackgroundColor3 = C.overlay, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ClipsDescendants = true, ZIndex = 20}, left)
corner(helpPanel, s(12))
local helpScroll = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = s(3), ScrollBarImageColor3 = C.surfaceHi, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 21}, helpPanel)
local HELP_TEXT = table.concat({
	'<b>Search tags</b>  <font color="#9AA1B8">type, press Enter</font>',
	'',
	'<font color="#B0B0B2">sort:</font>  relevance  newest  mostfavorited  bestselling  price_low_to_high  price_high_to_low',
	'<font color="#B0B0B2">price_min:</font> 50   <font color="#B0B0B2">price_max:</font> 500   <font color="#B0B0B2">price:</font> 100-500  or  free',
	'<font color="#B0B0B2">creator:</font> Roblox   or   creator:"Group Name"',
	'<font color="#B0B0B2">sale:</font> on (hide off-sale)   all',
	'<font color="#B0B0B2">category:</font> featured  collectibles  community  premium  recommended',
	'<font color="#B0B0B2">sales:</font> collectibles  premium  all',
	'<font color="#B0B0B2">period:</font> day  week  month  alltime',
	'<font color="#B0B0B2">limit:</font> 10  28  30  60  120',
	'',
	'<i>Underscores work as spaces in tag values:</i>  sort:price_high_to_low',
	'',
	'<b>Saved tab</b>',
	'<font color="#B0B0B2">sort:</font> newest  oldest  name  price_low_to_high  price_high_to_low  favorites',
	'<font color="#B0B0B2">is:</font> favorite  free  paid  offsale     <font color="#B0B0B2">has:</font> idle  walk  run  jump  fall  climb  swim',
	'<font color="#B0B0B2">Recent tab:</font> same filters except is:favorite',
	'',
	'<b>Presets tab</b>',
	'<font color="#B0B0B2">sort:</font> newest  oldest  name   (search filters by name)',
	'',
	'<font color="#B0B0B2">Tab</font>  autocomplete the highlighted suggestion',
	'Example:  <i>zombie sort:price_high_to_low price_max:300</i>',
}, "\n")
local helpText = new("TextLabel", {
	Position = UDim2.fromOffset(s(14), s(12)), Size = UDim2.new(1, -s(28), 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
	RichText = true, Text = HELP_TEXT, TextWrapped = true, Font = Enum.Font.Gotham, TextSize = s(15), TextColor3 = C.text, TextTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 22,
}, helpScroll)

local footer = new("Frame", {Position = UDim2.fromOffset(0, BODY_H - FOOT_H), Size = UDim2.fromOffset(LW, FOOT_H), BackgroundTransparency = 1}, left)
local prevBtn = mkBtn(footer, {Text = "← Back", Size = UDim2.fromOffset(s(90), FOOT_H), TextSize = s(14)}, C.surfaceHi, 0.6, C.textMuted)
corner(prevBtn, s(8))
local nextBtn = mkBtn(footer, {Text = "Next →", Size = UDim2.fromOffset(s(90), FOOT_H), Position = UDim2.new(1, -s(90), 0, 0), TextSize = s(14)}, C.surfaceHi, 0.6, C.textMuted)
corner(nextBtn, s(8))
local pageLbl = new("TextLabel", {Position = UDim2.fromOffset(s(94), 0), Size = UDim2.new(1, -s(188), 1, 0), BackgroundTransparency = 1, Text = "Loading…", Font = Enum.Font.GothamSemibold, TextSize = s(14), TextColor3 = C.textDim}, footer)

local rightP = new("Frame", {Position = UDim2.fromOffset(PAD + LW + GAP, TOPH), Size = UDim2.fromOffset(RW, BODY_H), BackgroundColor3 = C.panel, BackgroundTransparency = 0.5, BorderSizePixel = 0}, mf)
corner(rightP, s(14)); stroke(rightP, C.stroke, 1, 0.6)
local IP = s(10)
local innerW = RW - IP * 2
local VPH = s(200)

local masterViewport = new("ViewportFrame", {
	Position = UDim2.fromOffset(IP, IP), Size = UDim2.fromOffset(innerW, VPH), BackgroundColor3 = C.overlay, BackgroundTransparency = 0.15, BorderSizePixel = 0,
	Ambient = Color3.fromRGB(160, 160, 165), LightColor = WHITE, LightDirection = Vector3.new(-1, -1.5, -1), ClipsDescendants = true,
}, rightP)
corner(masterViewport, s(12)); stroke(masterViewport, C.stroke, 1, 0.5)
local hintLabel = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "Select a bundle\nto preview it here", Font = Enum.Font.GothamSemibold, TextSize = s(15), TextColor3 = C.textMuted, ZIndex = 3}, masterViewport)
local previewShimmer = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.surfaceHi, BackgroundTransparency = 0.5, BorderSizePixel = 0, Visible = false, ZIndex = 5}, masterViewport)
corner(previewShimmer, s(12)); applyShimmer(previewShimmer, C.overlay, C.surface)
local masterBadge = mkBadge(masterViewport, {Position = UDim2.fromOffset(s(10), s(10)), ZIndex = 6, Visible = false})
local statusChip = new("TextLabel", {
	Position = UDim2.fromOffset(s(10), VPH - s(34)), Size = UDim2.fromOffset(0, s(24)), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = C.overlay, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "NO BUNDLE", Font = Enum.Font.GothamBold, TextSize = s(13), TextColor3 = C.textMuted, ZIndex = 6,
}, masterViewport)
round(statusChip); pad(statusChip, s(12), s(12))

local yInfo = IP + VPH + s(10)
local nameLabel = new("TextLabel", {Position = UDim2.fromOffset(IP, yInfo), Size = UDim2.fromOffset(innerW - s(42), s(22)), BackgroundTransparency = 1, Text = "No bundle selected", Font = Enum.Font.GothamBold, TextSize = s(17), TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, rightP)
local creatorLabel = new("TextLabel", {Position = UDim2.fromOffset(IP, yInfo + s(24)), Size = UDim2.fromOffset(innerW - s(42), s(17)), BackgroundTransparency = 1, Text = "Pick one from the list", Font = Enum.Font.Gotham, TextSize = s(13), TextColor3 = C.textDim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, rightP)
local starBtn = mkBtn(rightP, {Text = "☆", Size = UDim2.fromOffset(s(38), s(38)), Position = UDim2.fromOffset(IP + innerW - s(38), yInfo), TextSize = s(22), Visible = false}, C.surface, 0.2, C.textDim)
corner(starBtn, s(9))

local ySlots = yInfo + s(48) + s(6)
local slotGrid = new("Frame", {Position = UDim2.fromOffset(IP, ySlots), Size = UDim2.fromOffset(innerW, s(66)), BackgroundTransparency = 1}, rightP)
local cellW = math.floor((innerW - s(6) * 3) / 4)
new("UIGridLayout", {CellSize = UDim2.fromOffset(cellW, s(30)), CellPadding = UDim2.fromOffset(s(6), s(6)), SortOrder = Enum.SortOrder.LayoutOrder}, slotGrid)
local slotButtons = {}
for i, slot in ipairs(buttonOrder) do
	local b = mkBtn(slotGrid, {Text = shortNames[slot], LayoutOrder = i, TextSize = s(14)}, C.surface, 0.5, C.textMuted)
	corner(b, s(8))
	slotButtons[slot] = b
end

local yAct = ySlots + s(66) + s(12)
local halfW = math.floor((innerW - s(10)) / 2)
local wearSelBtn = mkBtn(rightP, {Text = "Wear Selected", Size = UDim2.fromOffset(halfW, s(38)), Position = UDim2.fromOffset(IP, yAct), TextSize = s(14)}, C.surfaceHi, 0.55, C.textMuted)
corner(wearSelBtn, s(9))
local wearAllBtn = mkBtn(rightP, {Text = "Wear All", Size = UDim2.fromOffset(halfW, s(38)), Position = UDim2.fromOffset(IP + halfW + s(10), yAct), TextSize = s(14)}, C.surfaceHi, 0.55, C.textMuted)
corner(wearAllBtn, s(9))
local resetBtn = mkBtn(rightP, {Text = "Clear saved animations", Size = UDim2.fromOffset(innerW, s(30)), Position = UDim2.fromOffset(IP, yAct + s(38) + s(10)), TextSize = s(13), Font = Enum.Font.GothamSemibold}, C.surface, 0.6, C.textDim)
corner(resetBtn, s(8))

local toastLbl = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -s(18)), Size = UDim2.fromOffset(0, s(34)), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = C.panel, BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", Font = Enum.Font.GothamSemibold, TextSize = s(15),
	TextColor3 = C.text, TextTransparency = 1, Visible = false, ZIndex = 100,
}, mf)
round(toastLbl); pad(toastLbl, s(18), s(18))
local toastStroke = stroke(toastLbl, C.accent2, 1, 1)

local pill = mkBtn(g, {Text = "UGC", Size = UDim2.fromOffset(s(58), s(58)), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -s(50), 0, s(76)), TextSize = s(17), Font = Enum.Font.GothamBlack, Visible = false, Active = true}, C.surfaceHi, 0.1, C.text)
round(pill); stroke(pill, C.accent2, 1, 0.5)

local currentTab = "Discover"
local searchResults, savedTabList = {}, {}
local catalogCursor
local currentPageIndex = 1
local activeSpec
local activeBundle
local currentBundleItems = {}
local selectedSlot = "idleanimation"
local searchGen, masterGen, inspectGen = 0, 0, 0
local masterTrack, masterRig, masterAnimator
local cards, skeletons = {}, {}
local chipButtons, tagPills = {}, {}
local pagingBusy, wearBusy = false, false

local inspectBundle, playMaster, runSearch, refreshTags, drawGridPage, refreshSavedView

local toastGen = 0
toast = function(text, kind)
	toastGen = toastGen + 1
	local myGen = toastGen
	local col = (kind == "bad" and C.red) or (kind == "ok" and C.accent2) or C.accent2
	toastLbl.Text = text
	toastStroke.Color = col
	toastLbl.Visible = true
	toastLbl.Position = UDim2.new(0.5, 0, 1, -s(2))
	toastLbl.BackgroundTransparency, toastLbl.TextTransparency, toastStroke.Transparency = 1, 1, 1
	tw(toastLbl, 0.28, {Position = UDim2.new(0.5, 0, 1, -s(18)), BackgroundTransparency = 0.15, TextTransparency = 0}, Enum.EasingStyle.Back)
	tw(toastStroke, 0.28, {Transparency = 0.3})
	task.delay(2.4, function()
		if myGen ~= toastGen then return end
		tw(toastLbl, 0.3, {BackgroundTransparency = 1, TextTransparency = 1})
		tw(toastStroke, 0.3, {Transparency = 1})
		task.delay(0.32, function()
			if myGen == toastGen then toastLbl.Visible = false end
		end)
	end)
end

local spinning = {}
local spinAngle = 0
local spinConn
spinConn = rs.RenderStepped:Connect(function(dt)
	if not g.Parent then spinConn:Disconnect(); return end
	spinAngle = (spinAngle + math.rad(28) * dt) % (math.pi * 2)
	local cf = CFrame.Angles(0, spinAngle, 0)
	for model in pairs(spinning) do
		if model.Parent then model:PivotTo(cf) else spinning[model] = nil end
	end
end)
track(spinConn)

local function buildRig(vpFrame)
	local wm = vpFrame:FindFirstChildOfClass("WorldModel")
	if wm then wm:ClearAllChildren() else wm = new("WorldModel", {}, vpFrame) end
	local char = lp.Character or lp.CharacterAdded:Wait()
	local wasArch = char.Archivable
	char.Archivable = true
	local clone = char:Clone()
	char.Archivable = wasArch
	if not clone then return nil end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("Sound") then d:Destroy() end
	end
	local root = clone:FindFirstChild("HumanoidRootPart")
	local human = clone:FindFirstChildOfClass("Humanoid")
	if not root or not human then clone:Destroy(); return nil end
	root.Anchored = true
	pcall(function()
		human.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		human.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end)
	local animator = human:FindFirstChildOfClass("Animator") or new("Animator", {}, human)
	clone.Parent = wm
	clone:PivotTo(CFrame.new(0, 0, 0))
	local cam = vpFrame.CurrentCamera
	if not cam then
		cam = new("Camera", {}, vpFrame)
		vpFrame.CurrentCamera = cam
	end
	cam.FieldOfView = 50
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, 8), Vector3.new(0, -0.2, 0))
	spinning[clone] = true
	return clone, animator
end

local function tryPlayTrack(animator, animation, looped)
	local ok, pt = pcall(function()
		local tr = animator:LoadAnimation(animation)
		tr.Looped = looped
		tr:Play()
		return tr
	end)
	if not ok or not pt then return false, nil end
	task.wait(0.15)
	if not pt.IsPlaying then
		pcall(function() pt:Stop() end)
		return false, nil
	end
	return true, pt
end

local function setPreviewState(state, slot, n)
	local label = (slot and shortNames[slot]) and string.upper(shortNames[slot]) or ""
	if state == "empty" then
		statusChip.Text, statusChip.TextColor3 = "NO BUNDLE", C.textMuted
		previewShimmer.Visible = false
		hintLabel.Visible = true
	elseif state == "loading" then
		statusChip.Text, statusChip.TextColor3 = label .. "  ·  LOADING", C.textDim
		previewShimmer.Visible = true
	elseif state == "retry" then
		statusChip.Text, statusChip.TextColor3 = label .. "  ·  RETRY " .. tostring(n or 1), C.orange
		previewShimmer.Visible = true
	elseif state == "playing" then
		statusChip.Text, statusChip.TextColor3 = "•  " .. label, C.accent2
		previewShimmer.Visible = false
	elseif state == "missing" then
		statusChip.Text, statusChip.TextColor3 = "NO ANIMATIONS", C.orange
		previewShimmer.Visible = false
	else
		statusChip.Text, statusChip.TextColor3 = label .. "  ·  FAILED", C.red
		previewShimmer.Visible = false
	end
end

local function refreshSlotButtons()
	for slot, b in pairs(slotButtons) do
		local has = currentBundleItems[slot] ~= nil
		if has and slot == selectedSlot then setBtn(b, C.surfaceHi, 0, C.text)
		elseif has then setBtn(b, C.surface, 0.2, C.text)
		else setBtn(b, C.surface, 0.5, C.textMuted) end
	end
end

local function setActionsEnabled(on)
	if on then
		setBtn(wearSelBtn, C.surfaceHi, 0.15, C.text)
		setBtn(wearAllBtn, C.surfaceHi, 0.15, C.text)
	else
		setBtn(wearSelBtn, C.surfaceHi, 0.55, C.textMuted)
		setBtn(wearAllBtn, C.surfaceHi, 0.55, C.textMuted)
	end
end

local function refreshActiveInfo()
	if not activeBundle then
		nameLabel.Text = "No bundle selected"
		creatorLabel.Text = "Pick one from the list"
		masterBadge.Visible = false
		starBtn.Visible = false
		return
	end
	if activeBundle.IsPreset then
		nameLabel.Text = activeBundle.Name
		creatorLabel.Text = "Preset  ·  " .. tostring(activeBundle.Count or 0) .. ((activeBundle.Count or 0) == 1 and " slot" or " slots")
		masterBadge.Visible = false
		starBtn.Visible = false
		return
	end
	local key = tostring(activeBundle.Id)
	local meta = metaCache[key]
	nameLabel.Text = activeBundle.Name
	local parts = {}
	if meta and meta.creator then parts[#parts + 1] = "by " .. meta.creator end
	parts[#parts + 1] = "ID " .. key
	creatorLabel.Text = table.concat(parts, "  ·  ")
	masterBadge.Visible = true
	applyBadge(masterBadge, meta)
	starBtn.Visible = true
	local saved = savedBookmarks[key] ~= nil
	starBtn.Text = saved and "★" or "☆"
	starBtn.TextColor3 = saved and C.gold or C.textDim
end

onMetaChanged = function(key)
	local refs = badgeRefs[key]
	if refs then
		for i = #refs, 1, -1 do
			local lbl = refs[i]
			if lbl.Parent then applyBadge(lbl, metaCache[key]) else table.remove(refs, i) end
		end
	end
	if activeBundle and tostring(activeBundle.Id) == key then refreshActiveInfo() end
	local bm = savedBookmarks[key]
	local mt = metaCache[key]
	if bm and mt then
		bm.Kind, bm.Amount, bm.Creator = mt.kind, mt.amount, mt.creator
		queueSave(SAVED_BUNDLES_FILE, savedBookmarks)
	end
	if mt then
		local touched = false
		for _, h in ipairs(historyList) do
			if tostring(h.Id) == key then
				h.Kind, h.Amount, h.Creator = mt.kind, mt.amount, mt.creator
				touched = true
			end
		end
		if touched then queueSave(HISTORY_FILE, historyList) end
	end
end

local function updateSelection()
	for _, c in ipairs(cards) do
		if c.box.Parent then c.restore() end
	end
end

local function runMasterPlayback(myGen, payload, slot, tracks)
	local refetched = false
	local idx, fails = 1, 0
	while myGen == masterGen do
		local tr = tracks[idx]
		local ok, played = false, nil
		if tr then ok, played = tryPlayTrack(masterAnimator, tr, #tracks == 1) end
		if myGen ~= masterGen then
			if played then pcall(function() played:Stop(0) end) end
			return nil
		end
		if ok then
			fails = 0
			masterTrack = played
			setPreviewState("playing", slot)
			if #tracks == 1 then return true end
			played.Stopped:Wait()
			idx = idx % #tracks + 1
		else
			fails = fails + 1
			if fails >= 2 * math.max(#tracks, 1) then
				if refetched then return false end
				refetched, fails = true, 0
				clearAssetCache(payload.Id)
				task.wait(0.4)
				if myGen ~= masterGen then return nil end
				tracks = getTracksFor(payload, slot)
				idx = 1
				if #tracks == 0 then return false end
			else
				idx = idx % math.max(#tracks, 1) + 1
				task.wait(0.3)
			end
		end
	end
	return nil
end

playMaster = function(slot)
	local payload = currentBundleItems[slot]
	if not payload then return end
	masterGen = masterGen + 1
	local myGen = masterGen
	if masterTrack then pcall(function() masterTrack:Stop(0.1) end); masterTrack = nil end
	setPreviewState("loading", slot)
	task.spawn(function()
		if not masterAnimator or not masterRig or not masterRig.Parent then
			masterRig, masterAnimator = buildRig(masterViewport)
		end
		if myGen ~= masterGen then return end
		if not masterAnimator then setPreviewState("failed", slot); return end
		local tracks = {}
		for attempt = 0, 4 do
			tracks = getTracksFor(payload, slot)
			if #tracks > 0 then break end
			if myGen ~= masterGen then return end
			setPreviewState("retry", slot, attempt + 1)
			clearAssetCache(payload.Id)
			task.wait(math.min(0.5 + attempt * 0.3, 2.5))
			if myGen ~= masterGen then return end
		end
		if myGen ~= masterGen then return end
		if #tracks == 0 then setPreviewState("failed", slot); return end
		local result = runMasterPlayback(myGen, payload, slot, tracks)
		if result == false and myGen == masterGen then setPreviewState("failed", slot) end
	end)
end

inspectBundle = function(entry)
	activeBundle = {Id = entry.Id, Name = entry.Name or "Unknown"}
	inspectGen = inspectGen + 1
	local myInspect = inspectGen
	masterGen = masterGen + 1
	if masterTrack then pcall(function() masterTrack:Stop(0.1) end); masterTrack = nil end
	table.clear(currentBundleItems)
	hintLabel.Visible = false
	seedMeta(entry)
	ensureMeta(entry.Id, true)
	refreshActiveInfo()
	refreshSlotButtons()
	setActionsEnabled(false)
	setPreviewState("loading", selectedSlot)
	updateSelection()
	task.spawn(function()
		local details = getDetails(entry.Id)
		if myInspect ~= inspectGen then return end
		if not details then setPreviewState("failed", selectedSlot); return end
		for k, v in pairs(mapBundleItems(details.Items)) do currentBundleItems[k] = v end
		local slot = currentBundleItems[selectedSlot] and selectedSlot or nil
		if not slot then
			for _, name in ipairs(buttonOrder) do
				if currentBundleItems[name] then slot = name; break end
			end
		end
		if not slot then
			refreshSlotButtons()
			setPreviewState("missing", selectedSlot)
			return
		end
		selectedSlot = slot
		refreshSlotButtons()
		setActionsEnabled(true)
		masterRig, masterAnimator = nil, nil
		playMaster(slot)
	end)
end

for _, slot in ipairs(buttonOrder) do
	slotButtons[slot].MouseButton1Click:Connect(function()
		if not activeBundle or not currentBundleItems[slot] then return end
		selectedSlot = slot
		refreshSlotButtons()
		playMaster(slot)
	end)
end

wearSelBtn.MouseButton1Click:Connect(function()
	if not activeBundle or wearBusy then return end
	local payload = currentBundleItems[selectedSlot]
	if not payload then return end
	if not lp.Character then toast("No character found", "bad"); return end
	wearBusy = true
	wearSelBtn.Text = "Equipping…"
	local slot = selectedSlot
	task.spawn(function()
		local list = getTracksFor(payload, slot)
		if #list > 0 then
			preloadAnimations(list)
			local n = equipMap(lp.Character, {[slot] = list}, true)
			if n > 0 and activeBundle and not activeBundle.IsPreset then recordHistory(activeBundle.Id, activeBundle.Name) end
			toast(n > 0 and ("Equipped " .. shortNames[slot]) or "Couldn't equip that slot", n > 0 and "ok" or "bad")
		else
			toast("Animation failed to load", "bad")
		end
		wearSelBtn.Text = "Wear Selected"
		wearBusy = false
	end)
end)

wearAllBtn.MouseButton1Click:Connect(function()
	if not activeBundle or wearBusy or next(currentBundleItems) == nil then return end
	if not lp.Character then toast("No character found", "bad"); return end
	wearBusy = true
	wearAllBtn.Text = "Equipping…"
	task.spawn(function()
		local n = applyBundleItemsToCharacter(currentBundleItems)
		if n > 0 and activeBundle and not activeBundle.IsPreset then recordHistory(activeBundle.Id, activeBundle.Name) end
		toast(n > 0 and ("Equipped " .. n .. " animations") or "Nothing could be equipped", n > 0 and "ok" or "bad")
		wearAllBtn.Text = "Wear All"
		wearBusy = false
	end)
end)

resetBtn.MouseButton1Click:Connect(function()
	for k in pairs(equippedAnims) do equippedAnims[k] = nil end
	saveJSON(EQUIPPED_FILE, equippedAnims)
	toast("Saved animations cleared. Respawn to restore defaults")
end)

local function toggleBookmark(id, name)
	local key = tostring(id)
	local nowSaved
	if savedBookmarks[key] then
		savedBookmarks[key] = nil
		nowSaved = false
	else
		local mt = metaCache[key] or {}
		savedBookmarks[key] = {Id = id, Name = name, Fav = false, Time = tick(), Kind = mt.kind, Amount = mt.amount, Creator = mt.creator}
		nowSaved = true
		ensureMeta(id, true)
		captureBundleData(id)
	end
	saveJSON(SAVED_BUNDLES_FILE, savedBookmarks)
	for _, c in ipairs(cards) do
		if c.key == key then c.refreshSave() end
	end
	if activeBundle and tostring(activeBundle.Id) == key then refreshActiveInfo() end
	if currentTab == "Saved" and not nowSaved and refreshSavedView then refreshSavedView() end
	toast(nowSaved and "Saved to your list" or "Removed from saved", nowSaved and "ok" or nil)
	return nowSaved
end

starBtn.MouseButton1Click:Connect(function()
	if activeBundle then toggleBookmark(activeBundle.Id, activeBundle.Name) end
end)

local function clearSkeletons()
	for _, f in ipairs(skeletons) do stopShimmer(f); f:Destroy() end
	table.clear(skeletons)
end

local function clearGrid()
	for _, c in ipairs(cards) do
		if c.skeleton then stopShimmer(c.skeleton) end
		c.box:Destroy()
	end
	table.clear(cards)
end

local function showSkeletons()
	clearGrid()
	clearSkeletons()
	gridMsg.Visible = false
	for i = 1, PER_PAGE do
		local f = new("Frame", {BackgroundColor3 = C.surface, BackgroundTransparency = 0.35, BorderSizePixel = 0, Size = UDim2.fromOffset(CW, CH), LayoutOrder = i}, gridHolder)
		corner(f, s(12))
		applyShimmer(f, C.panel, C.surfaceHi)
		skeletons[#skeletons + 1] = f
	end
end

local function showGridMessage(msg)
	clearGrid()
	clearSkeletons()
	gridMsg.Text = msg
	gridMsg.Visible = true
end

local function updatePager(total)
	local pages = math.max(1, math.ceil(total / PER_PAGE))
	local more = (currentTab == "Discover" and catalogCursor ~= nil and not catalogCursor.IsFinished) and true or false
	pageLbl.Text = "Page " .. currentPageIndex .. " / " .. pages .. (more and "+" or "") .. "  ·  " .. total .. (more and "+" or "") .. " results"
	local canPrev = currentPageIndex > 1
	local canNext = currentPageIndex < pages or more
	setBtn(prevBtn, C.surfaceHi, canPrev and 0.3 or 0.7, canPrev and C.text or C.textMuted)
	setBtn(nextBtn, C.surfaceHi, canNext and 0.3 or 0.7, canNext and C.text or C.textMuted)
end

local cardOrder = 0
local function buildCard(entry, idx)
	local id = entry.Id
	local key = tostring(id)
	seedMeta(entry)
	ensureMeta(id, false)

	cardOrder += 1

	local box = new("ViewportFrame", {
		Name = "Card", BackgroundColor3 = C.panel, BackgroundTransparency = 0.25, BorderSizePixel = 0, ClipsDescendants = true,
		Size = UDim2.fromOffset(CW, CH),
		LayoutOrder = cardOrder,
		Ambient = Color3.fromRGB(160, 160, 165), LightColor = WHITE, LightDirection = Vector3.new(-1, -1.5, -1),
	}, gridHolder)
	corner(box, s(12))
	local boxStroke = stroke(box, C.stroke, 1, 0.5)

	local boxScale = new("UIScale", {Scale = 0.86}, box)
	tw(boxScale, 0.3 + idx * 0.05, {Scale = 1}, Enum.EasingStyle.Back)

	local skeleton = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.surface, BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 2}, box)
	corner(skeleton, s(12)); applyShimmer(skeleton, C.panel, C.surfaceHi)

	local cpad = s(6)
	new("TextLabel", {
		Position = UDim2.fromOffset(cpad + s(2), CH - AH - cpad - s(22)), Size = UDim2.fromOffset(CW - cpad * 2 - s(4), s(20)), BackgroundTransparency = 1,
		Text = entry.Name or "Unknown", Font = Enum.Font.GothamBold, TextSize = s(15), TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
	}, box)

	local badge = mkBadge(box, {Position = UDim2.fromOffset(cpad, cpad), ZIndex = 5})
	bindBadge(badge, id)

	local hit = new("TextButton", {Size = UDim2.new(1, 0, 1, -(AH + s(12))), BackgroundTransparency = 1, Text = "", ZIndex = 5}, box)

	local cardActions = new("Frame", {Position = UDim2.fromOffset(cpad, CH - AH - cpad), Size = UDim2.fromOffset(CW - cpad * 2, AH), BackgroundTransparency = 1, ZIndex = 6}, box)
	local saveBtn = mkBtn(cardActions, {Text = "+ Save", Size = UDim2.new(0.5, -s(3), 1, 0), TextSize = s(12), ZIndex = 6}, C.surfaceHi, 0.25, C.textDim)
	corner(saveBtn, s(6))
	local wearBtn = mkBtn(cardActions, {Text = "▶ Wear", Size = UDim2.new(0.5, -s(3), 1, 0), Position = UDim2.new(0.5, s(3), 0, 0), TextSize = s(12), ZIndex = 6}, C.surfaceHi, 0.15, C.text)
	corner(wearBtn, s(6))

	local function refreshSave()
		local saved = savedBookmarks[key] ~= nil
		saveBtn.Text = saved and "✓ Saved" or "+ Save"
		saveBtn.TextColor3 = saved and C.gold or C.textDim
	end
	refreshSave()

	if currentTab == "Saved" then
		local favBtn = mkBtn(box, {Text = (entry.Fav and "★" or "☆"), Size = UDim2.fromOffset(s(28), s(28)), Position = UDim2.new(1, -s(32), 0, s(4)), TextSize = s(18), ZIndex = 7}, C.overlay, 0.4, entry.Fav and C.gold or C.textDim)
		round(favBtn)
		favBtn.MouseButton1Click:Connect(function()
			local bm = savedBookmarks[key]
			if bm then
				bm.Fav = not bm.Fav
				saveJSON(SAVED_BUNDLES_FILE, savedBookmarks)
				favBtn.Text = bm.Fav and "★" or "☆"
				favBtn.TextColor3 = bm.Fav and C.gold or C.textDim
			end
		end)
	end

	local record = {key = key, box = box, skeleton = skeleton, refreshSave = refreshSave}
	record.restore = function()
		local selected = activeBundle ~= nil and tostring(activeBundle.Id) == key
		boxStroke.Color = selected and C.accent2 or C.stroke
		boxStroke.Thickness = selected and 2 or 1
		boxStroke.Transparency = selected and 0 or 0.5
	end
	cards[#cards + 1] = record
	record.restore()

	hit.MouseEnter:Connect(function()
		tw(box, 0.12, {BackgroundColor3 = C.surface})
		boxStroke.Color = C.accent2
		boxStroke.Transparency = 0
	end)
	hit.MouseLeave:Connect(function()
		tw(box, 0.15, {BackgroundColor3 = C.panel})
		record.restore()
	end)
	hit.MouseButton1Click:Connect(function() inspectBundle(entry) end)

	saveBtn.MouseButton1Click:Connect(function() toggleBookmark(id, entry.Name) end)
	wearBtn.MouseButton1Click:Connect(function()
		wearBtn.Text = "…"
		wearBundle(id, entry.Name, function()
			if wearBtn.Parent then wearBtn.Text = "▶ Wear" end
		end)
	end)

	task.spawn(function()
		task.wait(0.14 * idx)
		if not box.Parent then return end
		local function dropSkeleton()
			if skeleton.Parent then
				tw(skeleton, 0.25, {BackgroundTransparency = 1})
				task.delay(0.3, function()
					stopShimmer(skeleton)
					skeleton:Destroy()
				end)
			end
		end
		local details = getDetails(id)
		if not box.Parent then return end
		if not details then dropSkeleton(); return end
		local map = mapBundleItems(details.Items)
		local usable = {}
		for _, slot in ipairs(CARD_ORDER) do
			if map[slot] and #usable < 4 then usable[#usable + 1] = {slot = slot, payload = map[slot]} end
		end
		if #usable == 0 then dropSkeleton(); return end
		local rig, animator = buildRig(box)
		if not rig or not box.Parent then dropSkeleton(); return end
		local i, current = 1, nil
		while box.Parent do
			local u = usable[i]
			local list = getTracksFor(u.payload, u.slot)
			if #list > 0 then
				if current then pcall(function() current:Stop(0.1) end); current = nil end
				local ok, played = tryPlayTrack(animator, list[1], #list == 1)
				if ok then current = played; dropSkeleton() end
			end
			task.wait(2.6)
			i = i % #usable + 1
		end
		if current then pcall(function() current:Stop(0) end) end
	end)
end

drawGridPage = function(dataList)
	clearGrid()
	clearSkeletons()
	gridMsg.Visible = false

	if not dataList or #dataList == 0 then
		showGridMessage(currentTab == "Saved" and "No saved bundles match" or (currentTab == "Recent" and "No recently used bundles yet" or "No results"))
		updatePager(0)
		return
	end

	local start = (currentPageIndex - 1) * PER_PAGE + 1
	local ending = math.min(currentPageIndex * PER_PAGE, #dataList)
	if start > #dataList then
		currentPageIndex = 1
		start = 1
		ending = math.min(PER_PAGE, #dataList)
	end
	local idx = 1
	for i = start, ending do
		local entry = dataList[i]
		if not entry then break end
		buildCard(entry, idx)
		idx += 1
	end
	updatePager(#dataList)
end

refreshTags = function(q, spec)
	for _, p in ipairs(tagPills) do p:Destroy() end
	table.clear(tagPills)

	local issueSet = {}
	for _, issue in ipairs(spec.issues or {}) do issueSet[issue] = true end

	local any = false
	for _, tg in ipairs(q.tags) do
		any = true
		local txt = tg.key .. ":" .. tg.val
		local bad = issueSet[txt] == true
		local pillBtn = mkBtn(tagsRow, {
			Text = txt, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, TAG_H),
			TextSize = s(14), LayoutOrder = #tagPills + 1,
		}, bad and C.badBg or C.pillBg, 0.25, bad and C.badTx or C.pillTx)
		corner(pillBtn, math.floor(TAG_H / 2))
		pad(pillBtn, s(15), s(15))
		table.insert(tagPills, pillBtn)

		pillBtn.MouseButton1Click:Connect(function()
			local newTags = {}
			for _, t in ipairs(q.tags) do
				if not (t.key == tg.key and t.val == tg.val) then newTags[#newTags + 1] = t end
			end
			local parts = {}
			if q.keyword ~= "" then parts[#parts + 1] = q.keyword end
			for _, t in ipairs(newTags) do
				local v = t.val
				if v:find("%s") then v = '"' .. v .. '"' end
				parts[#parts + 1] = t.key .. ":" .. v
			end
			local newText = table.concat(parts, " ")
			sb.Text = newText
			if runSearch then runSearch(newText) end
		end)
	end
	tagHint.Visible = not any

	for tabName, set in pairs(chipButtons) do
		for tag, b in pairs(set) do
			local shown = (tabName == currentTab)
			b.Visible = shown
			if shown then
				local active = false
				for _, t in ipairs(q.tags) do
					if (t.key .. ":" .. t.val) == tag then active = true; break end
				end
				if active then setBtn(b, C.surfaceHi, 0.1, C.text)
				else setBtn(b, C.surface, 0.35, C.textDim) end
			end
		end
	end
end

local CHIP_SETS = {
	Discover = {
		{label = "Free",     tag = "price:free"},
		{label = "Newest",   tag = "sort:newest"},
		{label = "Popular",  tag = "sort:mostfavorited"},
		{label = "Cheapest", tag = "sort:pricelowtohigh"},
		{label = "Featured", tag = "category:featured"},
		{label = "Sale",     tag = "sale:on"},
	},
	Saved = {
		{label = "Favorites", tag = "is:favorite"},
		{label = "Newest",    tag = "sort:newest"},
		{label = "Oldest",    tag = "sort:oldest"},
		{label = "A–Z",       tag = "sort:name"},
		{label = "Free",      tag = "is:free"},
		{label = "Cheapest",  tag = "sort:pricelowtohigh"},
		{label = "Offsale",   tag = "is:offsale"},
	},
	Presets = {
		{label = "Newest", tag = "sort:newest"},
		{label = "Oldest", tag = "sort:oldest"},
		{label = "A–Z",    tag = "sort:name"},
	},
	Recent = {
		{label = "Newest",   tag = "sort:newest"},
		{label = "Oldest",   tag = "sort:oldest"},
		{label = "A–Z",      tag = "sort:name"},
		{label = "Free",     tag = "is:free"},
		{label = "Paid",     tag = "is:paid"},
		{label = "Cheapest", tag = "sort:pricelowtohigh"},
	},
}
for tabName, set in pairs(CHIP_SETS) do
	chipButtons[tabName] = {}
	for i, c in ipairs(set) do
		local b = mkBtn(chipsRow, {
			Text = c.label, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, CHIP_H),
			TextSize = s(13), LayoutOrder = i, Visible = (tabName == "Discover"),
		}, C.surface, 0.35, C.textDim)
		corner(b, math.floor(CHIP_H / 2))
		pad(b, s(14), s(14))
		chipButtons[tabName][c.tag] = b

		b.MouseButton1Click:Connect(function()
			local q = parseQuery(sb.Text)
			local found = false
			for j = #q.tags, 1, -1 do
				local tg = q.tags[j]
				if (tg.key .. ":" .. tg.val) == c.tag then table.remove(q.tags, j); found = true; break end
			end
			if not found then
				local k, v = c.tag:match("^(%a+):(.+)$")
				if k then
					for j = #q.tags, 1, -1 do
						if q.tags[j].key == k then table.remove(q.tags, j) end
					end
					q.tags[#q.tags + 1] = {key = k, val = v}
				end
			end
			local newText = buildQuery(q)
			sb.Text = newText
			if runSearch then runSearch(newText) end
		end)
	end
end

-- Suggestion values now use underscores for the sort prices
local applySuggestionRef
local TAG_VALUES = {
	sort = {"relevance", "newest", "mostfavorited", "bestselling", "price_low_to_high", "price_high_to_low"},
	price_min = {"50", "100", "500", "1000"},
	price_max = {"100", "300", "500", "1000"},
	price = {"free", "0-100", "100-500"},
	creator = {"Roblox"},
	sale = {"on", "all"},
	category = {"featured", "collectibles", "community", "premium", "recommended"},
	sales = {"collectibles", "premium", "all"},
	period = {"day", "week", "month", "alltime"},
	limit = {"10", "28", "30", "60", "120"},
	is = {"favorite", "free", "paid", "offsale"},
	has = {"idle", "walk", "run", "jump", "fall", "climb", "swim"},
}
local SORT_SAVED_VALUES = {"newest", "oldest", "name", "price_low_to_high", "price_high_to_low", "favorites"}
local SORT_RECENT_VALUES = {"newest", "oldest", "name"}
local KEYS_DISCOVER = {"sort", "price", "price_min", "price_max", "creator", "sale", "category", "sales", "period", "limit"}
local KEYS_SAVED = {"sort", "price", "price_min", "price_max", "creator", "is", "has"}
local KEYS_PRESETS = {"sort"}
local KEYS_RECENT = {"sort", "price", "price_min", "price_max", "creator", "is", "has"}

local suggestStrip = new("Frame", {
	Name = "Suggest", Position = UDim2.fromOffset(PAD, TOPH - s(34)), Size = UDim2.fromOffset(LW, s(30)),
	BackgroundColor3 = C.overlay, BackgroundTransparency = 0.08, BorderSizePixel = 0, Visible = false, ZIndex = 60,
}, mf)
corner(suggestStrip, s(10)); stroke(suggestStrip, C.stroke, 1, 0.4)
local suggestRow = new("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 61,
}, suggestStrip)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, s(5)), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center}, suggestRow)
pad(suggestRow, s(5), s(5), 0, 0)

local currentSuggestions = {}

local function getSuggestions()
	local text = sb.Text
	local token = text:match("(%S*)$") or ""
	local before = text:sub(1, #text - #token)
	local lower = token:lower()
	local out = {}

	local key, valPrefix = lower:match("^([%a_]+):(.*)$")
	local origKey = key
	if key then key = KEY_ALIASES[key] or key end
	if key and VALID_KEYS[key] then
		local vals
		if key == "sort" then
			vals = (currentTab == "Discover" and TAG_VALUES.sort) or (currentTab == "Saved" and SORT_SAVED_VALUES) or SORT_RECENT_VALUES
		elseif key == "is" and currentTab == "Recent" then
			vals = {"free", "paid", "offsale"}
		else
			vals = TAG_VALUES[key]
		end
		local normPrefix = ((valPrefix or ""):gsub("_", ""))
		for _, v in ipairs(vals or {}) do
			local normVal = (v:lower():gsub("_", ""))
			if normVal:find(normPrefix, 1, true) == 1 and normVal ~= normPrefix then
				out[#out + 1] = {label = origKey .. ":" .. v, apply = before .. origKey .. ":" .. v .. " ", run = true}
			end
		end
		return out
	end

	local used = {}
	for _, tg in ipairs(parseQuery(text).tags) do used[tg.key] = true end
	local keys = (currentTab == "Discover" and KEYS_DISCOVER) or (currentTab == "Saved" and KEYS_SAVED) or (currentTab == "Presets" and KEYS_PRESETS) or KEYS_RECENT
	for _, k in ipairs(keys) do
		local ak = KEY_ALIASES[k] or k
		if not used[ak] and (lower == "" or k:find(lower, 1, true) == 1) and (k .. ":") ~= lower then
			out[#out + 1] = {label = k .. ":", apply = before .. k .. ":", run = false}
		end
	end

	if #lower >= 2 then
		local seen, count = {}, 0
		local function consider(name)
			if count >= 4 or type(name) ~= "string" then return end
			local ln = name:lower()
			if seen[ln] or ln == lower or not ln:find(lower, 1, true) then return end
			seen[ln] = true
			count += 1
			out[#out + 1] = {label = name, apply = before .. name .. " ", run = true}
		end
		if currentTab == "Presets" then
			for _, v in ipairs(presetList) do consider(v.Name) end
		else
			for _, v in ipairs(historyList) do consider(v.Name) end
			for _, v in pairs(savedBookmarks) do if type(v) == "table" then consider(v.Name) end end
			for _, v in ipairs(searchResults) do consider(v.Name) end
		end
	end

	while #out > 8 do table.remove(out) end
	return out
end

-- Suggestions always show (when the textbox has text), not just on focus
local function refreshSuggestions()
	for _, c in ipairs(suggestRow:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	if sb.Text == "" then suggestStrip.Visible = false; return end
	currentSuggestions = getSuggestions()
	if #currentSuggestions == 0 then suggestStrip.Visible = false; return end
	new("TextLabel", {
		Text = "Tab ⇥", LayoutOrder = 0, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, s(22)),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = s(12), TextColor3 = C.textMuted, ZIndex = 62,
	}, suggestRow)
	for i, sg in ipairs(currentSuggestions) do
		local b = mkBtn(suggestRow, {
			Text = sg.label, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, s(22)),
			TextSize = s(13), LayoutOrder = i, ZIndex = 62,
		}, i == 1 and C.surfaceHi or C.surface, i == 1 and 0 or 0.2, i == 1 and C.text or C.textDim)
		corner(b, s(11)); pad(b, s(10), s(10))
		b.MouseButton1Down:Connect(function() applySuggestionRef(sg) end)
	end
	suggestStrip.Visible = true
end

applySuggestionRef = function(sg)
	sb.Text = sg.apply
	if sg.run and runSearch then runSearch(sg.apply) end
	refreshSuggestions()
	task.delay(0.05, function()
		pcall(function()
			sb:CaptureFocus()
			sb.CursorPosition = #sb.Text + 1
		end)
	end)
end

sb:GetPropertyChangedSignal("Text"):Connect(refreshSuggestions)

track(uis.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Tab and suggestStrip.Visible and currentSuggestions[1] then
		applySuggestionRef(currentSuggestions[1])
	end
end))

local renderPresets, presetPanel, presetEmpty, saveCurrentBtn, hideConfirm, confirmOverlay
do
	local ROW_H = s(54)
	local focusNameId
	local pendingDelete

	presetPanel = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, GRID_Y), Size = UDim2.fromOffset(LW, GRID_H), BackgroundColor3 = C.panel, BackgroundTransparency = 0.55,
		BorderSizePixel = 0, ScrollBarThickness = s(3), ScrollBarImageColor3 = C.surfaceHi, CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false, ClipsDescendants = true, ZIndex = 2,
	}, left)
	corner(presetPanel, s(12)); stroke(presetPanel, C.stroke, 1, 0.7)
	new("UIListLayout", {Padding = UDim.new(0, s(6)), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center}, presetPanel)
	pad(presetPanel, s(8), s(8), s(8), s(8))

	presetEmpty = new("TextLabel", {
		Position = UDim2.fromOffset(0, GRID_Y), Size = UDim2.fromOffset(LW, GRID_H), BackgroundTransparency = 1, Text = "",
		Font = Enum.Font.GothamSemibold, TextSize = s(15), TextColor3 = C.textMuted, TextWrapped = true, Visible = false, ZIndex = 4,
	}, left)

	saveCurrentBtn = mkBtn(chipsRow, {
		Text = "+ Save current", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, CHIP_H),
		TextSize = s(13), LayoutOrder = 0, Visible = false,
	}, C.surfaceHi, 0.15, C.text)
	corner(saveCurrentBtn, math.floor(CHIP_H / 2)); pad(saveCurrentBtn, s(14), s(14))

	confirmOverlay = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.overlay, BackgroundTransparency = 0.35, BorderSizePixel = 0, Text = "",
		AutoButtonColor = false, Visible = false, Active = true, ZIndex = 90,
	}, mf)
	local DW, DH = s(300), s(152)
	local dlg = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(DW, DH),
		BackgroundColor3 = C.panel, BorderSizePixel = 0, Active = true, ZIndex = 91,
	}, confirmOverlay)
	corner(dlg, s(14)); stroke(dlg, C.stroke, 1, 0.2)
	local dlgScale = new("UIScale", {Scale = 1}, dlg)
	new("TextLabel", {
		Position = UDim2.fromOffset(s(16), s(14)), Size = UDim2.fromOffset(DW - s(32), s(22)), BackgroundTransparency = 1,
		Text = "Delete preset?", Font = Enum.Font.GothamBlack, TextSize = s(18), TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 92,
	}, dlg)
	local confirmMsg = new("TextLabel", {
		Position = UDim2.fromOffset(s(16), s(42)), Size = UDim2.fromOffset(DW - s(32), s(50)), BackgroundTransparency = 1,
		Text = "", Font = Enum.Font.Gotham, TextSize = s(14), TextColor3 = C.textDim, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 92,
	}, dlg)
	local btnW = math.floor((DW - s(32) - s(10)) / 2)
	local cancelBtn = mkBtn(dlg, {Text = "Cancel", Size = UDim2.fromOffset(btnW, s(36)), Position = UDim2.fromOffset(s(16), DH - s(16) - s(36)), TextSize = s(14), ZIndex = 92}, C.surfaceHi, 0.1, C.text)
	corner(cancelBtn, s(9))
	local deleteBtn = mkBtn(dlg, {Text = "Delete", Size = UDim2.fromOffset(btnW, s(36)), Position = UDim2.fromOffset(s(16) + btnW + s(10), DH - s(16) - s(36)), TextSize = s(14), ZIndex = 92}, Color3.fromRGB(160, 84, 84), 0, WHITE)
	corner(deleteBtn, s(9))

	hideConfirm = function()
		pendingDelete = nil
		confirmOverlay.Visible = false
	end
	local function showConfirm(p)
		pendingDelete = p
		confirmMsg.Text = 'Do you want to delete this preset?\n"' .. tostring(p.Name) .. '"'
		confirmOverlay.BackgroundTransparency = 1
		confirmOverlay.Visible = true
		dlgScale.Scale = 0.9
		tw(confirmOverlay, 0.15, {BackgroundTransparency = 0.35})
		tw(dlgScale, 0.22, {Scale = 1}, Enum.EasingStyle.Back)
	end
	cancelBtn.MouseButton1Click:Connect(hideConfirm)
	confirmOverlay.MouseButton1Click:Connect(hideConfirm)
	deleteBtn.MouseButton1Click:Connect(function()
		local p = pendingDelete
		hideConfirm()
		if not p then return end
		for i = #presetList, 1, -1 do
			if presetList[i] == p then table.remove(presetList, i) end
		end
		saveJSON(PRESETS_FILE, presetList)
		renderPresets(activeSpec or {})
		toast("Preset deleted")
	end)

	local function snapshotEquipped()
		local anims, any = {}, false
		for slot, list in pairs(equippedAnims) do
			if type(list) == "table" and #list > 0 then
				local copy = {}
				for _, a in ipairs(list) do copy[#copy + 1] = {Name = a.Name, AnimationId = a.AnimationId} end
				anims[slot] = copy
				any = true
			end
		end
		return anims, any
	end

	local function nextPresetName()
		local maxN = 0
		for _, p in ipairs(presetList) do
			local n = tonumber(string.match(p.Name or "", "^[Pp]reset (%d+)$"))
			if n and n > maxN then maxN = n end
		end
		return "Preset " .. (maxN + 1)
	end

	local function summary(p)
		local names, n = {}, 0
		for _, slot in ipairs(buttonOrder) do
			local l = p.Anims and p.Anims[slot]
			if type(l) == "table" and #l > 0 then
				n += 1
				names[#names + 1] = shortNames[slot]
			end
		end
		return n .. (n == 1 and " slot" or " slots") .. "  ·  " .. table.concat(names, " · ")
	end

	local function inspectPreset(p)
		local count = 0
		for _ in pairs(p.Anims or {}) do count += 1 end
		activeBundle = {Id = "preset:" .. tostring(p.Id), Name = p.Name, IsPreset = true, Count = count}
		inspectGen = inspectGen + 1
		masterGen = masterGen + 1
		if masterTrack then pcall(function() masterTrack:Stop(0.1) end); masterTrack = nil end
		table.clear(currentBundleItems)
		hintLabel.Visible = false
		for slot, list in pairs(p.Anims or {}) do
			if type(list) == "table" and #list > 0 then
				currentBundleItems[slot] = {Id = "preset:" .. tostring(p.Id) .. "/" .. slot, Name = p.Name, AssetType = slot, Direct = list}
			end
		end
		refreshActiveInfo()
		updateSelection()
		local slot = currentBundleItems[selectedSlot] and selectedSlot or nil
		if not slot then
			for _, name in ipairs(buttonOrder) do
				if currentBundleItems[name] then slot = name; break end
			end
		end
		if not slot then
			refreshSlotButtons()
			setActionsEnabled(false)
			setPreviewState("missing", selectedSlot)
			return
		end
		selectedSlot = slot
		refreshSlotButtons()
		setActionsEnabled(true)
		masterRig, masterAnimator = nil, nil
		playMaster(slot)
	end

	local function buildRow(p, order)
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, ROW_H), BackgroundColor3 = C.surface, BackgroundTransparency = 0.3, BorderSizePixel = 0, LayoutOrder = order,
		}, presetPanel)
		corner(row, s(10)); stroke(row, C.stroke, 1, 0.6)
		local rowHit = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 2}, row)

		local prevW, wearW, renW, delW, g4 = s(56), s(44), s(60), s(52), s(4)
		local blockW = prevW + wearW + renW + delW + g4 * 3 + s(8)
		local yb = math.floor((ROW_H - s(30)) / 2)

		local nameBox = new("TextBox", {
			Position = UDim2.fromOffset(s(8), s(6)), Size = UDim2.new(1, -(blockW + s(14)), 0, s(22)), BackgroundColor3 = C.overlay, BackgroundTransparency = 1,
			BorderSizePixel = 0, Text = p.Name, ClearTextOnFocus = false, Font = Enum.Font.GothamBold, TextSize = s(15), TextColor3 = C.text,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ClipsDescendants = true, ZIndex = 3,
		}, row)
		corner(nameBox, s(6)); pad(nameBox, s(4), s(4))
		new("TextLabel", {
			Position = UDim2.fromOffset(s(12), s(30)), Size = UDim2.new(1, -(blockW + s(20)), 0, s(16)), BackgroundTransparency = 1,
			Text = summary(p), Font = Enum.Font.Gotham, TextSize = s(12), TextColor3 = C.textDim, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
		}, row)

		nameBox.Focused:Connect(function()
			tw(nameBox, 0.12, {BackgroundTransparency = 0.25})
		end)
		nameBox.FocusLost:Connect(function()
			tw(nameBox, 0.12, {BackgroundTransparency = 1})
			local newName = nameBox.Text
			newName = newName:gsub("^%s+", "")
			newName = newName:gsub("%s+$", "")
			newName = newName:sub(1, 24)
			if newName == "" then
				nameBox.Text = p.Name
			elseif newName ~= p.Name then
				p.Name = newName
				nameBox.Text = newName
				if activeBundle and activeBundle.IsPreset and activeBundle.Id == "preset:" .. tostring(p.Id) then
					activeBundle.Name = newName
					refreshActiveInfo()
				end
				saveJSON(PRESETS_FILE, presetList)
				toast("Renamed to " .. newName, "ok")
			else
				nameBox.Text = newName
			end
		end)

		local delBtn = mkBtn(row, {Text = "Delete", Size = UDim2.fromOffset(delW, s(30)), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -s(8), 0, yb), TextSize = s(12), ZIndex = 3}, C.badBg, 0.1, C.badTx)
		corner(delBtn, s(8))
		local renBtn = mkBtn(row, {Text = "Rename", Size = UDim2.fromOffset(renW, s(30)), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -(s(8) + delW + g4), 0, yb), TextSize = s(12), ZIndex = 3}, C.surfaceHi, 0.2, C.text)
		corner(renBtn, s(8))
		local wearBtn = mkBtn(row, {Text = "Wear", Size = UDim2.fromOffset(wearW, s(30)), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -(s(8) + delW + renW + g4 * 2), 0, yb), TextSize = s(12), ZIndex = 3}, C.surfaceHi, 0.1, C.text)
		corner(wearBtn, s(8))
		local previewBtn = mkBtn(row, {Text = "Preview", Size = UDim2.fromOffset(prevW, s(30)), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -(s(8) + delW + renW + wearW + g4 * 3), 0, yb), TextSize = s(12), ZIndex = 3}, C.surfaceHi, 0.1, C.text)
		corner(previewBtn, s(8))
		previewBtn.MouseButton1Click:Connect(function() inspectPreset(p) end)
		rowHit.MouseButton1Click:Connect(function() inspectPreset(p) end)

		renBtn.MouseButton1Click:Connect(function()
			task.delay(0.03, function()
				pcall(function()
					nameBox:CaptureFocus()
					nameBox.SelectionStart = 1
					nameBox.CursorPosition = #nameBox.Text + 1
				end)
			end)
		end)
		delBtn.MouseButton1Click:Connect(function() showConfirm(p) end)
		local busy = false
		wearBtn.MouseButton1Click:Connect(function()
			if busy then return end
			if not lp.Character then toast("No character found", "bad"); return end
			busy = true
			wearBtn.Text = "…"
			task.spawn(function()
				local n = equipMap(lp.Character, p.Anims or {}, true)
				toast(n > 0 and ("Equipped " .. p.Name) or "Couldn't equip that preset", n > 0 and "ok" or "bad")
				if wearBtn.Parent then wearBtn.Text = "Wear" end
				busy = false
			end)
		end)

		if focusNameId == p.Id then
			focusNameId = nil
			task.delay(0.12, function()
				pcall(function()
					nameBox:CaptureFocus()
					nameBox.SelectionStart = 1
					nameBox.CursorPosition = #nameBox.Text + 1
				end)
			end)
		end
	end

	renderPresets = function(spec)
		spec = spec or {}
		for _, c in ipairs(presetPanel:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		local kw = string.lower(spec.keyword or "")
		local list = {}
		for _, p in ipairs(presetList) do
			if kw == "" or string.find(string.lower(p.Name or ""), kw, 1, true) then list[#list + 1] = p end
		end
		local mode = spec.sort or "new"
		if mode == "name" then
			table.sort(list, function(a, b) return string.lower(a.Name or "") < string.lower(b.Name or "") end)
		elseif mode ~= "old" then
			local rev = {}
			for i = #list, 1, -1 do rev[#rev + 1] = list[i] end
			list = rev
		end
		for i, p in ipairs(list) do buildRow(p, i) end
		pageLbl.Text = #list .. (#list == 1 and " preset" or " presets")
		if #presetList == 0 then
			presetEmpty.Text = "No presets yet\nWear some animations, then tap\n“+ Save current”"
			presetEmpty.Visible = true
		elseif #list == 0 then
			presetEmpty.Text = "No presets match"
			presetEmpty.Visible = true
		else
			presetEmpty.Visible = false
		end
	end

	saveCurrentBtn.MouseButton1Click:Connect(function()
		local anims, any = snapshotEquipped()
		if not any then toast("Nothing equipped yet. Wear an animation first", "bad"); return end
		local p = {Id = tostring(os.time()) .. tostring(math.random(1000, 9999)), Name = nextPresetName(), Anims = anims, Time = os.time()}
		presetList[#presetList + 1] = p
		saveJSON(PRESETS_FILE, presetList)
		focusNameId = p.Id
		sb.Text = ""
		if runSearch then runSearch("") end
		toast("Saved as " .. p.Name .. ". Type to rename", "ok")
	end)
end

refreshSavedView = function()
	if currentTab ~= "Saved" then return end
	if runSearch then runSearch(sb.Text) end
end

runSearch = function(text)
	searchGen += 1
	local myGen = searchGen

	local q = parseQuery(text or "")
	local spec = compileQuery(currentTab, q)
	activeSpec = spec
	currentPageIndex = 1

	refreshTags(q, spec)

	local isPresets = (currentTab == "Presets")
	gridHolder.Visible = not isPresets
	presetPanel.Visible = isPresets
	saveCurrentBtn.Visible = isPresets
	prevBtn.Visible = not isPresets
	nextBtn.Visible = not isPresets
	if isPresets then
		clearGrid()
		clearSkeletons()
		gridMsg.Visible = false
		renderPresets(spec)
		return
	end
	presetEmpty.Visible = false

	if currentTab ~= "Discover" then
		savedTabList = (currentTab == "Saved") and buildSavedList(spec) or buildHistoryList(spec)
		drawGridPage(savedTabList)
		return
	end

	searchResults = {}
	catalogCursor = nil
	showSkeletons()
	pageLbl.Text = "Searching…"

	task.spawn(function()
		local params = buildParams(spec)
		local ok, pages = pcall(function() return aes:SearchCatalog(params) end)
		if myGen ~= searchGen then return end
		if not ok or not pages then
			showGridMessage("Search failed — try again")
			pageLbl.Text = "Error"
			return
		end
		catalogCursor = pages
		local page = pages:GetCurrentPage()
		local filtered = {}
		for _, entry in ipairs(page) do
			if passesClientFilter(entry, spec) then filtered[#filtered + 1] = entry end
		end
		if myGen ~= searchGen then return end
		searchResults = filtered
		if #filtered == 0 then
			showGridMessage("No bundles matched your search")
			updatePager(0)
		else
			drawGridPage(searchResults)
		end
	end)
end

local function setTab(tab)
	if currentTab == tab then return end
	currentTab = tab
	local order = {Discover = 0, Saved = 1, Recent = 2, Presets = 3}
	local btns = {Discover = tabDiscover, Saved = tabSaved, Recent = tabRecent, Presets = tabPresets}
	for name, b in pairs(btns) do
		setBtn(b, C.surface, 1, name == tab and C.text or C.textMuted)
	end
	tw(tabIndicator, 0.2, {Position = UDim2.new(order[tab] / 4, s(order[tab] == 0 and 2 or 1), 0, s(2))})
	runSearch(sb.Text)
	refreshSuggestions()
end

tabDiscover.MouseButton1Click:Connect(function() setTab("Discover") end)
tabSaved.MouseButton1Click:Connect(function() setTab("Saved") end)
tabRecent.MouseButton1Click:Connect(function() setTab("Recent") end)
tabPresets.MouseButton1Click:Connect(function() setTab("Presets") end)
onHistoryChanged = function()
	if currentTab == "Recent" and runSearch then runSearch(sb.Text) end
end

searchBtn.MouseButton1Click:Connect(function() runSearch(sb.Text) end)

-- Enter now also completes the highlighted suggestion if we're inside a tag
sb.FocusLost:Connect(function(enter)
	if not enter then return end
	if suggestStrip.Visible and currentSuggestions[1] then
		local cur = (sb.Text:gsub("%s+$", ""))
		local lastToken = cur:match("(%S*)$") or ""
		if lastToken:find(":", 1, true) then
			local sg = currentSuggestions[1]
			local ap = (sg.apply:gsub("%s+$", ""))
			if ap ~= cur and ap:sub(1, #cur) == cur then
				sb.Text = sg.apply
				if sg.run then runSearch(sg.apply) end
				return
			end
		end
	end
	runSearch(sb.Text)
end)

sb:GetPropertyChangedSignal("Text"):Connect(function()
	clearBtn.Visible = sb.Text ~= ""
end)
clearBtn.MouseButton1Click:Connect(function()
	sb.Text = ""
	runSearch("")
end)

prevBtn.MouseButton1Click:Connect(function()
	if pagingBusy or currentPageIndex <= 1 then return end
	currentPageIndex -= 1
	drawGridPage(currentTab ~= "Discover" and savedTabList or searchResults)
end)

nextBtn.MouseButton1Click:Connect(function()
	if pagingBusy then return end
	local list = currentTab ~= "Discover" and savedTabList or searchResults
	local pages = math.max(1, math.ceil(#list / PER_PAGE))
	local more = currentTab == "Discover" and catalogCursor ~= nil and not catalogCursor.IsFinished
	if currentPageIndex < pages then
		currentPageIndex += 1
		drawGridPage(list)
	elseif more then
		pagingBusy = true
		pageLbl.Text = "Loading…"
		task.spawn(function()
			local ok = pcall(function() catalogCursor:AdvanceToNextPageAsync() end)
			pagingBusy = false
			if not ok then toast("Couldn't load more results", "bad"); return end
			local page = catalogCursor:GetCurrentPage()
			local spec = activeSpec or {}
			for _, e in ipairs(page) do
				if passesClientFilter(e, spec) then searchResults[#searchResults + 1] = e end
			end
			currentPageIndex += 1
			drawGridPage(searchResults)
		end)
	end
end)

local helpOpen = false
helpBtn.MouseButton1Click:Connect(function()
	helpOpen = not helpOpen
	helpPanel.Visible = true
	if helpOpen then
		tw(helpPanel, 0.2, {BackgroundTransparency = 0.15})
		tw(helpText, 0.22, {TextTransparency = 0})
		setBtn(helpBtn, C.surfaceHi, 0.1, C.text)
	else
		tw(helpPanel, 0.18, {BackgroundTransparency = 1})
		tw(helpText, 0.18, {TextTransparency = 1})
		task.delay(0.2, function()
			if not helpOpen then helpPanel.Visible = false end
		end)
		setBtn(helpBtn, C.surface, 0.25, C.textDim)
	end
end)
pad(helpScroll, s(14), s(14), s(10), s(10))

local introTargets = nil

local function hideToPill()
	introTargets = collectFade(mf)
	for _, tg in ipairs(introTargets) do
		local props
		if tg.obj.BackgroundTransparency < 1 then props = {BackgroundTransparency = 1} end
		if tg.txtT and tg.obj.TextTransparency < 1 then
			props = props or {}
			props.TextTransparency = 1
		end
		if props then tw(tg.obj, 0.2, props) end
	end
	task.delay(0.24, function()
		mf.Visible = false
		pill.Visible = true
		pill.Size = UDim2.fromOffset(0, 0)
		tw(pill, 0.22, {Size = UDim2.fromOffset(s(58), s(58))}, Enum.EasingStyle.Back)
	end)
end

local function showFromPill()
	pill.Visible = false
	mf.Visible = true
	local targets = introTargets or collectFade(mf)
	for _, tg in ipairs(targets) do
		if tg.obj.Parent then
			local props
			if tg.obj.BackgroundTransparency ~= tg.bgT then props = {BackgroundTransparency = tg.bgT} end
			if tg.txtT and tg.obj.TextTransparency ~= tg.txtT then
				props = props or {}
				props.TextTransparency = tg.txtT
			end
			if props then tw(tg.obj, 0.28, props) end
		end
	end
end

closeBtn.MouseButton1Click:Connect(hideToPill)
minBtn.MouseButton1Click:Connect(hideToPill)
pill.MouseButton1Click:Connect(showFromPill)

local dragging, dragStart, startPos
top.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mf.Position
	end
end)
track(uis.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		mf.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end))
track(uis.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end))

track(uis.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		if mf.Visible then hideToPill() else showFromPill() end
	elseif input.KeyCode == Enum.KeyCode.Escape and confirmOverlay.Visible then
		hideConfirm()
	elseif input.KeyCode == Enum.KeyCode.Escape and helpOpen then
		helpOpen = false
		helpPanel.Visible = false
		helpText.TextTransparency = 1
		helpPanel.BackgroundTransparency = 1
		setBtn(helpBtn, C.surface, 0.25, C.textDim)
	end
end))

env.UgcAnimStudioCleanup = function()
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
	for obj in pairs(spinning) do spinning[obj] = nil end
	for obj, d in pairs(shimmers) do
		pcall(function() d[2]:Cancel() end)
		pcall(function() d[1]:Destroy() end)
		shimmers[obj] = nil
	end
	if masterTrack then pcall(function() masterTrack:Stop(0) end) end
	tweenShutdown()
	pcall(function() g:Destroy() end)
end

runSearch("")

env.UgcAnimStudio = {gui = g, main = mf}

end)

if not uiOk then
	warn("[UGC Anim Studio] BUILD ERROR: " .. tostring(uiErr))
	dbg("BUILD ERROR: " .. tostring(uiErr))
else
	dbg("ui built successfully")

	pcall(function()
		local mf2 = env.UgcAnimStudio and env.UgcAnimStudio.main
		if not mf2 then return end

		local us = Instance.new("UIScale")
		us.Scale = 0.86
		us.Parent = mf2

		local origPos = mf2.Position
		mf2.Position = origPos + UDim2.fromOffset(0, 26)

		local targets = collectFade(mf2)

		for _, tg in ipairs(targets) do
			if tg.bgT < 1 then tg.obj.BackgroundTransparency = 1 end
			if tg.txtT and tg.txtT < 1 then tg.obj.TextTransparency = 1 end
		end

		tw(mf2, 0.55, {Position = origPos}, Enum.EasingStyle.Quint)
		tw(us, 0.7, {Scale = 1}, Enum.EasingStyle.Back)

		for _, tg in ipairs(targets) do
			local props
			if tg.bgT < 1 then props = {BackgroundTransparency = tg.bgT} end
			if tg.txtT and tg.txtT < 1 then
				props = props or {}
				props.TextTransparency = tg.txtT
			end
			if props then tw(tg.obj, 0.55, props, Enum.EasingStyle.Quint) end
		end
	end)
end