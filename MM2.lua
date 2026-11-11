local discordInvite = "https://discord.com/invite/Hh3DGutqeb"

local http_request = (syn and syn.request) or (http and http.request) or request
if http_request then
    http_request({
        Url = "http://127.0.0.1:6463/rpc?v=1",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["Origin"] = "https://discord.com"
        },
        Body = game:GetService("HttpService"):JSONEncode({
            cmd = "INVITE_BROWSER",
            args = {code = string.match(discordInvite, "discord%.com/invite/(%w+)")},
            nonce = game:GetService("HttpService"):GenerateGUID(false)
        })
    })
else
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Executor Not Supported",
        Text = "Join manually: "..discordInvite,
        Duration = 5
    })
end


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
assert(Drawing and Drawing.new, "Drawing API is not available in this environment.")
local MacLib = loadstring(game:HttpGet(
    "https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"
))()
local Window = MacLib:Window({
    Title = "Exoz Hub",
    Subtitle = "Murder Mystery 2",
    Size = UDim2.fromOffset(850, 600),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo = true,
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
})
local TabGroup = Window:TabGroup()
local VisualsTab = TabGroup:Tab({
    Name = "Visuals",
    Image = "rbxassetid://7733774602"
})
local normalizeRole, findToolContaining, GetPlayerRole
local RoundClient
local newDrawing, safeRemove, Cleanup
do
    task.spawn(function()
        local modules = game:GetService("ReplicatedStorage"):WaitForChild("Modules", 20)
        local module = modules and modules:WaitForChild("CurrentRoundClient", 20)
        if module and module:IsA("ModuleScript") then
            local ok, client = pcall(require, module)
            if ok and type(client) == "table" then
                RoundClient = client
            end
        end
    end)
    local Settings = {
        Enabled = true,
        Roles = {
            Murderer = true,
            Sheriff = true,
            Innocent = true,
        },
        ESP = {
            Box2D = true,
            Box3D = false,
            Tracers = false,
            Name = true,
            Role = true,
            Distance = true,
            Radar = false,
            MaxDistance = 2500,
            Thickness = 1,
            TextSize = 13,
        },
        Radar = {
            Range = 250,
            Radius = 90,
        },
        Colors = {
            Murderer = Color3.fromRGB(255, 70, 70),
            Sheriff = Color3.fromRGB(70, 150, 255),
            Hero = Color3.fromRGB(70, 150, 255),
            Innocent = Color3.fromRGB(120, 255, 120),
        }
    }

    function normalizeRole(value)
        if value == nil then
            return nil
        end
        value = string.lower(tostring(value))
        if string.find(value, "murder") or value == "killer" then
            return "Murderer"
        end
        if value == "hero" then
            return "Hero"
        end
        if string.find(value, "sheriff")
            or string.find(value, "detective")
            or value == "cop"
        then
            return "Sheriff"
        end
        if string.find(value, "innocent")
            or value == "civilian"
            or value == "survivor"
        then
            return "Innocent"
        end
        return nil
    end

    function findToolContaining(container, words)
        if not container then
            return false
        end
        for _, object in ipairs(container:GetChildren()) do
            if object:IsA("Tool") then
                local lowerName = string.lower(object.Name)
                for _, word in ipairs(words) do
                    if string.find(lowerName, word) then
                        return true
                    end
                end
            end
        end
        return false
    end

    function GetPlayerRole(player)
        if not player then return nil end
        if RoundClient and type(RoundClient.PlayerData) == "table" then
            local data = RoundClient.PlayerData[player.Name]
                or RoundClient.PlayerData[player.UserId]
            if type(data) == "table" then
                if data.Role ~= nil then
                    return normalizeRole(data.Role)
                end
                return nil
            end
        end
        local character = player.Character
        local role = normalizeRole(player:GetAttribute("Role"))
            or normalizeRole(player:GetAttribute("PlayerRole"))
        if not role and character then
            role = normalizeRole(character:GetAttribute("Role"))
                or normalizeRole(character:GetAttribute("PlayerRole"))
        end
        if role then return role end
        for _, holder in ipairs({ player, character }) do
            if holder then
                if holder:GetAttribute("IsMurderer") == true then return "Murderer" end
                if holder:GetAttribute("IsSheriff") == true then return "Sheriff" end
                if holder:GetAttribute("IsInnocent") == true then return "Innocent" end
                local value = holder:FindFirstChild("Role")
                if value and value:IsA("StringValue") then
                    role = normalizeRole(value.Value)
                    if role then return role end
                end
            end
        end
        if player.Team then
            role = normalizeRole(player.Team.Name)
            if role then return role end
        end
        local backpack = player:FindFirstChildOfClass("Backpack")
        for _, container in ipairs({ character, backpack }) do
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") then
                        if tool:HasTag("Weapon_Knife") then return "Murderer" end
                        if tool:HasTag("Weapon_Gun") then return "Sheriff" end
                    end
                end
            end
        end
        return nil
    end

    function newDrawing(class, properties)
        local object = Drawing.new(class)
        for property, value in pairs(properties or {}) do
            object[property] = value
        end
        return object
    end

    function safeRemove(object)
        if object then
            pcall(function()
                object:Remove()
            end)
        end
    end
    local ESPObjects = {}
    local BoxEdges = {
        {1, 2},
        {2, 3},
        {3, 4},
        {4, 1},
        {5, 6},
        {6, 7},
        {7, 8},
        {8, 5},
        {1, 5},
        {2, 6},
        {3, 7},
        {4, 8},
    }

    local function CreateESP(player)
        if player == LocalPlayer then
            return
        end
        local esp = {
            Player = player,
            Box = newDrawing("Square", {
                Visible = false,
                Filled = false,
                Thickness = 1,
                Transparency = 1,
            }),
            BoxOutline = newDrawing("Square", {
                Visible = false,
                Filled = false,
                Thickness = 3,
                Transparency = 0.65,
                Color = Color3.new(0, 0, 0),
            }),
            Tracer = newDrawing("Line", {
                Visible = false,
                Thickness = 1,
                Transparency = 1,
            }),
            Name = newDrawing("Text", {
                Visible = false,
                Center = true,
                Outline = true,
                Font = 2,
                Size = 13,
                Transparency = 1,
            }),
            Distance = newDrawing("Text", {
                Visible = false,
                Center = true,
                Outline = true,
                Font = 2,
                Size = 13,
                Transparency = 1,
            }),
            Role = newDrawing("Text", {
                Visible = false,
                Center = true,
                Outline = true,
                Font = 2,
                Size = 13,
                Transparency = 1,
            }),
            RadarDot = newDrawing("Circle", {
                Visible = false,
                Radius = 4,
                Filled = true,
                Thickness = 1,
                Transparency = 1,
            }),
            Box3D = {}
        }
        for i = 1, 12 do
            esp.Box3D[i] = newDrawing("Line", {
                Visible = false,
                Thickness = 1,
                Transparency = 1,
            })
        end
        ESPObjects[player] = esp
    end

    local function HideESP(esp)
        esp.Box.Visible = false
        esp.BoxOutline.Visible = false
        esp.Tracer.Visible = false
        esp.Name.Visible = false
        esp.Distance.Visible = false
        esp.Role.Visible = false
        esp.RadarDot.Visible = false
        for _, line in ipairs(esp.Box3D) do
            line.Visible = false
        end
    end

    local function RemoveESP(player)
        local esp = ESPObjects[player]
        if not esp then
            return
        end
        safeRemove(esp.Box)
        safeRemove(esp.BoxOutline)
        safeRemove(esp.Tracer)
        safeRemove(esp.Name)
        safeRemove(esp.Distance)
        safeRemove(esp.Role)
        safeRemove(esp.RadarDot)
        for _, line in ipairs(esp.Box3D) do
            safeRemove(line)
        end
        ESPObjects[player] = nil
    end

    local function GetBoundingCorners(character)
        local root = character:FindFirstChild("HumanoidRootPart")
        local head = character:FindFirstChild("Head")
        if not root or not head then
            return nil
        end
        local height = math.max(
            5,
            math.abs(head.Position.Y - root.Position.Y) * 2 + 3
        )
        local width = 4
        local depth = 2.5
        local boxCFrame = CFrame.new(
            root.Position + Vector3.new(0, 0.4, 0)
        ) * CFrame.Angles(
            0,
            math.rad(root.Orientation.Y),
            0
        )
        local x = width / 2
        local y = height / 2
        local z = depth / 2
        return {
            boxCFrame * Vector3.new(-x, -y, -z),
            boxCFrame * Vector3.new( x, -y, -z),
            boxCFrame * Vector3.new( x,  y, -z),
            boxCFrame * Vector3.new(-x,  y, -z),
            boxCFrame * Vector3.new(-x, -y,  z),
            boxCFrame * Vector3.new( x, -y,  z),
            boxCFrame * Vector3.new( x,  y,  z),
            boxCFrame * Vector3.new(-x,  y,  z),
        }
    end

    local function GetScreenBoundingBox(corners)
        local minX = math.huge
        local minY = math.huge
        local maxX = -math.huge
        local maxY = -math.huge
        local visiblePoints = 0
        for _, worldPosition in ipairs(corners) do
            local screenPosition, onScreen =
                Camera:WorldToViewportPoint(worldPosition)
            if screenPosition.Z > 0 then
                visiblePoints += 1
                minX = math.min(minX, screenPosition.X)
                minY = math.min(minY, screenPosition.Y)
                maxX = math.max(maxX, screenPosition.X)
                maxY = math.max(maxY, screenPosition.Y)
            end
        end
        if visiblePoints == 0 then
            return nil
        end
        return Vector2.new(minX, minY),
               Vector2.new(maxX, maxY)
    end
    local RadarBackground = newDrawing("Circle", {
        Visible = false,
        Radius = Settings.Radar.Radius,
        Filled = true,
        Thickness = 1,
        Transparency = 0.30,
        Color = Color3.fromRGB(15, 15, 15),
    })
    local RadarOutline = newDrawing("Circle", {
        Visible = false,
        Radius = Settings.Radar.Radius,
        Filled = false,
        Thickness = 1,
        Transparency = 0.8,
        Color = Color3.fromRGB(255, 255, 255),
    })
    local RadarCrossHorizontal = newDrawing("Line", {
        Visible = false,
        Thickness = 1,
        Transparency = 0.4,
        Color = Color3.fromRGB(255, 255, 255),
    })
    local RadarCrossVertical = newDrawing("Line", {
        Visible = false,
        Thickness = 1,
        Transparency = 0.4,
        Color = Color3.fromRGB(255, 255, 255),
    })
    local RadarLocalDot = newDrawing("Circle", {
        Visible = false,
        Radius = 4,
        Filled = true,
        Thickness = 1,
        Transparency = 1,
        Color = Color3.fromRGB(255, 255, 255),
    })

    local function GetRadarCenter()
        local viewport = Camera.ViewportSize
        return Vector2.new(
            viewport.X - Settings.Radar.Radius - 30,
            Settings.Radar.Radius + 45
        )
    end

    local function UpdateRadarBase()
        local enabled = Settings.Enabled and Settings.ESP.Radar
        local center = GetRadarCenter()
        local radius = Settings.Radar.Radius
        RadarBackground.Visible = enabled
        RadarOutline.Visible = enabled
        RadarCrossHorizontal.Visible = enabled
        RadarCrossVertical.Visible = enabled
        RadarLocalDot.Visible = enabled
        if not enabled then
            return
        end
        RadarBackground.Position = center
        RadarBackground.Radius = radius
        RadarOutline.Position = center
        RadarOutline.Radius = radius
        RadarLocalDot.Position = center
        RadarCrossHorizontal.From =
            Vector2.new(center.X - radius, center.Y)
        RadarCrossHorizontal.To =
            Vector2.new(center.X + radius, center.Y)
        RadarCrossVertical.From =
            Vector2.new(center.X, center.Y - radius)
        RadarCrossVertical.To =
            Vector2.new(center.X, center.Y + radius)
    end

    local function UpdateRadarDot(esp, targetRoot, role)
        if not Settings.ESP.Radar then
            esp.RadarDot.Visible = false
            return
        end
        local localCharacter = LocalPlayer.Character
        if not localCharacter then
            esp.RadarDot.Visible = false
            return
        end
        local localRoot =
            localCharacter:FindFirstChild("HumanoidRootPart")
        if not localRoot then
            esp.RadarDot.Visible = false
            return
        end
        local worldDelta =
            targetRoot.Position - localRoot.Position
        local flatDelta =
            Vector3.new(worldDelta.X, 0, worldDelta.Z)
        local cameraRight =
            Vector3.new(
                Camera.CFrame.RightVector.X,
                0,
                Camera.CFrame.RightVector.Z
            )
        local cameraForward =
            Vector3.new(
                Camera.CFrame.LookVector.X,
                0,
                Camera.CFrame.LookVector.Z
            )
        if cameraRight.Magnitude <= 0.001
            or cameraForward.Magnitude <= 0.001
        then
            esp.RadarDot.Visible = false
            return
        end
        cameraRight = cameraRight.Unit
        cameraForward = cameraForward.Unit
        local relativeX = flatDelta:Dot(cameraRight)
        local relativeY = -flatDelta:Dot(cameraForward)
        local radarRange = Settings.Radar.Range
        local radius = Settings.Radar.Radius
        local radarOffset = Vector2.new(
            relativeX / radarRange * radius,
            relativeY / radarRange * radius
        )
        if radarOffset.Magnitude > radius - 6 then
            radarOffset =
                radarOffset.Unit * (radius - 6)
        end
        local center = GetRadarCenter()
        esp.RadarDot.Position =
            center + radarOffset
        esp.RadarDot.Color =
            Settings.Colors[role]
        esp.RadarDot.Visible = true
    end

    local function IsRoleEnabled(role)
        if role == "Murderer" then
            return Settings.Roles.Murderer
        elseif role == "Sheriff" or role == "Hero" then
            return Settings.Roles.Sheriff
        elseif role == "Innocent" then
            return Settings.Roles.Innocent
        end
        return false
    end

    local function UpdateESP(esp)
        local player = esp.Player
        if not Settings.Enabled then
            HideESP(esp)
            return
        end
        local character = player.Character
        if not character then
            HideESP(esp)
            return
        end
        local humanoid =
            character:FindFirstChildOfClass("Humanoid")
        local root =
            character:FindFirstChild("HumanoidRootPart")
        if not humanoid
            or not root
            or humanoid.Health <= 0
        then
            HideESP(esp)
            return
        end
        local role = GetPlayerRole(player)
        if not IsRoleEnabled(role) then
            HideESP(esp)
            return
        end
        local color =
            Settings.Colors[role]
            or Color3.new(1, 1, 1)
        local distance =
            (Camera.CFrame.Position - root.Position).Magnitude
        if distance > Settings.ESP.MaxDistance then
            HideESP(esp)
            return
        end
        local rootScreen, rootVisible =
            Camera:WorldToViewportPoint(root.Position)
        if rootScreen.Z <= 0 then
            HideESP(esp)
            return
        end
    local corners = GetBoundingCorners(character)
    if not corners then
        HideESP(esp)
        return
    end
    local topLeft, bottomRight =
        GetScreenBoundingBox(corners)
        if not topLeft or not bottomRight then
            HideESP(esp)
            return
        end
        local width =
            bottomRight.X - topLeft.X
        local height =
            bottomRight.Y - topLeft.Y
        esp.Box.Visible =
            Settings.ESP.Box2D
        esp.BoxOutline.Visible =
            Settings.ESP.Box2D
        if Settings.ESP.Box2D then
            esp.Box.Position = topLeft
            esp.Box.Size = Vector2.new(width, height)
            esp.Box.Color = color
            esp.Box.Thickness = Settings.ESP.Thickness
            esp.BoxOutline.Position = topLeft
            esp.BoxOutline.Size = Vector2.new(width, height)
            esp.BoxOutline.Thickness =
                Settings.ESP.Thickness + 2
        end
        if Settings.ESP.Box3D then
            local projected = {}
            local valid = true
            for index, corner in ipairs(corners) do
                local screen =
                    Camera:WorldToViewportPoint(corner)
                if screen.Z <= 0 then
                    valid = false
                    break
                end
                projected[index] =
                    Vector2.new(screen.X, screen.Y)
            end
            for index, edge in ipairs(BoxEdges) do
                local line = esp.Box3D[index]
                if valid then
                    line.From = projected[edge[1]]
                    line.To = projected[edge[2]]
                    line.Color = color
                    line.Thickness =
                        Settings.ESP.Thickness
                    line.Visible = true
                else
                    line.Visible = false
                end
            end
        else
            for _, line in ipairs(esp.Box3D) do
                line.Visible = false
            end
        end
        esp.Tracer.Visible =
            Settings.ESP.Tracers
        if Settings.ESP.Tracers then
            esp.Tracer.From = Vector2.new(
                Camera.ViewportSize.X / 2,
                Camera.ViewportSize.Y - 10
            )
            esp.Tracer.To =
                Vector2.new(
                    rootScreen.X,
                    rootScreen.Y
                )
            esp.Tracer.Color = color
            esp.Tracer.Thickness =
                Settings.ESP.Thickness
        end
        esp.Name.Visible =
            Settings.ESP.Name
        if Settings.ESP.Name then
            esp.Name.Text = player.DisplayName
            esp.Name.Size =
                Settings.ESP.TextSize
            esp.Name.Color = color
            esp.Name.Position =
                Vector2.new(
                    topLeft.X + width / 2,
                    topLeft.Y - 18
                )
        end
        esp.Role.Visible =
            Settings.ESP.Role
        if Settings.ESP.Role then
            esp.Role.Text = role
            esp.Role.Size =
                Settings.ESP.TextSize
            esp.Role.Color = color
            local offset =
                Settings.ESP.Name and 14 or 0
            esp.Role.Position =
                Vector2.new(
                    topLeft.X + width / 2,
                    topLeft.Y - 18 - offset
                )
        end
        esp.Distance.Visible =
            Settings.ESP.Distance
        if Settings.ESP.Distance then
            esp.Distance.Text =
                tostring(math.floor(distance))
                .. " studs"
            esp.Distance.Size =
                Settings.ESP.TextSize
            esp.Distance.Color = color
            esp.Distance.Position =
                Vector2.new(
                    topLeft.X + width / 2,
                    bottomRight.Y + 3
                )
        end
        UpdateRadarDot(
            esp,
            root,
            role
        )
    end
    for _, player in ipairs(Players:GetPlayers()) do
        CreateESP(player)
    end
    local PlayerAddedConnection =
        Players.PlayerAdded:Connect(function(player)
            CreateESP(player)
        end)
    local PlayerRemovingConnection =
        Players.PlayerRemoving:Connect(function(player)
            RemoveESP(player)
        end)
    local RenderConnection =
        RunService.RenderStepped:Connect(function()
            Camera = workspace.CurrentCamera
            UpdateRadarBase()
            for _, esp in pairs(ESPObjects) do
                UpdateESP(esp)
            end
        end)
    local RoleSection =
        VisualsTab:Section({
            Side = "Left"
        })
    local ESPSection =
        VisualsTab:Section({
            Side = "Right"
        })
    local SettingsSection =
        VisualsTab:Section({
            Side = "Right"
        })
    RoleSection:Header({
        Name = "Visuals"
    })
    RoleSection:Toggle({
        Name = "Enable ESP",
        Default = Settings.Enabled,
        Callback = function(value)
            Settings.Enabled = value
            if not value then
                for _, esp in pairs(ESPObjects) do
                    HideESP(esp)
                end
            end
        end
    }, "ESPEnabled")
    RoleSection:Header({
        Name = "Role Filters"
    })
    RoleSection:Toggle({
        Name = "Murderer",
        Default = Settings.Roles.Murderer,
        Callback = function(value)
            Settings.Roles.Murderer = value
        end
    }, "MurdererESP")
    RoleSection:Toggle({
        Name = "Sheriff",
        Default = Settings.Roles.Sheriff,
        Callback = function(value)
            Settings.Roles.Sheriff = value
        end
    }, "SheriffESP")
    RoleSection:Toggle({
        Name = "Innocent",
        Default = Settings.Roles.Innocent,
        Callback = function(value)
            Settings.Roles.Innocent = value
        end
    }, "InnocentESP")
    RoleSection:Header({
        Name = "Role Colors"
    })
    RoleSection:Colorpicker({
        Name = "Murderer Color",
        Default = Settings.Colors.Murderer,
        Callback = function(color)
            Settings.Colors.Murderer = color
        end
    }, "MurdererColor")
    RoleSection:Colorpicker({
        Name = "Sheriff Color",
        Default = Settings.Colors.Sheriff,
        Callback = function(color)
            Settings.Colors.Sheriff = color
            Settings.Colors.Hero = color
        end
    }, "SheriffColor")
    RoleSection:Colorpicker({
        Name = "Innocent Color",
        Default = Settings.Colors.Innocent,
        Callback = function(color)
            Settings.Colors.Innocent = color
        end
    }, "InnocentColor")
    ESPSection:Header({
        Name = "ESP Types"
    })
    ESPSection:Toggle({
        Name = "2D Box",
        Default = Settings.ESP.Box2D,
        Callback = function(value)
            Settings.ESP.Box2D = value
        end
    }, "Box2D")
    ESPSection:Toggle({
        Name = "3D Box",
        Default = Settings.ESP.Box3D,
        Callback = function(value)
            Settings.ESP.Box3D = value
        end
    }, "Box3D")
    ESPSection:Toggle({
        Name = "Tracers",
        Default = Settings.ESP.Tracers,
        Callback = function(value)
            Settings.ESP.Tracers = value
        end
    }, "Tracers")
    ESPSection:Toggle({
        Name = "Name",
        Default = Settings.ESP.Name,
        Callback = function(value)
            Settings.ESP.Name = value
        end
    }, "Names")
    ESPSection:Toggle({
        Name = "Role",
        Default = Settings.ESP.Role,
        Callback = function(value)
            Settings.ESP.Role = value
        end
    }, "Roles")
    ESPSection:Toggle({
        Name = "Distance",
        Default = Settings.ESP.Distance,
        Callback = function(value)
            Settings.ESP.Distance = value
        end
    }, "Distance")
    ESPSection:Toggle({
        Name = "Radar",
        Default = Settings.ESP.Radar,
        Callback = function(value)
            Settings.ESP.Radar = value
        end
    }, "Radar")
    SettingsSection:Header({
        Name = "ESP Settings"
    })
    SettingsSection:Slider({
        Name = "Max Distance",
        Default = Settings.ESP.MaxDistance,
        Minimum = 100,
        Maximum = 5000,
        DisplayMethod = "Value",
        Precision = 0,
        Callback = function(value)
            Settings.ESP.MaxDistance = value
        end
    }, "MaxDistance")
    SettingsSection:Slider({
        Name = "Line Thickness",
        Default = Settings.ESP.Thickness,
        Minimum = 1,
        Maximum = 5,
        DisplayMethod = "Value",
        Precision = 0,
        Callback = function(value)
            Settings.ESP.Thickness = value
        end
    }, "Thickness")
    SettingsSection:Slider({
        Name = "Text Size",
        Default = Settings.ESP.TextSize,
        Minimum = 10,
        Maximum = 24,
        DisplayMethod = "Value",
        Precision = 0,
        Callback = function(value)
            Settings.ESP.TextSize = value
        end
    }, "TextSize")
    SettingsSection:Header({
        Name = "Radar Settings"
    })
    SettingsSection:Slider({
        Name = "Radar Range",
        Default = Settings.Radar.Range,
        Minimum = 50,
        Maximum = 1000,
        DisplayMethod = "Value",
        Precision = 0,
        Callback = function(value)
            Settings.Radar.Range = value
        end
    }, "RadarRange")
    SettingsSection:Slider({
        Name = "Radar Size",
        Default = Settings.Radar.Radius,
        Minimum = 50,
        Maximum = 150,
        DisplayMethod = "Value",
        Precision = 0,
        Callback = function(value)
            Settings.Radar.Radius = value
        end
    }, "RadarSize")

    function Cleanup()
        if RenderConnection then
            RenderConnection:Disconnect()
        end
        if PlayerAddedConnection then
            PlayerAddedConnection:Disconnect()
        end
        if PlayerRemovingConnection then
            PlayerRemovingConnection:Disconnect()
        end
        for player in pairs(ESPObjects) do
            RemoveESP(player)
        end
        safeRemove(RadarBackground)
        safeRemove(RadarOutline)
        safeRemove(RadarCrossHorizontal)
        safeRemove(RadarCrossVertical)
        safeRemove(RadarLocalDot)
    end
