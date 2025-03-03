local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create main window
local Window = Rayfield:CreateWindow({
   Name = "🌟 Modern Hub V2",
   LoadingTitle = "Modern Hub Loading...",
   LoadingSubtitle = "by Modern Team",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "ModernHubConfig",
      FileName = "ModernHub"
   }
})

-- Create main tabs
local PlayerTab = Window:CreateTab("👤 Player", 6034287594)
local MovementTab = Window:CreateTab("⚡ Movement", 6034996695)
local CombatTab = Window:CreateTab("⚔️ Combat", 7733674079)

-- Function to find the football
local function getFootball()
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("MeshPart") and v.Name == "Football" then
            return v
        end
    end
    return nil
end

-- Function to check if football is being held by another player
local function isFootballHeld(football)
    if not football then return false end
    
    -- Check if football is parented to a character
    local parent = football.Parent
    while parent do
        if parent:FindFirstChildOfClass("Humanoid") then
            -- It's parented to a character
            local character = parent
            local plr = game.Players:GetPlayerFromCharacter(character)
            -- If it's held by another player (not us)
            return plr and plr ~= game.Players.LocalPlayer
        end
        parent = parent.Parent
    end
    
    return false
end

-- Function to simulate pressing E key
local function pressE()
    local vim = game:GetService("VirtualInputManager")
    vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.05)
    vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

-- Function to simulate left mouse click (shooting)
local function shootBall()
    local vim = game:GetService("VirtualInputManager")
    vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait(0.05)
    vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- Function to find the opponent's goal
local function findOpponentGoal()
    local goalsFolder = workspace:FindFirstChild("Goals")
    if not goalsFolder then return nil end
    
    -- Get goal choice from settings
    local targetGoalName = goalTargetChoice
    
    -- If automatic, determine which team the player is on
    if targetGoalName == "Auto" then
        local player = game.Players.LocalPlayer
        local character = player.Character
        if not character then return nil end
        
        -- Try to detect team based on common team indicators
        local isHome = true -- Default to Home team (will target Away goal)
        
        -- Check body colors (common in many games)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local bodyColors = humanoid:FindFirstChildOfClass("BodyColors")
            if bodyColors then
                local torsoColor = bodyColors.TorsoColor3
                -- Check if color is closer to blue (away) than white (home)
                -- Blue team should target Home goal, White team should target Away goal
                local whiteDistance = (torsoColor - Color3.new(1, 1, 1)).Magnitude
                local blueDistance = (torsoColor - Color3.new(0, 0, 1)).Magnitude
                
                -- If closer to blue color, we're on away team
                if blueDistance < whiteDistance then
                    isHome = false -- We're on Away team
                end
            end
        end
        
        -- Inverted from before - if we're Home team (white), target Away goal and vice versa
        targetGoalName = isHome and "Away" or "Home"
    end
    
    -- Debug notification about which goal we're targeting
    Rayfield:Notify({
       Title = "Target Goal",
       Content = "Targeting " .. targetGoalName .. " goal",
       Duration = 1
    })
    
    -- First try to find directly in Goals folder
    local opponentGoal = goalsFolder:FindFirstChild(targetGoalName)
    
    -- If not found, check inside Goals or Goals2 models
    if not opponentGoal then
        local goals1 = goalsFolder:FindFirstChild("Goals")
        local goals2 = goalsFolder:FindFirstChild("Goals2")
        
        if goals1 and goals1:IsA("Model") then
            opponentGoal = goals1:FindFirstChild(targetGoalName)
        end
        
        if not opponentGoal and goals2 and goals2:IsA("Model") then
            opponentGoal = goals2:FindFirstChild(targetGoalName)
        end
    end
    
    return opponentGoal
end

