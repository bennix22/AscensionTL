-- AscensionTL.lua (Ascension Transmog Learner)
local addonName, addon = ...
local frame = CreateFrame("Frame")

-- Saved variables for button position and settings
AscensionTL_Settings = AscensionTL_Settings or {
    minimapPos = 225, -- Default angle position
    autoLearnEnabled = false, -- Auto learn mode disabled by default
    totalLearned = 0 -- Total transmogs learned counter
}

-- Track if minimap button is unlocked for moving
local isButtonUnlocked = false

-- Session counter - resets when addon is loaded
local sessionLearned = 0

-- Track recently processed items to prevent double counting
local recentlyProcessed = {}
local processingBag = false -- Flag to prevent processing during a bag update

-- Register events we care about
frame:RegisterEvent("ADDON_LOADED")

-- Function to learn all uncollected transmog appearances
local function LearnAllTransmogs()
    local learned = 0
    local itemsToLearn = {}
    
    -- First pass - collect all items to learn
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemID = GetContainerItemID(bag, slot)
            if itemID then
                local appearanceID = C_Appearance.GetItemAppearanceID(itemID)
                if appearanceID and not C_AppearanceCollection.IsAppearanceCollected(appearanceID) then
                    -- Check if we haven't already processed this item recently
                    local itemKey = bag .. ":" .. slot .. ":" .. itemID
                    if not recentlyProcessed[itemKey] then
                        table.insert(itemsToLearn, {bag = bag, slot = slot, itemID = itemID, key = itemKey})
                    end
                end
            end
        end
    end
    
    -- Learn items with a delay between each
    if #itemsToLearn > 0 then
        processingBag = true
        
        for i, item in ipairs(itemsToLearn) do
            C_Timer.After((i-1) * 0.5, function()
                local currentItemID = GetContainerItemID(item.bag, item.slot)
                if currentItemID == item.itemID then
                    local appearanceID = C_Appearance.GetItemAppearanceID(item.itemID)
                    if appearanceID and not C_AppearanceCollection.IsAppearanceCollected(appearanceID) then
                        C_AppearanceCollection.CollectItemAppearance(item.itemID)
                        
                        -- Mark as processed to avoid double counting
                        recentlyProcessed[item.key] = GetTime()
                        
                        -- Update counters
                        learned = learned + 1
                        sessionLearned = sessionLearned + 1
                        AscensionTL_Settings.totalLearned = (AscensionTL_Settings.totalLearned or 0) + 1
                    end
                end
                
                -- If this is the last item, show the summary and reset processing flag
                if i == #itemsToLearn then
                    processingBag = false
                    if learned > 0 then
                        print("|cFF00FF00AscensionTL:|r Successfully learned " .. learned .. " transmog appearances.")
                        print("|cFF00FF00AscensionTL:|r Session: " .. sessionLearned .. " - Total: " .. AscensionTL_Settings.totalLearned)
                    else
                        print("|cFF00FF00AscensionTL:|r No unlearned transmog appearances found in your bags.")
                    end
                end
            end)
        end
    else
        print("|cFF00FF00AscensionTL:|r No unlearned transmog appearances found in your bags.")
    end
    
    -- Clean up old entries from recently processed table
    C_Timer.After(10, CleanupRecentlyProcessed)
    
    return learned
end

-- Function to clean up the recently processed items table
function CleanupRecentlyProcessed()
    local now = GetTime()
    for key, timestamp in pairs(recentlyProcessed) do
        if now - timestamp > 10 then -- Remove entries older than 10 seconds
            recentlyProcessed[key] = nil
        end
    end
end