end
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FarmSettings = {
    Enabled = false,
    ThroughWalls = true,
    NearestFirst = true,
    Speed = 45,
    AutoResetOnFull = false,
    StopReturnOnFull = false,
    FullBagHero = false,
    AutoRejoin = false,
    AntiFling = false,
    SkipOtherPlayers = true,
    RivalContactRadius = 1,
    AvoidMurderer = true,
    MurdererRadius = 16,
    PathDangerRadius = 16,
    FreshSpawnWindow = 1.5,
    FreshSpawnBonus = 1.00,
    RetargetInterval = 0.18,
    RetargetGain = 1.35,
}
local AutoFarm = {}
local InnocentEvading = false
local MiscMovementBusy = false
local FarmConnections = {}
local CoinConnections = setmetatable({}, { __mode = "k" })
local KnownCoins = setmetatable({}, { __mode = "k" })
local RecentAttempts = setmetatable({}, { __mode = "k" })
local SpawnNodes = {}
local PlayerSnapshots = setmetatable({}, { __mode = "k" })
local Token = 0
local CurrentTween = nil
local CurrentTarget = nil
local MotionConnection = nil
local CharacterState = nil
local RoundActive = nil
local FarmStartCFrame = nil
local FarmStartCharacter = nil
local BagFull = false
local BagFullHandled = false
local BagHandling = false
local beginBagHero
local stopBagHero
local HeroState = {
    Running = false,
    Generation = 0,
    BagHeroMode = false,
    GunReady = false,
    TargetPart = nil,
    TriedThisBag = false,
    RoundId = 0,
    FullRoundId = nil,
    FullCharacter = nil,
}
local LastBagCount = nil
local LastBagMaximum = nil
local FarmEnabledToggle = nil
local AutoResetToggle = nil
local StopReturnToggle = nil
local UpdatingFarmUI = false
local AntiFlingConnection = nil
local AntiFlingRoot = nil
local AntiFlingSafeCFrame = nil
local HotspotLearning = {
    Regions = {},
    TotalLiveSpawns = 0,
    StartedAt = os.clock(),
    Generation = 0,
    LastCamp = nil,
    LastCampSwitch = 0,
    CampPlan = nil,
    CampDecisions = 0,
}
local CoinNavigation = {
    Target = nil,
    ChosenAt = 0,
    StartDistance = 0,
    LastSwitchAt = -math.huge,
}
local LastAttemptedPickup = nil
local LastAttemptedPickupTime = 0
local HotspotRoundStartSeen = false
local HttpService = game:GetService("HttpService")
local HotspotDisk = {
    File = "MiniScripts/MM2_AdaptiveHotspots.json",
    Maps = {},
    MapKey = nil,
    Dirty = false,
    Running = true,
    LastSave = 0,
    Available = type(readfile) == "function" and type(writefile) == "function",
}

local function safeCount(value, limit)
    local number = tonumber(value)
    if not number or number ~= number or number < 0 or number == math.huge then return 0 end
    return math.min(number, limit or 50000)
end

local function encodePosition(v)
    if typeof(v) ~= "Vector3" then return nil end
    return { math.round(v.X * 10) / 10, math.round(v.Y * 10) / 10, math.round(v.Z * 10) / 10 }
end

local function decodePosition(value)
    if type(value) ~= "table" then return nil end
    local x, y, z = tonumber(value[1]), tonumber(value[2]), tonumber(value[3])
    if not x or not y or not z then return nil end
    if x ~= x or y ~= y or z ~= z then return nil end
    if math.abs(x) > 100000 or math.abs(y) > 100000 or math.abs(z) > 100000 then return nil end
    return Vector3.new(x, y, z)
end
local MapIdentityCache = { Root = nil, CheckedAt = 0, Children = -1, Result = nil }

local function activeMapIdentity(coin)
    local map = workspace:FindFirstChild("Map")
        or workspace:FindFirstChild("CurrentMap")
        or workspace:FindFirstChild("GameMap")
    local mapName = nil
    if map then
        local childCount = #map:GetChildren()
        if MapIdentityCache.Root == map and MapIdentityCache.Children == childCount
            and os.clock() - MapIdentityCache.CheckedAt < 8
            and MapIdentityCache.Result then
            return MapIdentityCache.Result
        end
        mapName = map:GetAttribute("MapName")
            or map:GetAttribute("MapID") or map:GetAttribute("MapId")
        if not mapName then
            local nameValue = map:FindFirstChild("MapName")
            if nameValue and nameValue:IsA("StringValue") then mapName = nameValue.Value end
        end
        if not mapName then
            local candidates = {}
            local generic = {
                Map = true, Coins = true, CoinContainer = true, Coin_Server = true,
                CoinSpawns = true, Spawns = true, Assets = true, Props = true,
                Decorations = true, Environment = true, Geometry = true,
                Main = true, Parts = true, Furniture = true, Lobby = true,
            }
            for _, child in ipairs(map:GetChildren()) do
                if child:IsA("Model") and not generic[child.Name] then
                    table.insert(candidates, child.Name)
                end
            end
            if #candidates == 1 then mapName = candidates[1] end
        end
        if not mapName and map.Name ~= "Map" and map.Name ~= "CurrentMap"
            and map.Name ~= "GameMap" then
            mapName = map.Name
        end
        if not mapName then
            local count, sumX, sumY, sumZ = 0, 0, 0, 0
            for _, part in ipairs(map:GetDescendants()) do
                if part:IsA("BasePart") and part.Anchored
                    and part.Name ~= "Coin_Server" then
                    count += 1
                    local p = part.Position
                    sumX += math.round(p.X / 8)
                    sumY += math.round(p.Y / 8)
                    sumZ += math.round(p.Z / 8)
                end
            end
            if count >= 10 then
                mapName = string.format("geometry-%d-%d-%d-%d", count, sumX, sumY, sumZ)
            end
        end
        MapIdentityCache.Root = map
        MapIdentityCache.CheckedAt = os.clock()
        MapIdentityCache.Children = childCount
        MapIdentityCache.Result = mapName and (tostring(game.PlaceId) .. ":" .. tostring(mapName)) or nil
    end
    if not mapName and coin then
        local top = coin
        while top.Parent and top.Parent ~= workspace do top = top.Parent end
        if top ~= coin and top.Name ~= "Coins" and top.Name ~= "CoinContainer"
            and top.Name ~= "Coin_Server" and top.Name ~= "Map" then
            mapName = top.Name
        end
    end
    if mapName and tostring(mapName) ~= "" then
        return tostring(game.PlaceId) .. ":" .. tostring(mapName)
    end
    return nil
end

local function packHotspotMap()
    local regions = {}
    for _, region in ipairs(HotspotLearning.Regions) do
        if #regions >= 90 then break end
        local anchors = {}
        for _, anchor in ipairs(region.Anchors) do
            if #anchors >= 24 then break end
            local point = encodePosition(anchor.Position)
            if point then
                table.insert(anchors, { p = point, w = safeCount(anchor.Weight) })
            end
        end
        local center = encodePosition(region.Center)
        if center and #anchors > 0 then
            table.insert(regions, {
                c = center, s = safeCount(region.Spread, 500),
                seen = safeCount(region.Seen), live = safeCount(region.LiveSpawns),
                initial = safeCount(region.InitialCoins),
                collected = safeCount(region.Collected), stolen = safeCount(region.Stolen),
                visits = safeCount(region.Visits),
                mean = region.MeanInterval,
                err = safeCount(region.IntervalError, 180),
                anchors = anchors,
            })
        end
    end
    return { savedAt = os.time(), regions = regions }
end

local function restoreHotspotMap(snapshot)
    table.clear(HotspotLearning.Regions)
    HotspotLearning.TotalLiveSpawns = 0
    HotspotLearning.StartedAt = os.clock()
    HotspotLearning.LastCamp = nil
    HotspotLearning.LastCampSwitch = 0
    HotspotLearning.CampPlan = nil
    if type(snapshot) ~= "table" or type(snapshot.regions) ~= "table" then return end
    local daysOld = math.max(0, os.time() - safeCount(snapshot.savedAt, 3000000000)) / 86400
    local freshness = math.clamp(math.exp(-daysOld / 45), 0.12, 1)
    for _, data in ipairs(snapshot.regions) do
        if #HotspotLearning.Regions >= 90 then break end
        if type(data) == "table" and type(data.anchors) == "table" then
            local center = decodePosition(data.c)
            local anchors = {}
            for _, a in ipairs(data.anchors) do
                if #anchors >= 24 then break end
                if type(a) == "table" then
                    local p = decodePosition(a.p)
                    if p then
                        table.insert(anchors, {
                            Position = p, Weight = safeCount(a.w) * freshness,
                            LastSeen = os.clock(),
                        })
                    end
                end
            end
            if center and #anchors > 0 then
                local mean = tonumber(data.mean)
                if not mean or mean ~= mean or mean <= 1 or mean > 180 then mean = nil end
                table.insert(HotspotLearning.Regions, {
                    Center = center,
                    Spread = safeCount(data.s, 500),
                    Seen = safeCount(data.seen) * freshness,
                    LiveSpawns = safeCount(data.live) * freshness,
                    InitialCoins = safeCount(data.initial) * freshness,
                    Collected = safeCount(data.collected) * freshness,
                    Stolen = safeCount(data.stolen) * freshness,
                    Anchors = anchors, LastSeen = os.clock(), LastLiveSpawn = nil,
                    MeanInterval = mean, IntervalError = safeCount(data.err, 180),
                    RoundSpawns = 0,
                    Visits = safeCount(data.visits) * freshness,
                    LastVisited = 0, CampFailUntil = 0,
                })
            end
        end
    end
end

local function saveHotspotMemory(force)
    if not HotspotDisk.Available then return end
    if not HotspotDisk.Dirty and not force then return end
    local now = os.clock()
    if not force and now - HotspotDisk.LastSave < 18 then return end
    if HotspotDisk.MapKey then
        HotspotDisk.Maps[HotspotDisk.MapKey] = packHotspotMap()
    end
    local keys = {}
    for key, snapshot in pairs(HotspotDisk.Maps) do
        table.insert(keys, { key = key, stamp = safeCount(snapshot.savedAt, 3000000000) })
    end
    if #keys > 24 then
        table.sort(keys, function(a, b) return a.stamp > b.stamp end)
        for i = 25, #keys do HotspotDisk.Maps[keys[i].key] = nil end
    end
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode({ version = 1, maps = HotspotDisk.Maps })
    end)
    if not ok then return end
    local wrote, err = pcall(writefile, HotspotDisk.File, encoded)
    if wrote then
        HotspotDisk.Dirty = false
        HotspotDisk.LastSave = now
    elseif not HotspotDisk.SaveWarning then
        HotspotDisk.SaveWarning = true
        warn("[Mini Scripts] Could not save hotspot memory: " .. tostring(err))
    end
end

local function selectHotspotMap(coin)
    local key = activeMapIdentity(coin)
    if not key or key == HotspotDisk.MapKey then return end
    if HotspotDisk.MapKey then
        HotspotDisk.Maps[HotspotDisk.MapKey] = packHotspotMap()
    end
    HotspotDisk.MapKey = key
    restoreHotspotMap(HotspotDisk.Maps[key])
    HotspotDisk.Dirty = true
end

do
    if HotspotDisk.Available then
        local folderOK = false
        if type(isfolder) == "function" then
            local ok, exists = pcall(isfolder, "MiniScripts")
            folderOK = ok and exists == true
        end
        if not folderOK and type(makefolder) == "function" then
            folderOK = pcall(makefolder, "MiniScripts")
        end
        if not folderOK then
            HotspotDisk.File = "MM2_AdaptiveHotspots.json"
        end
        local ok, contents = pcall(readfile, HotspotDisk.File)
        if ok and type(contents) == "string" then
            local decodedOK, parsed = pcall(function()
                return HttpService:JSONDecode(contents)
            end)
            if decodedOK and type(parsed) == "table" and parsed.version == 1
                and type(parsed.maps) == "table" then
                HotspotDisk.Maps = parsed.maps
            else
                warn("[Mini Scripts] Hotspot save was invalid; learning from fresh observations.")
            end
        end
    else
        warn("[Mini Scripts] Executor readfile/writefile unavailable; hotspot learning is session-only.")
    end
end
selectHotspotMap(nil)
task.spawn(function()
    while HotspotDisk.Running do
        task.wait(20)
        if HotspotDisk.Running then saveHotspotMemory(false) end
    end
end)

local function getCharacter()
    local character = LocalPlayer.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root then return nil end
    return character, humanoid, root
end

local function coinID(part)
    if not part then return nil end
    local value = part:GetAttribute("CoinID")
    if value == nil and part.Parent then
        value = part.Parent:GetAttribute("CoinID")
    end
    return value == nil and nil or tostring(value)
end

local function isCandy(part)
    return part and part:IsA("BasePart") and part:IsDescendantOf(workspace)
        and part.Name == "Coin_Server" and coinID(part) == "Candy"
        and part:GetAttribute("Collected") ~= true
        and part:GetAttribute("Delete") ~= true
end

local function getTouchingPlayer(part)
    if not part then return nil end
    local ancestor = part
    for _ = 1, 5 do
        ancestor = ancestor.Parent
        if not ancestor then break end
        if ancestor:IsA("Model") then
            local player = Players:GetPlayerFromCharacter(ancestor)
            if player then return player end
        end
    end
    return nil
end

local function cancelCurrentTarget(coin)
    if CurrentTarget == coin and CurrentTween then
        pcall(function() CurrentTween:Cancel() end)
    end
end

local function nearestRegion(position, allowNew)
    local winner, bestDistance = nil, math.huge
    for _, region in ipairs(HotspotLearning.Regions) do
        if math.abs(position.Y - region.Center.Y) < 9 then
            local radius = math.clamp(13 + region.Spread * 0.6, 13, 28)
            local distance = (region.Center - position).Magnitude
            if distance < radius and distance < bestDistance then
                winner, bestDistance = region, distance
            end
        end
    end
    if winner or not allowNew then return winner end
    if #HotspotLearning.Regions >= 90 then
        local oldestIndex, oldestAge = nil, -math.huge
        for index, region in ipairs(HotspotLearning.Regions) do
            local age = os.clock() - region.LastSeen
            if age > oldestAge then oldestIndex, oldestAge = index, age end
        end
        if oldestIndex then table.remove(HotspotLearning.Regions, oldestIndex) end
    end
    winner = {
        Center = position, Spread = 0, Seen = 0, LiveSpawns = 0,
        InitialCoins = 0, Collected = 0, Stolen = 0,
        Anchors = {}, LastSeen = os.clock(), LastLiveSpawn = nil,
        MeanInterval = nil, IntervalError = 0, RoundSpawns = 0,
        Visits = 0, LastVisited = 0, CampFailUntil = 0,
    }
    table.insert(HotspotLearning.Regions, winner)
    HotspotDisk.Dirty = true
    return winner
end

local function learnSpawn(position, isLiveSpawn)
    local now = os.clock()
    local region = nearestRegion(position, true)
    if not region then return end
    region.Seen += 1
    local distance = (position - region.Center).Magnitude
    local alpha = math.clamp(1 / math.sqrt(region.Seen), 0.08, 0.5)
    region.Center = region.Center:Lerp(position, alpha)
    region.Spread = region.Spread * 0.83 + distance * 0.17
    region.LastSeen = now
    HotspotDisk.Dirty = true
    local anchor = nil
    for _, candidate in ipairs(region.Anchors) do
        if (candidate.Position - position).Magnitude < 3 then
            anchor = candidate
            break
        end
    end
    if not anchor then
        if #region.Anchors >= 24 then
            table.sort(region.Anchors, function(a, b)
                return a.Weight < b.Weight
            end)
            table.remove(region.Anchors, 1)
        end
        anchor = { Position = position, Weight = 0, LastSeen = now }
        table.insert(region.Anchors, anchor)
    end
    anchor.Position = anchor.Position:Lerp(position, 0.35)
    anchor.Weight += (isLiveSpawn and 1 or 0.2)
    anchor.LastSeen = now
    if isLiveSpawn then
        HotspotLearning.TotalLiveSpawns += 1
        region.LiveSpawns += 1
        region.RoundSpawns = (region.RoundSpawns or 0) + 1
        if region.LastLiveSpawn then
            local interval = now - region.LastLiveSpawn
            if interval > 1.0 and interval < 180 then
                if region.MeanInterval then
                    region.IntervalError = region.IntervalError * 0.75
                        + math.abs(interval - region.MeanInterval) * 0.25
                    region.MeanInterval = region.MeanInterval * 0.7 + interval * 0.3
                else
                    region.MeanInterval = interval
                    region.IntervalError = interval * 0.4
                end
            end
        end
        region.LastLiveSpawn = now
    else
        region.InitialCoins += 1
    end
end

local function observeCoin(coin, info, asLive)
    if not info or info.Observed or not isCandy(coin) then return end
    info.Observed = true
    learnSpawn(coin.Position, asLive == true)
end

local function learnPickupOutcome(position, wasOurs)
    local region = nearestRegion(position, false)
    if not region then return end
    if wasOurs then
        region.Collected += 1
    else
        region.Stolen += 1
    end
    HotspotDisk.Dirty = true
end

local function resetHotspotLearning(seedExisting)
    selectHotspotMap(nil)
    HotspotLearning.Generation += 1
    HotspotLearning.TotalLiveSpawns = 0
    HotspotLearning.StartedAt = os.clock()
    HotspotLearning.LastCamp = nil
    HotspotLearning.LastCampSwitch = 0
    HotspotLearning.CampPlan = nil
    CoinNavigation.Target = nil
    for _, region in ipairs(HotspotLearning.Regions) do
        region.RoundSpawns = 0
        region.LastLiveSpawn = nil
        region.LastSeen = os.clock()
    end
    LastAttemptedPickup = nil
    LastAttemptedPickupTime = 0
    for coin, info in pairs(KnownCoins) do
        info.Observed = false
        if seedExisting then observeCoin(coin, info, false) end
    end
end

local function trackCoin(coin, existing)
    if not coin:IsA("BasePart") or coin.Name ~= "Coin_Server" then return end
    if KnownCoins[coin] then return end
    local info = {
        Born = existing and (os.clock() - 10) or os.clock(),
        Observed = false,
        TakenByOther = false,
        TouchedByMe = false,
    }
    KnownCoins[coin] = info
    selectHotspotMap(coin)
    observeCoin(coin, info, not existing)
    local connection = coin.Touched:Connect(function(otherPart)
        if not FarmSettings.Enabled or coinID(coin) ~= "Candy" then return end
        local player = getTouchingPlayer(otherPart)
        if player == LocalPlayer then
            info.TouchedByMe = true
            LastAttemptedPickup = coin.Position
            LastAttemptedPickupTime = os.clock()
            RecentAttempts[coin] = os.clock() + 3.5
            cancelCurrentTarget(coin)
        elseif player and FarmSettings.SkipOtherPlayers and not info.TakenByOther then
            info.TakenByOther = true
            learnPickupOutcome(coin.Position, false)
            cancelCurrentTarget(coin)
        end
    end)
    local statusConnection = coin:GetAttributeChangedSignal("Collected"):Connect(function()
        if coin:GetAttribute("Collected") == true then
            cancelCurrentTarget(coin)
        elseif coin:GetAttribute("Collected") == false then
            info.TakenByOther = false
            info.TouchedByMe = false
            info.Born = os.clock()
            info.Observed = false
            RecentAttempts[coin] = nil
            observeCoin(coin, info, true)
        end
    end)
    local deleteConnection = coin:GetAttributeChangedSignal("Delete"):Connect(function()
        if coin:GetAttribute("Delete") == true then cancelCurrentTarget(coin) end
    end)
    local idConnection = coin:GetAttributeChangedSignal("CoinID"):Connect(function()
        observeCoin(coin, info, true)
    end)
    local signals = { connection, statusConnection, deleteConnection, idConnection }
    if coin.Parent then
        table.insert(signals, coin.Parent:GetAttributeChangedSignal("CoinID"):Connect(function()
            observeCoin(coin, info, true)
        end))
    end
    CoinConnections[coin] = signals
end
for _, object in ipairs(workspace:GetDescendants()) do
    if object:IsA("BasePart") and object.Name == "Coin_Server" then
        trackCoin(object, true)
    end
