if getgenv().ElementaryEvilFarmLoaded then
    warn("Elementary Evil farm is already loaded.")
    return
end

getgenv().ElementaryEvilFarmLoaded = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

--// Kavo UI
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"
))()

local Window = Library.CreateLib("Elementary Evil | Event Farm", "DarkTheme")

local FarmTab = Window:NewTab("Auto Farm")
local CrystalSection = FarmTab:NewSection("Crystals / Shards")
local CandySection = FarmTab:NewSection("Halloween Candy")

local MiscTab = Window:NewTab("Misc")
local MiscSection = MiscTab:NewSection("Controls")

local ShardsFolder = Workspace:FindFirstChild("Shards")
local HalloweenDoors = Workspace:FindFirstChild("HalloweenDoors")

local HalloweenRemotes = ReplicatedStorage:FindFirstChild("HalloweenRemotes")
local RequestInteract = HalloweenRemotes and HalloweenRemotes:FindFirstChild("RequestInteract")

local Settings = {
    AutoCrystals = false,
    AutoCandy = false,

    CrystalDelay = 0.12,
    CandyDelay = 5,

    ReturnAfterFarm = false
}

local StartCFrame = nil
local Busy = false

local ProcessedDoors = setmetatable({}, {
    __mode = "k"
})

local function GetCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function GetRoot()
    local Character = GetCharacter()

    return Character:FindFirstChild("HumanoidRootPart")
        or Character:WaitForChild("HumanoidRootPart", 5)
end

local function SaveStartPosition()
    local Root = GetRoot()

    if Root then
        StartCFrame = Root.CFrame
    end
end

SaveStartPosition()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    SaveStartPosition()
end)


local function TeleportTo(CF)
    local Root = GetRoot()

    if not Root then
        return false
    end

    Root.Anchored = false

    Root.AssemblyLinearVelocity = Vector3.zero
    Root.AssemblyAngularVelocity = Vector3.zero

    Root.CFrame = CF

    return true
end

local function ReturnToStart()
    if StartCFrame then
        TeleportTo(StartCFrame)
    end
end

local function GetShardsFolder()
    ShardsFolder = Workspace:FindFirstChild("Shards")
    return ShardsFolder
end

local function IsValidShard(Shard)
    if not Shard then
        return false
    end

    if not Shard.Parent then
        return false
    end

    if not Shard:IsA("BasePart") then
        return false
    end

    if Shard:GetAttribute("Collected") == true then
        return false
    end

    return true
end

local function GetNearestShard()
    local Folder = GetShardsFolder()

    if not Folder then
        return nil
    end

    local Root = GetRoot()

    if not Root then
        return nil
    end

    local Closest = nil
    local ClosestDistance = math.huge

    for _, Shard in ipairs(Folder:GetChildren()) do
        if IsValidShard(Shard) then
            local Distance = (Root.Position - Shard.Position).Magnitude

            if Distance < ClosestDistance then
                ClosestDistance = Distance
                Closest = Shard
            end
        end
    end

    return Closest
end

local function TouchShard(Shard)
    if not IsValidShard(Shard) then
        return false
    end

    local Root = GetRoot()

    if not Root then
        return false
    end

    TeleportTo(
        Shard.CFrame * CFrame.new(0, 0.25, 0)
    )

    task.wait(0.04)

    if firetouchinterest then
        pcall(function()
            firetouchinterest(Root, Shard, 0)
            task.wait(0.03)
            firetouchinterest(Root, Shard, 1)
        end)
    end

    task.wait(Settings.CrystalDelay)

    return true
end

local function CollectAllCurrentShards()
    if Busy then
        return
    end

    Busy = true

    local Safety = 0

    while Safety < 1000 do
        Safety += 1

        if Settings.AutoCandy then
            -- Candy gets movement priority.
            break
        end

        local Shard = GetNearestShard()

        if not Shard then
            break
        end

        TouchShard(Shard)
    end

    Busy = false

    if Settings.ReturnAfterFarm then
        ReturnToStart()
    end
end


local function GetDoorsFolder()
    HalloweenDoors = Workspace:FindFirstChild("HalloweenDoors")
    return HalloweenDoors
end

local function GetDoorCollider(Door)
    if not Door then
        return nil
    end

    local Collider = Door:FindFirstChild("ClickCollider", true)

    if Collider and Collider:IsA("BasePart") then
        return Collider
    end

    if Collider then
        return Collider:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local function GetClickDetector(Door)
    local Collider = Door and Door:FindFirstChild("ClickCollider", true)

    if not Collider then
        return nil
    end

    return Collider:FindFirstChildOfClass("ClickDetector")
        or Collider:FindFirstChildWhichIsA("ClickDetector", true)
