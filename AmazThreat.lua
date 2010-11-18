
-- Amaz Threat Meter
-- Config
AMZT = {}

-- Threat mode
-- 1 = Time based update only using MaxInterval
-- 2 = Time based dynamic
AMZT.Mode = 2
AMZT.MaxInterval = 1 -- Update interval in seconds
AMZT.MinInterval = 0.1 -- Used when personal threat exceed ModeTreshhold

-- Show when?
AMZT.Show = {Solo = true, Party = true, Raid = true}

-- Window Style
AMZT.Style = {
	-- Main Window
	["BackdropColor"] = {0.1, 0.1, 0.1, 0},
	["Width"] = 180,
	
	-- Title Bar
	["Title"] = { 
		["Font"] = TukuiCF["media"].uffont,
		["FontSize"] = 10,
		["FontColor"] = {1, 0.82, 0},
		["TextAlign"] = "LEFT",
		["Color"] = { 0, 0, 0, 1},
		["Height"] = 12,
	},
	
	-- Unit Bar
	["Unit"] = {
		["Font"] = TukuiCF["media"].uffont,
		["FontSize"] = 10,
		["FontColor"] = {0.9, 0.9, 0.9},
		["Texture"] = TukuiCF["media"].normTex,
		["Height"] = 12,
		["MaxBars"] = 9,
		["BarSpacing"] = -1,
		["UseClassColor"] = false, -- Use class color for the bar background. If false UniColor will be used and the name/threat value will be class colored
		["UniColor"] = {0.23, 0.23, 0.23},
	},
	
	-- Anchor
	["Anchor"] = {
		{"TOPLEFT", AmazDamageThreat, "TOPLEFT", 2, -2},
		--{"BOTTOMRIGHT",frame1,"BOTTOMRIGHT",x,y},
	}
}

-- Our Threat bars
AMZT.Bars = {}

-- Local threat table
local AMZThreatTable = {}

-- Base Frame
local AMZTFrame = CreateFrame("Frame", "AmazThreatFrame", UIParent)
AMZTFrame.Elapsed = 0
AMZTFrame.Interval = 1
AMZTFrame.ValidTarget = false
AMZTFrame.Running = false

function AMZTFrame:PLAYER_ENTERING_WORLD(event)
	-- Set anchors
	for idx, anch in pairs(AMZT.Style.Anchor) do
		AMZTFrame:SetPoint(anch[1], anch[2], anch[3], anch[4], anch[5])
	end
end

function AMZTFrame:PLAYER_REGEN_DISABLED(event)
	AMZTFrame:StartMeter()
end

function AMZTFrame:PLAYER_REGEN_ENABLED(event)
	AMZTFrame:StopMeter()
end

function AMZTFrame:StartMeter()
	-- Dont enable in battlegrounds
	if (not UnitInBattleground("player")) then
		-- Wipe the table
		wipe(AMZThreatTable)
		
		-- Set the interval
		if (AMZT.Mode == 2) then
			AMZTFrame.Interval = AMZT.MinInterval
		else
			AMZTFrame.Interval = AMZT.MaxInterval
		end
		
		-- Get player, party and raid members for local threat table
		if (GetNumRaidMembers() > 0) then -- Check for raid
			for i=1, GetNumRaidMembers() do
				table.insert(AMZThreatTable, { unitName = UnitName("raid".. i), threat = 0,});
			end
		else -- Not in raid
			-- Add player
			table.insert(AMZThreatTable, { unitName = UnitName("player"), threat = 0,});
			
			-- Check for party
			if (GetNumPartyMembers() > 0) then
				for i=1, GetNumPartyMembers() do
					table.insert(AMZThreatTable, { unitName = UnitName("party".. i), threat = 0,});
				end
			end
		end
		
		-- Check current target
		AMZT:CheckTarget()
		
		-- Flag as running
		AMZTFrame.Running = true
		
		-- Start time based check
		AMZTFrame:SetScript("OnUpdate", function(self, elapsed)
			AMZT:DoUpdate(AMZTFrame, elapsed);
		end);
	end
end

function AMZTFrame:StopMeter()
	AMZTFrame.Running = false
	
	-- Stop time based check
	AMZTFrame:SetScript("OnUpdate", nil)
	
	-- Hide all bars
	for i = 1, table.getn(AMZT.Bars) do
		AMZT.Bars[i]:Hide()
	end
end