end
table.insert(FarmConnections, workspace.DescendantAdded:Connect(function(object)
    if object:IsA("BasePart") and object.Name == "Coin_Server" then
        trackCoin(object, false)
    end
end))
table.insert(FarmConnections, workspace.DescendantRemoving:Connect(function(object)
    if KnownCoins[object] then
        cancelCurrentTarget(object)
        local signals = CoinConnections[object]
        if signals then
            for _, signal in ipairs(signals) do signal:Disconnect() end
        end
        CoinConnections[object] = nil
        KnownCoins[object] = nil
        RecentAttempts[object] = nil
    end
end))

local function playersInRound()
    local others, murderers = {}, {}
    local now = os.clock()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            local human = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if human and root and human.Health > 0 then
                local last = PlayerSnapshots[player]
                local motion = root.AssemblyLinearVelocity
                if last and now - last.Time > 0.035 then
                    motion = (root.Position - last.Position) / (now - last.Time)
                end
                PlayerSnapshots[player] = { Position = root.Position, Time = now }
                local entry = {
                    Player = player, Root = root, Humanoid = human,
                    ObservedVelocity = motion,
                }
                table.insert(others, entry)
                if GetPlayerRole(player) == "Murderer" then
                    table.insert(murderers, entry)
                end
            end
        end
    end
    return others, murderers
end

local function horizontalDistance(a, b)
    return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function murdererThreatsNear(origin, destination, murderers)
    local result = {}
    local segment = destination - origin
    local flatSegment = Vector3.new(segment.X, 0, segment.Z)
    local length2 = flatSegment:Dot(flatSegment)
    for _, threat in ipairs(murderers) do
        if threat.Root and threat.Root.Parent then
            local center = threat.Root.Position
            if math.min(math.abs(center.Y - origin.Y), math.abs(center.Y - destination.Y)) < 13 then
                local flatTo = Vector3.new(center.X - origin.X, 0, center.Z - origin.Z)
                local t = length2 > 0.1 and math.clamp(flatTo:Dot(flatSegment) / length2, 0, 1) or 0
                local projected = origin + segment * t
                if horizontalDistance(projected, center) < 85 then
                    table.insert(result, center)
                end
            end
        end
    end
    return result
end

local function segmentSafe(a, b, threats, allowExit)
    local delta = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
    local length2 = delta:Dot(delta)
    local radius = FarmSettings.PathDangerRadius
    for _, center in ipairs(threats) do
        if math.min(math.abs(center.Y - a.Y), math.abs(center.Y - b.Y)) < 13 then
            local offset = Vector3.new(center.X - a.X, 0, center.Z - a.Z)
            local t = length2 > 0.001 and math.clamp(offset:Dot(delta) / length2, 0, 1) or 0
            local nearest = Vector3.new(a.X, 0, a.Z) + delta * t
            local minDistance = (nearest - Vector3.new(center.X, 0, center.Z)).Magnitude
            if minDistance < radius then
                local startDist = horizontalDistance(a, center)
                local endDist = horizontalDistance(b, center)
                if not (allowExit and startDist < radius and endDist > startDist + 0.5
                    and t <= 0.001) then
                    return false
                end
            end
        end
    end
    return true
end

local function destinationSafe(point, murderers)
    for _, threat in ipairs(murderers) do
        local center = threat.Root.Position
        if math.abs(center.Y - point.Y) < 13
            and horizontalDistance(center, point) < FarmSettings.MurdererRadius then
            return false
        end
    end
    return true
end

local function detourHasFloor(point, character)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    params.IgnoreWater = true
    params.RespectCanCollide = true
    local hit = workspace:Raycast(point + Vector3.new(0, 5, 0), Vector3.new(0, -30, 0), params)
    return hit ~= nil and hit.Position.Y > workspace.FallenPartsDestroyHeight + 70
        and math.abs(hit.Position.Y - point.Y) < 21
end

local function routeTo(origin, destination, murderers, character)
    local threats = murdererThreatsNear(origin, destination, murderers)
    if not destinationSafe(destination, murderers) then return nil end
    if segmentSafe(origin, destination, threats, true) then
        return { destination }
    end
    local nodes = { origin, destination }
    local radius = FarmSettings.PathDangerRadius + 3.5
    for _, center in ipairs(threats) do
        for step = 0, 11 do
            local angle = step * math.pi / 6
            local point = Vector3.new(
                center.X + math.cos(angle) * radius,
                origin.Y,
                center.Z + math.sin(angle) * radius
            )
            if destinationSafe(point, murderers) and detourHasFloor(point, character) then
                table.insert(nodes, point)
            end
        end
    end
    local n = #nodes
    local cost, prev, visited = {}, {}, {}
    for i = 1, n do cost[i] = math.huge end
    cost[1] = 0
    for _ = 1, n do
        local u, smallest = nil, math.huge
        for i = 1, n do
            if not visited[i] and cost[i] < smallest then
                smallest, u = cost[i], i
            end
        end
        if not u or u == 2 then break end
        visited[u] = true
        for v = 2, n do
            if not visited[v] and v ~= u
                and segmentSafe(nodes[u], nodes[v], threats, u == 1) then
                local newCost = cost[u] + (nodes[u] - nodes[v]).Magnitude
                if newCost < cost[v] then
                    cost[v], prev[v] = newCost, u
                end
            end
        end
    end
    if cost[2] == math.huge then return nil end
    local backwards = {}
    local index = 2
    while index and index ~= 1 do
        table.insert(backwards, nodes[index])
        index = prev[index]
    end
    if not index then return nil end
    local result = {}
    for i = #backwards, 1, -1 do table.insert(result, backwards[i]) end
    return result
end

local function hotspotConfidence(region, now)
    local evidence = region.LiveSpawns + region.InitialCoins * 0.22
    local confidence = 1 - math.exp(-evidence / 3)
    local lastAge = math.max(0, now - region.LastSeen)
    local recency = math.exp(-lastAge / 95)
    local quality = (region.Collected + 1.5)
        / (region.Collected + region.Stolen * 1.3 + 2.5)
    return confidence * recency * quality
end

local function hotspotBonusAt(position, now)
    local region = nearestRegion(position, false)
    if not region then return 0 end
    local distance = (position - region.Center).Magnitude
    return math.min(0.9, 1.3 * hotspotConfidence(region, now)
        / (1 + distance / 30))
end

local function otherAlreadyTouched(coin, info, others)
    if info.TakenByOther then return true end
    if not FarmSettings.SkipOtherPlayers then return false end
    for _, entry in ipairs(others) do
        if math.abs(entry.Root.Position.Y - coin.Position.Y) < 9
            and horizontalDistance(entry.Root.Position, coin.Position) <= FarmSettings.RivalContactRadius then
            info.TakenByOther = true
            learnPickupOutcome(coin.Position, false)
            cancelCurrentTarget(coin)
            return true
        end
    end
    return false
end

local function coinScore(coin, info, position, others, murderers, now)
    if not isCandy(coin) or info.TakenByOther or info.TouchedByMe
        or (RecentAttempts[coin] or 0) > now
        or coin.Position.Y <= workspace.FallenPartsDestroyHeight + 70
        or math.abs(coin.Position.Y - position.Y) > 80 then
        return nil
    end
    observeCoin(coin, info)
    if otherAlreadyTouched(coin, info, others) then return nil end
    if not destinationSafe(coin.Position, murderers) then return nil end
    local distance = (coin.Position - position).Magnitude
    local ourEta = distance / math.max(FarmSettings.Speed, 8)
    local score = ourEta * (FarmSettings.NearestFirst and 1 or 0.6)
    local threats = murdererThreatsNear(position, coin.Position, murderers)
    if not segmentSafe(position, coin.Position, threats, true) then
        score += 1.2
    end
    local threatRace = false
    if FarmSettings.SkipOtherPlayers then
        for _, rival in ipairs(others) do
            local fromRival = coin.Position - rival.Root.Position
            local rivalDist = fromRival.Magnitude
            if rivalDist > 0.05 then
                local approaching = rival.ObservedVelocity:Dot(fromRival.Unit)
                if approaching > 4 then
                    local rivalSpeed = math.max(14, rival.Humanoid.WalkSpeed, approaching)
                    local rivalEta = rivalDist / math.min(rivalSpeed, 90)
                    if rivalEta + 0.18 < ourEta then
                        return nil
                    elseif rivalEta < ourEta + 0.9 then
                        threatRace = true
                    end
                end
            end
        end
    end
    score -= hotspotBonusAt(coin.Position, now)
    if (now - info.Born) <= FarmSettings.FreshSpawnWindow then
        score -= FarmSettings.FreshSpawnBonus
    end
    if threatRace then score -= 0.3 end
    return score
end

local function nextCoin(position, currentCoin)
    local now = os.clock()
    local others, murderers = playersInRound()
    local best, bestScore, currentScore = nil, math.huge, nil
    for coin, info in pairs(KnownCoins) do
        if not coin.Parent then
            KnownCoins[coin] = nil
        else
            local score = coinScore(coin, info, position, others, murderers, now)
            if coin == currentCoin then currentScore = score end
            if score and score < bestScore then
                best, bestScore = coin, score
            end
        end
    end
    return best, bestScore, currentScore, murderers
end

local function bestCampingPosition(position, murderers, character, others)
    local now = os.clock()
    local plan = HotspotLearning.CampPlan
    if plan then
        local region = plan.Region
        local stillKnown = false
        for _, saved in ipairs(HotspotLearning.Regions) do
            if saved == region then stillKnown = true break end
        end
        if not stillKnown or not destinationSafe(plan.Position, murderers)
            or (not plan.ArrivedAt and now - plan.ChosenAt > plan.MaxTravel) then
            if stillKnown and not plan.ArrivedAt then
                region.CampFailUntil = now + 12
            end
            plan = nil
            HotspotLearning.CampPlan = nil
        else
            local dist = (plan.Position - position).Magnitude
            if dist <= 4.5 and not plan.ArrivedAt then
                plan.ArrivedAt = now
                region.LastVisited = now
                region.Visits = (region.Visits or 0) + 1
                HotspotDisk.Dirty = true
            end
            if not plan.ArrivedAt and now - plan.ChosenAt < plan.MaxTravel then
                return plan.Position
            end
            if plan.ArrivedAt and now - plan.ArrivedAt < 7 then
                return plan.Position
            end
            if plan.ArrivedAt and now - plan.ArrivedAt < 14
                and now - (plan.LastEvaluation or 0) < 0.8 then
                return plan.Position
            end
            plan.LastEvaluation = now
        end
    end
    local elapsed = math.max(now - HotspotLearning.StartedAt, 12)
    local totalVisits = 0
    for _, region in ipairs(HotspotLearning.Regions) do
        totalVisits += (region.Visits or 0)
    end
    local bestRegion, bestPosition, bestScore = nil, nil, -math.huge
    local currentScore = -math.huge
    local currentCandidate = nil
    local regionCount = 0
    local backupRegion, backupPosition, backupScore = nil, nil, -math.huge
    local farRegion, farPosition, farScore = nil, nil, -math.huge
    for _, region in ipairs(HotspotLearning.Regions) do
        if region.Seen > 0 and #region.Anchors > 0
            and math.abs(region.Center.Y - position.Y) < 16
            and (region.CampFailUntil or 0) < now then
            local anchorPosition, anchorScore = nil, -math.huge
            for _, anchor in ipairs(region.Anchors) do
                local p = anchor.Position + Vector3.new(0, 1.9, 0)
                if destinationSafe(p, murderers) then
                    if not anchor.FloorCheckedAt or now - anchor.FloorCheckedAt >= 5 then
                        anchor.HasFloor = detourHasFloor(p, character)
                        anchor.FloorCheckedAt = now
                    end
                    if anchor.HasFloor then
                        local rank = math.log(1 + anchor.Weight)
                            - (p - region.Center).Magnitude / 110
                        if rank > anchorScore then
                            anchorScore, anchorPosition = rank, p
                        end
                    end
                end
            end
            if anchorPosition then
                regionCount += 1
                local travel = (anchorPosition - position).Magnitude
                    / math.max(FarmSettings.Speed, 8)
                local currentRound = region.RoundSpawns or 0
                local historicalPrior = math.min(region.LiveSpawns, 45) * 0.07
                    + math.min(region.InitialCoins, 15) * 0.025
                local predictedRate = math.min(1.65,
                    (currentRound + historicalPrior + 0.5) / (elapsed + 14) * 18)
                local quality = (region.Collected + 1.5)
                    / (region.Collected + region.Stolen * 1.3 + 2.5)
                local confidence = hotspotConfidence(region, now)
                local readiness = 0.45
                if region.MeanInterval and region.LastLiveSpawn then
                    local due = region.LastLiveSpawn + region.MeanInterval
                    local spread = math.max(4, region.IntervalError * 2 + 2)
                    readiness = 1 / (1 + math.abs(due - now - travel) / spread)
                end
                local visits = region.Visits or 0
                local visitAge = region.LastVisited > 0 and (now - region.LastVisited)
                    or math.max(elapsed, 30)
                local novelty = region.LastVisited > 0
                    and math.clamp(visitAge / 24, 0, 1.2) or 1.25
                local uncertainty = math.sqrt(math.log(totalVisits + 3) / (visits + 1))
                local crowding = 0
                for _, rival in ipairs(others or {}) do
                    if math.abs(rival.Root.Position.Y - anchorPosition.Y) < 10 then
                        local d = horizontalDistance(rival.Root.Position, anchorPosition)
                        if d < 25 then crowding += (25 - d) / 25 end
                    end
                end
                local score = predictedRate * (0.85 + 0.4 * quality)
                    + quality * 0.55 + confidence * 0.35
                    + novelty * 0.88 + uncertainty * 0.32
                    + readiness * 0.18
                    - travel * 0.034 - crowding * 0.5
                if region.LastVisited > 0 then
                    score -= 0.8 * math.exp(-visitAge / 18)
                end
                local nearbyCoverage = 0
                for _, recentlyVisited in ipairs(HotspotLearning.Regions) do
                    local last = recentlyVisited.LastVisited or 0
                    if last > 0 and math.abs(recentlyVisited.Center.Y - region.Center.Y) < 13 then
                        local apart = horizontalDistance(recentlyVisited.Center, region.Center)
                        if apart < 55 then
                            local decay = math.exp(-(now - last) / 32)
                            nearbyCoverage = math.max(nearbyCoverage,
                                (1 - apart / 55) * decay)
                        end
                    end
                end
                score -= nearbyCoverage * 0.75
                if plan and region == plan.Region then
                    currentScore, currentCandidate = score, anchorPosition
                else
                    if score > backupScore then
                        backupScore, backupRegion, backupPosition = score, region, anchorPosition
                    end
                    if plan and horizontalDistance(anchorPosition, plan.Position) >= 55
                        and score > farScore then
                        farScore, farRegion, farPosition = score, region, anchorPosition
                    end
                end
                if score > bestScore then
                    bestScore, bestRegion, bestPosition = score, region, anchorPosition
                end
            end
        end
    end
    if not bestPosition then
        HotspotLearning.CampPlan = nil
        return nil
    end
    if plan and plan.ArrivedAt then
        local stay = now - plan.ArrivedAt
        if stay < 14 and currentCandidate
            and (bestRegion == plan.Region or not bestPosition
                or horizontalDistance(bestPosition, plan.Position) < 42
                or bestScore < currentScore + 0.85) then
            return plan.Position
        end
        if stay >= 14 and backupRegion and regionCount > 1 then
            if farRegion and farScore >= backupScore - 0.95 then
                bestRegion, bestPosition, bestScore = farRegion, farPosition, farScore
            else
                bestRegion, bestPosition, bestScore = backupRegion, backupPosition, backupScore
            end
        end
    end
    if not plan or plan.Region ~= bestRegion
        or (plan.Position - bestPosition).Magnitude > 8 then
        local travel = (bestPosition - position).Magnitude
            / math.max(FarmSettings.Speed, 8)
        HotspotLearning.CampPlan = {
            Region = bestRegion,
            Position = bestPosition,
            ChosenAt = now,
            MaxTravel = math.max(6, travel * 1.8 + 4),
            ArrivedAt = nil,
        }
        HotspotLearning.LastCamp = bestRegion
        HotspotLearning.LastCampSwitch = now
        HotspotLearning.CampDecisions += 1
    end
    return HotspotLearning.CampPlan.Position
end

local function clearTween()
    if CurrentTween then
        local old = CurrentTween
        CurrentTween = nil
        pcall(function() old:Cancel() end)
    end
    CurrentTarget = nil
end

local function antiFlingStep(deltaTime)
    if MiscMovementBusy then return end
    local character, humanoid, root = getCharacter()
    if HeroState.BagHeroMode and root then
        AntiFlingRoot = root
        AntiFlingSafeCFrame = root.CFrame
        return
    end
    if not character or not humanoid or not root then
        AntiFlingRoot = nil
        AntiFlingSafeCFrame = nil
        return
    end
    if root ~= AntiFlingRoot then
        AntiFlingRoot = root
        AntiFlingSafeCFrame = root.CFrame
        return
    end
    local velocity = root.AssemblyLinearVelocity
    local spin = root.AssemblyAngularVelocity
    local excessiveImpulse = velocity.Magnitude > 100 or spin.Magnitude > 18
    local isFarmTweening = FarmSettings.Enabled
        and RoundActive ~= false
        and CharacterState ~= nil
        and CharacterState.Root == root
        and CurrentTween ~= nil
    local unexpectedlyMoved = false
    if isFarmTweening and AntiFlingSafeCFrame then
        local dt = math.clamp(deltaTime or (1 / 60), 0, 0.25)
        local allowedTravel = math.max(12, FarmSettings.Speed * dt * 2 + 8)
        unexpectedlyMoved = (root.Position - AntiFlingSafeCFrame.Position).Magnitude > allowedTravel
    end
    if excessiveImpulse or unexpectedlyMoved then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if unexpectedlyMoved and AntiFlingSafeCFrame then
            clearTween()
            root.CFrame = AntiFlingSafeCFrame
        end
    else
        AntiFlingSafeCFrame = root.CFrame
    end
end

local function setAntiFling(enabled)
    FarmSettings.AntiFling = enabled
    if AntiFlingConnection then
        AntiFlingConnection:Disconnect()
        AntiFlingConnection = nil
    end
    AntiFlingRoot = nil
    AntiFlingSafeCFrame = nil
    if enabled then
        AntiFlingConnection = RunService.Heartbeat:Connect(antiFlingStep)
    end
end

local function restoreCharacter()
    clearTween()
    local state = CharacterState
    CharacterState = nil
    if not state then return end
    if MotionConnection then
        MotionConnection:Disconnect()
        MotionConnection = nil
    end
    if state.Humanoid and state.Humanoid.Parent then
        state.Humanoid.AutoRotate = state.AutoRotate
        state.Humanoid.PlatformStand = state.PlatformStand
        state.Humanoid.WalkSpeed = state.WalkSpeed
    end
    if state.Force then state.Force:Destroy() end
    if state.Attachment then state.Attachment:Destroy() end
    for part, canCollide in pairs(state.Collision) do
        if part and part.Parent then part.CanCollide = canCollide end
    end
    if state.Root and state.Root.Parent then
        state.Root.AssemblyLinearVelocity = Vector3.zero
        state.Root.AssemblyAngularVelocity = Vector3.zero
    end
end

local function prepareCharacter(character, humanoid, root)
    if InnocentEvading then return false end
    if CharacterState and CharacterState.Character == character then return true end
    restoreCharacter()
    local oldCarrier = workspace:FindFirstChild("_MiniFarmCarrier")
    if oldCarrier then pcall(function() oldCarrier:Destroy() end) end
    humanoid.Sit = false
    root.Anchored = false
    local attachment = Instance.new("Attachment")
    attachment.Name = "FarmFloatAttachment"
    attachment.Parent = root
    local force = Instance.new("VectorForce")
    force.Name = "FarmGravityBalance"
    force.Attachment0 = attachment
    force.ApplyAtCenterOfMass = true
    force.RelativeTo = Enum.ActuatorRelativeTo.World
    force.Parent = root
    local state = {
        Character = character,
        Humanoid = humanoid,
        Root = root,
        Attachment = attachment,
        Force = force,
        Collision = {},
        AutoRotate = humanoid.AutoRotate,
        PlatformStand = humanoid.PlatformStand,
        WalkSpeed = humanoid.WalkSpeed,
    }
    CharacterState = state
    humanoid.AutoRotate = false
    humanoid.PlatformStand = true
    humanoid.WalkSpeed = 0
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    MotionConnection = RunService.Stepped:Connect(function()
        if CharacterState ~= state or not character.Parent or not root.Parent then return end
        force.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity, 0)
        if FarmSettings.ThroughWalls then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    if state.Collision[part] == nil then
                        state.Collision[part] = part.CanCollide
                    end
                    part.CanCollide = false
                end
            end
        else
            for part, collision in pairs(state.Collision) do
                if part and part.Parent then part.CanCollide = collision end
            end
            table.clear(state.Collision)
        end
    end)
    return true
end

local function safeDestination(character, coin)
    if not isCandy(coin) then return nil end
    local y = coin.Position.Y + 0.7
    local parameters = RaycastParams.new()
    parameters.FilterType = Enum.RaycastFilterType.Exclude
    parameters.FilterDescendantsInstances = { character, coin }
    parameters.IgnoreWater = true
    local hit = workspace:Raycast(coin.Position + Vector3.new(0, 4, 0), Vector3.new(0, -35, 0), parameters)
    if hit then y = math.max(y, hit.Position.Y + 2.1) end
    if y <= workspace.FallenPartsDestroyHeight + 75 then return nil end
    return Vector3.new(coin.Position.X, y, coin.Position.Z)
end

