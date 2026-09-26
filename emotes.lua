local camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

local function Scale(axis, value)
    local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local refWidth, refHeight = 1920, 1080
    local multiplier = isTouch and 2 or 1.5
    local viewportSize = camera and camera.ViewportSize or Vector2.new(1920, 1080)

    if axis == "X" then
        return value * (viewportSize.X / refWidth) * multiplier
    elseif axis == "Y" then
        return value * (viewportSize.Y / refHeight) * multiplier
    end
end

local function GetSafeService(serviceName)
    local getService = type(cloneref) == "function" and cloneref or function(...) return ... end
    return getService(game:GetService(serviceName))
end

local Services = setmetatable({}, {
    __index = function(_, serviceName)
        return GetSafeService(serviceName)
    end
})

local Players = Services.Players
local RunService = Services.RunService
local UIS = Services.UserInputService
local TweenService = Services.TweenService
local AvatarEditorService = Services.AvatarEditorService
local HttpService = Services.HttpService

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local isR6 = Humanoid.RigType == Enum.HumanoidRigType.R6
local lastPosition = Character.PrimaryPart and Character.PrimaryPart.Position or Vector3.new()

local TitleLabel_Ref, CatalogTab_Ref, SavedTab_Ref, CatalogFrame_Ref, SavedFrame_Ref

LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    isR6 = Humanoid.RigType == Enum.HumanoidRigType.R6

    if TitleLabel_Ref then TitleLabel_Ref.Text = isR6 and "GAZE SMOTES" or "Gaze Emotes" end
    if CatalogTab_Ref then CatalogTab_Ref.Text = isR6 and "Anim" or "Catalog" end
    if SavedTab_Ref then SavedTab_Ref.Visible = not isR6 end

    if isR6 and CatalogFrame_Ref and SavedFrame_Ref then
        CatalogFrame_Ref.Visible = true
        SavedFrame_Ref.Visible = false
        CatalogTab_Ref.BackgroundColor3 = Color3.fromRGB(30, 30, 80)
        SavedTab_Ref.BackgroundColor3 = Color3.fromRGB(20, 50, 20)
    end

    lastPosition = Character.PrimaryPart and Character.PrimaryPart.Position or Vector3.new()
end)

local Settings = {
    ["Stop Emote When Moving"] = true,
    ["Fade In"] = 0.1,
    ["Fade Out"] = 0.1,
    ["Weight"] = 1,
    ["Speed"] = 1,
    ["Time Position"] = 0,
    ["Freeze On Finish"] = false,
    ["Looped"] = true,
    ["Stop Other Animations On Play"] = true,
    ["High Priority"] = true,
    _sliders = {},
    _toggles = {}
}

local SavedEmotes = {}
local SAVE_FILENAME = "GazeEmotes_NewNEWN3WSaved.json"

local function LoadEmotes()
    local success, result = pcall(function()
        if readfile and isfile and isfile(SAVE_FILENAME) then
            return HttpService:JSONDecode(readfile(SAVE_FILENAME))
        end
        return {}
    end)
    
    SavedEmotes = (success and type(result) == "table") and result or {}

    for _, emoteData in ipairs(SavedEmotes) do
        if not emoteData.AnimationId then
            emoteData.AnimationId = "rbxassetid://" .. tostring(emoteData.AssetId or emoteData.Id)
        end
        if emoteData.Favorite == nil then
            emoteData.Favorite = false
        end
    end
end

local function SaveEmotes()
    pcall(function()
        if writefile then
            writefile(SAVE_FILENAME, HttpService:JSONEncode(SavedEmotes))
        end
    end)
end

LoadEmotes()

local currentAnimationTrack = nil

local function PlayEmote(assetId)
    if currentAnimationTrack then
        currentAnimationTrack:Stop(Settings["Fade Out"])
    end

    local animId = "rbxassetid://" .. tostring(assetId)
    local success, objects = pcall(function()
        return game:GetObjects(animId)
    end)

    if success and objects and #objects > 0 then
        local firstObj = objects[1]
        if firstObj:IsA("Animation") then
            animId = firstObj.AnimationId
        end
    end

    local animation = Instance.new("Animation")
    animation.AnimationId = animId

    local track = Humanoid:LoadAnimation(animation)
    local animPriority = Settings["High Priority"] and Enum.AnimationPriority.Action4 or Enum.AnimationPriority.Action
    track.Priority = animPriority

    local weight = Settings["Weight"] == 0 and 0.001 or Settings["Weight"]

    if Settings["Stop Other Animations On Play"] then
        for _, playingTrack in pairs(Humanoid.Animator:GetPlayingAnimationTracks()) do
            if playingTrack.Priority ~= animPriority then
                playingTrack:Stop()
            end
        end
    end

    track:Play(Settings["Fade In"], weight, Settings["Speed"])
    currentAnimationTrack = track
    currentAnimationTrack.TimePosition = math.clamp(Settings["Time Position"], 0, 1) * (currentAnimationTrack.Length or 1)
    currentAnimationTrack.Priority = animPriority
    currentAnimationTrack.Looped = Settings["Looped"]

    return track
end

RunService.RenderStepped:Connect(function()
    if Settings["Looped"] and currentAnimationTrack and currentAnimationTrack.IsPlaying then
        currentAnimationTrack.Looped = Settings["Looped"]
    end

    if Character:FindFirstChild("HumanoidRootPart") then
        local hrp = Character.HumanoidRootPart
        if Settings["Stop Emote When Moving"] and currentAnimationTrack and currentAnimationTrack.IsPlaying then
            local isMoving = (hrp.Position - lastPosition).Magnitude > 0.1
            local isJumping = Humanoid and Humanoid:GetState() == Enum.HumanoidStateType.Jumping
            
            if isMoving or isJumping then
                currentAnimationTrack:Stop(Settings["Fade Out"])
                currentAnimationTrack = nil
            end
        end
        lastPosition = hrp.Position
    end
end)

local CoreGui = Services.CoreGui
local MainGui = Instance.new("ScreenGui")
MainGui.Name = "GazeEmoteGUI"
MainGui.Parent = CoreGui
MainGui.Enabled = false
MainGui.DisplayOrder = 999

local function ApplyUICorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = parent
    return corner
end

local function ApplyUIStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(60, 120, 200)
    stroke.Thickness = thickness or 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local function PlayPopInAnimation(parent)
    local scale = Instance.new("UIScale")
    scale.Scale = 0.85
    scale.Parent = parent
    TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

local RealIdCache = {}