-- Function to check if the local player has the football
local function playerHasBall()
    local football = getFootball()
    if not football then return false end
    
    local player = game.Players.LocalPlayer
    if not player.Character then return false end
    
    -- Check if ball is parented to the player's character or held by them
    local parent = football.Parent
    while parent do
        if parent == player.Character then
            return true
        end
        parent = parent.Parent
    end
    
    -- Alternative detection - check if ball is very close to player
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if rootPart and (football.Position - rootPart.Position).Magnitude < 5 then
        return true
    end
    
    return false
end

-- Variables for teleport, auto-steal and auto-score
local teleportDistance = 3
local autoStealEnabled = true
local autoScoreEnabled = true
local goalTargetChoice = "Away" -- Default to Away goal (blue goal)

-- Teleport Distance Slider
CombatTab:CreateSlider({
    Name = "⚽ Teleport Distance",
    Range = {1, 10},
    Increment = 0.5,
    Suffix = "studs",
    CurrentValue = 3,
    Flag = "TeleportDistance",
    Callback = function(Value)
        teleportDistance = Value
    end,
})

-- Auto-Steal Toggle
CombatTab:CreateToggle({
    Name = "🔄 Auto-Steal Ball",
    CurrentValue = true,
    Flag = "AutoStealBall",
    Callback = function(Value)
        autoStealEnabled = Value
    end,
})

-- Goal Target Dropdown
CombatTab:CreateDropdown({
    Name = "🥅 Target Goal",
    Options = {"Auto", "Home", "Away"},
    CurrentOption = "Away",
    Flag = "TargetGoal",
    Callback = function(Value)
        goalTargetChoice = Value
    end,
})

-- Updated Auto-Score Toggle with debug info
CombatTab:CreateToggle({
    Name = "⚽ Auto Score Goals",
    CurrentValue = true,
    Flag = "AutoScoreGoals",
    Callback = function(Value)
        autoScoreEnabled = Value
        
        -- Show which goal we're targeting
        if Value then
            local targetDesc = goalTargetChoice
            if targetDesc == "Auto" then
                targetDesc = "Auto (White→Away, Blue→Home)"
            end
            
            Rayfield:Notify({
               Title = "Auto Scoring Enabled",
               Content = "Target: " .. targetDesc .. " goal",
               Duration = 3
            })
        end
    end,
})

-- Football Teleport Toggle
local TeleportConnection = nil
CombatTab:CreateToggle({
    Name = "⚽ Auto Teleport to Football",
    CurrentValue = false,
    Flag = "TeleportFootball",
    Callback = function(Value)
        if Value then
            -- Start teleporting loop
            TeleportConnection = game:GetService("RunService").Heartbeat:Connect(function()
                local football = getFootball()
                local player = game.Players.LocalPlayer
                
                if football and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    -- Check if player has the ball
                    if playerHasBall() and autoScoreEnabled then
                        -- We have the ball, let's score!
                        local opponentGoal = findOpponentGoal()
                        
                        if opponentGoal then
                            -- Get the center position of the goal
                            local goalPosition
                            if opponentGoal:IsA("BasePart") then
                                goalPosition = opponentGoal.Position
                            else
                                -- If it's a model, find its primary part or calculate the center
                                if opponentGoal.PrimaryPart then
                                    goalPosition = opponentGoal.PrimaryPart.Position
                                else
                                    -- Calculate average position of all parts
                                    local parts = {}
                                    for _, part in pairs(opponentGoal:GetDescendants()) do
                                        if part:IsA("BasePart") then
                                            table.insert(parts, part.Position)
                                        end
                                    end
                                    
                                    if #parts > 0 then
                                        local sum = Vector3.new(0, 0, 0)
                                        for _, pos in ipairs(parts) do
                                            sum = sum + pos
                                        end
                                        goalPosition = sum / #parts
                                    end
                                end
                            end
                            
                            if goalPosition then
                                local rootPart = player.Character.HumanoidRootPart
                                
                                -- Calculate direction to goal
                                local direction = (goalPosition - rootPart.Position).Unit
                                
                                -- Teleport directly in front of goal (3-5 studs away)
                                local teleportDistance = 3 + math.random(0, 2) -- Random distance 3-5 studs
                                local teleportPosition = goalPosition - (direction * teleportDistance)
                                
                                -- Ensure proper height to avoid clipping into ground
                                teleportPosition = Vector3.new(
                                    teleportPosition.X,
                                    goalPosition.Y, -- Use goal's Y position
                                    teleportPosition.Z
                                )
                                
                                -- Teleport directly to position
                                rootPart.CFrame = CFrame.new(teleportPosition, goalPosition)
                                
                                -- Wait a tiny bit and shoot
                                task.wait(0.05)
                                shootBall()
                            end
                        end
                    else
                        -- Check if ball is held by another player
                        local ballHeld = isFootballHeld(football)
                        
                        -- Teleport to the ball
                        if ballHeld then
                            -- If ball is held, teleport closer to steal it
                            player.Character.HumanoidRootPart.CFrame = football.CFrame + Vector3.new(0, 0, 0)
                            
                            -- Auto press E to try to steal the ball
                            if autoStealEnabled then
                                pressE()
                            end
                        else
                            -- Normal teleport when ball is free
                            player.Character.HumanoidRootPart.CFrame = football.CFrame + Vector3.new(0, teleportDistance, 0)
                        end
                    end
                end
            end)
        else
            -- Stop teleporting
            if TeleportConnection then
                TeleportConnection:Disconnect()
                TeleportConnection = nil
            end
        end
    end,
})