local function glideTo(root, destination, runToken, targetCoin, travelType)
    if not root or not root.Parent or runToken ~= Token then return false, "stopped" end
    local distance = (destination - root.Position).Magnitude
    if distance <= 1.1 then return true, "arrived" end
    clearTween()
    local speed = math.clamp(FarmSettings.Speed, 8, 90)
    local rotation = root.CFrame - root.Position
    local created, tween = pcall(function()
        return TweenService:Create(root, TweenInfo.new(distance / speed, Enum.EasingStyle.Linear), {
            CFrame = CFrame.new(destination) * rotation,
        })
    end)
    if not created or not tween then return false, "tween-error" end
    local finished = false
    local playbackState = nil
    local connection = tween.Completed:Connect(function(state)
        playbackState = state
        finished = true
    end)
    CurrentTarget = targetCoin
    CurrentTween = tween
    tween:Play()
    local reason = "interrupted"
    local lastScan = 0
    while not finished and FarmSettings.Enabled and runToken == Token do
        if InnocentEvading then
            reason = "safety-evade"
            break
        end
        if BagHandling then
            reason = "bag-full"
            break
        end
        if not root.Parent or RoundActive == false then
            reason = "stopped"
            break
        end
        local character, humanoid = getCharacter()
        if not character or humanoid.Health <= 0 then
            reason = "dead"
            break
        end
        if targetCoin then
            local info = KnownCoins[targetCoin]
            if not info or not isCandy(targetCoin) or info.TakenByOther then
                reason = "taken"
                break
            end
            if info.TouchedByMe then
                reason = "touched"
                break
            end
        end
        local now = os.clock()
        if now - lastScan >= FarmSettings.RetargetInterval then
            lastScan = now
            local newBest, newScore, currentScore, murderers = nextCoin(root.Position, targetCoin)
            if travelType ~= "return" then
                local threats = murdererThreatsNear(root.Position, destination, murderers)
                if not segmentSafe(root.Position, destination, threats, true)
                    or not destinationSafe(destination, murderers) then
                    reason = "repath"
                    break
                end
            end
            if targetCoin then
                if not currentScore then
                    reason = "unsafe-or-taken"
                    break
                end
                if newBest and newBest ~= targetCoin and newScore then
                    local age = now - CoinNavigation.ChosenAt
                    local remaining = (targetCoin.Position - root.Position).Magnitude
                    local initial = math.max(CoinNavigation.StartDistance, 1)
                    local progress = math.clamp(1 - remaining / initial, 0, 1)
                    local commitTime = math.clamp(initial
                        / math.max(FarmSettings.Speed, 8) * 0.23, 0.9, 2.8)
                    local gainNeeded = math.max(FarmSettings.RetargetGain,
                        math.max(currentScore, 0) * 0.32)
                    if age >= commitTime and progress < 0.76 and remaining > 9
                        and now - CoinNavigation.LastSwitchAt >= 1.6
                        and currentScore - newScore >= gainNeeded then
                        CoinNavigation.LastSwitchAt = now
                        reason = "better-spawn"
                        break
                    end
                end
            elseif newBest and travelType == "camp" then
                reason = "new-coin"
                break
            end
        end
        task.wait(0.025)
    end
    if not finished then pcall(function() tween:Cancel() end) end
    connection:Disconnect()
    if CurrentTween == tween then CurrentTween = nil end
    if CurrentTarget == targetCoin then CurrentTarget = nil end
    if playbackState == Enum.PlaybackState.Completed then
        return true, "arrived"
    end
    return false, reason
end

local function navigateTo(character, root, destination, runToken, coin, travelType)
    local _, murderers = playersInRound()
    local route = routeTo(root.Position, destination, murderers, character)
    if not route then return false, "unsafe-route" end
    for _, waypoint in ipairs(route) do
        if not FarmSettings.Enabled or runToken ~= Token or BagHandling then
            return false, "stopped"
        end
        local arrived, reason = glideTo(root, waypoint, runToken, coin, travelType)
        if not arrived then return false, reason end
    end
    return true, "arrived"
end

local function touchCoin(character, root, coin)
    if not isCandy(coin) then return end
    if type(firetouchinterest) == "function" then
        local parts = { root }
        for _, name in ipairs({ "Head", "Torso", "UpperTorso", "LowerTorso" }) do
            local part = character:FindFirstChild(name)
            if part and part:IsA("BasePart") then table.insert(parts, part) end
        end
        for _, bodyPart in ipairs(parts) do
            if bodyPart.Parent and coin.Parent then
                pcall(function()
                    firetouchinterest(bodyPart, coin, 0)
                    firetouchinterest(bodyPart, coin, 1)
                end)
            end
        end
    end
    LastAttemptedPickup = coin.Position
    LastAttemptedPickupTime = os.clock()
    RecentAttempts[coin] = os.clock() + 3.5
end

local function farmLoop(runToken)
    while FarmSettings.Enabled and runToken == Token do
        local character, humanoid, root = getCharacter()
        if InnocentEvading or BagHandling or not character or RoundActive == false then
            if CharacterState and runToken == Token then restoreCharacter() end
            task.wait(0.12)
            continue
        end
        local coin, _, _, murderers = nextCoin(root.Position)
        if coin then
            HotspotLearning.CampPlan = nil
            if coin ~= CoinNavigation.Target then
                CoinNavigation.Target = coin
                CoinNavigation.ChosenAt = os.clock()
                CoinNavigation.StartDistance = (root.Position - coin.Position).Magnitude
            end
            local destination = safeDestination(character, coin)
            if destination and prepareCharacter(character, humanoid, root) then
                local arrived, reason = navigateTo(character, root, destination, runToken, coin, "coin")
                if runToken ~= Token then break end
                if BagHandling then
                    CoinNavigation.Target = nil
                    task.wait(0.12)
                    continue
                end
                local info = KnownCoins[coin]
                if info and not info.TakenByOther and (arrived or info.TouchedByMe) then
                    touchCoin(character, root, coin)
                elseif info and not info.TakenByOther and not info.TouchedByMe then
                    RecentAttempts[coin] = os.clock() + (reason == "unsafe-route" and 0.9 or 0.3)
                end
            else
                RecentAttempts[coin] = os.clock() + 1.0
            end
            CoinNavigation.Target = nil
        else
            local others = playersInRound()
            local camp = bestCampingPosition(root.Position, murderers, character, others)
            if camp and (camp - root.Position).Magnitude > 3 then
                if prepareCharacter(character, humanoid, root) then
                    local arrived, reason = navigateTo(character, root, camp, runToken, nil, "camp")
                    if not arrived and (reason == "unsafe-route"
                        or reason == "tween-error" or reason == "repath") then
                        local plan = HotspotLearning.CampPlan
                        if plan then
                            plan.Region.CampFailUntil = os.clock() + 9
                            HotspotLearning.CampPlan = nil
                        end
                    end
                end
            else
                if CharacterState then restoreCharacter() end
                task.wait(0.08)
            end
        end
        task.wait(0.01)
    end
    if runToken == Token then restoreCharacter() end
end
local ActiveFarmWorkerToken = nil

local function ensureFarmWorker()
    if not FarmSettings.Enabled or ActiveFarmWorkerToken == Token then return end
    local runToken = Token
    ActiveFarmWorkerToken = runToken
    task.spawn(function()
        local ok, err = pcall(farmLoop, runToken)
        if ActiveFarmWorkerToken == runToken then ActiveFarmWorkerToken = nil end
        if not ok then
            warn("[Mini Scripts] Auto Farm recovered from worker error: " .. tostring(err))
        end
        if FarmSettings.Enabled and runToken == Token then
            task.delay(0.25, function()
                if FarmSettings.Enabled and runToken == Token then ensureFarmWorker() end
            end)
        end
    end)
end

function AutoFarm.Start()
    if FarmSettings.Enabled then
        ensureFarmWorker()
        return
    end
    local character, _, root = getCharacter()
    FarmStartCFrame = root and root.CFrame or nil
    FarmStartCharacter = character
    FarmSettings.Enabled = true
    HotspotLearning.CampPlan = nil
    CoinNavigation.Target = nil
    Token += 1
    ensureFarmWorker()
end

function AutoFarm.Stop()
    if not FarmSettings.Enabled and not CharacterState then return end
    FarmSettings.Enabled = false
    Token += 1
    BagHandling = false
    if stopBagHero then stopBagHero() end
    HotspotLearning.CampPlan = nil
    CoinNavigation.Target = nil
    restoreCharacter()
    saveHotspotMemory(true)
end

local function setFarmToggleOff()
    if not FarmEnabledToggle or UpdatingFarmUI then return end
    UpdatingFarmUI = true
    pcall(function() FarmEnabledToggle:UpdateState(false) end)
    UpdatingFarmUI = false
end

local function actOnFullBag()
    if not FarmSettings.Enabled or not BagFull or BagFullHandled or BagHandling then return end
    if RoundActive == false
        or HeroState.FullRoundId ~= HeroState.RoundId
        or HeroState.FullCharacter ~= LocalPlayer.Character then return end
    if FarmSettings.FullBagHero and not HeroState.TriedThisBag and beginBagHero then
        HeroState.TriedThisBag = true
        if beginBagHero() then return end
    end
    if not FarmSettings.StopReturnOnFull and not FarmSettings.AutoResetOnFull then return end
    BagFullHandled = true
    BagHandling = true
    if FarmSettings.StopReturnOnFull then
        local originalPosition = FarmStartCFrame
        local originalCharacter = FarmStartCharacter
        AutoFarm.Stop()
        local character, _, root = getCharacter()
        if originalPosition and root and character == originalCharacter then
            root.CFrame = originalPosition
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        setFarmToggleOff()
        BagHandling = false
        return
    end
    if FarmSettings.AutoResetOnFull then
        warn("[MM2 Farm] Auto Reset fallback started; this is a script reset, not murderer damage.")
        restoreCharacter()
        RoundActive = false
        local originalCharacter, humanoid = getCharacter()
        if not originalCharacter or not humanoid then
            BagHandling = false
            ensureFarmWorker()
            return
        end
        humanoid.Health = 0
        task.spawn(function()
            local deadline = os.clock() + 25
            while os.clock() < deadline and FarmSettings.Enabled do
                local character = getCharacter()
                if character and character ~= originalCharacter then break end
                task.wait(0.15)
            end
            BagHandling = false
            if FarmSettings.Enabled then ensureFarmWorker() end
        end)
    end
end

function AutoFarm.Reset()
    if stopBagHero then stopBagHero() end
    HeroState.TriedThisBag = false
    HeroState.FullRoundId = nil
    HeroState.FullCharacter = nil
    BagFull = false
    BagFullHandled = false
    LastBagCount = nil
    LastBagMaximum = nil
    table.clear(RecentAttempts)
    for _, info in pairs(KnownCoins) do
        info.TakenByOther = false
        info.TouchedByMe = false
    end
end

do
    task.spawn(function()
        local remoteFolder = ReplicatedStorage:FindFirstChild("Remotes")
            or ReplicatedStorage:WaitForChild("Remotes", 30)
        local gameplay = remoteFolder and (remoteFolder:FindFirstChild("Gameplay")
            or remoteFolder:WaitForChild("Gameplay", 30))
        if gameplay and HotspotDisk.Running then

        local function connect(name, handler)
            local remote = gameplay:FindFirstChild(name)
            if remote and remote:IsA("RemoteEvent") then
                table.insert(FarmConnections, remote.OnClientEvent:Connect(handler))
            end
        end
        connect("CoinCollected", function(_, current, maximum)
            current, maximum = tonumber(current), tonumber(maximum)
            if not current or not maximum or maximum <= 0 then return end
            if LastAttemptedPickup and os.clock() - LastAttemptedPickupTime < 2.5
                and (not LastBagCount or current > LastBagCount) then
                learnPickupOutcome(LastAttemptedPickup, true)
            end
            LastAttemptedPickup = nil
            LastBagCount, LastBagMaximum = current, maximum
            if current < maximum then
                BagFull = false
                BagFullHandled = false
                HeroState.FullRoundId = nil
                HeroState.FullCharacter = nil
                HeroState.TriedThisBag = false
            elseif RoundActive ~= false then
                local liveCharacter = getCharacter()
                if liveCharacter then
                    if not BagFull then
                        BagFullHandled = false
                        HeroState.TriedThisBag = false
                    end
                    BagFull = true
                    HeroState.FullRoundId = HeroState.RoundId
                    HeroState.FullCharacter = liveCharacter
                    actOnFullBag()
                end
            end
        end)
        connect("RoundStart", function()
            HeroState.RoundId += 1
            BagHandling = false
            saveHotspotMemory(true)
            MapIdentityCache.CheckedAt = -math.huge
            selectHotspotMap(nil)
            RoundActive = true
            AutoFarm.Reset()
            resetHotspotLearning(false)
            HotspotRoundStartSeen = true
            if FarmSettings.Enabled then ensureFarmWorker() end
        end)
        connect("CoinsStarted", function()
            HeroState.RoundId += 1
            BagHandling = false
            MapIdentityCache.CheckedAt = -math.huge
            selectHotspotMap(nil)
            RoundActive = true
            AutoFarm.Reset()
            if HotspotRoundStartSeen then
                for coin, info in pairs(KnownCoins) do
                    if not info.Observed then observeCoin(coin, info, false) end
                end
            else
                resetHotspotLearning(true)
            end
            HotspotRoundStartSeen = false
            if FarmSettings.Enabled then ensureFarmWorker() end
        end)
        connect("VictoryScreen", function()
            if stopBagHero then stopBagHero() end
            RoundActive = false
            clearTween()
            saveHotspotMemory(true)
        end)
        connect("RoundEndFade", function()
            if stopBagHero then stopBagHero() end
            RoundActive = false
            clearTween()
            saveHotspotMemory(true)
        end)
        end
    end)
end
local FarmDeathConnection = nil

local function bindFarmCharacter(character)
    if LocalPlayer.Character ~= character then return end
    if HeroState.FullCharacter and HeroState.FullCharacter ~= character then
        if stopBagHero then stopBagHero() end
        BagHandling = false
        BagFull = false
        BagFullHandled = false
        HeroState.FullRoundId = nil
        HeroState.FullCharacter = nil
        HeroState.TriedThisBag = false
    end
    if FarmDeathConnection then
        FarmDeathConnection:Disconnect()
        FarmDeathConnection = nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
        or character:WaitForChild("Humanoid", 12)
    if humanoid and LocalPlayer.Character == character then
        FarmDeathConnection = humanoid.Died:Connect(function()
            if LocalPlayer.Character ~= character then return end
            if stopBagHero then stopBagHero() end
            BagHandling = false
            BagFull = false
            BagFullHandled = false
            HeroState.FullRoundId = nil
            HeroState.FullCharacter = nil
            HeroState.TriedThisBag = false
            if FarmSettings.Enabled then
                RoundActive = false
                clearTween()
                CoinNavigation.Target = nil
                HotspotLearning.CampPlan = nil
            end
        end)
    end
    if FarmSettings.Enabled then ensureFarmWorker() end
end
table.insert(FarmConnections, LocalPlayer.CharacterAdded:Connect(function(character)
    task.spawn(bindFarmCharacter, character)
end))
if LocalPlayer.Character then task.spawn(bindFarmCharacter, LocalPlayer.Character) end
local AutoFarmTab = TabGroup:Tab({
    Name = "Auto Farm",
    Image = "rbxassetid://7743866529",
})
local FarmSection = AutoFarmTab:Section({ Side = "Left" })
FarmSection:Header({ Name = "Coin Farm" })
FarmEnabledToggle = FarmSection:Toggle({
    Name = "Auto Farm",
    Default = false,
    Callback = function(value)
        if UpdatingFarmUI then return end
        if value then
            AutoFarm.Start()
            if BagFull and (FarmSettings.AutoResetOnFull or FarmSettings.StopReturnOnFull
                or FarmSettings.FullBagHero) then
                actOnFullBag()
            end
        else
            AutoFarm.Stop()
        end
    end,
}, "FarmEnabled")
FarmSection:Slider({
    Name = "Tween Speed",
    Default = FarmSettings.Speed,
    Minimum = 8,
    Maximum = 90,
    Precision = 0,
    DisplayMethod = "Value",
    Callback = function(value) FarmSettings.Speed = value end,
}, "FarmSpeed")
AutoResetToggle = FarmSection:Toggle({
    Name = "Auto Reset When Full",
    Default = false,
    Callback = function(value)
        FarmSettings.AutoResetOnFull = value
        if value and FarmSettings.StopReturnOnFull then
            FarmSettings.StopReturnOnFull = false
            if StopReturnToggle then StopReturnToggle:UpdateState(false) end
        end
        if value and BagFull then actOnFullBag() end
    end,
}, "FarmAutoReset")
StopReturnToggle = FarmSection:Toggle({
    Name = "Stop & Return When Full",
    Default = false,
    Callback = function(value)
        FarmSettings.StopReturnOnFull = value
        if value and FarmSettings.AutoResetOnFull then
            FarmSettings.AutoResetOnFull = false
            if AutoResetToggle then AutoResetToggle:UpdateState(false) end
        end
        if value and BagFull then actOnFullBag() end
    end,
}, "FarmStopReturn")
FarmSection:Toggle({
    Name = "Anti Fling",
    Default = false,
    Callback = function(value)
        setAntiFling(value)
    end,
}, "FarmAntiFling")
FarmSection:Toggle({
    Name = "Auto Shoot When Full", Default = false,
    Callback = function(value)
        FarmSettings.FullBagHero = value
        if not value and HeroState.Running and stopBagHero then
            stopBagHero()
            BagHandling = false
            if FarmSettings.Enabled and BagFull then
                BagFullHandled = false
                actOnFullBag()
            end
        end
    end,
}, "FarmFullBagHero")
FarmSection:Toggle({
    Name = "Auto Rejoin", Default = false,
    Callback = function(value) FarmSettings.AutoRejoin = value end,
}, "FarmAutoRejoin")

local SheriffSettings = {
    GunESP = false,
    AutoGrab = false,
    Aimbot = false,
    AimKey = Enum.UserInputType.MouseButton2,
    AimHeld = false,
    ShowCircle = false,
    FOV = 145,
    SilentAim = false,
}
local SheriffConnections = {}
local GunDropCache = nil
local InitialDropScanDone = false
local GunDropMarker = nil
local DropBox = newDrawing("Square", {
    Visible = false, Filled = false, Thickness = 2,
    Color = Color3.fromRGB(255, 209, 79), Transparency = 1,
})
local DropLabel = newDrawing("Text", {
    Visible = false, Text = "GUN DROP", Center = true, Outline = true,
    Font = 2, Size = 14, Color = Color3.fromRGB(255, 209, 79), Transparency = 1,
})
local AimCircle = newDrawing("Circle", {
    Visible = false, Filled = false, Thickness = 1.5,
    Radius = SheriffSettings.FOV, NumSides = 72,
    Color = Color3.fromRGB(255, 255, 255), Transparency = 0.85,
})
local LastESPFrame = 0
local LastGrabAttempt = 0
local SheriffRenderName = "MiniScriptsSheriff_" .. tostring(math.random(100000, 999999))
local OriginalAimMethods = {}
local WeaponService = nil
do
    local services = ReplicatedStorage:FindFirstChild("ClientServices")
    if services then
        local moduleFolder = ReplicatedStorage:FindFirstChild("Modules")
        local roundModule = (moduleFolder and moduleFolder:FindFirstChild("CurrentRoundClient"))
            or services:FindFirstChild("CurrentRoundClient")
        local weaponModule = services:FindFirstChild("WeaponService")
        if roundModule and roundModule:IsA("ModuleScript") then
            pcall(function() RoundClient = require(roundModule) end)
        end
        if weaponModule and weaponModule:IsA("ModuleScript") then
            pcall(function() WeaponService = require(weaponModule) end)
        end
    end
end

local function isDroppedGunObject(instance)
    if not instance or not instance:IsDescendantOf(workspace) then return false end
    local name = string.lower(instance.Name)
    if name ~= "gundrop" and name ~= "droppedgun" and name ~= "gun_drop" then
        return false
    end
    return instance:IsA("BasePart") or instance:IsA("Model") or instance:IsA("Tool")
end

local function toGunPart(instance)
    if not isDroppedGunObject(instance) then return nil end
    if instance:IsA("BasePart") then return instance end
    if instance:IsA("Model") and instance.PrimaryPart then return instance.PrimaryPart end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function getGunDropPart()
    if GunDropCache and isDroppedGunObject(GunDropCache) then
        return toGunPart(GunDropCache)
    end
    GunDropCache = nil
    if InitialDropScanDone then return nil end
    InitialDropScanDone = true
    local direct = workspace:FindFirstChild("GunDrop")
    if isDroppedGunObject(direct) then
        GunDropCache = direct
        return toGunPart(direct)
    end
    for _, child in ipairs(workspace:GetDescendants()) do
        if isDroppedGunObject(child) then
            GunDropCache = child
            return toGunPart(child)
        end
    end
    return nil
end
table.insert(SheriffConnections, workspace.DescendantAdded:Connect(function(object)
    if isDroppedGunObject(object) then
        GunDropCache = object
    end
end))
table.insert(SheriffConnections, workspace.DescendantRemoving:Connect(function(object)
    if object == GunDropCache or (GunDropCache and GunDropCache:IsDescendantOf(object)) then
        GunDropCache = nil
    end
end))

local function hasGunEquipped()
    local character = LocalPlayer.Character
    if not character then return false end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") then
            if item:HasTag("Weapon_Gun") or string.find(string.lower(item.Name), "gun", 1, true) then
                return true
            end
        end
    end
    return false
end

local function hasGunAnywhere()
    if hasGunEquipped() then return true end
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not backpack then return false end
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and (item:HasTag("Weapon_Gun")
            or string.find(string.lower(item.Name), "gun", 1, true)) then
            return true
        end
    end
    return false
end

local function ensureGunMarker()
    if GunDropMarker and GunDropMarker.Parent then return GunDropMarker end
    local marker = Instance.new("Part")
    marker.Name = "MiniScriptsGunDropMarker"
    marker.Anchored = true
    marker.CanCollide = false
    marker.CanTouch = false
    marker.CanQuery = false
    marker.CastShadow = false
    marker.Transparency = 1
    marker.Size = Vector3.new(2.5, 2.5, 2.5)
    marker.Parent = workspace.CurrentCamera
    GunDropMarker = marker
    return marker
end