function AMZTFrame:PLAYER_TARGET_CHANGED(event)
	if (AMZTFrame.Running) then
		-- Check if a new valid target
		AMZT:CheckTarget()
		
		if (UnitAffectingCombat("player")) then
			-- Reset threat values if in combat
			for i=1, table.getn(AMZThreatTable) do
				AMZThreatTable[i].threat = 0
			end
			
			-- Hide all threat bars
			for i=1, table.getn(AMZT.Bars) do
				AMZT.Bars[i]:Hide()
			end
			
			-- Do an update since new target
			AMZT:DoUpdate(AMZTFrame, 1)
		end
	end
end

function AMZTFrame:RAID_ROSTER_UPDATE(event)
	-- Remove ppl from local threat table if they leave raid
	for i=1, table.getn(AMZThreatTable) do
		if (not UnitInRaid(AMZThreatTable[i].unitName)) then
			table.remove(AMZThreatTable, i)
			return
		end
	end
end

function AMZTFrame:PARTY_MEMBERS_CHANGED(event)
	-- Remove ppl from local threat table if they leave party
	for i=1, table.getn(AMZThreatTable) do
		if (not UnitInParty(AMZThreatTable[i].unitName)) then
			table.remove(AMZThreatTable, i)
			return
		end
	end
end

function AMZT:CheckTarget()
	if (UnitName("target") ~= nil and not UnitPlayerControlled("target")) then
		AMZTFrame.ValidTarget = true
	else
		AMZTFrame.ValidTarget = false
	end
end

function AMZT:SetupFrames()
	AMZTFrame:SetBackdrop({bgFile = TukuiCF["media"].blank,
			edgeFile = "",
			tile = false, tileSize = 0, edgeSize = 0,
			insets = { left = 0, right = 0, top = 0, bottom = 0 }});
	AMZTFrame:SetBackdropColor(unpack(AMZT.Style.BackdropColor))
	AMZTFrame:SetWidth(AMZT.Style.Width)
	local height = AMZT.Style.Title.Height + (AMZT.Style.Unit.Height * AMZT.Style.Unit.MaxBars)
	AMZTFrame:SetHeight(height)
	
	-- Title bar
	local titleBar = CreateFrame("Frame", "AmazThreatTitleFrame", AMZTFrame)
	titleBar:SetBackdrop({bgFile = TukuiCF["media"].blank,
			edgeFile = "",
			tile = false, tileSize = 0, edgeSize = 0,
			insets = { left = 0, right = 0, top = 0, bottom = 0 }});
	titleBar:SetBackdropColor(unpack(AMZT.Style.Title.Color))
	titleBar:SetHeight(AMZT.Style.Title.Height)
	--titleBar:SetWidth(AMZT.Style.Width)
	titleBar:SetPoint("TOPLEFT", AMZTFrame, "TOPLEFT", 0, 0)
	titleBar:SetPoint("TOPRIGHT", AMZTFrame, "TOPRIGHT", 0, 0)
	
	-- Title Font
	titleBar.Caption = titleBar:CreateFontString(nil, "ARTWORK")
	titleBar.Caption:SetPoint(AMZT.Style.Title.TextAlign, titleBar, AMZT.Style.Title.TextAlign, 4, 0)
	titleBar.Caption:SetFont(AMZT.Style.Title.Font, AMZT.Style.Title.FontSize)
	titleBar.Caption:SetTextColor(unpack(AMZT.Style.Title.FontColor))
	titleBar.Caption:SetText("Threat")
	titleBar.Caption:Show()
	
	-- Create threat bars
	local tbAnchor = titleBar
	
	for i = 1, AMZT.Style.Unit.MaxBars do
		local unitBar = CreateFrame("StatusBar", "AmazThreatFrame".. i, AMZTFrame)
		--unitBar:SetWidth(AMZT.Style.Width)
		unitBar:SetHeight(AMZT.Style.Unit.Height)
		unitBar:SetStatusBarTexture(AMZT.Style.Unit.Texture)
		unitBar:SetPoint("TOPLEFT", tbAnchor, "BOTTOMLEFT", 0, AMZT.Style.Unit.BarSpacing)
		unitBar:SetPoint("TOPRIGHT", tbAnchor, "BOTTOMRIGHT", 0, AMZT.Style.Unit.BarSpacing)
		unitBar:SetMinMaxValues(0,100)
		
		if (not AMZT.Style.Unit.UseClassColor) then
			unitBar.UniColor = true
			unitBar:SetStatusBarColor(unpack(AMZT.Style.Unit.UniColor))
		else
			unitBar.UniColor = false
		end
		
		-- Unit Name text
		unitBar.UnitName = unitBar:CreateFontString(nil, "ARTWORK")
		unitBar.UnitName:SetPoint("LEFT", unitBar, "LEFT", 3, 0)
		unitBar.UnitName:SetFont(AMZT.Style.Unit.Font, AMZT.Style.Unit.FontSize)
		unitBar.UnitName:SetTextColor(unpack(AMZT.Style.Unit.FontColor))
		unitBar.UnitName:SetText("")
		unitBar.UnitName:Show()
		
		-- Threat value text
		unitBar.Threat = unitBar:CreateFontString(nil, "ARTWORK")
		unitBar.Threat:SetPoint("RIGHT", unitBar, "RIGHT", -3, 0)
		unitBar.Threat:SetFont(AMZT.Style.Unit.Font, AMZT.Style.Unit.FontSize)
		unitBar.Threat:SetTextColor(unpack(AMZT.Style.Unit.FontColor))
		unitBar.Threat:SetText("")
		unitBar.Threat:Show()
		
		unitBar:Hide()
		
		AMZT.Bars[i] = unitBar
		tbAnchor = unitBar
	end
