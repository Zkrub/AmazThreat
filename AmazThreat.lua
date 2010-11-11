
-- Amaz Threat Meter
-- Config
AMZT = {}

-- Threat mode
-- 1 = Time based update only
-- 2 = Time based + damage based update
AMZT.Mode = 2
AMZT.Interval = 0.1 -- Update interval in seconds
AMZT.ModeTreshhold = 0.8 -- Only used for mode 2. If threat above defined value updates are based on damage instead
AMZT.DamageTreshhold = 25000 -- Only used for mode 2. Required amount of damage needed before update

-- Show when?
AMZT.Show = {Solo = true, Party = true, Raid = true}

-- Window Style
AMZT.Style = {
	-- Main Window
	["BackdropColor"] = {0.1, 0.1, 0.1, 0},
	["Width"] = 180,
	
	-- Title Bar
	["Title"] = { 
		["Font"] = [[Interface\AddOns\Tukui\media\fonts\visitor1.ttf]],
		["FontSize"] = 10,
		["FontColor"] = {1, 0.82, 0},
		["Color"] = { 0, 0, 0, 1},
		["Height"] = 12,
	},
	
	-- Unit Bar
	["Unit"] = {
		["Font"] = [[Interface\AddOns\Tukui\media\fonts\visitor1.ttf]],
		["FontSize"] = 10,
		["FontColor"] = {0.9, 0.9, 0.9},
		["Height"] = 12,
		["MaxBars"] = 9,
		["BarSpacing"] = -1,
		["UseClassColor"] = false, -- Use class color for the bar background. If false UniColor will be used and the name/threat value will be class colored
		["UniColor"] = {0.23, 0.23, 0.23},
	},
}

-- Our Threat bars
AMZT.Bars = {}

-- Local threat table
local AMZThreatTable = {}

-- Base Frame
local AMZTFrame = CreateFrame("Frame", "AmazThreatFrame", UIParent)
AMZTFrame.Elapsed = 0

function AMZTFrame:PLAYER_ENTERING_WORLD(event)
end

function AMZTFrame:PLAYER_REGEN_DISABLED(event)
	-- Get player, party and raid members for local threat table
	table.insert(AMZThreatTable, {
		unitName = UnitName("player"),
		threat = -1,
	});
	
	-- Start time based check
	AMZTFrame:SetScript("OnUpdate", function(self, elapsed)
		AMZT:DoUpdate(AMZTFrame, elapsed);
	end);
end

function AMZTFrame:PLAYER_REGEN_ENABLED(event)
	-- Stop time based check
	AMZTFrame:SetScript("OnUpdate", nil)
	
	-- Clear threat table
	wipe(AMZThreatTable)
	
	-- Hide all bars
	for i = 1, table.getn(AMZT.Bars) do
		AMZT.Bars[i]:Hide()
	end
end

function AMZTFrame:PLAYER_TARGET_CHANGED(event)
	-- Clear threat table if in combat
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
	titleBar:SetWidth(AMZT.Style.Width)
	titleBar:SetPoint("TOPLEFT", AMZTFrame, "TOPLEFT", 0, 0)
	
	-- Title Font
	titleBar.Caption = titleBar:CreateFontString(nil, "ARTWORK")
	titleBar.Caption:SetPoint("LEFT", titleBar, "LEFT", 4, 0)
	titleBar.Caption:SetFont(AMZT.Style.Title.Font, AMZT.Style.Title.FontSize)
	titleBar.Caption:SetTextColor(unpack(AMZT.Style.Title.FontColor))
	titleBar.Caption:SetText("Threat")
	titleBar.Caption:Show()
	
	-- Create threat bars
	local tbAnchor = titleBar
	local uniColor = AMZT.Style.Unit.UseClassColor
	for i = 1, AMZT.Style.Unit.MaxBars do
		local unitBar = CreateFrame("StatusBar", "AmazThreatFrame".. i, AMZTFrame)
		unitBar:SetWidth(AMZT.Style.Width)
		unitBar:SetHeight(AMZT.Style.Unit.Height)
		unitBar:SetStatusBarTexture(TukuiCF["media"].normTex)
		unitBar:SetPoint("TOP", tbAnchor, "BOTTOM", 0, AMZT.Style.Unit.BarSpacing)
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
		
		--unitBar:SetValue(110-(i*10))
		unitBar:Hide()
		
		AMZT.Bars[i] = unitBar
		tbAnchor = unitBar
	end
end

function AMZT:DoUpdate(amztFrame, elapsed)
	amztFrame.Elapsed = amztFrame.Elapsed + elapsed
	
	if (amztFrame.Elapsed >= AMZT.Interval and UnitName("target") ~= nil) then
		for i = 1, table.getn(AMZThreatTable) do
			isTanking, status, scaledPercent, rawPercent, threatValue = UnitDetailedThreatSituation(AMZThreatTable[i].unitName, "target")
			
			if (scaledPercent == nil) then
				AMZThreatTable[i].threat = -1
			else
				AMZThreatTable[i].threat = scaledPercent
			end
		end
		AMZT:RenderFrame()
		amztFrame.Elapsed = 0
	end
end

function AMZT:RenderFrame()
	-- Sort the threat table
	table.sort(AMZThreatTable, function(a,b) return a.threat>b.threat end)
	
	-- Get top threat units (according to AMZT.Style.Unit.MaxBars), ignore if threat is -1
	for i = 1, table.getn(AMZThreatTable) do
		if (i > AMZT.Style.Unit.MaxBars) then
			return
		end
		
		-- Set threat
		local threatBar = AMZT.Bars[i]
		if (AMZThreatTable[i].threat > 0) then
			threatBar:Show()
			threatBar:SetValue(AMZThreatTable[i].threat)
			
			-- Check if different unit. Update unitname & color if changed
			if (threatBar.UnitName:GetText() ~= AMZThreatTable[i].unitName) then
				threatBar.Threat:SetText(AMZThreatTable[i].threat .."%")
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
			threatBar:Hide()
		end
	end
end

function AMZT:Init()
    AMZTFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	AMZTFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	AMZTFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	AMZTFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	
	AMZTFrame:SetScript("OnEvent", function(self, event, ...)
		AMZTFrame[event](self, event, ...)
	end)
	
	AMZT:SetupFrames()
	
	AMZTFrame:SetPoint("TOPLEFT", AmazDamageThreat, "TOPLEFT", 2, -2)
end

AMZT.Init()