local function GetRealAnimationId(assetInput)
    local function resolveSingleId(id)
        local numericId = tonumber(id)
        if not numericId then return nil end
        if RealIdCache[numericId] then return RealIdCache[numericId] end

        local realId = nil

        pcall(function()
            local desc = Instance.new("HumanoidDescription")
            desc.WalkAnimation = numericId
            desc.RunAnimation = numericId
            desc.JumpAnimation = numericId
            desc.FallAnimation = numericId
            desc.ClimbAnimation = numericId
            desc.SwimAnimation = numericId

            local dummy = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
            local animate = dummy:FindFirstChild("Animate")

            if animate then
                for _, folder in ipairs(animate:GetChildren()) do
                    if folder:IsA("Folder") and string.lower(folder.Name) ~= "idle" then
                        for _, child in ipairs(folder:GetChildren()) do
                            if child:IsA("Animation") and child.AnimationId ~= "" then
                                realId = tonumber(child.AnimationId:match("%d+"))
                                if realId then break end
                            end
                        end
                    end
                    if realId then break end
                end
            end
            dummy:Destroy()
        end)

        if realId then 
            RealIdCache[numericId] = realId
            return realId 
        end

        pcall(function()
            local objects = game:GetObjects("rbxassetid://" .. tostring(numericId))
            if objects and #objects > 0 then
                local function scanContainer(container)
                    if container:IsA("Animation") and container.AnimationId ~= "" then
                        realId = tonumber(container.AnimationId:match("%d+"))
                        if realId then return end
                    end
                    for _, child in ipairs(container:GetChildren()) do
                        if realId then return end
                        scanContainer(child)
                    end
                end
                scanContainer(objects[1])
            end
        end)

        if realId then RealIdCache[numericId] = realId end
        return realId
    end

    if type(assetInput) == "table" then
        local resolvedTable = {}
        for key, id in pairs(assetInput) do
            resolvedTable[key] = resolveSingleId(id)
        end
        return resolvedTable
    end

    return resolveSingleId(assetInput)
end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, Scale("X", 470), 0, Scale("Y", 450))
MainFrame.Position = UDim2.new(0.5, -Scale("X", 325), 0.5, -Scale("Y", 225))
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BackgroundTransparency = 0.15
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = MainGui
ApplyUICorner(MainFrame, 8)
ApplyUIStroke(MainFrame, Color3.fromRGB(80, 80, 120), 1.5)

local ResizeBtn = Instance.new("TextButton")
ResizeBtn.Size = UDim2.new(0, 24, 0, 24)
ResizeBtn.Position = UDim2.new(1, -24, 1, -24)
ResizeBtn.BackgroundTransparency = 1
ResizeBtn.Text = "◢"
ResizeBtn.TextColor3 = Color3.fromRGB(100, 100, 140)
ResizeBtn.TextSize = 18
ResizeBtn.ZIndex = 10
ResizeBtn.Parent = MainFrame

local isResizing = false
local dragStartPos, startFrameSize

ResizeBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = true
        dragStartPos = input.Position
        startFrameSize = MainFrame.AbsoluteSize
    end
end)

UIS.InputChanged:Connect(function(input)
    if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartPos
        local newWidth = math.max(150, startFrameSize.X + delta.X)
        local newHeight = math.max(100, startFrameSize.Y + delta.Y)
        MainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = false
    end
end)

local TitleLabel = Instance.new("TextLabel")
TitleLabel_Ref = TitleLabel
TitleLabel.Size = UDim2.new(1, 0, 0, Scale("Y", 36))
TitleLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
TitleLabel.BackgroundTransparency = 0.5
TitleLabel.Text = isR6 and "Gaze Emotes (R6)" or "Gaze Emotes"
TitleLabel.TextColor3 = Color3.new(1, 1, 1)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextScaled = true
TitleLabel.Parent = MainFrame
ApplyUICorner(TitleLabel, 8)

local CatalogTab = Instance.new("TextButton")
CatalogTab_Ref = CatalogTab
CatalogTab.Size = UDim2.new(0.3, 0, 0, Scale("Y", 24))
CatalogTab.Position = UDim2.new(0.05, 0, 0, Scale("Y", 40))
CatalogTab.BackgroundColor3 = Color3.fromRGB(30, 30, 80)
CatalogTab.BackgroundTransparency = 0.2
CatalogTab.Text = isR6 and "Animation" or "Catalog"
CatalogTab.TextColor3 = Color3.new(1, 1, 1)
CatalogTab.Font = Enum.Font.GothamBold
CatalogTab.TextScaled = true
CatalogTab.Parent = MainFrame
ApplyUICorner(CatalogTab, 4)

local SavedTab = Instance.new("TextButton")
SavedTab_Ref = SavedTab
SavedTab.Size = UDim2.new(0.3, 0, 0, Scale("Y", 24))
SavedTab.Position = UDim2.new(0.35, 0, 0, Scale("Y", 40))
SavedTab.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
SavedTab.BackgroundTransparency = 0.2
SavedTab.Text = "Saved"
SavedTab.TextColor3 = Color3.new(1, 1, 1)
SavedTab.Font = Enum.Font.GothamBold
SavedTab.TextScaled = true
SavedTab.Visible = not isR6
SavedTab.Parent = MainFrame
ApplyUICorner(SavedTab, 4)

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(0, Scale("X", 2), 1, -Scale("Y", 70))
Divider.Position = UDim2.new(0.6, -Scale("X", 1), 0, Scale("Y", 70))
Divider.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
Divider.BackgroundTransparency = 0.5
Divider.Parent = MainFrame

local CatalogFrame = Instance.new("Frame")
CatalogFrame_Ref = CatalogFrame
CatalogFrame.Size = UDim2.new(0.6, -Scale("X", 10), 1, -Scale("Y", 70))
CatalogFrame.Position = UDim2.new(0, Scale("X", 5), 0, Scale("Y", 70))
CatalogFrame.BackgroundTransparency = 1
CatalogFrame.Visible = true
CatalogFrame.Parent = MainFrame

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(0.6, -Scale("X", 8), 0, Scale("Y", 28))
SearchBox.Position = UDim2.new(0, Scale("X", 8), 0, 0)
SearchBox.PlaceholderText = "Search..."
SearchBox.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
SearchBox.BackgroundTransparency = 0.3
SearchBox.TextColor3 = Color3.new(1, 1, 1)
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextScaled = true
SearchBox.ClearTextOnFocus = false
SearchBox.Text = ""
SearchBox.Parent = CatalogFrame
ApplyUICorner(SearchBox, 4)
ApplyUIStroke(SearchBox, Color3.fromRGB(50, 50, 70), 1)

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0.2, -Scale("X", 4), 0, Scale("Y", 28))
RefreshBtn.Position = UDim2.new(0.6, Scale("X", 4), 0, 0)
RefreshBtn.BackgroundColor3 = Color3.fromRGB(0, 60, 150)
RefreshBtn.BackgroundTransparency = 0.2
RefreshBtn.Text = "Refresh"
RefreshBtn.Font = Enum.Font.GothamBold
RefreshBtn.TextScaled = true
RefreshBtn.TextColor3 = Color3.new(1, 1, 1)
RefreshBtn.Parent = CatalogFrame
ApplyUICorner(RefreshBtn, 4)