local function updateDropDrawing(camera)
    DropBox.Visible = false
    DropLabel.Visible = false
    if not SheriffSettings.GunESP or not camera then return end
    local dropPart = getGunDropPart()
    if not dropPart then return end
    local marker = ensureGunMarker()
    marker.CFrame = CFrame.new(dropPart.Position + Vector3.new(0, 2.4, 0))
    if marker.Parent ~= camera then marker.Parent = camera end
    local cf = marker.CFrame
    local half = marker.Size * 0.5
    local xs, ys = {}, {}
    for _, x in ipairs({ -1, 1 }) do
        for _, y in ipairs({ -1, 1 }) do
            for _, z in ipairs({ -1, 1 }) do
                local pos = cf:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
                local screen = camera:WorldToViewportPoint(pos)
                if screen.Z <= 0 then return end
                table.insert(xs, screen.X)
                table.insert(ys, screen.Y)
            end
        end
    end
    local left, right = math.min(unpack(xs)), math.max(unpack(xs))
    local top, bottom = math.min(unpack(ys)), math.max(unpack(ys))
    DropBox.Position = Vector2.new(left, top)
    DropBox.Size = Vector2.new(right - left, bottom - top)
    DropBox.Visible = true
    DropLabel.Position = Vector2.new((left + right) * 0.5, top - 18)
    DropLabel.Visible = true
end

local function teleportToGunDrop()
    local part = getGunDropPart()
    local character, humanoid, root = getCharacter()
    if not part or not root then return end
    if FarmSettings.Enabled then AutoFarm.Stop() end
    root.CFrame = CFrame.new(part.Position + Vector3.new(0, 1.8, 0))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function tryRemoteGunPickup()
    if not (SheriffSettings.AutoGrab or HeroState.BagHeroMode)
        or hasGunAnywhere() then return end
    local part = getGunDropPart()
    local _, _, root = getCharacter()
    if not part or not root then return end
    local now = os.clock()
    if now - LastGrabAttempt < 0.40 then return end
    LastGrabAttempt = now
    if type(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(root, part, 0)
            firetouchinterest(root, part, 1)
        end)
    end
    local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and type(fireproximityprompt) == "function" then
        pcall(function() fireproximityprompt(prompt) end)
    end
    local clickDetector = part:FindFirstChildWhichIsA("ClickDetector", true)
    if clickDetector and type(fireclickdetector) == "function" then
        pcall(function() fireclickdetector(clickDetector) end)
    end
end

local function aimCenter(camera)
    if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
        return camera.ViewportSize * 0.5
    end
    local location = UserInputService:GetMouseLocation()
    local inset = game:GetService("GuiService"):GetGuiInset()
    return location - inset
end

local function murdererCharacter(player)
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    if RoundClient and type(RoundClient.PlayerData) == "table" then
        local entry = RoundClient.PlayerData[player.Name]
        if entry and entry.Role ~= nil then
            return entry.Role == "Murderer" and entry.Dead ~= true and char or nil
        end
    end
    return GetPlayerRole(player) == "Murderer" and char or nil
end

local function targetVisible(camera, character, part)
    local origin = camera.CFrame.Position
    local direction = part.Position - origin
    if direction.Magnitude <= 0.1 then return true end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local exclusion = { LocalPlayer.Character }
    local collection = game:GetService("CollectionService")
    for _, passthrough in ipairs(collection:GetTagged("WeaponPassthrough")) do
        table.insert(exclusion, passthrough)
    end
    rayParams.FilterDescendantsInstances = exclusion
    for _ = 1, 7 do
        local result = workspace:Raycast(origin, direction, rayParams)
        if not result then return true end
        if result.Instance:IsDescendantOf(character) then return true end
        if result.Instance:IsA("BasePart") and result.Instance.Transparency >= 0.99 then
            table.insert(exclusion, result.Instance)
            rayParams.FilterDescendantsInstances = exclusion
        else
            return false
        end
    end
    return false
end

local function bestMurdererTarget(camera)
    if not camera then return nil end
    local reticle = aimCenter(camera)
    local best, bestDistance = nil, SheriffSettings.FOV
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = murdererCharacter(player)
            if character then
                local part = character:FindFirstChild("Head")
                    or character:FindFirstChild("HumanoidRootPart")
                if part then
                    local screen, onScreen = camera:WorldToViewportPoint(part.Position)
                    if onScreen and screen.Z > 0 then
                        local distance = (Vector2.new(screen.X, screen.Y) - reticle).Magnitude
                        if distance <= bestDistance and targetVisible(camera, character, part) then
                            best, bestDistance = part, distance
                        end
                    end
                end
            end
        end
    end
    return best
end

local function leadPosition(part)
    local velocity = part.AssemblyLinearVelocity
    if velocity.Magnitude > 65 then velocity = velocity.Unit * 65 end
    return part.Position + velocity * 0.06
end
if WeaponService then
    for _, methodName in ipairs({ "GetMouseTargetCFrame", "GetTargetPosition" }) do
        local original = WeaponService[methodName]
        if type(original) == "function" then
            OriginalAimMethods[methodName] = original
            WeaponService[methodName] = function(self, ...)
                if (SheriffSettings.SilentAim or HeroState.BagHeroMode)
                    and hasGunEquipped() then
                    local camera = workspace.CurrentCamera
                    local part = (HeroState.BagHeroMode and HeroState.TargetPart)
                        or bestMurdererTarget(camera)
                    if part and part.Parent then
                        return CFrame.new(leadPosition(part))
                    end
                end
                return original(self, ...)
            end
        end
    end
end

local function matchingAimInput(input)
    return input.KeyCode == SheriffSettings.AimKey
        or input.UserInputType == SheriffSettings.AimKey
end
table.insert(SheriffConnections, UserInputService.InputBegan:Connect(function(input)
    if UserInputService:GetFocusedTextBox() then return end
    if matchingAimInput(input) then SheriffSettings.AimHeld = true end
end))
table.insert(SheriffConnections, UserInputService.InputEnded:Connect(function(input)
    if matchingAimInput(input) then SheriffSettings.AimHeld = false end
end))
RunService:BindToRenderStep(SheriffRenderName, Enum.RenderPriority.Camera.Value + 1, function(dt)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local center = aimCenter(camera)
    AimCircle.Visible = SheriffSettings.ShowCircle
    if SheriffSettings.ShowCircle then
        AimCircle.Position = center
        AimCircle.Radius = SheriffSettings.FOV
    end
    if SheriffSettings.Aimbot and SheriffSettings.AimHeld then
        local part = bestMurdererTarget(camera)
        if part then
            local desired = CFrame.lookAt(camera.CFrame.Position, leadPosition(part))
            camera.CFrame = camera.CFrame:Lerp(desired, math.clamp(dt * 18, 0, 1))
        end
    end
    local now = os.clock()
    if now - LastESPFrame >= 1 / 30 then
        LastESPFrame = now
        updateDropDrawing(camera)
        tryRemoteGunPickup()
    end
end)

local SheriffTab = TabGroup:Tab({
    Name = "Sheriff", Image = "rbxassetid://7733765307",
})
local GunSection = SheriffTab:Section({ Side = "Left" })
local AimSection = SheriffTab:Section({ Side = "Right" })
GunSection:Header({ Name = "Gun Drop" })
GunSection:Toggle({
    Name = "Gun Drop ESP", Default = false,
    Callback = function(value)
        SheriffSettings.GunESP = value
        if not value then
            DropBox.Visible = false
            DropLabel.Visible = false
        end
    end,
}, "SheriffGunESP")
GunSection:Button({
    Name = "Teleport to Gun Drop", Callback = teleportToGunDrop,
})
GunSection:Toggle({
    Name = "Auto Grab Gun", Default = false,
    Callback = function(value) SheriffSettings.AutoGrab = value end,
}, "SheriffAutoGrab")
AimSection:Header({ Name = "Aim" })
AimSection:Toggle({
    Name = "Aimbot", Default = false,
    Callback = function(value)
        SheriffSettings.Aimbot = value
        if not value then SheriffSettings.AimHeld = false end
    end,
}, "SheriffAimbot")
AimSection:Keybind({
    Name = "Aimbot Key",
    Default = Enum.UserInputType.MouseButton2,
    Blacklist = false,
    Callback = function() end,
    onBinded = function(key)
        if typeof(key) == "EnumItem" then
            SheriffSettings.AimKey = key
            SheriffSettings.AimHeld = false
        end
    end,
}, "SheriffAimKey")
AimSection:Toggle({
    Name = "FOV Circle", Default = false,
    Callback = function(value)
        SheriffSettings.ShowCircle = value
        if not value then AimCircle.Visible = false end
    end,
}, "SheriffAimCircle")
AimSection:Slider({
    Name = "Circle Size", Default = SheriffSettings.FOV,
    Minimum = 50, Maximum = 300, DisplayMethod = "Value", Precision = 0,
    Callback = function(value) SheriffSettings.FOV = value end,
}, "SheriffCircleSize")
AimSection:Toggle({
    Name = "Silent Aim", Default = false,
    Callback = function(value) SheriffSettings.SilentAim = value end,
}, "SheriffSilentAim")

local function SheriffCleanup()
    RunService:UnbindFromRenderStep(SheriffRenderName)
    for _, connection in ipairs(SheriffConnections) do connection:Disconnect() end
    for name, original in pairs(OriginalAimMethods) do
        if WeaponService then WeaponService[name] = original end
    end
    safeRemove(DropBox)
    safeRemove(DropLabel)
    safeRemove(AimCircle)
    if GunDropMarker then GunDropMarker:Destroy(); GunDropMarker = nil end
end

local function equippedGunTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") and (obj:HasTag("Weapon_Gun")
            or string.find(obj.Name:lower(), "gun", 1, true)) then
            return obj
        end
    end
    return nil
end

local function equipHeroGun()
    local equipped = equippedGunTool()
    if equipped then return equipped end
    local character, humanoid = getCharacter()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not character or not humanoid or not backpack then return nil end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool:HasTag("Weapon_Gun")
            or string.find(tool.Name:lower(), "gun", 1, true)) then
            pcall(function() humanoid:EquipTool(tool) end)
            return equippedGunTool()
        end
    end
    return nil
end

local function liveMurderer()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = murdererCharacter(player)
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local root = character:FindFirstChild("HumanoidRootPart")
                if humanoid and humanoid.Health > 0 and root then
                    return player, character, root
                end
            end
        end
    end
    return nil
end

local function heroBehindPosition(root, targetRoot, character)
    local forward = targetRoot.CFrame.LookVector
    local origin = targetRoot.Position
    for _, range in ipairs({ 30, 36, 26 }) do
        for _, side in ipairs({ 0, 9, -9, 15, -15 }) do
            local desired = origin - forward * range
                + targetRoot.CFrame.RightVector * side
            local ray = RaycastParams.new()
            ray.FilterType = Enum.RaycastFilterType.Exclude
            ray.FilterDescendantsInstances = { targetRoot.Parent, character }
            local floor = workspace:Raycast(desired + Vector3.new(0, 9, 0),
                Vector3.new(0, -32, 0), ray)
            if floor and floor.Normal.Y >= 0.6
                and floor.Position.Y > workspace.FallenPartsDestroyHeight + 14 then
                local feetHeight = math.max(2.8, root.Size.Y * 1.2)
                local at = Vector3.new(desired.X, floor.Position.Y + feetHeight, desired.Z)
                local target = origin + Vector3.new(0, 1.7, 0)
                local direction = target - (at + Vector3.new(0, 1.5, 0))
                local hit = workspace:Raycast(at + Vector3.new(0, 1.5, 0), direction, ray)
                if not hit then
                    return CFrame.lookAt(at, target)
                end
            end
        end
    end
    return nil
end
stopBagHero = function()
    HeroState.Generation += 1
    HeroState.Running = false
    HeroState.BagHeroMode = false
    HeroState.GunReady = false
    HeroState.TargetPart = nil
end
beginBagHero = function()
    if not FarmSettings.Enabled or not BagFull or HeroState.Running then return false end
    if RoundActive == false
        or HeroState.FullRoundId ~= HeroState.RoundId
        or HeroState.FullCharacter ~= LocalPlayer.Character then return false end
    local murderer = liveMurderer()
    if not murderer then return false end
    if not equipHeroGun() and not getGunDropPart() then return false end
    HeroState.TriedThisBag = true
    HeroState.Running = true
    HeroState.BagHeroMode = true
    HeroState.GunReady = false
    HeroState.TargetPart = nil
    HeroState.Generation += 1
    local runId = HeroState.Generation
    local runRound = HeroState.RoundId
    local runCharacter = HeroState.FullCharacter
    BagHandling = true
    clearTween()
    restoreCharacter()
    if HeroState.StopInnocentEvade then pcall(HeroState.StopInnocentEvade) end
    task.spawn(function()
        local lastMove, lastShot, lastDropWarp = 0, 0, 0
        local noGunSince, noTargetSince = nil, nil
        local shotsAttempted = 0
        local resetFallback = false
        local reason = nil
        local ok, err = pcall(function()
            while FarmSettings.Enabled and HeroState.Running
                and HeroState.Generation == runId and BagFull
                and HeroState.RoundId == runRound
                and HeroState.FullCharacter == runCharacter
                and LocalPlayer.Character == runCharacter
                and RoundActive ~= false do
                local character, humanoid, root = getCharacter()
                if not character or not humanoid or not root then break end
                local _, murderer, enemyRoot = liveMurderer()
                if not murderer or not enemyRoot then
                    noTargetSince = noTargetSince or os.clock()
                    if os.clock() - noTargetSince > 3 then
                        reason = "murderer no longer detected"
                        break
                    end
                    task.wait(0.16)
                    continue
                end
                noTargetSince = nil
                local tool = equipHeroGun()
                if not tool then
                    noGunSince = noGunSince or os.clock()
                    HeroState.GunReady = false
                    HeroState.TargetPart = nil
                    if os.clock() - noGunSince > (shotsAttempted > 0 and 8 or 4.5) then
                        reason = "gun unavailable"
                        resetFallback = shotsAttempted == 0
                        break
                    end
                    tryRemoteGunPickup()
                    local drop = getGunDropPart()
                    if drop and os.clock() - lastDropWarp > 1.3 then
                        lastDropWarp = os.clock()
                        pcall(function()
                            character:PivotTo(CFrame.new(drop.Position + Vector3.new(0, 2.3, 0)))
                            root.AssemblyLinearVelocity = Vector3.zero
                        end)
                        tryRemoteGunPickup()
                    end
                    task.wait(0.18)
                    continue
                end
                noGunSince = nil
                HeroState.GunReady = true
                HeroState.TargetPart = murderer:FindFirstChild("Head") or enemyRoot
                if os.clock() - lastMove > 0.65 then
                    lastMove = os.clock()
                    local destination = heroBehindPosition(root, enemyRoot, character)
                    if destination then
                        pcall(function()
                            character:PivotTo(destination)
                            root.AssemblyLinearVelocity = Vector3.zero
                            root.AssemblyAngularVelocity = Vector3.zero
                        end)
                    end
                end
                if os.clock() - lastShot >= 1.05 then
                    lastShot = os.clock()
                    local fired = pcall(function() tool:Activate() end)
                    if fired then shotsAttempted += 1 end
                end
                task.wait(0.12)
            end
        end)
        if not ok then
            warn("[MM2 Hero] " .. tostring(err))
            reason = "hero encountered an error"
            resetFallback = shotsAttempted == 0
        end
        if HeroState.Generation ~= runId then return end
        stopBagHero()
        BagHandling = false
        if FarmSettings.Enabled and BagFull and RoundActive ~= false
            and HeroState.RoundId == runRound
            and HeroState.FullRoundId == runRound
            and HeroState.FullCharacter == runCharacter
            and LocalPlayer.Character == runCharacter then
            if resetFallback and (FarmSettings.AutoResetOnFull or FarmSettings.StopReturnOnFull) then
                warn("[MM2 Hero] " .. tostring(reason or "attempt failed")
                    .. "; falling back to full-bag action.")
                BagFullHandled = false
                actOnFullBag()
            else
                BagFullHandled = true
                BagHandling = true
                if reason then warn("[MM2 Hero] Stopped: " .. reason .. "; no forced reset.") end
            end
        end
    end)
    return true
end
local RejoinConnections = {}
local LastRejoinAttempt = -math.huge

local function attemptRejoin(message)
    if not FarmSettings.AutoRejoin then return end
    local reason = tostring(message or ""):lower()
    if reason:find("ban", 1, true) then return end
    if not (reason:find("kick", 1, true)
        or reason:find("disconnect", 1, true)
        or reason:find("connection", 1, true)
        or reason:find("error", 1, true)) then return end
    if os.clock() - LastRejoinAttempt < 25 then return end
    LastRejoinAttempt = os.clock()
    task.defer(function()
        if not FarmSettings.AutoRejoin then return end
        local TeleportService = game:GetService("TeleportService")
        local ok, failure = pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
        if not ok then warn("[MM2 Rejoin] Could not rejoin: " .. tostring(failure)) end
    end)
end
local GuiService = game:GetService("GuiService")
local connected = pcall(function()
    table.insert(RejoinConnections, GuiService.ErrorMessageChanged:Connect(attemptRejoin))
end)
if not connected then
    warn("[MM2 Rejoin] Disconnection detection is not supported by this client.")
end
local CollectionService = game:GetService("CollectionService")

local MurdererSettings = {
    KnifeStabRangeEnabled = false,
    KnifeStabRange = 150,
    Whitelisted = {},
}
local MurdererConnections = {}
local MurdererBusy = false
local MurdererJob = 0

local function isWhitelisted(player)
    return player and MurdererSettings.Whitelisted[player.UserId] == true
end

local function targetAlive(player)
    if not player or player == LocalPlayer then return nil end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root then return nil end
    return character, humanoid, root
end

local function knifeReach()
    if MurdererSettings.KnifeStabRangeEnabled then
        return MurdererSettings.KnifeStabRange
    end
    return 7
end

local function findKnife()
    local character = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    for _, container in ipairs({ character, backpack }) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and (
                    CollectionService:HasTag(tool, "Weapon_Knife")
                    or tool:FindFirstChild("KnifeClient") ~= nil
                    or tool:FindFirstChild("Stab") ~= nil
                    or string.find(string.lower(tool.Name), "knife", 1, true) ~= nil
                ) then
                    return tool
                end
            end
        end
    end
    return nil
end

local function equipKnife()
    local tool = findKnife()
    local character, humanoid = getCharacter()
    if not tool or not character or not humanoid then return nil end
    if tool.Parent ~= character then
        pcall(function() humanoid:EquipTool(tool) end)
    end
    return tool.Parent == character and tool or nil
end

local function swingAt(tool, targetRoot)
    if not tool or tool.Parent ~= LocalPlayer.Character then return false end
    local _, _, ownRoot = getCharacter()
    if not ownRoot or not targetRoot or not targetRoot.Parent then return false end
    if (ownRoot.Position - targetRoot.Position).Magnitude > knifeReach() then
        return false
    end
    pcall(function() tool:Activate() end)
    if type(firetouchinterest) == "function" then
        local handle = tool:FindFirstChild("Handle")
            or tool:FindFirstChildWhichIsA("BasePart")
        if handle then
            pcall(function()
                firetouchinterest(handle, targetRoot, 0)
                firetouchinterest(handle, targetRoot, 1)
            end)
        end
    end
    return true
end

local function stabTarget(player, runId)
    for attempt = 1, 3 do
        if runId ~= MurdererJob or isWhitelisted(player) then return end
        local character, humanoid, ownRoot = getCharacter()
        local _, targetHumanoid, targetRoot = targetAlive(player)
        if not character or not humanoid or not ownRoot
            or not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
            return
        end
        if (ownRoot.Position - targetRoot.Position).Magnitude > knifeReach() then
            return
        end
        local tool = equipKnife()
        if not tool then return end
        swingAt(tool, targetRoot)
        task.wait(0.17)
    end
end

local function startStabbing(playersToStab)
    if MurdererBusy then return end
    if not findKnife() then
        warn("[MM2 Murderer] Equip the murderer's knife before stabbing.")
        return
    end
    if not getCharacter() then return end
    if FarmSettings.Enabled then
        AutoFarm.Stop()
        setFarmToggleOff()
    end
    MurdererBusy = true
    MurdererJob += 1
    local thisJob = MurdererJob
    task.spawn(function()
        local ok, failure = pcall(function()
            for _, player in ipairs(playersToStab) do
                if thisJob ~= MurdererJob then break end
                if not isWhitelisted(player) and targetAlive(player) then
                    stabTarget(player, thisJob)
                end
            end
        end)
        if not ok then
            warn("[MM2 Murderer] Stab action interrupted: " .. tostring(failure))
        end
        if thisJob == MurdererJob then
            MurdererBusy = false
        end
    end)
end

local function stabEveryone()
    local _, _, ownRoot = getCharacter()
    local targets = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not isWhitelisted(player) and targetAlive(player) then
            table.insert(targets, player)
        end
    end
    table.sort(targets, function(a, b)
        local _, _, ar = targetAlive(a)
        local _, _, br = targetAlive(b)
        if not ar then return false end
        if not br then return true end
        if not ownRoot then return a.UserId < b.UserId end
        return (ar.Position - ownRoot.Position).Magnitude
            < (br.Position - ownRoot.Position).Magnitude
    end)
    startStabbing(targets)
end

local function formatPlayer(player)
    if player.DisplayName == player.Name then return player.Name end
    return player.DisplayName .. " (@" .. player.Name .. ")"
end

local function listPlayerChoices()
    local choices = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(choices, formatPlayer(player))
        end
    end
    table.sort(choices)
    if #choices == 0 then choices[1] = "No players" end
    return choices
end

local function findPlayerByChoice(choice)
    if type(choice) ~= "string" then return nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and choice == formatPlayer(player) then return player end
    end
    return nil
end

