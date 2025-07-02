local script = {}

script.settings = {
    Enabled = true,
    TeamCheck = false,
    HealthCheck = true,
    VisibleCheck = true,
    Sensitivity = 5,
    LockPart = "Head",
    Distance = false,
    MaxDistance = 200,
    Hotkey1 = Enum.UserInputType.MouseButton2,
    Hotkey2 = Enum.KeyCode.E,
    Toggle = false,
    fov = {
        Enabled = true,
        Visible = true,
        Radius = 100,
        NumSides = 64,
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
    if typeof(script.settings) ~= "table" then return end
    if typeof(script.settings.fov) ~= "table" then return end
    if typeof(script.settings.Enabled) ~= "boolean" then return end
    if typeof(script.settings.LockPart) ~= "string" then return end

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

    if shouldAim then
        local localCharacter = localPlayer.Character
        local localHead = localCharacter and localCharacter:FindFirstChild("Head")
        if not (localCharacter and localHead) then return end

        local minDistance = math.huge
        local mouseLocation = UserInputService:GetMouseLocation()

        for _, player in ipairs(Players:GetPlayers()) do
            if player == localPlayer then continue end

            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if not (character and humanoid) then continue end

            if script.settings.TeamCheck and player.TeamColor == localPlayer.TeamColor then
                continue
            end

            if script.settings.HealthCheck and humanoid.Health <= 0 then
                continue
            end

            local targetPart = character:FindFirstChild(script.settings.LockPart)
            if not targetPart then continue end

            if script.settings.Distance and (targetPart.Position - localHead.Position).Magnitude > script.settings.MaxDistance then
                continue
            end

            if script.settings.VisibleCheck then
                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                rayParams.FilterDescendantsInstances = {localCharacter}
                local result = Workspace:Raycast(localHead.Position, targetPart.Position - localHead.Position, rayParams)
                if result and not result.Instance:IsDescendantOf(character) then
                    continue
                end
            end

            local screenPos, onScreen = camera:WorldToScreenPoint(targetPart.Position)
            if onScreen then
                local screenVector = Vector2.new(screenPos.X, screenPos.Y)
                if fovSettings.Enabled and (screenVector - screenCenter).Magnitude > fovSettings.Radius then
                    continue
                end

                local distance = (screenVector - mouseLocation).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    closestTarget = targetPart
                end
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