end

function AMZT:DoUpdate(amztFrame, elapsed)
	amztFrame.Elapsed = amztFrame.Elapsed + elapsed
	
	--if (amztFrame.Elapsed >= AMZTFrame.Interval and UnitName("target") ~= nil and not UnitPlayerControlled("target")) then
	if (amztFrame.Elapsed >= AMZTFrame.Interval and AMZTFrame.ValidTarget) then
		for i = 1, table.getn(AMZThreatTable) do
			isTanking, status, scaledPercent, rawPercent, threatValue = UnitDetailedThreatSituation(AMZThreatTable[i].unitName, "target")
			
			if (scaledPercent == nil) then
				AMZThreatTable[i].threat = 0
			else
				AMZThreatTable[i].threat = scaledPercent
			end
		end
		
		-- Check player threat for interval
		isTanking, status, scaledPercent, rawPercent, threatValue = UnitDetailedThreatSituation("player", "target")
		if (scaledPercent ~= nil and AMZT.Mode == 2) then
			AMZTFrame.Interval = (AMZT.MinInterval+(AMZT.MaxInterval-(AMZT.MaxInterval*(scaledPercent/100))) * 0.9)
		end
		
		AMZT:RenderFrame()
		amztFrame.Elapsed = 0
	end
end

function AMZT:RenderFrame()
	-- Sort the threat table
	table.sort(AMZThreatTable, function(a,b) return a.threat>b.threat end)
	
	-- Get top threat units (according to AMZT.Style.Unit.MaxBars), ignore if threat is 0
	for i = 1, table.getn(AMZThreatTable) do
		if (i > AMZT.Style.Unit.MaxBars) then
			return
		end
		
		-- Set threat
		local threatBar = AMZT.Bars[i]
		if (AMZThreatTable[i].threat > 0) then
			threatBar:Show()
			threatBar:SetValue(AMZThreatTable[i].threat)
			threatBar.Threat:SetText(string.format("%.1f %%", AMZThreatTable[i].threat))
			
			-- Check if different unit. Update unitname & color if changed
			if (threatBar.UnitName:GetText() ~= AMZThreatTable[i].unitName) then
				threatBar.UnitName:SetText(AMZThreatTable[i].unitName)
							
				local _, cls = UnitClass(AMZThreatTable[i].unitName)
				local c = RAID_CLASS_COLORS[cls]
				
				if (threatBar.UniColor) then
					threatBar.UnitName:SetTextColor(c.r, c.g, c.b)
					threatBar.Threat:SetTextColor(c.r, c.g, c.b)
				else
					threatBar:SetStatusBarColor(c.r, c.g, c.b)
				end
			end
		else
			-- Hide bar if threat is 0
			threatBar:Hide()
		end
	end
end

function AMZT:Init()
    AMZTFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	AMZTFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	AMZTFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	AMZTFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	--AMZTFrame:RegisterEvent("RAID_ROSTER_UPDATE")
	--AMZTFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
	
	AMZTFrame:SetScript("OnEvent", function(self, event, ...)
		AMZTFrame[event](self, event, ...)
	end)
	
	AMZT:SetupFrames()
	
end

AMZT.Init()
