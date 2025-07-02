local script = {}

script.settings = {
    Enabled = false,
    TeamCheck = false,
    HealthCheck = false,
    VisibleCheck = false,
    Sensitivity = 0,
    LockPart = "Head",
    Distance = false,
    MaxDistance = 1000,
    Hotkey1 = Enum.UserInputType.MouseButton2,
    Hotkey2 = Enum.KeyCode.E,
    Toggle = false,
    fov = {
        Enabled = false,
        Visible = false,
        Radius = 50,
        NumSides = 0,
        Thickness = 1,
        Transparency = 1,
        Filled = false,
        Color = Color3.fromRGB(255, 255, 255),
        LockedColor = Color3.fromRGB(255, 0, 0)
    }
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local isDrawingAvailable = Drawing and typeof(Drawing.new) == "function"
if not isDrawingAvailable then
    warn("Drawing API not available; FOV will be disabled.")
end

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local isToggledOn = false
local wasHotkeyPressed = false
local fovCircle = nil

RunService.RenderStepped:Connect(function(deltaTime)
    local fovSettings = script.settings.fov
    local screenCenter = camera.ViewportSize / 2

    if isDrawingAvailable and fovSettings.Enabled then
        if not fovCircle then
            fovCircle = Drawing.new("Circle")
        end
        fovCircle.Visible = fovSettings.Visible
        fovCircle.Radius = fovSettings.Radius
        fovCircle.NumSides = fovSettings.NumSides
        fovCircle.Thickness = fovSettings.Thickness
        fovCircle.Transparency = fovSettings.Transparency
        fovCircle.Filled = fovSettings.Filled
        fovCircle.Position = screenCenter
    elseif fovCircle then
        fovCircle:Remove()
        fovCircle = nil
    end

    if not script.settings.Enabled then
        isToggledOn = false
        return
    end

    local isHotkeyPressed =
        (script.settings.Hotkey1 and UserInputService:IsMouseButtonPressed(script.settings.Hotkey1)) or
        (script.settings.Hotkey2 and UserInputService:IsKeyDown(script.settings.Hotkey2))

    if script.settings.Toggle then
        if isHotkeyPressed and not wasHotkeyPressed then
            isToggledOn = not isToggledOn
        end
    end
    wasHotkeyPressed = isHotkeyPressed

    local shouldAim = (script.settings.Toggle and isToggledOn) or (not script.settings.Toggle and isHotkeyPressed)
    local closestTarget = nil
    local closestDistance = math.huge

    if shouldAim then
        local localCharacter = localPlayer.Character
        local localHead = localCharacter and localCharacter:FindFirstChild("Head")
        if not (localCharacter and localHead) then return end

        for _, player in ipairs(Players:GetPlayers()) do
            if player == localPlayer then continue end

            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if not (character and humanoid) then continue end

            if script.settings.TeamCheck and player.TeamColor == localPlayer.TeamColor then continue end
            if script.settings.HealthCheck and humanoid.Health <= 0 then continue end

            local targetPart = character:FindFirstChild(script.settings.LockPart)
            if not targetPart then continue end

            if script.settings.Distance and (targetPart.Position - localHead.Position).Magnitude > script.settings.MaxDistance then
                continue end

            if script.settings.VisibleCheck then
                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                rayParams.FilterDescendantsInstances = {localCharacter}
                local result = Workspace:Raycast(localHead.Position, targetPart.Position - localHead.Position, rayParams)
                if result and not result.Instance:IsDescendantOf(character) then continue end
            end

            local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
            if not onScreen then continue end

            local screenVec = Vector2.new(screenPos.X, screenPos.Y)
            local distanceFromCenter = (screenVec - screenCenter).Magnitude

            if distanceFromCenter <= fovSettings.Radius and distanceFromCenter < closestDistance then
                closestDistance = distanceFromCenter
                closestTarget = targetPart
            end
        end

        if closestTarget then
            local targetCFrame = CFrame.new(camera.CFrame.Position, closestTarget.Position)
            local sensitivity = script.settings.Sensitivity
            if typeof(sensitivity) == "number" and sensitivity > 0 then
                local speed = (11 - math.clamp(sensitivity, 0, 10)) * 2
                local alpha = 1 - math.exp(-deltaTime * speed)
                camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
            else
                camera.CFrame = targetCFrame
            end
        end
    end

    if fovCircle then
        fovCircle.Color = (shouldAim and closestTarget) and fovSettings.LockedColor or fovSettings.Color
    end
end)

return script
