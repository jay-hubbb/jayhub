getgenv().brSlot1 = {"Nuclearo Dinossauro"}
getgenv().brSlot3 = {"Job Job Job Sahur"}
getgenv().Luck = "5:00"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")

local SpawnMachine = workspace:WaitForChild("SpawnMachines"):WaitForChild("Default")
local ActionRemote = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net"):WaitForChild("RF/SpawnMachine.Action")
local PlotRemote = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net"):WaitForChild("RF/Plot.PlotAction")

local BrainrotsUI = SpawnMachine.Main.Billboard.BillboardGui.Frame.Brainrots
local BrainrotsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Brainrots")

local brList = {}

local function fetchBrList()
    table.clear(brList)
    for _, rarityFolder in ipairs(BrainrotsFolder:GetChildren()) do
        if rarityFolder:IsA("Folder") then
            brList[rarityFolder.Name] = {}
            for _, brainrotModel in ipairs(rarityFolder:GetChildren()) do
                if brainrotModel:IsA("Model") then
                    table.insert(brList[rarityFolder.Name], brainrotModel.Name)
                end
            end
        end
    end
end

fetchBrList()

local function TeleportTo(cf)
    root.CFrame = cf + Vector3.new(0, 3, 0)
    task.wait(0.4)
end

local function TeleportToMachine()
    TeleportTo(SpawnMachine:GetPivot())
end

local function GetLine(i)
    return BrainrotsUI:FindFirstChild("Line_" .. i)
end

local function RefetchTool(brainrotName)
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("BrainrotName") == brainrotName then
            return tool
        end
    end
end

local function MachineHasBrainrot()
    return GetLine(1) or GetLine(2) or GetLine(3)
end

local function ClearMachine()
    TeleportToMachine()
    while MachineHasBrainrot() do
        ActionRemote:InvokeServer("Withdraw", SpawnMachine)
        task.wait(0.4)
    end
end

local function UnequipAll()
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            tool.Parent = backpack
        end
    end
end

local function IsCommon(name)
    for _, n in ipairs(brList.Common or {}) do
        if n == name then
            return true
        end
    end
end

local function GetSlot1Tool()
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool")
        and tool:GetAttribute("BrainrotName") == getgenv().brSlot1[1]
        and tool:GetAttribute("Mutation") == "None" then
            return tool
        end
    end
end

local function GetSlot3Tool()
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool")
        and tool:GetAttribute("BrainrotName") == getgenv().brSlot3[1]
        and tool:GetAttribute("Mutation") ~= "None" then
            return tool
        end
    end
end

local function GetAnyCommon()
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and IsCommon(tool:GetAttribute("BrainrotName")) or tool:GetAttribute("Level") == 125 then
            return tool
        end
    end
end

local function CollectNearestCommon()
    local folder = workspace.ActiveBrainrots.Common
    local oldCF = root.CFrame
    local closest, dist = nil, math.huge

    for _, br in ipairs(folder:GetChildren()) do
        if br:GetAttribute("Mutation") == "None" then
            local d = (br:GetPivot().Position - root.Position).Magnitude
            if d < dist then
                dist = d
                closest = br
            end
        end
    end

    if not closest then
        return
    end

    root.CFrame = closest:GetPivot() * CFrame.new(0, 0, -2.5)
    task.wait(0.3)

    local prompt
    for _, desc in ipairs(closest:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            prompt = desc
            break
        end
    end

    if prompt then
        prompt.HoldDuration = 0
        fireproximityprompt(prompt)
    end

    task.wait(0.4)
    root.CFrame = oldCF
    task.wait(0.4)

    UnequipAll()
end

local function GetPlayerBase()
    for _, base in ipairs(workspace.Bases:GetChildren()) do
        if base:GetAttribute("Holder") == player.UserId then
            return base
        end
    end
end

local function TeleportToBase()
    local base = GetPlayerBase()
    if base then
        TeleportTo(base:GetPivot())
    end
end

local function GetFreeSlot(base)
    local used = tonumber(base.UpgradeBase.Sign.SurfaceGui.Button.SlotCount.Text:match("^(%d+)/"))
    for i = 1, used do
        local slot = base:FindFirstChild("slot " .. i .. " brainrot")
        if slot and #slot:GetChildren() == 1 then
            return tostring(i)
        end
    end
end

local function UpgradeTo125(tool)
    if tool:GetAttribute("Level") == 125 then
        return
    end

    local base = GetPlayerBase()
    if not base then
        return
    end

    local slot = GetFreeSlot(base)
    if not slot then
        return
    end
    
    TeleportToBase()

    tool.Parent = character
    PlotRemote:InvokeServer("Place Brainrot", base.Name, slot)

    repeat
        PlotRemote:InvokeServer("Upgrade Brainrot", base.Name, slot)
        task.wait(0.2)
    until base["slot " .. slot .. " brainrot"]
        :GetChildren()[2]
        .ModelExtents.StatsGui.Frame.Level.Text == "Lv.50"

    PlotRemote:InvokeServer("Pick Up Brainrot", base.Name, slot)
    UnequipAll()
end

local function PrepareSlot2Common()
    local tool = GetAnyCommon()
    if not tool then
        CollectNearestCommon()
        task.wait(1)
        tool = GetAnyCommon()
    end
    if not tool then
        return
    end

    local name = tool:GetAttribute("BrainrotName")
    UpgradeTo125(tool)
    task.wait(0.5)

    return RefetchTool(name)
end

local function WaitForSlot(i)
    while GetLine(i) do
        task.wait(0.2)
    end
end

local function Deposit(tool, i)
    if tool.Parent ~= backpack and tool.Parent ~= character then
        return
    end
    WaitForSlot(i)
    tool.Parent = character
    ActionRemote:InvokeServer("Deposit", SpawnMachine)
end

local function WaitForLuck()
    if getgenv().Luck == "" then
        return
    end
    local label = BrainrotsUI.AFKLuckContainer.TimeLabel
    while label.Text ~= getgenv().Luck do
        task.wait(0.2)
    end
end

local function AutoFuse()
    local slot1 = GetSlot1Tool()
    local slot3 = GetSlot3Tool()
    if not slot1 or not slot3 then
        return
    end

    local slot2 = PrepareSlot2Common()
    if not slot2 then
        return
    end

    ClearMachine()

    Deposit(slot1, 1)
    task.wait(0.3)
    Deposit(slot2, 2)
    task.wait(0.3)
    Deposit(slot3, 3)

    WaitForLuck()
    ActionRemote:InvokeServer("Combine", SpawnMachine)
end

AutoFuse()