local SortBtn = Instance.new("TextButton")
SortBtn.Size = UDim2.new(0.2, -Scale("X", 8), 0, Scale("Y", 28))
SortBtn.Position = UDim2.new(0.8, Scale("X", 4), 0, 0)
SortBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
SortBtn.BackgroundTransparency = 0.2
SortBtn.Text = "Sort: Relevance"
SortBtn.Font = Enum.Font.GothamBold
SortBtn.TextScaled = true
SortBtn.TextColor3 = Color3.new(1, 1, 1)
SortBtn.Parent = CatalogFrame
ApplyUICorner(SortBtn, 4)

local SavedFrame = Instance.new("Frame")
SavedFrame_Ref = SavedFrame
SavedFrame.Size = UDim2.new(0.6, -Scale("X", 10), 1, -Scale("Y", 70))
SavedFrame.Position = UDim2.new(0, Scale("X", 5), 0, Scale("Y", 70))
SavedFrame.BackgroundTransparency = 1
SavedFrame.Visible = false
SavedFrame.Parent = MainFrame

local SearchSavedBox = Instance.new("TextBox")
SearchSavedBox.Size = UDim2.new(0.7, -Scale("X", 16), 0, Scale("Y", 28))
SearchSavedBox.Position = UDim2.new(0, Scale("X", 8), 0, 0)
SearchSavedBox.PlaceholderText = "Search Saved..."
SearchSavedBox.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
SearchSavedBox.BackgroundTransparency = 0.3
SearchSavedBox.TextColor3 = Color3.new(1, 1, 1)
SearchSavedBox.Font = Enum.Font.Gotham
SearchSavedBox.TextScaled = true
SearchSavedBox.ClearTextOnFocus = false
SearchSavedBox.Text = ""
SearchSavedBox.Parent = SavedFrame
ApplyUICorner(SearchSavedBox, 4)
ApplyUIStroke(SearchSavedBox, Color3.fromRGB(50, 50, 70), 1)

local EmoteIdBox = Instance.new("TextBox")
EmoteIdBox.Size = UDim2.new(0.2, 0, 0, Scale("Y", 28))
EmoteIdBox.Position = UDim2.new(0.7, -Scale("X", 4), 0, 0)
EmoteIdBox.PlaceholderText = "Emote ID"
EmoteIdBox.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
EmoteIdBox.BackgroundTransparency = 0.3
EmoteIdBox.TextColor3 = Color3.new(1, 1, 1)
EmoteIdBox.Font = Enum.Font.Gotham
EmoteIdBox.TextScaled = true
EmoteIdBox.ClearTextOnFocus = false
EmoteIdBox.Text = ""
EmoteIdBox.Parent = SavedFrame
ApplyUICorner(EmoteIdBox, 4)
ApplyUIStroke(EmoteIdBox, Color3.fromRGB(50, 50, 70), 1)

local AddEmoteBtn = Instance.new("TextButton")
AddEmoteBtn.Size = UDim2.new(0.1, 0, 0, Scale("Y", 28))
AddEmoteBtn.Position = UDim2.new(0.9, 0, 0, 0)
AddEmoteBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 160)
AddEmoteBtn.BackgroundTransparency = 0.2
AddEmoteBtn.Text = "+"
AddEmoteBtn.Font = Enum.Font.GothamBold
AddEmoteBtn.TextScaled = true
AddEmoteBtn.TextColor3 = Color3.new(1, 1, 1)
AddEmoteBtn.Parent = SavedFrame
ApplyUICorner(AddEmoteBtn, 4)

local SavedScrollFrame = Instance.new("ScrollingFrame")
SavedScrollFrame.Size = UDim2.new(1, -Scale("X", 16), 1, -Scale("Y", 40))
SavedScrollFrame.Position = UDim2.new(0, Scale("X", 8), 0, Scale("Y", 36))
SavedScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
SavedScrollFrame.ScrollBarThickness = 0
SavedScrollFrame.BackgroundTransparency = 1
SavedScrollFrame.Parent = SavedFrame

local EmptySavedLabel = Instance.new("TextLabel")
EmptySavedLabel.Size = UDim2.new(1, 0, 0, Scale("Y", 36))
EmptySavedLabel.Position = UDim2.new(0, 0, 0.5, -Scale("Y", 18))
EmptySavedLabel.BackgroundTransparency = 1
EmptySavedLabel.Text = "Sorry I Was Changing Save Files Again 😅"
EmptySavedLabel.TextColor3 = Color3.new(1, 1, 1)
EmptySavedLabel.Font = Enum.Font.GothamBold
EmptySavedLabel.TextScaled = true
EmptySavedLabel.Visible = false
EmptySavedLabel.Parent = SavedScrollFrame

local SavedGridLayout = Instance.new("UIGridLayout")
SavedGridLayout.CellSize = UDim2.new(0, Scale("X", 120), 0, Scale("Y", 200))
SavedGridLayout.CellPadding = UDim2.new(0, Scale("X", 8), 0, Scale("Y", 8))
SavedGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SavedGridLayout.Parent = SavedScrollFrame

local SettingsFrame = Instance.new("Frame")
SettingsFrame.Size = UDim2.new(0.4, -Scale("X", 10), 1, -Scale("Y", 70))
SettingsFrame.Position = UDim2.new(0.6, Scale("X", 5), 0, Scale("Y", 70))
SettingsFrame.BackgroundTransparency = 1
SettingsFrame.Parent = MainFrame

local SettingsTitle = Instance.new("TextLabel")
SettingsTitle.Size = UDim2.new(1, 0, 0, Scale("Y", 28))
SettingsTitle.BackgroundTransparency = 1
SettingsTitle.Text = "Settings"
SettingsTitle.TextColor3 = Color3.new(1, 1, 1)
SettingsTitle.Font = Enum.Font.GothamBold
SettingsTitle.TextScaled = true
SettingsTitle.Parent = SettingsFrame

local SettingsScrollFrame = Instance.new("ScrollingFrame")
SettingsScrollFrame.Size = UDim2.new(1, -Scale("X", 20), 1, -Scale("Y", 40))
SettingsScrollFrame.Position = UDim2.new(0, Scale("X", 10), 0, Scale("Y", 30))
SettingsScrollFrame.BackgroundTransparency = 1
SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
SettingsScrollFrame.ScrollBarThickness = 4
SettingsScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 140)
SettingsScrollFrame.Parent = SettingsFrame

SettingsScrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    SettingsScrollFrame.CanvasPosition = Vector2.new(0, SettingsScrollFrame.CanvasPosition.Y)
end)

local SettingsListLayout = Instance.new("UIListLayout", SettingsScrollFrame)
SettingsListLayout.Padding = UDim.new(0, 8)
SettingsListLayout.FillDirection = Enum.FillDirection.Vertical
SettingsListLayout.SortOrder = Enum.SortOrder.LayoutOrder

SettingsListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, SettingsListLayout.AbsoluteContentSize.Y + 10)
end)

local RefreshSavedList

AddEmoteBtn.MouseButton1Click:Connect(function()
    local id = tonumber(EmoteIdBox.Text)
    if id then
        local exists = false
        for _, emoteData in ipairs(SavedEmotes) do
            if emoteData.Id == id then
                exists = true
                break
            end
        end
        if not exists then
            task.spawn(function()
                local realAnimId = GetRealAnimationId(id)
                table.insert(SavedEmotes, {
                    Id = id,
                    AssetId = id,
                    Name = "Custom ID: " .. id,
                    AnimationId = "rbxassetid://" .. tostring(realAnimId or id),
                    Favorite = false
                })
                SaveEmotes()
                if RefreshSavedList then RefreshSavedList() end
            end)
        end
    end
end)

local function CreateSlider(settingName, minVal, maxVal, defaultVal)
    Settings[settingName] = defaultVal or minVal
    
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, Scale("Y", 65))
    container.BackgroundTransparency = 1
    container.Parent = SettingsScrollFrame

    local bgFrame = Instance.new("Frame")
    bgFrame.Size = UDim2.new(1, 0, 1, 0)
    bgFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    bgFrame.BackgroundTransparency = 0.4
    bgFrame.Parent = container
    ApplyUICorner(bgFrame, 6)
    ApplyUIStroke(bgFrame, Color3.fromRGB(60, 60, 90), 1)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, -Scale("X", 10), 0, Scale("Y", 20))
    label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = string.format("%s: %.2f", settingName, Settings[settingName])
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.Gotham
    label.TextScaled = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = bgFrame

    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(0.5, -Scale("X", 20), 0, Scale("Y", 20))
    inputBox.Position = UDim2.new(0.5, Scale("X", 10), 0, Scale("Y", 5))
    inputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    inputBox.Text = tostring(Settings[settingName])
    inputBox.TextColor3 = Color3.new(1, 1, 1)
    inputBox.Font = Enum.Font.Gotham
    inputBox.TextScaled = true
    inputBox.ClearTextOnFocus = false
    inputBox.Parent = bgFrame
    ApplyUICorner(inputBox, 4)

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -Scale("X", 40), 0, Scale("Y", 12))
    barBg.Position = UDim2.new(0, Scale("X", 20), 0, Scale("Y", 35))
    barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    barBg.Parent = bgFrame
    ApplyUICorner(barBg, 6)

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
    barFill.Parent = barBg
    ApplyUICorner(barFill, 6)

    local sliderKnob = Instance.new("Frame")
    sliderKnob.Size = UDim2.new(0, Scale("X", 20), 0, Scale("Y", 20))
    sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    sliderKnob.Position = UDim2.new(0, 0, 0.5, 0)
    sliderKnob.BackgroundColor3 = Color3.fromRGB(220, 220, 255)
    sliderKnob.Parent = barBg
    ApplyUICorner(sliderKnob, 10)
    ApplyUIStroke(sliderKnob, Color3.fromRGB(0, 0, 0), 1)

    local function UpdateVisuals(alpha)
        alpha = math.clamp(alpha, 0, 1)
        TweenService:Create(barFill, TweenInfo.new(0.15), {Size = UDim2.new(alpha, 0, 1, 0)}):Play()
        TweenService:Create(sliderKnob, TweenInfo.new(0.15), {Position = UDim2.new(alpha, 0, 0.5, 0)}):Play()
    end

    local function SetValue(val)
        Settings[settingName] = math.clamp(val, minVal, maxVal)
        label.Text = string.format("%s: %.2f", settingName, Settings[settingName])
        inputBox.Text = tostring(Settings[settingName])
        UpdateVisuals((Settings[settingName] - minVal) / (maxVal - minVal))

        if currentAnimationTrack and currentAnimationTrack.IsPlaying then
            if settingName == "Speed" then
                currentAnimationTrack:AdjustSpeed(Settings["Speed"])
            elseif settingName == "Weight" then
                local w = Settings["Weight"]
                currentAnimationTrack:AdjustWeight(w == 0 and 0.001 or w)
            elseif settingName == "Time Position" then
                if currentAnimationTrack.Length > 0 then
                    currentAnimationTrack.TimePosition = math.clamp(val, 0, 1) * currentAnimationTrack.Length
                end
            end
        end
    end

    local isDragging = false
    local function UpdateDrag(input)
        local alpha = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
        local newVal = math.floor((minVal + (maxVal - minVal) * alpha) * 100) / 100
        SetValue(newVal)
    end

    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            UpdateDrag(input)
        end
    end)

    sliderKnob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            UpdateDrag(input)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            UpdateDrag(input)
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isDragging = false
        end
    end)

    inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local parsed = tonumber(inputBox.Text)
            if parsed then
                SetValue(parsed)
            else
                inputBox.Text = tostring(Settings[settingName])
            end
        end
    end)

    Settings._sliders[settingName] = SetValue
    SetValue(Settings[settingName])
end

local function CreateToggle(settingName)
    Settings[settingName] = Settings[settingName] or false
    
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, Scale("Y", 40))
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    container.BackgroundTransparency = 0.4
    container.Parent = SettingsScrollFrame
    ApplyUICorner(container, 6)
    ApplyUIStroke(container, Color3.fromRGB(60, 60, 90), 1)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -Scale("X", 90), 1, 0)
    label.Position = UDim2.new(0, Scale("X", 10), 0, 0)
    label.BackgroundTransparency = 1
    label.Text = settingName
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.Gotham
    label.TextScaled = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, Scale("X", 60), 0, Scale("Y", 24))
    toggleBtn.Position = UDim2.new(1, -Scale("X", 70), 0.5, -Scale("Y", 12))
    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextScaled = true
    toggleBtn.Parent = container
    ApplyUICorner(toggleBtn, 4)

    local function UpdateVisuals(state)
        toggleBtn.Text = state and "ON" or "OFF"
        toggleBtn.BackgroundColor3 = state and Color3.fromRGB(0, 150, 100) or Color3.fromRGB(150, 40, 40)
        toggleBtn.BackgroundTransparency = 0.2
    end

    toggleBtn.MouseButton1Click:Connect(function()
        Settings[settingName] = not Settings[settingName]
        UpdateVisuals(Settings[settingName])
    end)

    UpdateVisuals(Settings[settingName])
    Settings._toggles[settingName] = UpdateVisuals