-- Function to check if a specific item can be learned
local function CheckAndLearnItem(bag, slot)
    -- If we're already processing a bag update, skip
    if processingBag then return false end
    
    local itemID = GetContainerItemID(bag, slot)
    if itemID then
        local itemKey = bag .. ":" .. slot .. ":" .. itemID
        
        -- Check if we've recently processed this item
        if recentlyProcessed[itemKey] then
            return false
        end
        
        local appearanceID = C_Appearance.GetItemAppearanceID(itemID)
        if appearanceID and not C_AppearanceCollection.IsAppearanceCollected(appearanceID) then
            -- Mark as processing to prevent duplicate events
            processingBag = true
            
            -- Add a short delay to avoid double triggers
            C_Timer.After(0.5, function()
                -- Double-check the item is still there and still uncollected
                local currentItemID = GetContainerItemID(bag, slot)
                if currentItemID == itemID then
                    local appearanceID = C_Appearance.GetItemAppearanceID(itemID)
                    if appearanceID and not C_AppearanceCollection.IsAppearanceCollected(appearanceID) then
                        C_AppearanceCollection.CollectItemAppearance(itemID)
                        
                        -- Mark as processed to avoid double counting
                        recentlyProcessed[itemKey] = GetTime()
                        
                        -- Update counters
                        sessionLearned = sessionLearned + 1
                        AscensionTL_Settings.totalLearned = (AscensionTL_Settings.totalLearned or 0) + 1
                        
                        print("|cFF00FF00AscensionTL:|r Auto-learned appearance from " .. GetContainerItemLink(bag, slot))
                        print("|cFF00FF00AscensionTL:|r Session: " .. sessionLearned .. " - Total: " .. AscensionTL_Settings.totalLearned)
                    end
                end
                
                -- Reset processing flag
                processingBag = false
            end)
            
            return true
        end
    end
    return false
end

-- Toggle auto-learn mode
local function ToggleAutoLearn()
    AscensionTL_Settings.autoLearnEnabled = not AscensionTL_Settings.autoLearnEnabled
    
    if AscensionTL_Settings.autoLearnEnabled then
        frame:RegisterEvent("BAG_UPDATE")
        print("|cFF00FF00AscensionTL:|r Auto-learn mode ENABLED")
    else
        frame:UnregisterEvent("BAG_UPDATE")
        print("|cFF00FF00AscensionTL:|r Auto-learn mode DISABLED")
    end
    
    -- Update button appearance
    if AscensionTLMinimapButton then
        if AscensionTL_Settings.autoLearnEnabled then
            AscensionTLMinimapButton.icon:SetVertexColor(0, 1, 0) -- Green tint when enabled
        else
            AscensionTLMinimapButton.icon:SetVertexColor(1, 1, 1) -- Normal color when disabled
        end
    end
end

-- Toggle minimap button lock state
local function ToggleButtonLock()
    isButtonUnlocked = not isButtonUnlocked
    
    if isButtonUnlocked then
        print("|cFF00FF00AscensionTL:|r Minimap button UNLOCKED - drag to reposition")
        -- Add a pulsing animation to indicate it's unlocked
        if not AscensionTLMinimapButton.pulse then
            AscensionTLMinimapButton.pulse = AscensionTLMinimapButton:CreateAnimationGroup()
            local scale = AscensionTLMinimapButton.pulse:CreateAnimation("Scale")
            scale:SetOrder(1)
            scale:SetDuration(0.5)
            scale:SetScale(1.2, 1.2)
            scale:SetSmoothing("IN_OUT")
            
            local scale2 = AscensionTLMinimapButton.pulse:CreateAnimation("Scale")
            scale2:SetOrder(2)
            scale2:SetDuration(0.5)
            scale2:SetScale(0.833, 0.833) -- 1/1.2 to return to normal size
            scale2:SetSmoothing("IN_OUT")
        end
        AscensionTLMinimapButton.pulse:SetLooping("REPEAT")
        AscensionTLMinimapButton.pulse:Play()
    else
        print("|cFF00FF00AscensionTL:|r Minimap button LOCKED")
        if AscensionTLMinimapButton.pulse then
            AscensionTLMinimapButton.pulse:Stop()
        end
    end
    
    -- Update tooltip
    GameTooltip:Hide()
    if AscensionTLMinimapButton:IsMouseOver() then
        AscensionTLMinimapButton:GetScript("OnEnter")(AscensionTLMinimapButton)
    end