local MurdererTab = TabGroup:Tab({
    Name = "Murderer", Image = "rbxassetid://7733674079",
})
local MurdererSection = MurdererTab:Section({ Side = "Left" })
MurdererSection:Header({ Name = "Knife" })
MurdererSection:Toggle({
    Name = "Knife Stab Range", Default = false,
    Callback = function(value)
        MurdererSettings.KnifeStabRangeEnabled = value
    end,
}, "MurdererKnifeRange")
MurdererSection:Slider({
    Name = "Stab Range", Default = MurdererSettings.KnifeStabRange,
    Minimum = 7, Maximum = 500, DisplayMethod = "Value", Precision = 0,
    Callback = function(value)
        MurdererSettings.KnifeStabRange = math.clamp(math.floor(value + 0.5), 7, 500)
    end,
}, "MurdererKnifeRangeSize")
MurdererSection:Button({
    Name = "Stab All", Callback = stabEveryone,
})
local AllowSelectionStab = false
local PlayerDropdown = MurdererSection:Dropdown({
    Name = "Stab Player", Options = listPlayerChoices(),
    Search = true, Multi = false, Required = false,
    Callback = function(value)
        if not AllowSelectionStab then return end
        local selected = findPlayerByChoice(value)
        if selected then startStabbing({ selected }) end
    end,
}, "MurdererStabPlayer")
AllowSelectionStab = true
local AllowWhitelistSelection = false
local WhitelistDropdown = MurdererSection:Dropdown({
    Name = "Whitelist Players", Options = listPlayerChoices(),
    Search = true, Multi = true, Required = false, Default = {},
    Callback = function(selections)
        if not AllowWhitelistSelection then return end
        local names = {}
        if type(selections) == "table" then
            for key, value in pairs(selections) do
                if type(key) == "string" and value == true then
                    names[key] = true
                elseif type(key) == "number" and type(value) == "string" then
                    names[value] = true
                end
            end
        elseif type(selections) == "string" then
            names[selections] = true
        end
        local allowed = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and names[formatPlayer(player)] then
                allowed[player.UserId] = true
            end
        end
        MurdererSettings.Whitelisted = allowed
    end,
}, "MurdererWhitelist")
AllowWhitelistSelection = true
local KnownPlayerChoices = listPlayerChoices()

local function refreshStabPlayers()
    if not PlayerDropdown or not WhitelistDropdown then return end
    local current = listPlayerChoices()
    local oldSet, newSet = {}, {}
    for _, name in ipairs(KnownPlayerChoices) do oldSet[name] = true end
    for _, name in ipairs(current) do newSet[name] = true end
    local removed, added = {}, {}
    for _, name in ipairs(KnownPlayerChoices) do
        if not newSet[name] then table.insert(removed, name) end
    end
    for _, name in ipairs(current) do
        if not oldSet[name] then table.insert(added, name) end
    end
    AllowSelectionStab = false
    AllowWhitelistSelection = false
    if #removed > 0 then
        pcall(function() PlayerDropdown:RemoveOptions(removed) end)
        pcall(function() WhitelistDropdown:RemoveOptions(removed) end)
    end
    if #added > 0 then
        pcall(function() PlayerDropdown:InsertOptions(added) end)
        pcall(function() WhitelistDropdown:InsertOptions(added) end)
    end
    KnownPlayerChoices = current
    AllowSelectionStab = true
    AllowWhitelistSelection = true
end
table.insert(MurdererConnections, Players.PlayerAdded:Connect(function()
    task.defer(refreshStabPlayers)
end))
table.insert(MurdererConnections, Players.PlayerRemoving:Connect(function(player)
    MurdererSettings.Whitelisted[player.UserId] = nil
    task.defer(refreshStabPlayers)
end))

local function MurdererCleanup()
    MurdererJob += 1
    MurdererBusy = false
    MurdererSettings.KnifeStabRangeEnabled = false
    MurdererSettings.Whitelisted = {}
    for _, connection in ipairs(MurdererConnections) do
        connection:Disconnect()
    end
end
local InnocentCleanup = (function()
local InnocentConnections = {}
local TextChatService = game:GetService("TextChatService")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ValueSync = nil
local PreviewProfile = nil
local PreviewInventoryEvent = nil
local PreviewGeneration = { Emotes = 0, Items = 0 }
local PreviewEnabled = { Emotes = false, Items = false }
local PreviewAdded = { Emotes = {}, Items = {} }
local ValueImageIndex = {}
local ValueNameIndex = {}
local ValueBadges = setmetatable({}, { __mode = "k" })
local PreviewItemService = nil
local CatalogIndexed = false
local LastValueRefresh = 0
local ValueScanQueued = false

local function safeLoadCatalogs()
    if ValueSync and PreviewProfile then return true end
    local database = ReplicatedStorage:FindFirstChild("Database")
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    local syncModule = database and database:FindFirstChild("Sync")
    local profileModule = modules and modules:FindFirstChild("ProfileData")
    if not syncModule or not profileModule then return false end
    local okSync, sync = pcall(require, syncModule)
    local okProfile, profile = pcall(require, profileModule)
    if not okSync or type(sync) ~= "table" or not okProfile or type(profile) ~= "table" then
        return false
    end
    ValueSync, PreviewProfile = sync, profile
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local inventory = remotes and remotes:FindFirstChild("Inventory")
    local event = inventory and inventory:FindFirstChild("InventoryDataChanged")
    if event and event:IsA("BindableEvent") then PreviewInventoryEvent = event end
    return true
end

local function normalItemName(name)
    if type(name) ~= "string" then return "" end
    local clean = string.lower(name):gsub("[^%w]", "")
    return clean
end
local ValueSnapshot = [[
Niks Scythe|250000000
Gingerscope|16000
Travelers Axe|7200
Celestial|1900
Vampires Axe|1400
Emberbow|450
Emberscythe|450
Harvester|250
Icepiercer|165
Icebreaker|70
Batwing|45
Elderwood Scythe|40
SwirlyAxe|40
Hallowscythe|32
Log Chopper|20
Ice Wing|15
Travelers Gun|5000
Evergun|3400
Evergreen|2700
Constellation|2500
Vampires Gun|1900
Alienbeam|1900
Turkey|1900
Raygun|1900
Darkshot|1500
Darksword|1400
Blossom|1200
Sakura|1100
Sunrise|775
Snowcannon|725
Bauble|675
Sunset|650
Soul|570
Spirit|560
Rainbow Gun|410
Flora|405
Rainbow|400
Bloom|395
Xenoshot|390
Xenoknife|385
Heart Wand|350
Blizzard|250
Snowstorm|250
Ocean|240
Flowerwood Gun|235
Waves|235
Flowerwood Knife|230
Snow Dagger|170
Treat|155
Sweet|150
Embersickle|140
WaterGun|140
Icecream|140
Borealis|135
Australis|130
Mortal|125
Immortal|125
Bat|120
Candy|90
Pearlshine|80
Pearl|75
Beachy|75
Sands|75
Heartblade|65
Ornament|60
Red Luger|38
Phantom|37
Spectre|37
Candleflame|35
Elderwood Revolver|35
Darkbringer|35
Iceblaster|35
Sugar|33
Makeshift|33
Lightbringer|33
Elderwood Blade|32
Green Luger|25
Amerilaser|23
Laser|23
Hallowgun|22
Icebeam|20
Shark|20
Plasmabeam|20
Night Blade|20
Swirlygun|18
Iceflake|18
Battle Axe II|18
Pixel|18
Ginger Luger|18
Old Glory|17
Blaster|17
Luger|17
Plasmablade|17
Virtual|15
Slasher|15
Minty|15
Luger Cane|15
Vampires Edge|15
Jinglegun|15
Cookiecane|14
Gingermint|14
Nebula|13
Swirlyblade|13
Death Shard|13
BattleAxe|13
Gingerblade|13
Eternal Cane|13
Gemstone|13
Chill|12
Clockwork|12
Spider|12
Heat|12
Tides|12
Fang|12
Eternal|10
Xmas|10
Frostsaber|10
Eternal III|10
Bioblade|10
Eternal IV|10
Handsaw|9
Hallows Edge|9
Ice Shard|9
Eternal II|8
Boneblade|8
Pumpking|8
Saw|8
Ghost Blade|8
Flames|7
Winters Edge|7
Ice Dragon|7
Hallows Blade|7
Frostbite|7
Eggblade|5
Snowflake|5
Prismatic|5
Peppermint|4
Cookieblade|4
Red Seer|3
Blue Seer|3
Purple Seer|3
Seer|3
Orange Seer|2
Yellow Seer|2
Chroma Travelers Gun|140000
Chroma Evergun|47000
Chroma Evergreen|33000
Chroma Bauble|29000
Chroma Constellation|26000
Chroma Vampires Gun|25000
Chroma Alienbeam|23000
Chroma Emberscythe|13000
Chroma Raygun|13000
Chroma Sunrise|8300
Chroma Snowcannon|7700
Chroma Emberbow|5500
Chroma Sunset|5500
Chroma Blizzard|5500
Chroma Snowstorm|4300
Chroma Heart Wand|3400
Chroma Snow Dagger|2400
Chroma WaterGun|2300
Chroma Icecream|1900
Chroma Mortal|1800
Chroma Immortal|1800
Chroma Ornament|1800
Chroma Treat|1800
Chroma Sweet|1800
Chroma Embersickle|1600
Chroma Sands|1200
Chroma Beachy|1100
Chroma Darkbringer|60
Chroma Lightbringer|55
Chroma Luger|48
Chroma Laser|40
Chroma Candleflame|40
Chroma DeathShard|35
Chroma Swirlygun|35
Chroma Elderwood Blade|35
Chroma Shark|33
Chroma Slasher|33
Chroma Fang|33
Chroma Gemstone|33
Chroma Heat|30
Chroma Cookiecane|30
Chroma Tides|25
Chroma Seer|25
Chroma Gingerblade|25
Chroma Saw|22
Chroma Boneblade|20
]]
local TradeValues = {}
for line in string.gmatch(ValueSnapshot, "[^\r\n]+") do
    local name, value = line:match("^([^|]+)|(%d+)$")
    if name and value then TradeValues[normalItemName(name)] = tonumber(value) end
end
ValueSnapshot = nil

local function indexValueCatalog()
    if CatalogIndexed or not safeLoadCatalogs() then return end
    table.clear(ValueNameIndex)
    table.clear(ValueImageIndex)
    for _, category in ipairs({ "Weapons", "Pets", "Emotes", "Toys", "Effects", "Perks", "Radios" }) do
        local list = ValueSync[category]
        if type(list) == "table" then
            for id, info in pairs(list) do
                if type(info) == "table" then
                    local display = info.ItemName or info.DisplayName or info.Name or tostring(id)
                    local byName = normalItemName(display)
                    local byId = normalItemName(tostring(id))
                    local price = TradeValues[byName] or TradeValues[byId]
                    if price then
                        ValueNameIndex[byId] = price
                        ValueNameIndex[byName] = price
                        local image = tostring(info.Image or info.Icon or "")
                        local asset = image:match("[Aa]sset[Ii]d[=/](%d+)")
                            or image:match("rbxassetid://(%d+)")
                            or image:match("[&?]id=(%d+)")
                            or image:match("(%d+)")
                        if asset then
                            local current = ValueImageIndex[asset]
                            if current == nil then ValueImageIndex[asset] = price
                            elseif current ~= price then ValueImageIndex[asset] = false end
                        end
                    end
                end
            end
        end
    end
    CatalogIndexed = true
end

local function knownRole(player)
    return GetPlayerRole(player)
end

local function sendChat(message)
    local ok = pcall(function()
        local channel = TextChatService:FindFirstChild("TextChannels")
        channel = channel and (channel:FindFirstChild("RBXGeneral")
            or channel:FindFirstChildWhichIsA("TextChannel"))
        if not channel then
            local input = TextChatService:FindFirstChild("ChatInputBarConfiguration")
            channel = input and input.TargetTextChannel
        end
        if not channel then error("Modern chat channel unavailable") end
        channel:SendAsync(message)
    end)
    if ok then return true end
    local okLegacy = pcall(function()
        ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents", 1)
            :WaitForChild("SayMessageRequest", 1):FireServer(message, "All")
    end)
    if not okLegacy then warn("[MM2 Innocent] Chat is unavailable in this server") end
    return okLegacy
end

local function announceRoles()
    if RoundClient and type(RoundClient.GetLatestPlayerData) == "function" then
        pcall(function()
            local latest = RoundClient.GetLatestPlayerData()
            if type(latest) == "table" then RoundClient.PlayerData = latest end
        end)
    end
    local murderer, sheriff = {}, {}
    for _, player in ipairs(Players:GetPlayers()) do
        local role = knownRole(player)
        if role == "Murderer" then table.insert(murderer, player.Name)
        elseif role == "Sheriff" or role == "Hero" then
            table.insert(sheriff, player.Name .. (role == "Hero" and " (Hero)" or ""))
        end
    end
    local message = "MM2 Roles | Murderer: "
        .. (#murderer > 0 and table.concat(murderer, ", ") or "Unknown")
        .. " | Sheriff: "
        .. (#sheriff > 0 and table.concat(sheriff, ", ") or "Unknown")
    sendChat(message)
end

local function playReplicatedGameEmote(id)
    if not PreviewEnabled.Emotes or not ValueSync
        or type(ValueSync.Emotes) ~= "table" or not ValueSync.Emotes[id] then
        return false
    end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local misc = remotes and remotes:FindFirstChild("Misc")
    local event = misc and misc:FindFirstChild("PlayEmote")
    if not (event and event:IsA("BindableEvent")) then
        return false
    end
    return pcall(function() event:Fire(id) end)
end

local function updateClientItem(category, id, amount)
    if PreviewInventoryEvent then
        pcall(function() PreviewInventoryEvent:Fire(category, id, amount) end)
    end
end

local function getPreviewItemService()
    if PreviewItemService then return PreviewItemService end
    local folder = ReplicatedStorage:FindFirstChild("ClientServices")
    local module = folder and folder:FindFirstChild("ItemService")
    if not module then return nil end
    local ok, service = pcall(require, module)
    if ok and type(service) == "table" and service.BaseItemFrame then
        PreviewItemService = service
    end
    return PreviewItemService
end

local function makePreviewFrame(category, id)
    local inventory = PlayerGui:FindFirstChild("Inventory2", true)
    local main = inventory and inventory:FindFirstChild("Main")
    local section = main and main:FindFirstChild(category)
    local items = section and section:FindFirstChild("Items")
    local itemList = items and items:FindFirstChild("ItemList")
    local service = getPreviewItemService()
    if not itemList or not service then return nil end
    local info = (ValueSync[category] and ValueSync[category][id])
        or (category == "Emotes" and ValueSync.Toys and ValueSync.Toys[id])
    if type(info) ~= "table" then return nil end
    local frame = service.BaseItemFrame:Clone()
    frame.Name = "MiniScriptsPreview_" .. tostring(id)
    frame:SetAttribute("DataID", tostring(id))
    frame:SetAttribute("MiniScriptsClientPreview", true)
    local ok = pcall(function()
        service:ApplyItemToFrame(frame, info, 1)
        if frame:FindFirstChild("Tags") then service:ApplyTags(frame, info) end
        frame.LayoutOrder = service:GetLayoutOrder(category, id)
    end)
    if not ok then frame:Destroy(); return nil end
    if category == "Emotes" and ValueSync.Emotes and ValueSync.Emotes[id] then
        local button = frame:IsA("GuiButton") and frame
            or frame:FindFirstChildWhichIsA("GuiButton", true)
        if button then
            button.Activated:Connect(function()
                if frame.Parent and PreviewEnabled.Emotes then
                    playReplicatedGameEmote(id)
                end
            end)
        end
    end
    frame.Parent = itemList
    return frame
end

local function revertPreview(group)
    local added = PreviewAdded[group]
    if PreviewProfile then
        for i = #added, 1, -1 do
            local change = added[i]
            local section = PreviewProfile[change.category]
            local owned = section and section.Owned
            if change.frame then
                pcall(function() change.frame:Destroy() end)
            end
            if type(owned) == "table" then
                if change.map then
                    if owned[change.id] == 1 then owned[change.id] = nil end
                else
                    local index = table.find(owned, change.id)
                    if index then table.remove(owned, index) end
                end
                if change.category == "Emotes" then
                    updateClientItem(change.category, change.id, 0)
                end
            end
        end
    end
    table.clear(added)
end

local function addPreviewItem(group, category, id)
    if not PreviewProfile then return end
    local section = PreviewProfile[category]
    local owned = section and section.Owned
    if type(owned) ~= "table" then return end
    local map = category == "Weapons" or category == "Pets"
    if map then
        if owned[id] ~= nil and owned[id] ~= 0 then return end
        owned[id] = 1
    else
        if table.find(owned, id) then return end
        table.insert(owned, id)
    end
    local frame = makePreviewFrame(category, id)
    table.insert(PreviewAdded[group], {
        category = category, id = id, map = map, frame = frame,
    })
    if category == "Emotes" then updateClientItem(category, id, 1) end
end

local function setPreview(group, enabled)
    PreviewGeneration[group] += 1
    local generation = PreviewGeneration[group]
    PreviewEnabled[group] = enabled
    if not enabled then
        revertPreview(group)
        return
    end
    if not safeLoadCatalogs() then
        PreviewEnabled[group] = false
        warn("[MM2 Innocent] MM2 item catalog not yet available")
        return
    end
    task.spawn(function()
        local categories = group == "Emotes"
            and { "Emotes" }
            or { "Weapons", "Pets", "Effects", "Perks", "Radios", "Toys" }
        local seen = {}
        local count = 0
        for _, category in ipairs(categories) do
            local definitions = ValueSync[category]
            local storeCategory = category == "Toys" and "Emotes" or category
            if type(definitions) == "table" then
                seen[storeCategory] = seen[storeCategory] or {}
                for id, info in pairs(definitions) do
                    if generation ~= PreviewGeneration[group] or not PreviewEnabled[group] then
                        return
                    end
                    if type(id) == "string" and type(info) == "table"
                        and not seen[storeCategory][id] then
                        seen[storeCategory][id] = true
                        addPreviewItem(group, storeCategory, id)
                        count += 1
                        if count % 20 == 0 then task.wait() end
                    end
                end
            end
        end
    end)
end
local ValueContext = {
    Inventory2 = true, TradeGUI = true, Trade = true,
    Inspect = true, Inventory = true,
}

local function insideValueContext(frame)
    local node = frame
    for _ = 1, 11 do
        if not node or node == PlayerGui then break end
        if ValueContext[node.Name] then return true end
        node = node.Parent
    end
    return false
end

local function getItemNameAndIcon(frame)
    local container = frame:FindFirstChild("Container")
    if not container or not container:IsA("GuiObject") then return nil end
    local icon = container:FindFirstChild("Icon")
    if not icon or not icon:IsA("ImageLabel") and not icon:IsA("ImageButton") then
        return nil
    end
    local name = frame:FindFirstChild("ItemName")
    local label = name and name:FindFirstChild("Label")
    local itemName = label and label:IsA("TextLabel") and label.Text or nil
    if not itemName or itemName == "" then
        local alternative = frame:FindFirstChild("Title", true)
        if alternative and alternative:IsA("TextLabel") then itemName = alternative.Text end
    end
    return itemName, icon, container
end

local function extractImageId(image)
    image = tostring(image or "")
    return image:match("[Aa]sset[Ii]d[=/](%d+)")
        or image:match("rbxassetid://(%d+)")
        or image:match("[&?]id=(%d+)")
        or image:match("^%d+$")
end

local function priceOfItem(frame, name, icon)
    local directId = frame:GetAttribute("DataID") or frame:GetAttribute("ItemID")
    local id = directId and normalItemName(tostring(directId))
    if id and ValueNameIndex[id] then return ValueNameIndex[id] end
    local asset = extractImageId(icon.Image)
    local byImage = asset and ValueImageIndex[asset]
    if type(byImage) == "number" then return byImage end
    local normalized = normalItemName(name)
    if normalized ~= "" then
        if ValueNameIndex[normalized] then return ValueNameIndex[normalized] end
        if TradeValues[normalized] then return TradeValues[normalized] end
    end
    return nil
end

local function priceText(price)
    if price >= 1000000 then
        return string.format("%.1fM", price / 1000000):gsub("%.0M", "M")
    elseif price >= 10000 then
        return string.format("%.1fK", price / 1000):gsub("%.0K", "K")
    end
    return tostring(price)
end

local function updateValueTile(frame)
    if not insideValueContext(frame) then return end
    local itemName, icon, container = getItemNameAndIcon(frame)
    if not icon then return end
    local price = priceOfItem(frame, itemName, icon)
    local badge = container:FindFirstChild("MiniScriptsMM2Value")
    if not price then
        if badge then badge.Visible = false end
        return
    end
    if not badge then
        badge = Instance.new("TextLabel")
        badge.Name = "MiniScriptsMM2Value"
        badge.AnchorPoint = Vector2.new(1, 1)
        badge.Position = UDim2.new(1, -3, 1, -3)
        badge.Size = UDim2.fromOffset(56, 18)
        badge.BackgroundColor3 = Color3.fromRGB(15, 15, 16)
        badge.BackgroundTransparency = 0.14
        badge.BorderSizePixel = 0
        badge.TextColor3 = Color3.fromRGB(255, 255, 255)
        badge.Font = Enum.Font.GothamBold
        badge.TextSize = 11
        badge.TextXAlignment = Enum.TextXAlignment.Center
        badge.TextYAlignment = Enum.TextYAlignment.Center
        badge.TextTruncate = Enum.TextTruncate.AtEnd
        badge.ZIndex = math.max(container.ZIndex, icon.ZIndex) + 8
        badge.Parent = container
        ValueBadges[frame] = badge
    end
    badge.Text = priceText(price)
    badge.Visible = frame.Visible and icon.Image ~= ""
end

local function scanItemValues()
    if not safeLoadCatalogs() then return end
    indexValueCatalog()
    for _, gui in ipairs(PlayerGui:GetDescendants()) do
        if gui:IsA("GuiObject") and ValueContext[gui.Name] and gui.Visible ~= false then
            for _, child in ipairs(gui:GetDescendants()) do
                if child:IsA("Frame") and child:FindFirstChild("Container") then
                    updateValueTile(child)
                end
            end
        end
    end
end

local function scheduleValueScan()
    if ValueScanQueued then return end
    ValueScanQueued = true
    task.defer(function()
        ValueScanQueued = false
        scanItemValues()
    end)
end
indexValueCatalog()

local InnocentTab = TabGroup:Tab({
    Name = "Innocent", Image = "rbxassetid://7734056608",
})
local InnocentSection = InnocentTab:Section({ Side = "Left" })
InnocentSection:Header({ Name = "Innocent" })
InnocentSection:Button({
    Name = "Reveal Roles in Chat", Callback = announceRoles,
})
InnocentSection:Toggle({
    Name = "Unlock All Emotes", Default = false,
    Callback = function(value)
        if value then
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local misc = remotes and remotes:FindFirstChild("Misc")
            local event = misc and misc:FindFirstChild("PlayEmote")
            if not (event and event:IsA("BindableEvent")) then
                warn("[MM2 Innocent] Original PlayEmote handler not found; FE playback may not work")
            end
        end
        setPreview("Emotes", value)
    end,
}, "InnocentLocalEmotes")
InnocentSection:Toggle({
    Name = "Unlock Every Item (CLIENT-SIDED)", Default = false,
    Callback = function(value) setPreview("Items", value) end,
}, "InnocentLocalItems")
local StarterGui = game:GetService("StarterGui")

local SurvivalSettings = {
    AutoDodge = false,
    AutoEscape = false,
    SpectateMurderer = false,
    GunDropNotifications = false,
}
local ActiveThrownKnives = setmetatable({}, { __mode = "k" })
local ReportedDrops = setmetatable({}, { __mode = "k" })
local EvadeTween = nil
local EvadeBusy = false
local EvadeJob = 0
local LastEvadeAt = 0
local LastSurvivalTick = 0
local LastSpectateTick = 0
local LastSpectatedPlayer = nil

local function notifyGunDrop()
    task.spawn(function()
        for attempt = 1, 3 do
            local ok = pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "MM2 | Gun Dropped",
                    Text = "The sheriff's gun is on the map.",
                    Duration = 5,
                })
            end)
            if ok then return end
            task.wait(0.3)
        end
        warn("[MM2 Innocent] Gun dropped (notification UI unavailable)")
    end)