-- Football ESP/Beam Toggle
local BeamConnection = nil
local beam = nil
local attachment0 = nil
local attachment1 = nil

CombatTab:CreateToggle({
    Name = "⚽ Football ESP Beam",
    CurrentValue = false,
    Flag = "FootballBeam",
    Callback = function(Value)
        local player = game.Players.LocalPlayer
        
        if Value then
            -- Create beam parts if they don't exist
            if not attachment0 then
                attachment0 = Instance.new("Attachment")
                attachment0.Parent = player.Character.HumanoidRootPart
                attachment0.Position = Vector3.new(0, 0, 0)
            end
            
            if not attachment1 then
                attachment1 = Instance.new("Attachment")
                attachment1.Parent = workspace.Terrain
            end
            
            if not beam then
                beam = Instance.new("Beam")
                beam.Attachment0 = attachment0
                beam.Attachment1 = attachment1
                beam.Width0 = 0.2
                beam.Width1 = 0.2
                beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
                beam.Enabled = true
                beam.Parent = player.Character.HumanoidRootPart
            end
            
            -- Update beam position
            BeamConnection = game:GetService("RunService").Heartbeat:Connect(function()
                local football = getFootball()
                local character = player.Character
                
                if football and character and character:FindFirstChild("HumanoidRootPart") then
                    attachment1.WorldPosition = football.Position
                end
            end)
        else
            -- Clean up beam when toggled off
            if BeamConnection then
                BeamConnection:Disconnect()
                BeamConnection = nil
            end
            
            if beam then
                beam:Destroy()
                beam = nil
            end
            
            if attachment0 then
                attachment0:Destroy()
                attachment0 = nil
            end
            
            if attachment1 then
                attachment1:Destroy()
                attachment1 = nil
            end
        end
    end,
})

-- Enhanced Speed hack variables
local speedEnabled = false
local speedValue = 50
local defaultSpeed = 16
local speedConnection = nil
local universalSpeedEnabled = false
local universalSpeedConnection = nil

-- Speed hack slider
MovementTab:CreateSlider({
    Name = "🏃 Speed Value",
    Range = {16, 200},
    Increment = 2,
    Suffix = "studs/s",
    CurrentValue = 50,
    Flag = "SpeedValue",
    Callback = function(Value)
        speedValue = Value
        
        -- Update speed immediately if enabled
        if speedEnabled or universalSpeedEnabled then
            local player = game.Players.LocalPlayer
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid.WalkSpeed = speedValue
            end
        end
    end,
})