end

-- Create right-click dropdown menu
local function InitializeDropDownMenu(frame, level, menuList)
    local info = UIDropDownMenu_CreateInfo()
    
    info.text = "Auto-Learn Mode"
    info.checked = AscensionTL_Settings.autoLearnEnabled
    info.func = ToggleAutoLearn
    UIDropDownMenu_AddButton(info, level)
    
    info = UIDropDownMenu_CreateInfo()
    info.text = "Learn All Now"
    info.func = function() LearnAllTransmogs() CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info, level)
    
    info = UIDropDownMenu_CreateInfo()
    info.text = isButtonUnlocked and "Lock Minimap Button" or "Unlock Minimap Button"
    info.func = function() ToggleButtonLock() CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info, level)
    
    info = UIDropDownMenu_CreateInfo()
    info.text = "Reset Session Counter"
    info.func = function() 
        sessionLearned = 0 
        print("|cFF00FF00AscensionTL:|r Session counter reset")
        CloseDropDownMenus() 
    end
    UIDropDownMenu_AddButton(info, level)
end

-- Create minimap button
local function CreateMinimapButton()
    local button = CreateFrame("Button", "AscensionTLMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")
    
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\Icons\\INV_Misc_EngGizmos_30")
    icon:SetPoint("CENTER", 0, 0)
    button.icon = icon -- Store reference to icon
    
    -- Initialize icon color based on auto-learn status
    if AscensionTL_Settings.autoLearnEnabled then
        icon:SetVertexColor(0, 1, 0) -- Green tint when enabled
    end
    
    -- Button functionality
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, buttonPressed)
        if buttonPressed == "LeftButton" then
            if isButtonUnlocked then
                -- If unlocked, left click will also lock it again after moving
                ToggleButtonLock()
            else
                LearnAllTransmogs()
            end
        else -- Right button
            local dropDown = CreateFrame("Frame", "AscensionTLDropDown", UIParent, "UIDropDownMenuTemplate")
            UIDropDownMenu_Initialize(dropDown, InitializeDropDownMenu, "MENU")
            ToggleDropDownMenu(1, nil, dropDown, "cursor", 3, -3)
        end
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Ascension Transmog Learner")
        
        if isButtonUnlocked then
            GameTooltip:AddLine("Button is UNLOCKED", 1, 0.5, 0)
            GameTooltip:AddLine("Drag to move button", 1, 1, 0)
            GameTooltip:AddLine("Left-click to lock position", 1, 1, 0)
        else
            GameTooltip:AddLine("Left-click: Learn all transmogs", 0, 1, 0)
            GameTooltip:AddLine("Right-click: Open menu", 0, 1, 0)
            GameTooltip:AddLine("Auto-learn mode: " .. (AscensionTL_Settings.autoLearnEnabled and "ENABLED" or "DISABLED"), 
                               AscensionTL_Settings.autoLearnEnabled and 0 or 1, 
                               AscensionTL_Settings.autoLearnEnabled and 1 or 0, 
                               0)
                               
            -- Add counter information
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Transmogs Learned:", 1, 1, 0)
            GameTooltip:AddLine("Session: " .. sessionLearned, 0.7, 0.7, 1)
            GameTooltip:AddLine("Total: " .. (AscensionTL_Settings.totalLearned or 0), 0.7, 0.7, 1)
        end
        
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Make it draggable when unlocked
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        if isButtonUnlocked then
            self:StartMoving()
            self.isMoving = true
        end
    end)
    
    button:SetScript("OnDragStop", function(self)
        if self.isMoving then
            self:StopMovingOrSizing()
            self.isMoving = false
            
            -- Convert position to angle and save it
            local xpos, ypos = self:GetCenter()
            local xmin, ymin = Minimap:GetCenter()
            local xdiff, ydiff = xpos - xmin, ypos - ymin
            
            local angle = math.deg(math.atan2(ydiff, xdiff))
            AscensionTL_Settings.minimapPos = angle
            
            -- Update position
            UpdateMinimapPosition(button)
        end
    end)
    
    -- Function to update position based on saved angle
    function UpdateMinimapPosition(button)
        local angle = math.rad(AscensionTL_Settings.minimapPos or 225)
        local x, y = math.cos(angle), math.sin(angle)
        local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
        
        -- Adjust for non-round minimaps
        if minimapShape == "SQUARE" then
            x = math.max(-0.7, math.min(x, 0.7))
            y = math.max(-0.7, math.min(y, 0.7))
        end
        
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x * 80, y * 80)
    end
    
    -- Initial position
    UpdateMinimapPosition(button)
    
    return button