end

local function reportNewGunDrop(instance)
    if not SurvivalSettings.GunDropNotifications or not isDroppedGunObject(instance)
        or ReportedDrops[instance] then
        return
    end
    ReportedDrops[instance] = true
    notifyGunDrop()
end
table.insert(InnocentConnections, workspace.DescendantAdded:Connect(reportNewGunDrop))
table.insert(InnocentConnections, workspace.DescendantRemoving:Connect(function(object)
    if ReportedDrops[object] then ReportedDrops[object] = nil end
end))

local function getLivingMurderers()
    local result = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and knownRole(player) == "Murderer" then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root and humanoid and humanoid.Health > 0 then
                table.insert(result, { Player = player, Root = root, Humanoid = humanoid })
            end
        end
    end
    return result
end

local function updateSpectate()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local targetHumanoid, targetPlayer
    if SurvivalSettings.SpectateMurderer then
        for _, threat in ipairs(getLivingMurderers()) do
            targetHumanoid, targetPlayer = threat.Humanoid, threat.Player
            break
        end
    end
    if not targetHumanoid then
        local character = LocalPlayer.Character
        targetHumanoid = character and character:FindFirstChildOfClass("Humanoid")
        targetPlayer = nil
    end
    if targetHumanoid and camera.CameraSubject ~= targetHumanoid then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = targetHumanoid
    end
    LastSpectatedPlayer = targetPlayer
end

local function addThrownKnife(object)
    ActiveThrownKnives[object] = true
end
for _, object in ipairs(CollectionService:GetTagged("ThrowingKnife")) do
    addThrownKnife(object)
end
table.insert(InnocentConnections,
    CollectionService:GetInstanceAddedSignal("ThrowingKnife"):Connect(addThrownKnife))
table.insert(InnocentConnections,
    CollectionService:GetInstanceRemovedSignal("ThrowingKnife"):Connect(function(object)
        ActiveThrownKnives[object] = nil
    end))

local function knifeMotion(projectile)
    if not projectile or not projectile:IsDescendantOf(workspace) then return nil end
    local visual = projectile:FindFirstChild("KnifeVisual", true)
    local blade = projectile:FindFirstChild("BladePosition", true)
    local part = (visual and visual:IsA("BasePart") and visual)
        or (blade and blade:IsA("BasePart") and blade)
        or (projectile:IsA("BasePart") and projectile)
    if not part then return nil end
    local direction = part:GetAttribute("Direction") or projectile:GetAttribute("Direction")
    if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.2 then return nil end
    local speed = tonumber(part:GetAttribute("ThrowSpeed")
        or projectile:GetAttribute("ThrowSpeed")) or 96
    if speed <= 0 then return nil end
    return part.Position, direction.Unit * math.clamp(speed, 25, 250)
end

local function imminentKnife(root)
    local bestVelocity, bestTime = nil, math.huge
    local myVelocity = root.AssemblyLinearVelocity
    if myVelocity.Magnitude > 30 then myVelocity = Vector3.zero end
    for projectile in pairs(ActiveThrownKnives) do
        local position, velocity = knifeMotion(projectile)
        if position and (position - root.Position).Magnitude < 75 then
            local relativeVelocity = velocity - myVelocity
            local relativeSpeed2 = relativeVelocity:Dot(relativeVelocity)
            if relativeSpeed2 > 25 then
                local relativePosition = root.Position - position
                local timeToImpact = math.clamp(
                    relativePosition:Dot(relativeVelocity) / relativeSpeed2, 0, 0.48)
                local predictedSeparation = relativePosition - relativeVelocity * timeToImpact
                if predictedSeparation.Magnitude <= 5.2 and timeToImpact < bestTime then
                    bestVelocity, bestTime = velocity, timeToImpact
                end
            end
        end
    end
    return bestVelocity
end

local function findEscapeFloor(position, character, root, humanoid)
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = { character }
    ray.IgnoreWater = true
    local hit = workspace:Raycast(position + Vector3.new(0, 5, 0),
        Vector3.new(0, -27, 0), ray)
    if not hit or hit.Normal.Y < 0.65
        or not hit.Instance.CanCollide
        or hit.Position.Y <= workspace.FallenPartsDestroyHeight + 75
        or math.abs(hit.Position.Y - root.Position.Y) > 13 then
        return nil
    end
    return Vector3.new(position.X,
        hit.Position.Y + humanoid.HipHeight + root.Size.Y * 0.5, position.Z)
end

local function clearWalkingLine(character, a, b)
    local displacement = b - a
    if displacement.Magnitude <= 0.1 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignored = { character }
    params.FilterDescendantsInstances = ignored
    params.IgnoreWater = true
    for _ = 1, 5 do
        local hit = workspace:Raycast(a, displacement, params)
        if not hit then return true end
        if hit.Instance:IsA("BasePart") and not hit.Instance.CanCollide then
            table.insert(ignored, hit.Instance)
            params.FilterDescendantsInstances = ignored
        else
            return false
        end
    end
    return false
end

local function pickSafeStep(character, humanoid, root, direction, distance, threats)
    direction = Vector3.new(direction.X, 0, direction.Z)
    if direction.Magnitude <= 0.05 then return nil end
    local start = root.Position
    local proposed = start + direction.Unit * distance
    local midpoint = start:Lerp(proposed, 0.5)
    if not findEscapeFloor(midpoint, character, root, humanoid) then return nil end
    local target = findEscapeFloor(proposed, character, root, humanoid)
    if not target or math.abs(target.Y - start.Y) > 7 then return nil end
    if not clearWalkingLine(character, start + Vector3.new(0, 1, 0),
        target + Vector3.new(0, 1, 0)) then
        return nil
    end
    for _, threat in ipairs(threats) do
        if math.abs(threat.Root.Position.Y - target.Y) < 12
            and (threat.Root.Position - target).Magnitude < 15 then
            return nil
        end
    end
    return target
end

local function chooseEscapePoint(character, humanoid, root, threats, knifeVelocity)
    local candidates = {}
    local dangerPosition = nil
    if #threats > 0 then
        table.sort(threats, function(a, b)
            return (a.Root.Position - root.Position).Magnitude
                < (b.Root.Position - root.Position).Magnitude
        end)
        dangerPosition = threats[1].Root.Position
    end
    if knifeVelocity then
        local lateral = Vector3.new(-knifeVelocity.Z, 0, knifeVelocity.X)
        table.insert(candidates, lateral)
        table.insert(candidates, -lateral)
        if dangerPosition then
            local away = root.Position - dangerPosition
            table.insert(candidates, lateral + away * 0.3)
            table.insert(candidates, -lateral + away * 0.3)
        end
    elseif dangerPosition then
        local away = root.Position - dangerPosition
        local flatAway = Vector3.new(away.X, 0, away.Z)
        table.insert(candidates, flatAway)
        local tangent = Vector3.new(-flatAway.Z, 0, flatAway.X)
        table.insert(candidates, flatAway + tangent * 0.8)
        table.insert(candidates, flatAway - tangent * 0.8)
        table.insert(candidates, tangent)
        table.insert(candidates, -tangent)
    end
    local best, bestScore
    for _, direction in ipairs(candidates) do
        for _, distance in ipairs({ 12, 8 }) do
            local point = pickSafeStep(character, humanoid, root,
                direction, distance, threats)
            if point then
                local score = 0
                if dangerPosition then
                    local nowDist = (root.Position - dangerPosition).Magnitude
                    local nextDist = (point - dangerPosition).Magnitude
                    if nextDist <= nowDist + 2 then continue end
                    score += nextDist - nowDist
                end
                score += distance * 0.06
                if not best or score > bestScore then
                    best, bestScore = point, score
                end
            end
        end
    end
    return best
end

local function stopEvade()
    EvadeJob += 1
    if EvadeTween then
        pcall(function() EvadeTween:Cancel() end)
        EvadeTween = nil
    end
    EvadeBusy = false
    InnocentEvading = false
end
HeroState.StopInnocentEvade = stopEvade

local function startEvade(root, destination)
    if EvadeBusy or not root or not root.Parent then return end
    if (destination - root.Position).Magnitude < 2 then return end
    EvadeBusy = true
    EvadeJob += 1
    local job = EvadeJob
    InnocentEvading = true
    if FarmSettings.Enabled then
        restoreCharacter()
    end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    local orientation = root.CFrame - root.Position
    local distance = (destination - root.Position).Magnitude
    local tween = TweenService:Create(root,
        TweenInfo.new(math.clamp(distance / 38, 0.16, 0.48), Enum.EasingStyle.Linear),
        { CFrame = CFrame.new(destination) * orientation })
    EvadeTween = tween
    tween:Play()
    task.spawn(function()
        tween.Completed:Wait()
        if EvadeJob ~= job then return end
        if EvadeTween == tween then EvadeTween = nil end
        task.wait(0.12)
        if EvadeJob ~= job then return end
        EvadeBusy = false
        InnocentEvading = false
    end)
end

local function updateSurvival()
    if MiscMovementBusy or HeroState.BagHeroMode then return end
    if not SurvivalSettings.AutoDodge and not SurvivalSettings.AutoEscape then return end
    if EvadeBusy or os.clock() - LastEvadeAt < 0.55 then return end
    local character, humanoid, root = getCharacter()
    if not character or humanoid.Sit or knownRole(LocalPlayer) == "Murderer" then return end
    local threats = getLivingMurderers()
    local knifeVelocity = SurvivalSettings.AutoDodge and imminentKnife(root) or nil
    local closeThreat = nil
    if SurvivalSettings.AutoEscape then
        for _, entry in ipairs(threats) do
            local distance = entry.Root.Position - root.Position
            if math.abs(distance.Y) < 12 and distance.Magnitude <= 25 then
                closeThreat = entry
                break
            end
        end
    end
    if not knifeVelocity and not closeThreat then return end
    local destination = chooseEscapePoint(character, humanoid, root,
        threats, knifeVelocity)
    if not destination and knifeVelocity and closeThreat then
        destination = chooseEscapePoint(character, humanoid, root, threats, nil)
    end
    if destination then
        LastEvadeAt = os.clock()
        startEvade(root, destination)
    else
        LastEvadeAt = os.clock() - 0.2
    end
end
table.insert(InnocentConnections, RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - LastSurvivalTick >= 0.07 then
        LastSurvivalTick = now
        updateSurvival()
    end
    if now - LastSpectateTick >= 0.35 then
        LastSpectateTick = now
        if SurvivalSettings.SpectateMurderer or LastSpectatedPlayer then
            updateSpectate()
        end
    end
end))
table.insert(InnocentConnections, LocalPlayer.CharacterAdded:Connect(function()
    stopEvade()
    if SurvivalSettings.SpectateMurderer then
        task.defer(updateSpectate)
    end
end))
InnocentSection:Header({ Name = "Survival" })
InnocentSection:Toggle({
    Name = "Auto Dodge Knife", Default = false,
    Callback = function(value)
        SurvivalSettings.AutoDodge = value
        if not value and not SurvivalSettings.AutoEscape then stopEvade() end
    end,
}, "InnocentAutoDodge")
InnocentSection:Toggle({
    Name = "Auto Escape", Default = false,
    Callback = function(value)
        SurvivalSettings.AutoEscape = value
        if not value and not SurvivalSettings.AutoDodge then stopEvade() end
    end,
}, "InnocentAutoEscape")
InnocentSection:Toggle({
    Name = "Spectate Murderer", Default = false,
    Callback = function(value)
        SurvivalSettings.SpectateMurderer = value
        updateSpectate()
    end,
}, "InnocentSpectateMurderer")
InnocentSection:Toggle({
    Name = "Gun Drop Notification", Default = false,
    Callback = function(value)
        SurvivalSettings.GunDropNotifications = value
        if value then
            local part = getGunDropPart()
            if part then
                reportNewGunDrop(GunDropCache or part)
            end
        end
    end,
}, "InnocentGunDropNotification")
local bindWindowWatch
table.insert(InnocentConnections, PlayerGui.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Frame") and descendant:FindFirstChild("Container") then
        scheduleValueScan()
    end
    if ValueContext[descendant.Name] or descendant.Name == "TradeGUI" then
        task.defer(function()
            if descendant:IsDescendantOf(PlayerGui) and not ValueBadges[descendant] then
                bindWindowWatch(descendant)
            end
        end)
    end
end))
bindWindowWatch = function(object)
    if ValueContext[object.Name] and object:IsA("GuiObject") then
        table.insert(InnocentConnections,
            object:GetPropertyChangedSignal("Visible"):Connect(scheduleValueScan))
    elseif object.Name == "TradeGUI" and object:IsA("ScreenGui") then
        table.insert(InnocentConnections,
            object:GetPropertyChangedSignal("Enabled"):Connect(scheduleValueScan))
    end
end
for _, window in ipairs(PlayerGui:GetDescendants()) do bindWindowWatch(window) end
local trade = ReplicatedStorage:FindFirstChild("Trade")
local tradeUpdated = trade and trade:FindFirstChild("UpdateTrade")
if tradeUpdated and tradeUpdated:IsA("RemoteEvent") then
    table.insert(InnocentConnections, tradeUpdated.OnClientEvent:Connect(function()
        task.defer(scheduleValueScan)
    end))
end
table.insert(InnocentConnections, RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - LastValueRefresh >= 1.2 then
        LastValueRefresh = now
        scanItemValues()
    end
end))

local function InnocentCleanup()
    SurvivalSettings.AutoDodge = false
    SurvivalSettings.AutoEscape = false
    SurvivalSettings.SpectateMurderer = false
    SurvivalSettings.GunDropNotifications = false
    stopEvade()
    updateSpectate()
    setPreview("Emotes", false)
    setPreview("Items", false)
    for _, connection in ipairs(InnocentConnections) do
        connection:Disconnect()
    end
    for frame, badge in pairs(ValueBadges) do
        pcall(function() badge:Destroy() end)
        ValueBadges[frame] = nil
    end
end
return InnocentCleanup
end)()
local MiscCleanup = (function()

local MiscSettings = {
    WalkSpeed = 16,
    JumpPower = 50,
    Gravity = workspace.Gravity,
    FOV = (workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView) or 70,
    WalkEdited = false,
    JumpEdited = false,
    GravityEdited = false,
    FOVEdited = false,
    InfiniteJump = false,
    NoClip = false,
    Fly = false,
    FlySpeed = 65,
}
local MiscOriginalGravity = workspace.Gravity
local MiscOriginalFOV = (workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView) or 70
local MiscOriginalHumanoids = setmetatable({}, { __mode = "k" })
local MiscOriginalCollisions = setmetatable({}, { __mode = "k" })
local MiscConnections = {}
local MiscFlight = nil
local MiscFlingBusy = false
local MiscFlingToken = 0
local MiscFlingState = nil
local MiscActionToken = 0
local MiscLastApply = 0
local MiscFlyToggle = nil
local MiscTeleportDropdown = nil
local MiscFlingDropdown = nil
local MiscStatsDropdown = nil
local MiscDropdownEnabled = false

local function miscRememberHumanoid(humanoid)
    if not humanoid or MiscOriginalHumanoids[humanoid] then return end
    MiscOriginalHumanoids[humanoid] = {
        WalkSpeed = humanoid.WalkSpeed,
        JumpPower = humanoid.JumpPower,
        UseJumpPower = humanoid.UseJumpPower,
    }
end

local function miscApplyMovement()
    local _, humanoid = getCharacter()
    if humanoid then
        miscRememberHumanoid(humanoid)
        if MiscSettings.WalkEdited and not MiscFlight then
            humanoid.WalkSpeed = MiscSettings.WalkSpeed
        end
        if MiscSettings.JumpEdited then
            humanoid.UseJumpPower = true
            humanoid.JumpPower = MiscSettings.JumpPower
        end
    end
    if MiscSettings.GravityEdited then
        workspace.Gravity = MiscSettings.Gravity
    end
    local camera = workspace.CurrentCamera
    if camera and MiscSettings.FOVEdited then
        camera.FieldOfView = MiscSettings.FOV
    end
end

local function miscClipCharacter()
    local character = LocalPlayer.Character
    if not character then return end
    for _, item in ipairs(character:GetDescendants()) do
        if item:IsA("BasePart") then
            if MiscOriginalCollisions[item] == nil then
                MiscOriginalCollisions[item] = item.CanCollide
            end
            item.CanCollide = false
        end
    end
end

local function miscRestoreCollisions()
    for part, original in pairs(MiscOriginalCollisions) do
        if part and part.Parent then
            part.CanCollide = original
        end
        MiscOriginalCollisions[part] = nil
    end
end

local function miscStopFlight()
    local state = MiscFlight
    MiscFlight = nil
    if state then
        if state.GravityForce then pcall(function() state.GravityForce:Destroy() end) end
        if state.Attachment then pcall(function() state.Attachment:Destroy() end) end
        if state.Humanoid and state.Humanoid.Parent then
            state.Humanoid.PlatformStand = state.PlatformStand
            state.Humanoid.AutoRotate = state.AutoRotate
            if MiscSettings.WalkEdited then
                state.Humanoid.WalkSpeed = MiscSettings.WalkSpeed
            elseif state.OriginalWalkSpeed then
                state.Humanoid.WalkSpeed = state.OriginalWalkSpeed
            end
            if state.Humanoid.Health > 0 then
                state.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
        if state.Root and state.Root.Parent then
            state.Root.AssemblyLinearVelocity = Vector3.zero
            state.Root.AssemblyAngularVelocity = Vector3.zero
        end
    end
    if not MiscSettings.NoClip and not MiscFlingBusy then
        miscRestoreCollisions()
    end
    MiscMovementBusy = MiscFlingBusy
end

local function miscStartFlight()
    if not MiscSettings.Fly or MiscFlingBusy then return end
    local character, humanoid, root = getCharacter()
    if not root then return end
    if MiscFlight and MiscFlight.Root == root and MiscFlight.Character == character then
        return
    end
    miscStopFlight()
    if FarmSettings.Enabled then
        AutoFarm.Stop()
        setFarmToggleOff()
    end
    if HeroState.StopInnocentEvade then HeroState.StopInnocentEvade() end
    miscRememberHumanoid(humanoid)
    local attachment = Instance.new("Attachment")
    attachment.Name = "MiniScriptsFlightAttachment"
    attachment.Parent = root
    local gravityForce = Instance.new("VectorForce")
    gravityForce.Name = "MiniScriptsFlightGravityBalance"
    gravityForce.Attachment0 = attachment
    gravityForce.RelativeTo = Enum.ActuatorRelativeTo.World
    gravityForce.ApplyAtCenterOfMass = true
    gravityForce.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity, 0)
    gravityForce.Parent = root
    MiscFlight = {
        Character = character, Humanoid = humanoid, Root = root,
        Attachment = attachment, GravityForce = gravityForce,
        PlatformStand = humanoid.PlatformStand,
        AutoRotate = humanoid.AutoRotate,
        OriginalWalkSpeed = humanoid.WalkSpeed,
    }
    humanoid.Sit = false
    root.Anchored = false
    humanoid.PlatformStand = true
    humanoid.AutoRotate = false
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    MiscMovementBusy = true
    miscClipCharacter()
end

local function miscSetFly(enabled)
    MiscSettings.Fly = enabled
    if enabled then
        miscStartFlight()
    else
        miscStopFlight()
    end
end

local function miscFlightStep(dt)
    if not MiscSettings.Fly or MiscFlingBusy then return end
    miscStartFlight()
    local state = MiscFlight
    local camera = workspace.CurrentCamera
    if not state or not camera or not state.Root.Parent
        or LocalPlayer.Character ~= state.Character then return end
    local look = camera.CFrame.LookVector
    local right = camera.CFrame.RightVector
    local forward = Vector3.new(look.X, 0, look.Z)
    local side = Vector3.new(right.X, 0, right.Z)
    forward = forward.Magnitude > 0.001 and forward.Unit or Vector3.new(0, 0, -1)
    side = side.Magnitude > 0.001 and side.Unit or Vector3.new(1, 0, 0)
    local direction = Vector3.zero
    if not UserInputService:GetFocusedTextBox() then
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += side end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= side end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q)
            or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            direction -= Vector3.yAxis
        end
    end
    if direction.Magnitude > 1 then direction = direction.Unit end
    local delta = direction * MiscSettings.FlySpeed * math.clamp(dt or 1/60, 0, 0.06)
    local pivot = state.Character:GetPivot()
    local position = pivot.Position + delta
    local desired = CFrame.lookAt(position, position + forward)
    state.GravityForce.Force = Vector3.new(0,
        state.Root.AssemblyMass * workspace.Gravity, 0)
    state.Character:PivotTo(desired)
    state.Root.AssemblyLinearVelocity = Vector3.zero
    state.Root.AssemblyAngularVelocity = Vector3.zero
    if not state.Humanoid.PlatformStand then state.Humanoid.PlatformStand = true end
    miscClipCharacter()
    MiscMovementBusy = true
end

local function miscInterruptMovement()
    MiscActionToken += 1
    local actionToken = MiscActionToken
    MiscMovementBusy = true
    if FarmSettings.Enabled then
        AutoFarm.Stop()
        setFarmToggleOff()
    end
    if HeroState.StopInnocentEvade then HeroState.StopInnocentEvade() end
    AntiFlingSafeCFrame = nil
    AntiFlingRoot = nil
    task.delay(0.9, function()
        if actionToken == MiscActionToken then
            MiscMovementBusy = MiscSettings.Fly or MiscFlingBusy
        end
    end)