end

function Settings:EditSlider(name, value)
    local sliderFunc = self._sliders[name]
    if sliderFunc then sliderFunc(value) end
end

function Settings:EditToggle(name, value)
    local toggleFunc = self._toggles[name]
    if toggleFunc then
        self[name] = value
        toggleFunc(value)
    end
end

local function CreateButton(text, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, Scale("Y", 45))
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    container.BackgroundTransparency = 0.4
    container.Parent = SettingsScrollFrame
    ApplyUICorner(container, 6)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -Scale("X", 20), 1, -Scale("Y", 10))
    btn.Position = UDim2.new(0, Scale("X", 10), 0, Scale("Y", 5))
    btn.BackgroundColor3 = Color3.fromRGB(30, 90, 180)
    btn.BackgroundTransparency = 0.2
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.Parent = container
    ApplyUICorner(btn, 6)

    btn.MouseButton1Click:Connect(function()
        if typeof(callback) == "function" then callback() end
    end)
    return btn
end

local ResetBtn = CreateButton("Reset Settings", function() end)
CreateToggle("Stop Emote When Moving")
CreateToggle("Looped")
CreateSlider("Speed", 0, 5, Settings["Speed"])
CreateSlider("Time Position", 0, 1, Settings["Time Position"])
CreateSlider("Weight", 0, 1, Settings["Weight"])
CreateSlider("Fade In", 0, 2, Settings["Fade In"])
CreateSlider("Fade Out", 0, 2, Settings["Fade Out"])
CreateToggle("Stop Other Animations On Play")
CreateToggle("High Priority")

ResetBtn.MouseButton1Click:Connect(function()
    Settings:EditToggle("Stop Emote When Moving", true)
    Settings:EditToggle("Stop Other Animations On Play", true)
    Settings:EditToggle("High Priority", true)
    Settings:EditSlider("Fade In", 0.1)
    Settings:EditSlider("Fade Out", 0.1)
    Settings:EditSlider("Weight", 1)
    Settings:EditSlider("Speed", 1)
    Settings:EditSlider("Time Position", 0)
    Settings:EditToggle("Freeze On Finish", false)
    Settings:EditToggle("Looped", true)
end)

local SortTypes = {
    {Enum.CatalogSortType.Relevance, "Relevance"},
    {Enum.CatalogSortType.PriceHighToLow, "Price High→Low"},
    {Enum.CatalogSortType.PriceLowToHigh, "Price Low→High"},
    {Enum.CatalogSortType.MostFavorited, "Most Favorited"},
    {Enum.CatalogSortType.RecentlyCreated, "Recently Created"},
    {Enum.CatalogSortType.Bestselling, "Bestselling"}
}

local currentSortIndex = 1
local currentSearchQuery = ""
local catalogPageCursor = nil
local currentPageNumber = 1
local currentTabId = 1

local function FetchCatalogPage(keyword)
    if isR6 then
        return {
            IsFinished = true,
            GetCurrentPage = function()
                return {{Id = 115314801778772, Name = "Dance If Youre The Best", AssetId = 115314801778772}}
            end,
            AdvanceToNextPageAsync = function() end
        }
    end

    local searchParams = CatalogSearchParams.new()
    searchParams.SearchKeyword = keyword or ""
    searchParams.CategoryFilter = Enum.CatalogCategoryFilter.None
    searchParams.SalesTypeFilter = Enum.SalesTypeFilter.All
    searchParams.AssetTypes = {Enum.AvatarAssetType.EmoteAnimation}
    searchParams.IncludeOffSale = true
    searchParams.SortType = SortTypes[currentSortIndex][1]
    searchParams.Limit = 10

    local success, result = pcall(function()
        return AvatarEditorService:SearchCatalog(searchParams)
    end)
    return success and result or nil
end

local function CreateCatalogCard(item)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, Scale("X", 120), 0, Scale("Y", 180))
    card.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    card.BackgroundTransparency = 0.2
    ApplyUICorner(card, 8)
    ApplyUIStroke(card, Color3.fromRGB(60, 60, 90), 1)

    local assetId = item.AssetId or item.Id

    local thumbnail = Instance.new("ImageLabel")
    thumbnail.Size = UDim2.new(1, -Scale("X", 10), 0, Scale("Y", 90))
    thumbnail.Position = UDim2.new(0, Scale("X", 5), 0, Scale("Y", 5))
    thumbnail.BackgroundTransparency = 1
    thumbnail.ScaleType = Enum.ScaleType.Fit
    thumbnail.Image = "rbxthumb://type=Asset&id=" .. tonumber(assetId) .. "&w=150&h=150"
    thumbnail.Parent = card
    ApplyUICorner(thumbnail, 4)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -Scale("X", 10), 0, Scale("Y", 28))
    nameLabel.Position = UDim2.new(0, Scale("X", 5), 0, Scale("Y", 100))
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = item.Name or "Unknown"
    nameLabel.TextScaled = true
    nameLabel.TextWrapped = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Parent = card

    local shopUrl = "https://www.roblox.com/catalog/" .. tonumber(item.Id)
    local linkBtn = Instance.new("TextButton")
    linkBtn.Parent = card
    linkBtn.Size = UDim2.new(0, Scale("X", 36), 0, Scale("Y", 36))
    linkBtn.Position = UDim2.new(1, -Scale("X", 42), 0, Scale("Y", 5))
    linkBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    linkBtn.BackgroundTransparency = 0.2
    linkBtn.Text = "🛒🔗"
    linkBtn.Font = Enum.Font.GothamBold
    linkBtn.TextScaled = true
    linkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    linkBtn.AutoButtonColor = false
    ApplyUICorner(linkBtn, 6)
    
    linkBtn.MouseButton1Click:Connect(function()
        if setclipboard then setclipboard(shopUrl) end
        linkBtn.Text = "✅"
        linkBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
        task.wait(0.7)
        linkBtn.Text = "🛒🔗"
        linkBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    end)

    local playBtn = Instance.new("TextButton")
    playBtn.Size = UDim2.new(0.45, -Scale("X", 5), 0, Scale("Y", 24))
    playBtn.Position = UDim2.new(0, Scale("X", 5), 1, -Scale("Y", 29))
    playBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
    playBtn.BackgroundTransparency = 0.2
    playBtn.Text = "Play"
    playBtn.Font = Enum.Font.GothamBold
    playBtn.TextScaled = true
    playBtn.TextColor3 = Color3.new(1, 1, 1)
    playBtn.Parent = card
    ApplyUICorner(playBtn, 4)
    
    playBtn.MouseButton1Click:Connect(function()
        PlayEmote(assetId)
    end)

    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0.45, -Scale("X", 5), 0, Scale("Y", 24))
    saveBtn.Position = UDim2.new(0.55, 0, 1, -Scale("Y", 29))
    saveBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 160)
    saveBtn.BackgroundTransparency = 0.2
    saveBtn.Text = "Save"
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextScaled = true
    saveBtn.TextColor3 = Color3.new(1, 1, 1)
    saveBtn.Parent = card
    ApplyUICorner(saveBtn, 4)
    
    saveBtn.MouseButton1Click:Connect(function()
        local exists = false
        for _, savedItem in ipairs(SavedEmotes) do
            if savedItem.Id == item.Id then
                exists = true
                break
            end
        end
        if not exists then
            saveBtn.Text = "..."
            task.spawn(function()
                local realAnimId = GetRealAnimationId(assetId)
                table.insert(SavedEmotes, {
                    Id = item.Id,
                    AssetId = assetId,
                    Name = item.Name or "Unknown",
                    AnimationId = "rbxassetid://" .. tostring(realAnimId or assetId),
                    Favorite = false
                })
                SaveEmotes()
                saveBtn.Text = "Saved!"
                saveBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 100)
                task.wait(1)
                saveBtn.Text = "Save"
                saveBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 160)
            end)
        else
            saveBtn.Text = "Already"
            task.wait(0.7)
            saveBtn.Text = "Save"
        end
    end)

    return card