-- Normal Speed hack toggle
MovementTab:CreateToggle({
    Name = "🏃 Basic Speed Hack",
    CurrentValue = false,
    Flag = "SpeedHack",
    Callback = function(Value)
        speedEnabled = Value
        local player = game.Players.LocalPlayer
        
        if Value then
            -- Save default speed if needed
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                defaultSpeed = player.Character.Humanoid.WalkSpeed
                player.Character.Humanoid.WalkSpeed = speedValue
            end
            
            -- Keep speed consistent when character respawns
            speedConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if player.Character and player.Character:FindFirstChild("Humanoid") then
                    if player.Character.Humanoid.WalkSpeed ~= speedValue then
                        player.Character.Humanoid.WalkSpeed = speedValue
                    end
                end
            end)
        else
            -- Revert to default speed
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid.WalkSpeed = defaultSpeed
            end
            
            -- Disconnect the speed loop
            if speedConnection then
                speedConnection:Disconnect()
                speedConnection = nil
            end
        end
    end,
})

-- Universal Speed hack toggle (works on most games)
MovementTab:CreateToggle({
    Name = "🔥 Universal Speed Hack",
    CurrentValue = false,
    Flag = "UniversalSpeedHack",
    Callback = function(Value)
        universalSpeedEnabled = Value
        local player = game.Players.LocalPlayer
        
        if Value then
            -- Create a new connection that applies multiple speed methods
            universalSpeedConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if player.Character then
                    local humanoid = player.Character:FindFirstChild("Humanoid")
                    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                    
                    -- Method 1: Traditional walk speed
                    if humanoid then
                        humanoid.WalkSpeed = speedValue
                    end
                    
                    -- Method 2: Check for player moving and boost with velocity
                    if rootPart and humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Seated then
                        local moveDirection = humanoid.MoveDirection
                        
                        -- Only apply if player is actually trying to move
                        if moveDirection.Magnitude > 0 then
                            local currentVelocity = rootPart.Velocity
                            
                            -- Maintain Y velocity (jumping/falling) but boost X and Z
                            local multiplier = speedValue / 16 -- Based on default speed
                            local targetVelocity = Vector3.new(
                                moveDirection.X * speedValue,
                                currentVelocity.Y,
                                moveDirection.Z * speedValue
                            )
                            
                            -- Blend current and target velocity for smoother movement
                            rootPart.Velocity = Vector3.new(
                                targetVelocity.X,
                                currentVelocity.Y,
                                targetVelocity.Z
                            )
                        end
                    end
                    
                    -- Method 3: Find and modify any existing BodyMovers
                    for _, child in pairs(rootPart:GetChildren()) do
                        if child:IsA("BodyVelocity") or child:IsA("BodyForce") then
                            -- Game is using custom movement - modify it
                            if child:IsA("BodyVelocity") then
                                local vel = child.Velocity
                                local magnitude = vel.Magnitude
                                if magnitude > 0 then
                                    local multiplier = speedValue / 16
                                    child.Velocity = vel.Unit * magnitude * multiplier
                                end
                            end
                        end
                    end
                end
            end)
        else
            -- Disable universal speed hack
            if universalSpeedConnection then
                universalSpeedConnection:Disconnect()
                universalSpeedConnection = nil
            end
            
            -- Reset to default speed if the other speed hack isn't active
            if not speedEnabled and player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid.WalkSpeed = defaultSpeed
            end
        end
    end,
})

-- Add a tooltip for clarity
MovementTab:CreateParagraph({
    Title = "Speed Hack Tips",
    Content = "• Basic Speed Hack works in most standard games\n• Universal Speed Hack works in games with custom movement systems\n• Try both options if one doesn't work well in your current game"
})

-- Notification when loaded
Rayfield:Notify({
   Title = "Modern Hub V2 Loaded",
   Content = "UI Framework Ready!",
   Duration = 3,
   Image = 11695805807
})