end

local function miscTeleport(targetCFrame)
    local character, humanoid, root = getCharacter()
    if not character or not root or not targetCFrame then
        warn("[EXOZ Misc] Teleport failed: character or destination is missing.")
        return
    end
    if MiscSettings.Fly then
        miscSetFly(false)
        if MiscFlyToggle then
            pcall(function() MiscFlyToggle:UpdateState(false) end)
        end
    end
    miscInterruptMovement()
    humanoid.Sit = false
    root.Anchored = false
    local pivotFromRoot = root.CFrame:ToObjectSpace(character:GetPivot())
    local destinationPivot = targetCFrame * pivotFromRoot
    local job = MiscActionToken
    local ok, failure = pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        character:PivotTo(destinationPivot)
    end)
    if not ok then
        warn("[EXOZ Misc] Teleport failed: " .. tostring(failure))
        return
    end
    task.spawn(function()
        for _ = 1, 2 do
            RunService.Heartbeat:Wait()
            if job ~= MiscActionToken or LocalPlayer.Character ~= character then break end
            if (root.Position - targetCFrame.Position).Magnitude > 4 then
                character:PivotTo(destinationPivot)
            end
        end
        if LocalPlayer.Character == character
            and (root.Position - targetCFrame.Position).Magnitude > 18 then
            warn("[EXOZ Misc] Server or game movement may have rejected the teleport.")
        end
    end)
end

local function miscLivingRoot(player)
    if not player or player == LocalPlayer then return nil end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if humanoid and humanoid.Health > 0 and root then return root end
    return nil
end

local function miscRoleTarget(role)
    if RoundClient and type(RoundClient.GetLatestPlayerData) == "function" then
        pcall(function()
            local latest = RoundClient.GetLatestPlayerData()
            if type(latest) == "table" then RoundClient.PlayerData = latest end
        end)
    end
    local _, _, myRoot = getCharacter()
    local nearest, nearestDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        local playerRole = knownRole(player)
        if playerRole == role or (role == "Sheriff" and playerRole == "Hero") then
            local root = miscLivingRoot(player)
            if root then
                local distance = myRoot and (root.Position - myRoot.Position).Magnitude or 0
                if distance < nearestDist then
                    nearest = player
                    nearestDist = distance
                end
            end
        end
    end
    return nearest
end

local function miscTeleportToPlayer(player)
    local root = miscLivingRoot(player)
    if not root then
        warn("[EXOZ Misc] Player isn't available or alive.")
        return
    end
    miscTeleport(root.CFrame * CFrame.new(0, 2.5, 4))
end

local function miscTeleportToMap()
    local candidates = {}
    for part in pairs(KnownCoins) do
        if part and part:IsA("BasePart") and part:IsDescendantOf(workspace)
            and part.Name == "Coin_Server"
            and part.Position.Y > workspace.FallenPartsDestroyHeight + 70 then
            table.insert(candidates, part)
        end
    end
    if #candidates == 0 then
        for _, part in ipairs(workspace:GetDescendants()) do
            if part:IsA("BasePart") and part.Name == "Coin_Server" then
                table.insert(candidates, part)
            end
        end
    end
    if #candidates == 0 then
        warn("[EXOZ Misc] No map coins are available right now.")
        return
    end
    local coin = candidates[math.random(1, #candidates)]
    miscTeleport(CFrame.new(coin.Position + Vector3.new(0, 2.8, 0)))
end

local function miscRestoreFling()
    local state = MiscFlingState
    MiscFlingState = nil
    if not state then return end
    if state.Spinner then pcall(function() state.Spinner:Destroy() end) end
    if state.Attachment then pcall(function() state.Attachment:Destroy() end) end
    local root, humanoid = state.Root, state.Humanoid
    if root and root.Parent and LocalPlayer.Character == state.Character then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        pcall(function()
            state.Character:PivotTo(state.OriginPivot)
        end)
        root.CanCollide = state.RootCollision
        root.Massless = state.RootMassless
        if humanoid and humanoid.Parent then
            humanoid.PlatformStand = state.PlatformStand
            humanoid.AutoRotate = state.AutoRotate
            if humanoid.Health > 0 then
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end
end

local function miscFlingPlayer(player)
    local targetRoot = miscLivingRoot(player)
    local character, humanoid, root = getCharacter()
    if not targetRoot or not character or not root or MiscFlingBusy then
        warn("[EXOZ Misc] Fling unavailable: target or your character is missing.")
        return
    end
    if MiscSettings.Fly then
        miscSetFly(false)
        if MiscFlyToggle then
            pcall(function() MiscFlyToggle:UpdateState(false) end)
        end
    end
    miscInterruptMovement()
    MiscFlingBusy = true
    MiscMovementBusy = true
    MiscFlingToken += 1
    local flingToken = MiscFlingToken
    local attachment = Instance.new("Attachment")
    attachment.Name = "MiniScriptsFlingAttachment"
    attachment.Parent = root
    local spinner = Instance.new("AngularVelocity")
    spinner.Attachment0 = attachment
    spinner.RelativeTo = Enum.ActuatorRelativeTo.World
    spinner.MaxTorque = 1e9
    spinner.AngularVelocity = Vector3.new(0, 240, 0)
    spinner.Parent = root
    MiscFlingState = {
        Root = root, Humanoid = humanoid, Character = character,
        OriginPivot = character:GetPivot(), RootCollision = root.CanCollide,
        RootMassless = root.Massless,
        PlatformStand = humanoid.PlatformStand, AutoRotate = humanoid.AutoRotate,
        Attachment = attachment, Spinner = spinner,
    }
    humanoid.Sit = false
    humanoid.PlatformStand = true
    humanoid.AutoRotate = false
    root.Anchored = false
    root.Massless = false
    root.CanCollide = true
    task.spawn(function()
        local ok, failure = pcall(function()
            local started = os.clock()
            while flingToken == MiscFlingToken and os.clock() - started < 1.35 do
                if LocalPlayer.Character ~= character then break end
                local target = miscLivingRoot(player)
                if not target then break end
                local t = os.clock() - started
                local radius = 0.4 + (t % 0.18) * 2.4
                local angle = t * 45
                local offset = Vector3.new(math.cos(angle) * radius,
                    math.sin(t * 19) * 0.65, math.sin(angle) * radius)
                local destination = target.Position + offset
                local pivotOffset = root.CFrame:ToObjectSpace(character:GetPivot())
                character:PivotTo(CFrame.new(destination) * pivotOffset)
                root.AssemblyAngularVelocity = Vector3.new(0, 240, 0)
                root.AssemblyLinearVelocity = Vector3.new(
                    math.cos(angle) * 110, 24, math.sin(angle) * 110)
                RunService.Heartbeat:Wait()
            end
        end)
        if not ok then
            warn("[EXOZ Misc] Fling error: " .. tostring(failure))
        end
        if flingToken == MiscFlingToken then
            miscRestoreFling()
            MiscFlingBusy = false
            MiscMovementBusy = false
            AntiFlingRoot = nil
            AntiFlingSafeCFrame = nil
            if MiscSettings.NoClip then miscClipCharacter() end
            print("[EXOZ Misc] Fling attempt finished; success depends on server physics.")
        end
    end)
end

local function miscPrintStats(player)
    if not player or not player.Parent then return end
    local results = {}
    local seen = {}
    local count = 0

    local function add(label, value)
        if count >= 160 then return end
        local dataType = typeof(value)
        if dataType ~= "string" and dataType ~= "number" and dataType ~= "boolean" then return end
        local safeLabel = tostring(label)
        local lowerLabel = safeLabel:lower()
        if lowerLabel:find("token", 1, true) or lowerLabel:find("secret", 1, true)
            or lowerLabel:find("password", 1, true) or lowerLabel:find("auth", 1, true) then
            return
        end
        if seen[safeLabel] then return end
        seen[safeLabel] = true
        results[safeLabel] = tostring(value):sub(1, 120)
        count += 1
    end

    local function inspectFolder(folder, prefix, depth)
        if not folder or depth > 3 then return end
        for _, child in ipairs(folder:GetChildren()) do
            local path = prefix .. "." .. child.Name
            if child:IsA("ValueBase") then
                local ok, value = pcall(function() return child.Value end)
                if ok then add(path, value) end
            elseif child:IsA("Folder") and depth < 3 then
                inspectFolder(child, path, depth + 1)
            end
        end
    end
    for name, value in pairs(player:GetAttributes()) do add("Attribute." .. name, value) end
    for _, name in ipairs({ "leaderstats", "Stats", "Data", "Statistics", "Profile", "PlayerData" }) do
        local folder = player:FindFirstChild(name)
        if folder then inspectFolder(folder, name, 1) end
    end

    local function inspectTable(data, prefix, depth)
        if type(data) ~= "table" or depth > 2 then return end
        for name, value in pairs(data) do
            local key = tostring(name)
            if #key <= 48 then
                local path = prefix .. "." .. key
                if type(value) == "table" then
                    if depth < 2 and (key:lower():find("stats", 1, true)
                        or key:lower():find("data", 1, true)
                        or key:lower():find("profile", 1, true)
                        or key:lower():find("currency", 1, true)
                        or key:lower():find("currencies", 1, true)) then
                        inspectTable(value, path, depth + 1)
                    end
                else
                    add(path, value)
                end
            end
        end
    end
    if RoundClient and type(RoundClient.GetLatestPlayerData) == "function" then
        pcall(function()
            local latest = RoundClient.GetLatestPlayerData()
            if type(latest) == "table" then RoundClient.PlayerData = latest end
        end)
    end
    if RoundClient and type(RoundClient.PlayerData) == "table" then
        local data = RoundClient.PlayerData[player.Name]
            or RoundClient.PlayerData[player.UserId]
        inspectTable(data, "Round", 1)
    end
    if player == LocalPlayer then
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        local module = modules and modules:FindFirstChild("ProfileData")
        if module and module:IsA("ModuleScript") then
            local ok, data = pcall(require, module)
            if ok then inspectTable(data, "OwnProfile", 1) end
        end
    end
    print("\n========== MM2 PLAYER STATS ==========")
    print("Player: " .. player.DisplayName .. " (@" .. player.Name .. ")")
    print("UserId: " .. tostring(player.UserId))
    local sorted = {}
    for name in pairs(results) do table.insert(sorted, name) end
    table.sort(sorted)
    for _, name in ipairs(sorted) do print("  " .. name .. ": " .. results[name]) end

    local function summary(label, keywords)
        for _, keyword in ipairs(keywords) do
            for _, name in ipairs(sorted) do
                local lastKey = (name:match("([^%.]+)$") or name):lower()
                if lastKey == keyword then
                    print("  " .. label .. ": " .. results[name] .. " (" .. name .. ")")
                    return
                end
            end
        end
        print("  " .. label .. ": Not replicated / unavailable")
    end
    print("-- Key stats --")
    summary("Level", { "level", "lvl" })
    summary("Coins", { "coins", "coin", "coinsbalance", "coinbalance", "coinamount" })
    summary("Gems", { "gems", "gem", "diamonds", "gembalance" })
    summary("Prestige", { "prestige", "prestiges" })
    summary("XP", { "xp", "exp", "experience" })
    summary("Wins", { "wins", "victories" })
    print("======================================\n")
end

local function miscStatsChoices()
    local choices = listPlayerChoices()
    for i = #choices, 1, -1 do
        if choices[i] == "No players" then table.remove(choices, i) end
    end
    table.insert(choices, 1, formatPlayer(LocalPlayer))
    return choices
end

local function miscStatsPlayer(choice)
    if choice == formatPlayer(LocalPlayer) then return LocalPlayer end
    return findPlayerByChoice(choice)
end

local MiscTab = TabGroup:Tab({
    Name = "Misc", Image = "rbxassetid://7743871002",
})
local MiscMovementSection = MiscTab:Section({ Side = "Left" })
local MiscPlayersSection = MiscTab:Section({ Side = "Right" })
MiscMovementSection:Header({ Name = "Movement" })
do
    local _, humanoid = getCharacter()
    if humanoid then
        MiscSettings.WalkSpeed = humanoid.WalkSpeed
        MiscSettings.JumpPower = humanoid.JumpPower
    end
end
MiscMovementSection:Slider({
    Name = "Walkspeed", Default = MiscSettings.WalkSpeed,
    Minimum = 0, Maximum = 200, Precision = 0, DisplayMethod = "Value",
    Callback = function(value)
        MiscSettings.WalkSpeed = value
        MiscSettings.WalkEdited = true
        miscApplyMovement()
    end,
}, "MiscWalkSpeed")
MiscMovementSection:Slider({
    Name = "Jump Power", Default = MiscSettings.JumpPower,
    Minimum = 0, Maximum = 250, Precision = 0, DisplayMethod = "Value",
    Callback = function(value)
        MiscSettings.JumpPower = value
        MiscSettings.JumpEdited = true
        miscApplyMovement()
    end,
}, "MiscJumpPower")
MiscMovementSection:Slider({
    Name = "Gravity", Default = MiscSettings.Gravity,
    Minimum = 0, Maximum = 300, Precision = 1, DisplayMethod = "Value",
    Callback = function(value)
        MiscSettings.Gravity = value
        MiscSettings.GravityEdited = true
        workspace.Gravity = value
    end,
}, "MiscGravity")
MiscMovementSection:Slider({
    Name = "FOV", Default = MiscSettings.FOV,
    Minimum = 40, Maximum = 120, Precision = 0, DisplayMethod = "Value",
    Callback = function(value)
        MiscSettings.FOV = value
        MiscSettings.FOVEdited = true
        miscApplyMovement()
    end,
}, "MiscFOV")
MiscMovementSection:Toggle({
    Name = "Infinite Jump", Default = false,
    Callback = function(value) MiscSettings.InfiniteJump = value end,
}, "MiscInfiniteJump")
MiscMovementSection:Toggle({
    Name = "No Clip", Default = false,
    Callback = function(value)
        MiscSettings.NoClip = value
        if value then
            miscClipCharacter()
        elseif not MiscSettings.Fly and not MiscFlingBusy then
            miscRestoreCollisions()
        end
    end,
}, "MiscNoClip")
MiscFlyToggle = MiscMovementSection:Toggle({
    Name = "Fly(Q Down - Space UP)", Default = false,
    Callback = miscSetFly,
}, "MiscFly")
MiscMovementSection:Slider({
    Name = "Fly Speed", Default = MiscSettings.FlySpeed,
    Minimum = 10, Maximum = 200, Precision = 0, DisplayMethod = "Value",
    Callback = function(value) MiscSettings.FlySpeed = value end,
}, "MiscFlySpeed")
MiscPlayersSection:Header({ Name = "Teleport" })
MiscPlayersSection:Button({
    Name = "Teleport to Murderer",
    Callback = function()
        local player = miscRoleTarget("Murderer")
        if player then miscTeleportToPlayer(player)
        else warn("[EXOZ Misc] Murderer not detected.") end
    end,
})
MiscPlayersSection:Button({
    Name = "Teleport to Sheriff",
    Callback = function()
        local player = miscRoleTarget("Sheriff")
        if player then miscTeleportToPlayer(player)
        else warn("[EXOZ Misc] Sheriff not detected.") end
    end,
})
MiscTeleportDropdown = MiscPlayersSection:Dropdown({
    Name = "Teleport to Player", Options = listPlayerChoices(),
    Search = true, Multi = false, Required = false,
    Callback = function(choice)
        if not MiscDropdownEnabled then return end
        local player = findPlayerByChoice(choice)
        if player then miscTeleportToPlayer(player) end
    end,
}, "MiscTeleportPlayer")
MiscPlayersSection:Button({
    Name = "Teleport to Map", Callback = miscTeleportToMap,
})
MiscPlayersSection:Header({ Name = "Fling" })
MiscPlayersSection:Button({
    Name = "Fling Murderer",
    Callback = function()
        local player = miscRoleTarget("Murderer")
        if player then miscFlingPlayer(player)
        else warn("[EXOZ Misc] Murderer not detected.") end
    end,
})
MiscPlayersSection:Button({
    Name = "Fling Sheriff",
    Callback = function()
        local player = miscRoleTarget("Sheriff")
        if player then miscFlingPlayer(player)
        else warn("[EXOZ Misc] Sheriff not detected.") end
    end,
})
MiscFlingDropdown = MiscPlayersSection:Dropdown({
    Name = "Fling Player", Options = listPlayerChoices(),
    Search = true, Multi = false, Required = false,
    Callback = function(choice)
        if not MiscDropdownEnabled then return end
        local player = findPlayerByChoice(choice)
        if player then miscFlingPlayer(player) end
    end,
}, "MiscFlingPlayer")
MiscPlayersSection:Header({ Name = "Player Stats" })
MiscStatsDropdown = MiscPlayersSection:Dropdown({
    Name = "Print Player Stats", Options = miscStatsChoices(),
    Search = true, Multi = false, Required = false,
    Callback = function(choice)
        if not MiscDropdownEnabled then return end
        local player = miscStatsPlayer(choice)
        if player then miscPrintStats(player) end
    end,
}, "MiscPrintPlayerStats")
MiscDropdownEnabled = true
local MiscKnownChoices = listPlayerChoices()

local function miscRefreshDropdowns()
    if not MiscTeleportDropdown or not MiscFlingDropdown or not MiscStatsDropdown then return end
    local latest = listPlayerChoices()
    local old, now = {}, {}
    for _, choice in ipairs(MiscKnownChoices) do old[choice] = true end
    for _, choice in ipairs(latest) do now[choice] = true end
    local removed, added = {}, {}
    for _, choice in ipairs(MiscKnownChoices) do
        if not now[choice] then table.insert(removed, choice) end
    end
    for _, choice in ipairs(latest) do
        if not old[choice] then table.insert(added, choice) end
    end
    MiscDropdownEnabled = false
    if #removed > 0 then
        pcall(function() MiscTeleportDropdown:RemoveOptions(removed) end)
        pcall(function() MiscFlingDropdown:RemoveOptions(removed) end)
        pcall(function() MiscStatsDropdown:RemoveOptions(removed) end)
    end
    if #added > 0 then
        pcall(function() MiscTeleportDropdown:InsertOptions(added) end)
        pcall(function() MiscFlingDropdown:InsertOptions(added) end)
        pcall(function() MiscStatsDropdown:InsertOptions(added) end)
    end
    MiscKnownChoices = latest
    MiscDropdownEnabled = true
end
table.insert(MiscConnections, Players.PlayerAdded:Connect(function()
    task.defer(miscRefreshDropdowns)
end))
table.insert(MiscConnections, Players.PlayerRemoving:Connect(function()
    task.defer(miscRefreshDropdowns)
end))
table.insert(MiscConnections, UserInputService.JumpRequest:Connect(function()
    if not MiscSettings.InfiniteJump or MiscSettings.Fly then return end
    local _, humanoid = getCharacter()
    if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
end))
table.insert(MiscConnections, LocalPlayer.CharacterAdded:Connect(function(character)
    miscStopFlight()
    miscRestoreCollisions()
    task.defer(function()
        if not character or not character.Parent then return end
        local humanoid = character:WaitForChild("Humanoid", 5)
        local root = character:WaitForChild("HumanoidRootPart", 5)
        if humanoid and root then
            miscApplyMovement()
            if MiscSettings.Fly then miscStartFlight() end
        end
    end)
end))
table.insert(MiscConnections, RunService.Stepped:Connect(function()
    if (MiscSettings.NoClip or MiscSettings.Fly) and not MiscFlingBusy then
        miscClipCharacter()
    end
end))
table.insert(MiscConnections, RunService.Heartbeat:Connect(function(dt)
    local now = os.clock()
    if now - MiscLastApply > 0.35 then
        MiscLastApply = now
        miscApplyMovement()
    end
    if MiscSettings.Fly and not MiscFlingBusy then
        local ok, message = pcall(miscFlightStep, dt)
        if not ok then
            warn("[EXOZ Misc] Fly stopped after error: " .. tostring(message))
            miscSetFly(false)
            if MiscFlyToggle then
                pcall(function() MiscFlyToggle:UpdateState(false) end)
            end
        end
    end
end))

local function cleanup()
    MiscFlingToken += 1
    miscRestoreFling()
    MiscFlingBusy = false
    MiscActionToken += 1
    MiscSettings.Fly = false
    miscStopFlight()
    miscRestoreCollisions()
    MiscMovementBusy = false
    for _, connection in ipairs(MiscConnections) do
        connection:Disconnect()
    end
    workspace.Gravity = MiscOriginalGravity
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = MiscOriginalFOV
    end
    for humanoid, original in pairs(MiscOriginalHumanoids) do
        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed = original.WalkSpeed
            humanoid.JumpPower = original.JumpPower
            humanoid.UseJumpPower = original.UseJumpPower
        end
    end
end
return cleanup
end)()

local SettingsTab = TabGroup:Tab({
    Name = "Settings", Image = "rbxassetid://7734053495",
})
local ConfigReady, ConfigError = pcall(function()
    MacLib:SetFolder("ExozHub_MM2_Configs")
    SettingsTab:InsertConfigSection("Left")
end)
if not ConfigReady then
    warn("[EXOZ Settings] Config section unavailable: " .. tostring(ConfigError))
end

do
    local credits = SettingsTab:Section({ Side = "Right" })
    credits:Header({ Name = "Credits" })
    credits:Header({ Name = "Developers: flamesiscoolz, vn" })
end
Window.onUnloaded(function()
    HotspotDisk.Running = false
    saveHotspotMemory(true)
    if stopBagHero then stopBagHero() end
    for _, connection in ipairs(RejoinConnections) do connection:Disconnect() end
    MiscCleanup()
    InnocentCleanup()
    MurdererCleanup()
    SheriffCleanup()
    setAntiFling(false)
    AutoFarm.Stop()
    for _, connection in ipairs(FarmConnections) do
        connection:Disconnect()
    end
    if FarmDeathConnection then
        FarmDeathConnection:Disconnect()
        FarmDeathConnection = nil
    end
    for _, signals in pairs(CoinConnections) do
        for _, signal in ipairs(signals) do signal:Disconnect() end
    end
    Cleanup()
end)
VisualsTab:Select()
if ConfigReady then
    local ok, err = pcall(function() MacLib:LoadAutoLoadConfig() end)
    if not ok then warn("[EXOZ Settings] Auto-load failed: " .. tostring(err)) end
end