end

local CatalogScrollFrame = Instance.new("ScrollingFrame")
CatalogScrollFrame.Size = UDim2.new(1, -Scale("X", 16), 1, -Scale("Y", 100))
CatalogScrollFrame.Position = UDim2.new(0, Scale("X", 8), 0, Scale("Y", 36))
CatalogScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
CatalogScrollFrame.ScrollBarThickness = 6
CatalogScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 140)
CatalogScrollFrame.BackgroundTransparency = 1
CatalogScrollFrame.Parent = CatalogFrame

local CatalogGridLayout = Instance.new("UIGridLayout", CatalogScrollFrame)
CatalogGridLayout.CellSize = UDim2.new(0, Scale("X", 120), 0, Scale("Y", 180))
CatalogGridLayout.CellPadding = UDim2.new(0, Scale("X", 8), 0, Scale("Y", 8))

local EmptyCatalogLabel = Instance.new("TextLabel", CatalogScrollFrame)
EmptyCatalogLabel.Size = UDim2.new(1, 0, 0, Scale("Y", 36))
EmptyCatalogLabel.Position = UDim2.new(0, 0, 0.5, -Scale("Y", 18))
EmptyCatalogLabel.BackgroundTransparency = 1
EmptyCatalogLabel.Text = "Nothing Silly Here :3 (except me)"
EmptyCatalogLabel.TextColor3 = Color3.new(1, 1, 1)
EmptyCatalogLabel.Font = Enum.Font.GothamBold
EmptyCatalogLabel.TextScaled = true
EmptyCatalogLabel.Visible = false

local PrevPageBtn = Instance.new("TextButton", CatalogFrame)
PrevPageBtn.Size = UDim2.new(0.4, -Scale("X", 6), 0, Scale("Y", 32))
PrevPageBtn.Position = UDim2.new(0, Scale("X", 4), 1, -Scale("Y", 36))
PrevPageBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
PrevPageBtn.BackgroundTransparency = 0.2
PrevPageBtn.Text = "< Prev"
PrevPageBtn.Font = Enum.Font.GothamBold
PrevPageBtn.TextScaled = true
PrevPageBtn.TextColor3 = Color3.new(1, 1, 1)
ApplyUICorner(PrevPageBtn, 6)

local NextPageBtn = Instance.new("TextButton", CatalogFrame)
NextPageBtn.Size = UDim2.new(0.4, -Scale("X", 6), 0, Scale("Y", 32))
NextPageBtn.Position = UDim2.new(0.6, Scale("X", 2), 1, -Scale("Y", 36))
NextPageBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
NextPageBtn.BackgroundTransparency = 0.2
NextPageBtn.Text = "Next >"
NextPageBtn.Font = Enum.Font.GothamBold
NextPageBtn.TextScaled = true
NextPageBtn.TextColor3 = Color3.new(1, 1, 1)
ApplyUICorner(NextPageBtn, 6)

local PageIndicatorBox = Instance.new("TextBox", CatalogFrame)
PageIndicatorBox.Size = UDim2.new(0.2, 0, 0, Scale("Y", 32))
PageIndicatorBox.Position = UDim2.new(0.4, Scale("X", 2), 1, -Scale("Y", 36))
PageIndicatorBox.BackgroundTransparency = 1
PageIndicatorBox.Font = Enum.Font.Gotham
PageIndicatorBox.TextScaled = true
PageIndicatorBox.TextColor3 = Color3.new(1, 1, 1)
PageIndicatorBox.Text = "1 / Enter page"

local PageErrorLabel = Instance.new("TextLabel", CatalogFrame)
PageErrorLabel.Size = UDim2.new(0.3, 0, 0, Scale("Y", 24))
PageErrorLabel.Position = UDim2.new(0.35, 0, 1, -Scale("Y", 68))
PageErrorLabel.BackgroundTransparency = 1
PageErrorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
PageErrorLabel.Font = Enum.Font.Gotham
PageErrorLabel.TextScaled = true
PageErrorLabel.Text = ""
PageErrorLabel.Visible = false

local function UpdatePaginationUI()
    PrevPageBtn.Visible = (currentPageNumber > 1)
    if catalogPageCursor and typeof(catalogPageCursor.IsFinished) == "boolean" then
        NextPageBtn.Visible = not catalogPageCursor.IsFinished
    else
        NextPageBtn.Visible = true
    end
end