end

-- Show counter status
local function ShowCounters()
    print("|cFF00FF00AscensionTL:|r Transmogs Learned")
    print("|cFF00FF00AscensionTL:|r Session: " .. sessionLearned)
    print("|cFF00FF00AscensionTL:|r Total: " .. (AscensionTL_Settings.totalLearned or 0))
end

-- Create a debounced version of the BAG_UPDATE handler
local bagUpdateTimer
local lastBagUpdated

local function ProcessBagUpdate(bag)
    -- If there's a pending update for this bag, cancel it
    if bagUpdateTimer and lastBagUpdated == bag then
        bagUpdateTimer:Cancel()
    end
    
    -- Store the bag being updated
    lastBagUpdated = bag
    
    -- Create a delayed timer for processing
    bagUpdateTimer = C_Timer.NewTimer(1.0, function()
        -- Only process if auto-learn is enabled and we're not already processing
        if AscensionTL_Settings.autoLearnEnabled and not processingBag then
            for slot = 1, GetContainerNumSlots(bag) do
                CheckAndLearnItem(bag, slot)
            end
        end
        bagUpdateTimer = nil
    end)
end

-- Main event handler
frame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize total counter if it doesn't exist
        AscensionTL_Settings.totalLearned = AscensionTL_Settings.totalLearned or 0
        
        local minimapButton = CreateMinimapButton()
        
        -- Enable auto-learn if it was enabled previously
        if AscensionTL_Settings.autoLearnEnabled then
            frame:RegisterEvent("BAG_UPDATE")
        end
        
        -- Create slash commands
        SLASH_ASCENSIONTL1 = "/atl"
        SLASH_ASCENSIONTL2 = "/ascensiontl"
        SlashCmdList["ASCENSIONTL"] = function(msg)
            if msg == "learn" then
                LearnAllTransmogs()
            elseif msg == "auto" then
                ToggleAutoLearn()
            elseif msg == "unlock" or msg == "move" then
                ToggleButtonLock()
            elseif msg == "show" then
                minimapButton:Show()
            elseif msg == "hide" then
                minimapButton:Hide()
            elseif msg == "count" or msg == "stats" then
                ShowCounters()
            elseif msg == "reset" then
                sessionLearned = 0
                print("|cFF00FF00AscensionTL:|r Session counter reset")
            else
                print("|cFF00FF00AscensionTL Commands:|r")
                print("/atl learn - Learn all transmogs in your bags")
                print("/atl auto - Toggle auto-learn mode")
                print("/atl unlock - Toggle minimap button movement")
                print("/atl count - Show transmog counters")
                print("/atl reset - Reset session counter")
                print("/atl show - Show minimap button")
                print("/atl hide - Hide minimap button")
            end
        end
        
        print("|cFF00FF00AscensionTL loaded.|r Type /atl for commands.")
        
        -- Start cleanup timer for recently processed items
        C_Timer.NewTicker(30, CleanupRecentlyProcessed)
    elseif event == "BAG_UPDATE" and AscensionTL_Settings.autoLearnEnabled then
        -- Use the debounced handler
        ProcessBagUpdate(arg1)
    end
end)