end

local function GetNextCandyDoor()
    local Folder = GetDoorsFolder()

    if not Folder then
        return nil
    end

    local Root = GetRoot()

    if not Root then
        return nil
    end

    local ClosestDoor = nil
    local ClosestDistance = math.huge

    for _, Door in ipairs(Folder:GetChildren()) do
        if Door:IsA("Model")
            and Door.Parent
            and not ProcessedDoors[Door]
        then
            local Collider = GetDoorCollider(Door)

            if Collider then
                local Distance = (Root.Position - Collider.Position).Magnitude

                if Distance < ClosestDistance then
                    ClosestDistance = Distance
                    ClosestDoor = Door
                end
            end
        end
    end

    return ClosestDoor
end

local function CollectCandyDoor(Door)
    if not Door or not Door.Parent then
        return false
    end

    local Collider = GetDoorCollider(Door)

    if not Collider then
        ProcessedDoors[Door] = true
        return false
    end

    TeleportTo(
        Collider.CFrame * CFrame.new(0, 0, 3)
    )

    task.wait(0.15)

    local Detector = GetClickDetector(Door)

    local Fired = false

    if Detector and fireclickdetector then
        local Success = pcall(function()
            fireclickdetector(Detector)
        end)

        Fired = Success
    end


    if not Fired and RequestInteract then
        local Success = pcall(function()
            RequestInteract:FireServer(Door)
        end)

        Fired = Success
    end

    if Fired then
        ProcessedDoors[Door] = true
  
        task.wait(Settings.CandyDelay)

        local Root = GetRoot()

        if Root then
            Root.Anchored = false
        end

        return true
    end

    return false
end

local function CollectAllCurrentCandy()
    if Busy then
        return
    end

    Busy = true

    local Safety = 0

    while Safety < 250 do
        Safety += 1

        if not Settings.AutoCandy then
            break
        end

        local Door = GetNextCandyDoor()

        if not Door then
            break
        end

        CollectCandyDoor(Door)

        task.wait(0.1)
    end

    Busy = false

    if Settings.ReturnAfterFarm then
        ReturnToStart()
    end
end

task.spawn(function()
    while task.wait(0.08) do
        if not Busy then


            if Settings.AutoCandy then
                local Door = GetNextCandyDoor()

                if Door then
                    Busy = true

                    pcall(function()
                        CollectCandyDoor(Door)
                    end)

                    Busy = false
                end

            elseif Settings.AutoCrystals then
                local Shard = GetNearestShard()

                if Shard then
                    Busy = true

                    pcall(function()
                        TouchShard(Shard)
                    end)

                    Busy = false
                end
            end
        end
    end
end)



CrystalSection:NewToggle(
    "Auto Collect Crystals",
    "Automatically collects every shard/crystal that spawns.",
    function(Value)
        Settings.AutoCrystals = Value
    end
)

CrystalSection:NewButton(
    "Collect All Crystals Now",
    "Teleports through every currently available crystal.",
    function()
        task.spawn(function()
            local OldAuto = Settings.AutoCandy
            Settings.AutoCandy = false

            CollectAllCurrentShards()

            Settings.AutoCandy = OldAuto
        end)
    end
)

CandySection:NewToggle(
    "Auto Collect Candy",
    "Automatically uses every Halloween trick-or-treat door.",
    function(Value)
        Settings.AutoCandy = Value

        if Value then
            task.spawn(CollectAllCurrentCandy)
        end
    end
)

CandySection:NewButton(
    "Collect All Candy Doors Now",
    "Runs through all currently spawned Halloween doors.",
    function()
        Settings.AutoCandy = true

        task.spawn(CollectAllCurrentCandy)
    end
)

CandySection:NewButton(
    "Reset Candy Door List",
    "Allows the script to retry every Halloween door.",
    function()
        table.clear(ProcessedDoors)
    end
)

MiscSection:NewToggle(
    "Return To Start",
    "Returns to your saved position after a farming pass.",
    function(Value)
        Settings.ReturnAfterFarm = Value
    end
)

MiscSection:NewButton(
    "Save Current Position",
    "Changes the return position to where you are standing now.",
    function()
        SaveStartPosition()
    end
)

MiscSection:NewButton(
    "Return To Saved Position",
    "Teleports back to your saved position.",
    function()
        ReturnToStart()
    end
)

MiscSection:NewButton(
    "STOP EVERYTHING",
    "Turns off all automatic collection.",
    function()
        Settings.AutoCrystals = false
        Settings.AutoCandy = false

        local Root = GetRoot()

        if Root then
            Root.Anchored = false
        end
    end
)