local catalogRenderId = 0
local function RenderCatalogPage(pageDataObj)
    catalogRenderId = catalogRenderId + 1
    local myRenderId = catalogRenderId
    PageIndicatorBox.Text = "Loading..."

    for _, child in ipairs(CatalogScrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local items = nil
    local success, result = pcall(function()
        return pageDataObj:GetCurrentPage()
    end)
    
    if success then
        items = result
    else
        PageIndicatorBox.Text = "ERROR"
        return
    end

    if myRenderId ~= catalogRenderId then return end

    if items and #items > 0 then
        EmptyCatalogLabel.Visible = false
        local myTabId = currentTabId
        
        local startTime = os.clock()
        for _, item in ipairs(items) do
            if currentTabId ~= myTabId or myRenderId ~= catalogRenderId then break end
            local card = CreateCatalogCard(item)
            card.Parent = CatalogScrollFrame
            
            if os.clock() - startTime > 0.005 then
                RunService.RenderStepped:Wait()
                startTime = os.clock()
            end
        end
    else
        EmptyCatalogLabel.Visible = true
    end

    if myRenderId == catalogRenderId then
        CatalogScrollFrame.CanvasSize = UDim2.new(0, 0, 0, CatalogGridLayout.AbsoluteContentSize.Y + 8)
        PageIndicatorBox.Text = tostring(currentPageNumber) .. " / Enter page"
        UpdatePaginationUI()
    end
end

local function GetPageOffset(targetPage)
    local initialPage = FetchCatalogPage(currentSearchQuery)
    if not initialPage then return nil end

    for i = 2, targetPage do
        if initialPage.IsFinished then break end
        local success = pcall(function()
            initialPage:AdvanceToNextPageAsync()
        end)
        if not success then break end
    end
    return initialPage
end

local function PerformSearch(query)
    currentSearchQuery = query or ""
    currentPageNumber = 1
    PageIndicatorBox.Text = "Loading..."
    catalogPageCursor = FetchCatalogPage(currentSearchQuery)
    if catalogPageCursor then RenderCatalogPage(catalogPageCursor) end
end

RefreshBtn.MouseButton1Click:Connect(function()
    PerformSearch(SearchBox.Text)
end)

SearchBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then PerformSearch(SearchBox.Text) end
end)

SortBtn.MouseButton1Click:Connect(function()
    currentSortIndex = currentSortIndex % #SortTypes + 1
    SortBtn.Text = "Sort: " .. SortTypes[currentSortIndex][2]
    PerformSearch(currentSearchQuery)
end)

local function GoNextPage()
    if not catalogPageCursor or catalogPageCursor.IsFinished then return end
    local success = pcall(function()
        catalogPageCursor:AdvanceToNextPageAsync()
    end)
    if success then
        currentPageNumber = currentPageNumber + 1
        RenderCatalogPage(catalogPageCursor)
    else
        local targetPage = currentPageNumber + 1
        local newCursor = GetPageOffset(targetPage)
        if newCursor then
            catalogPageCursor = newCursor
            currentPageNumber = math.min(targetPage, currentPageNumber + 1)
            RenderCatalogPage(catalogPageCursor)
        end
    end
end

local function GoPrevPage()
    if not catalogPageCursor or currentPageNumber <= 1 then return end
    local success = pcall(function()
        catalogPageCursor:AdvanceToPreviousPageAsync()
    end)
    if success then
        currentPageNumber = math.max(1, currentPageNumber - 1)
        RenderCatalogPage(catalogPageCursor)
    else
        local targetPage = math.max(1, currentPageNumber - 1)
        local newCursor = GetPageOffset(targetPage)
        if newCursor then
            catalogPageCursor = newCursor
            currentPageNumber = targetPage
            RenderCatalogPage(catalogPageCursor)
        end
    end
end

NextPageBtn.MouseButton1Click:Connect(GoNextPage)
PrevPageBtn.MouseButton1Click:Connect(GoPrevPage)

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.Right then
            GoNextPage()
        elseif input.KeyCode == Enum.KeyCode.Left then
            GoPrevPage()
        end
    end
end)

PageIndicatorBox.FocusLost:Connect(function(enterPressed)
    if not enterPressed then return end
    local sanitized = PageIndicatorBox.Text:gsub("%s+", "")
    local pageNum = tonumber(sanitized:match("%d+"))
    
    if not pageNum or pageNum < 1 then
        PageErrorLabel.Text = "Invalid page number"
        PageErrorLabel.Visible = true
        task.delay(2, function()
            if PageErrorLabel then PageErrorLabel.Visible = false end
        end)
        PageIndicatorBox.Text = "Page " .. tostring(currentPageNumber)
        return
    end

    local targetNum = math.floor(pageNum)
    if targetNum == currentPageNumber then
        PageIndicatorBox.Text = "Page " .. tostring(currentPageNumber)
        return
    end

    PageIndicatorBox.Text = "Loading..."
    local success, result = pcall(function()
        return GetPageOffset(targetNum)
    end)

    if not success or not result then
        PageErrorLabel.Text = "Unable to fetch page"
        PageErrorLabel.Visible = true
        task.delay(2, function()
            if PageErrorLabel then PageErrorLabel.Visible = false end
        end)
        PageIndicatorBox.Text = "Page " .. tostring(currentPageNumber)
        return
    end

    catalogPageCursor = result
    currentPageNumber = math.max(1, targetNum)
    RenderCatalogPage(catalogPageCursor)
end)

local function CreateSavedCard(item)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, Scale("X", 120), 0, Scale("Y", 200))
    card.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    card.BackgroundTransparency = 0.2
    ApplyUICorner(card, 8)
    ApplyUIStroke(card, Color3.fromRGB(60, 60, 90), 1)

    local thumbnail = Instance.new("ImageLabel")
    thumbnail.Size = UDim2.new(1, -Scale("X", 10), 0, Scale("Y", 90))
    thumbnail.Position = UDim2.new(0, Scale("X", 5), 0, Scale("Y", 5))
    thumbnail.BackgroundTransparency = 1
    thumbnail.ScaleType = Enum.ScaleType.Fit
    thumbnail.Image = "rbxthumb://type=Asset&id=" .. tonumber(item.AssetId or item.Id) .. "&w=150&h=150"
    thumbnail.Parent = card
    ApplyUICorner(thumbnail, 4)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -Scale("X", 10), 0, Scale("Y", 28))
    nameLabel.Position = UDim2.new(0, Scale("X", 5), 0, Scale("Y", 100))
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = item.Name or "Unknown"
    nameLabel.TextScaled = true
    nameLabel.TextWrapped = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Parent = card

    local playBtn = Instance.new("TextButton")
    playBtn.Size = UDim2.new(0.45, -Scale("X", 5), 0, Scale("Y", 24))
    playBtn.Position = UDim2.new(0, Scale("X", 5), 1, -Scale("Y", 29))
    playBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
    playBtn.BackgroundTransparency = 0.2
    playBtn.Text = "Play"
    playBtn.Font = Enum.Font.GothamBold
    playBtn.TextScaled = true
    playBtn.TextColor3 = Color3.new(1, 1, 1)
    playBtn.Parent = card
    ApplyUICorner(playBtn, 4)
    
    playBtn.MouseButton1Click:Connect(function()
        PlayEmote(item.Id)
    end)

    local removeBtn = Instance.new("TextButton")
    removeBtn.Size = UDim2.new(0.45, -Scale("X", 5), 0, Scale("Y", 24))
    removeBtn.Position = UDim2.new(0.55, 0, 1, -Scale("Y", 29))
    removeBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
    removeBtn.BackgroundTransparency = 0.2
    removeBtn.Text = "Remove"
    removeBtn.Font = Enum.Font.GothamBold
    removeBtn.TextScaled = true
    removeBtn.TextColor3 = Color3.new(1, 1, 1)
    removeBtn.Parent = card
    ApplyUICorner(removeBtn, 4)

    local copyAnimIdBtn = Instance.new("TextButton")
    copyAnimIdBtn.Size = UDim2.new(0, Scale("X", 40), 0, Scale("Y", 24))
    copyAnimIdBtn.Position = UDim2.new(0.5, -Scale("X", 20), 0, Scale("Y", 5))
    copyAnimIdBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
    copyAnimIdBtn.BackgroundTransparency = 0.2
    copyAnimIdBtn.Text = "Copy AnimId"
    copyAnimIdBtn.Font = Enum.Font.GothamBold
    copyAnimIdBtn.TextScaled = true
    copyAnimIdBtn.TextColor3 = Color3.new(1, 1, 1)
    copyAnimIdBtn.Parent = card
    ApplyUICorner(copyAnimIdBtn, 4)
    
    copyAnimIdBtn.MouseButton1Click:Connect(function()
        if setclipboard then setclipboard(item.AnimationId:gsub("rbxassetid://", "")) end
        copyAnimIdBtn.Text = "Copied!"
        task.wait(0.7)
        copyAnimIdBtn.Text = "Copy AnimId"
    end)

    local favoriteBtn = Instance.new("TextButton")
    favoriteBtn.Size = UDim2.new(0, Scale("X", 24), 0, Scale("Y", 24))
    favoriteBtn.Position = UDim2.new(1, -Scale("X", 30), 0, Scale("Y", 5))
    favoriteBtn.Text = item.Favorite and "★" or "☆"
    favoriteBtn.Font = Enum.Font.GothamBold
    favoriteBtn.TextScaled = true
    favoriteBtn.TextColor3 = Color3.fromRGB(255, 220, 50)
    favoriteBtn.BackgroundTransparency = 1
    favoriteBtn.Parent = card

    favoriteBtn.MouseButton1Click:Connect(function()
        item.Favorite = not item.Favorite
        favoriteBtn.Text = item.Favorite and "★" or "☆"
        SaveEmotes()
        if RefreshSavedList then RefreshSavedList() end
    end)

    removeBtn.MouseButton1Click:Connect(function()
        for i, savedItem in ipairs(SavedEmotes) do
            if savedItem.Id == item.Id then
                table.remove(SavedEmotes, i)
                SaveEmotes()
                if RefreshSavedList then RefreshSavedList() end
                break
            end
        end
    end)

    return card
end

local savedRenderId = 0
RefreshSavedList = function()
    savedRenderId = savedRenderId + 1
    local myRenderId = savedRenderId

    for _, child in ipairs(SavedScrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local searchQuery = (SearchSavedBox.Text or ""):lower()
    local filteredList = {}

    for _, item in ipairs(SavedEmotes) do
        if searchQuery == "" or (item.Name and item.Name:lower():find(searchQuery)) then
            table.insert(filteredList, item)
        end
    end

    table.sort(filteredList, function(a, b)
        if a.Favorite ~= b.Favorite then
            return a.Favorite
        else
            return false
        end
    end)

    if #filteredList > 0 then
        EmptySavedLabel.Visible = false
        local myTabId = currentTabId
        
        local startTime = os.clock()
        for _, item in ipairs(filteredList) do
            if currentTabId ~= myTabId or myRenderId ~= savedRenderId then break end
            local card = CreateSavedCard(item)
            card.Parent = SavedScrollFrame
            
            if os.clock() - startTime > 0.005 then
                RunService.RenderStepped:Wait()
                startTime = os.clock()
            end
        end
    else
        EmptySavedLabel.Visible = true
    end

    if myRenderId == savedRenderId then
        SavedScrollFrame.CanvasSize = UDim2.new(0, 0, 0, SavedGridLayout.AbsoluteContentSize.Y + 8)
    end
end

CatalogTab.MouseButton1Click:Connect(function()
    currentTabId = currentTabId + 1
    CatalogFrame.Visible = true
    SavedFrame.Visible = false
    CatalogTab.BackgroundColor3 = Color3.fromRGB(30, 30, 80)
    SavedTab.BackgroundColor3 = Color3.fromRGB(20, 50, 20)
end)

SearchSavedBox:GetPropertyChangedSignal("Text"):Connect(RefreshSavedList)

SavedTab.MouseButton1Click:Connect(function()
    currentTabId = currentTabId + 1
    CatalogFrame.Visible = false
    SavedFrame.Visible = true
    CatalogTab.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
    SavedTab.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
    RefreshSavedList()
end)

PerformSearch("")

local function ToggleMainUI()
    MainGui.Enabled = not MainGui.Enabled
end

local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "ToggleButtonGui"
ToggleGui.ResetOnSpawn = false
ToggleGui.Parent = CoreGui
ToggleGui.Enabled = true

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Parent = ToggleGui
ToggleBtn.Text = "G"
ToggleBtn.Font = Enum.Font.GothamSemibold
ToggleBtn.TextScaled = true
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0, 20, 0.5, -50)
ToggleBtn.AnchorPoint = Vector2.new(0, 0.5)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
ToggleBtn.BackgroundTransparency = 0.2
ToggleBtn.TextColor3 = Color3.new(1, 1, 1)
ToggleBtn.Active = true
pcall(function() ToggleBtn.Draggable = true end)

ApplyUICorner(ToggleBtn, 12)
ApplyUIStroke(ToggleBtn, Color3.fromRGB(60, 60, 100), 2)

local AspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
AspectRatioConstraint.Parent = ToggleBtn
AspectRatioConstraint.AspectRatio = 1

ToggleBtn.MouseButton1Click:Connect(ToggleMainUI)

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.G then
        ToggleMainUI()
    end
end)

MainGui.Enabled = true
RefreshSavedList()

task.spawn(function()
    local function SetupCollision(char)
        local hrp = char:WaitForChild("HumanoidRootPart")
        local bodyParts = {}
        hrp.CanCollide = true
        
        local function AddPart(part)
            if part:IsA("BasePart") and part ~= hrp then
                table.insert(bodyParts, part)
            end
        end
        
        for _, part in pairs(char:GetDescendants()) do
            AddPart(part)
        end
        
        local descendantConnection = char.DescendantAdded:Connect(AddPart)
        local heartbeatConnection
        
        heartbeatConnection = RunService.Heartbeat:Connect(function()
            if not char or not char.Parent then
                heartbeatConnection:Disconnect()
                descendantConnection:Disconnect()
                return
            end
            for i = 1, #bodyParts do
                local p = bodyParts[i]
                if p and p.Parent then
                    p.CanCollide = false
                end
            end
        end)
    end
    
    if LocalPlayer.Character then SetupCollision(LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(SetupCollision)
end)
