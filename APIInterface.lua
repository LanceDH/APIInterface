
local _addonName, _addon = ...;

local APII = LibStub("AceAddon-3.0"):NewAddon(_addonName);

local LISTITEM_HEIGHT = 34;
local LISTITEM_EXPAND_MARGIN = 43;
local SEARCH_CUTOFF_AMOUNT = 1000;
local FORMAT_SEARCH_CUTOFF_CHANGED = "Search cutoff changed to %d for this session.";
local FORMAT_SEARCH_CUTOFF = "Searched stopped after %d results."
local FORMAT_NO_RESULTS = "No global variables found containing \"%s\"."
local FORMAT_RESULTS_TITLE = "%d %ss containing \"%s\"";
local FORMAT_IN_SYSTEMS = "In system: %s";
local FORMAT_UNDOCUMENTED = "(|cffff3333%d undocumented|r)";
local FORMAT_UNDOCUMENTED_TITLE = "function |cffff3333%s|r (Undocumented)";
local TOOLTIP_GLOBAL_FORMAT = "Search for global variables for %ss containing the given search string.";
local TOOLTIP_GLOBAL_FRAME = "Searching for functions can cause errors trying to access forbidden variables.";
local TOOLTIP_GLOBAL_STRING1 = "Hold shift to search in both variable name and value.";
local TOOLTIP_GLOBAL_STRING2 = "Hold control to search only in variable value.";
local TOOLTIP_UNDOCUMENTED = "Include undocumented system functions in systems and search.";
local TOOLTIP_UNDOCUMENTED_WARNING = "Enabling this will cause increase memory usage.";
local ERROR_COMBAT = "Can't open %s during combat. The frame will open once you leave combat.";
local COLOR_FILTER1 = "|cff......";
local COLOR_FILTER2 = "|r";
local DETAILS_NO_PUBLIC = "This function does nothing in public clients";
local DETAILS_NO_PUBLIC_REPLACE = "|cffff0000This function does nothing in public clients|r";
local ARGUMENT_LABEL_FORMAT = "arg (%d+):";
local ARGUMENT_LABEL_FORMAT_NEW = "%d. %s:";

local _includeUndocumented = true;
local _EventArgLookup = {};

----------
-- Code
----------

local function APII_Resize_OnMouseUp(self, button)
	if (button == "LeftButton") then
		APII_Core:StopMovingOrSizing();
		HybridScrollFrame_CreateButtons(APIIListsSystemList, "APII_ListSystemTemplate", 1, 0);
		APIIListsSystemListScrollBar.doNotHide = true;
		APII:UpdateSystemList();
		APII:AdjustSelection();
	end
end

local function APII_Resize_OnMouseDown(self, button)
	if (button == "RightButton") then
		APII:ResetFrame()
	elseif (button == "LeftButton") then
		APII_Core:StartSizing();
	end
end

function APII_List_OnClick(self, button)
	APIILists.searchBox:ClearFocus();

	if (self.Type ~= "system" ) then
		if ( self.selected ) then
			self.selected = nil;
			APIIListsSystemList.Opened = "";
			self:SetHeight(LISTITEM_HEIGHT);
			HybridScrollFrame_CollapseButton(APIIListsSystemList);
			APII:UpdateSystemList();
		else
			APIIListsSystemList.Opened = self.Api:GetFullName();
			self.Details:SetText(table.concat(self.Api:GetDetailedOutputLines(), "\n", 2));
			self:SetHeight(LISTITEM_HEIGHT + LISTITEM_EXPAND_MARGIN + self.Details:GetHeight());
			APII:UpdateSystemList();
			APII:AdjustSelection();
			
		end
	else
		APIIListsSystemList.InSystem = self.Api;
		APIIListsSystemList.SystemScroll = APIIListsSystemListScrollBar:GetValue();
		APII:UpdateSystemList();
		APIILists.searchBox:SetText("");
		APIIListsSystemListScrollBar:SetValue(0);
	end
	
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
end

local function MatchContainsFunction(list, entry)
	for k, v in pairs(list) do
		if (v.Name == entry) then return true end;
	end
	return false;
end

function APII:GetUndocumentedFunctions(system)
	if not APII then APII = {}; end
	local namespace = system.Namespace;
	local documented = system:ListAllAPI();
	local list = documented and documented.functions;	
	if (not namespace or not list) then return nil; end
	
	if (APII[namespace]) then return APII[namespace]; end

	APII[namespace] = {};
	local global = _G[namespace];
	
	if(global) then
		for name, v in pairs(global) do
			if (not MatchContainsFunction(list, name)) then
				tinsert(APII[namespace], {["Name"] = namespace.."."..name, ["Type"] = "Function", ["Undocumented"] = true});
			end
		end
	end
	
	return APII[namespace];
end

function APII:UpdateSearchResults()
	--for i=#APIIListsSystemList.SearchResults, 1, -1 do
	--	table.remove(APIIListsSystemList.SearchResults, i)
	--end
	if (not APIIListsSystemList.Undocumented) then
		APIIListsSystemList.Undocumented = {}
	end
	
	local results = APIIListsSystemList.SearchResults;
	local matches;
	local undocumented = APIIListsSystemList.Undocumented ;
	
	wipe(results);
	wipe(undocumented);
	APIIListsSystemList.numUndocumented = 0;
	
	if APIIListsSystemList.InSystem then
		local namespace = APIIListsSystemList.InSystem.Namespace;
			undocumented = self:GetUndocumentedFunctions(APIIListsSystemList.InSystem);
		if APIIListsSystemList.SearchString == "" then
			matches = APIIListsSystemList.InSystem:ListAllAPI();
		else
			matches = APIIListsSystemList.InSystem:FindAllAPIMatches(APIIListsSystemList.SearchString);
		end
	else
		if (APIIListsSystemList.SearchString == "") then return; end
		matches = APIDocumentation:FindAllAPIMatches(APIIListsSystemList.SearchString);
		
		if (_includeUndocumented) then
			for k, system in ipairs(APIDocumentation.systems) do
				local result = APII:GetUndocumentedFunctions(system);
				if (result) then
					for k, info in pairs(result) do
						if (APIIListsSystemList.SearchString == "" or info.Name:lower():find(APIIListsSystemList.SearchString)) then
							tinsert(undocumented, info);
						end
					end
				end
			end
		end

		if (matches) then
			for k, info in ipairs(matches.systems) do
				table.insert(results, info);
			end
		end
	end

	if (matches) then
		for k, info in ipairs(matches.functions) do
			table.insert(results, info);
		end

		for k, info in ipairs(matches.events) do
			table.insert(results, info);
		end
		
		for k, info in ipairs(matches.tables) do
			table.insert(results, info);
		end
	end

	if (undocumented) then
		APIIListsSystemList.numUndocumented = #undocumented;
		if (_includeUndocumented) then
			for k, info in ipairs(undocumented) do
				if (APIIListsSystemList.SearchString == "" or info.Name:lower():find(APIIListsSystemList.SearchString)) then
					table.insert(results, info);
				end
			end
		end
	end
	
	self:UpdateFilterBar();
end

local function IsSearchMatch(key, value, search, objType, wantFrames)
	if type(key) ~= "string" then return false; end
	if (objType == "value") then
		return key:lower():find(search:lower()) and (type(value) == "number" or  type(value) == "boolean");
	else
		if (type(value) ~= objType) then return false; end
	end
	if objType.GetDebugName and objType:IsProtected() then return false; end
	if (objType == "table") then
		if wantFrames then
			return value.GetDebugName  ~= nil and key:lower():find(search:lower());
		end
		return value.GetDebugName  == nil and key:lower():find(search:lower());
	end
	
	if (objType == "string" and type(value) == "string") then
		if IsShiftKeyDown() then
			return key:lower():find(search:lower()) or value:lower():find(search:lower());
		elseif IsControlKeyDown() then
			return value:lower():find(search:lower());
		end
	end
	
	return key:lower():find(search:lower()) 
end

APII_COREMIXIN = {};

function APII_COREMIXIN:HandleHyperlink(self, link, text, button)
	local apiType, name, system = link:match("api:(%a+):(%a+):(%a*):?") ;
	local apiInfo = APIDocumentation:FindAPIByName(apiType, name, system);
	
	if apiType == "system"  and APIIListsSystemList.InSystem ~= apiInfo then
		APIIListsSystemList.InSystem = apiInfo
		APII:UpdateSystemList();
		APIILists.searchBox:SetText("");
		APIIListsSystemListScrollBar:SetValue(0);
	elseif apiType == "table" then
		
		APIIListsSystemList.InSystem = apiInfo.System;
		APII:UpdateSystemList();

		APIIListsSystemList.Opened = apiInfo:GetFullName();
		
		if 	APIILists.searchBox:GetText() == "" then
			-- If we open something that is currently visible
			APII:UpdateSystemList();
			APII:AdjustSelection();
		else
			-- Search_OnTextChanged handles the list update
			APIILists.searchBox:SetText("");	
		end
		
	end
end

function APII_COREMIXIN:Search_OnTextChanged(searchBox, userInput)
	local searchString = searchBox:GetText();
	APIIListsSystemList.SearchString = searchString;
	-- Make 'Search' text disapear when needed
	SearchBoxTemplate_OnTextChanged(searchBox);
	-- protect against malformed pattern
	if not pcall(function() APIDocumentation:FindAllAPIMatches(searchString) end) then 
		searchBox:SetTextColor(1, 0.25, 0.25, 1);
		return; 
	else
		searchBox:SetTextColor(1, 1, 1, 1);
	end

	
	if (userInput) then
		APIIListsSystemListScrollBar:SetValue(0);
		APII:ResetListButtons();
	
		APII:UpdateSearchResults();
	end
	APII:UpdateSystemList();
	APII:AdjustSelection();
	
	APIILists.buttonFunctions:SetEnabled(searchString ~= "");
	APIILists.buttonTables:SetEnabled(searchString ~= "");
	APIILists.buttonFrames:SetEnabled(searchString ~= "");
	APIILists.buttonStrings:SetEnabled(searchString ~= "");
	APIILists.ButtonValues:SetEnabled(searchString ~= "");
end

function APII_COREMIXIN:GlobalSearch_OnClick(objType, wantFrames)
	local search = APIIListsSystemList.SearchString;
	local numResults = 0;
	if (search == "") then return end;
	
	local results={};
	for k,v in pairs(_G)do
		if (IsSearchMatch(k, v, search, objType, wantFrames)) then 
			results[k] = v;
			numResults = numResults + 1;
			if (numResults >= SEARCH_CUTOFF_AMOUNT) then
				break;
			end
		end 
	end;
	
	if numResults > 0 then
		UIParentLoadAddOn("Blizzard_DebugTools");
		DisplayTableInspectorWindow(results, FORMAT_RESULTS_TITLE:format(numResults, objType, search));
		if (numResults >= SEARCH_CUTOFF_AMOUNT) then
			print(FORMAT_SEARCH_CUTOFF:format(SEARCH_CUTOFF_AMOUNT));
		end
	else
		print(FORMAT_NO_RESULTS:format(search));
	end
	
	APIILists.searchBox:ClearFocus();
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
end

function APII_COREMIXIN:GlobalSearch_OnEnter(frame, objType)
	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
	GameTooltip:SetText("Search in _G");
	GameTooltip:AddLine(TOOLTIP_GLOBAL_FORMAT:format(objType), 1, 1, 1);
	if (objType == "frame") then
		GameTooltip:AddLine(TOOLTIP_GLOBAL_FRAME, 1, 0.25, 0.25);
	elseif (objType == "string") then
		GameTooltip:AddLine(TOOLTIP_GLOBAL_STRING1, 1, 1, 1);
		GameTooltip:AddLine(TOOLTIP_GLOBAL_STRING2, 1, 1, 1);
	end
	GameTooltip:Show();
end

function APII_COREMIXIN:CheckDocumented_OnClick(button)
	_includeUndocumented =  button:GetChecked();
	APII:UpdateSystemList();
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
end

function APII_COREMIXIN:CheckDocumented_OnEnter(button)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
	GameTooltip:SetText("Include Undocumented");
	GameTooltip:AddLine(TOOLTIP_UNDOCUMENTED, 1, 1, 1);
	GameTooltip:AddLine(TOOLTIP_UNDOCUMENTED_WARNING, 1, 0.25, 0.25);
	GameTooltip:Show();
end

function APII_COREMIXIN:FilterClearButton_OnClick(self)
	APIIListsSystemListScrollBar:SetValue(0);	
	APIIListsSystemList.InSystem = nil;
	HybridScrollFrame_CollapseButton(APIIListsSystemList);
	APII:UpdateSystemList();
	APII:UpdateFilterBar();
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	APIIListsSystemListScrollBar:SetValue(APIIListsSystemList.SystemScroll or 0);
end

function APII:ResetFrame()
	APII_Core:SetSize(600, 450);
	HybridScrollFrame_CreateButtons(APIIListsSystemList, "APII_ListSystemTemplate", 1, 0);
	APIIListsSystemListScrollBar.doNotHide = true;
	APII:UpdateSystemList();
end

function APII:FindSelection()
	local scrollHeight = APIIListsSystemList:GetHeight();
	local newHeight = 0;
	local info;
	
	-- Searching backwards as we are most likely looking for a table, which are at the back = less looping
	for i=#APII.currentList, 1, -1 do
		info = APII.currentList[i];
		if info:GetFullName() == APIIListsSystemList.Opened then
			return (i-1) * LISTITEM_HEIGHT;
		end
	end
	
	-- for k, v in ipairs(APII.currentList) do
		-- if v:GetFullName() == APIIListsSystemList.Opened then
			-- return (k-1) * LISTITEM_HEIGHT;
		-- end
	-- end
	
	return nil;
end

function APII:AdjustSelection()
	if APIIListsSystemList.Opened == "" or APIIListsSystemList.Adjusting then return; end
	local selectedButton;	
	APIIListsSystemList.Adjusting = true;
	local newHeight;
	--check if selection is visible
	for _, button in next, APIIListsSystemList.buttons do
		if ( button.selected ) then
			selectedButton = button;
			break;
		end
	end	
	
	if ( not selectedButton ) then
		-- Not one of the buttons visible, search in the list
		newHeight = APII:FindSelection();
	else
		-- One of the visible buttons, make it fit in the display window
		if ( selectedButton:GetTop() > APIIListsSystemList:GetTop() ) then
			newHeight = APIIListsSystemListScrollBar:GetValue() + APIIListsSystemList:GetTop() - selectedButton:GetTop();
		elseif ( selectedButton:GetBottom() < APIIListsSystemList:GetBottom() ) then
			if ( selectedButton:GetHeight() > APIIListsSystemList:GetHeight() ) then
				newHeight = APIIListsSystemListScrollBar:GetValue() + APIIListsSystemList:GetTop() - selectedButton:GetTop();
			else
				newHeight = APIIListsSystemListScrollBar:GetValue() + APIIListsSystemList:GetBottom() - selectedButton:GetBottom();
			end
		end
	end
	
	-- Set new height if any
	if ( newHeight ) then
		local _, maxVal = APIIListsSystemListScrollBar:GetMinMaxValues();
		newHeight = min(newHeight, maxVal);
		APIIListsSystemListScrollBar:SetValue(newHeight);				
	end
	
	APIIListsSystemList.Adjusting = false;
end

function APII:ResetListButtons()
	HybridScrollFrame_CollapseButton(APIIListsSystemList);
	APIIListsSystemList.Opened = "";
	APIIListsSystemList.ExpandedHeight = nil;
end

function APII:UpdateFilterBar()
	APIILists.filterBar:SetHeight(APIIListsSystemList.InSystem and 20 or 0.1);
	local system = APIIListsSystemList.InSystem and FORMAT_IN_SYSTEMS:format(APIIListsSystemList.InSystem.Name);
	if (system) then
		local undocumented = APIIListsSystemList.numUndocumented > 0 and FORMAT_UNDOCUMENTED:format(APIIListsSystemList.numUndocumented);
		if (undocumented) then
			system = string.format("%s %s", system , undocumented);
		end
	end
	APIILists.filterBar.text:SetText(system or "")
	APIILists.filterBar.clearButton:SetShown(APIIListsSystemList.InSystem)
end

function APII:UpdateSystemList()
	local scrollFrame = APIIListsSystemList;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	if buttons == nil then return; end
	APII:UpdateSearchResults();
	local list = (APIIListsSystemList.SearchString == "" and #APIIListsSystemList.SearchResults == 0) and APIDocumentation.systems or APIIListsSystemList.SearchResults;
	APII.currentList = list;
	local heightStuff = LISTITEM_HEIGHT;
	
	for i=1, #buttons do
		local button = buttons[i];
		local displayIndex = i + offset;
		
		button:SetHeight(LISTITEM_HEIGHT);
		button.ClipboardString:Hide();
		button.ClipboardInfo:Hide();
		button.Details:Hide();
		button.Api = nil;
		button.Type = "";
		button.Name:SetText("");
		button.Key = 0;
		button.ClipboardString:SetTextColor(0.7, 0.7, 0.7, 1);
		button.selected = false;
		button.highlight:Hide();
		button:SetEnabled(false);
		button.background:SetVertexColor(1, 1, 1);
		
		if ( displayIndex <= #list) then
			button:Show();
			local info = list[displayIndex];
			button.Api = info;
			button.Key = displayIndex;
			button.index = displayIndex;
			button:SetEnabled(not info.Undocumented);
			if(info.Undocumented) then
				button.Name:SetText(FORMAT_UNDOCUMENTED_TITLE:format(info.Name));
				button.background:SetVertexColor(.25, .25, .25);
			else
				button.Type = info:GetType();
				button.Name:SetText(info:GetSingleOutputLine())
				if info.Type ~= "System" and scrollFrame.Opened == info:GetFullName()  then
					button.selected = true;
					button.ClipboardString:Show();
					button.ClipboardString:SetText(info.LiteralName and info.LiteralName or  info:GetClipboardString());
					button.ClipboardInfo:Show();
					button.Details:Show();
					button.highlight:Show();
					local details = "<html><body><p>";
					details = details .. table.concat(info:GetDetailedOutputLines(), "<br/>", 2)
					details = details:gsub(DETAILS_NO_PUBLIC, DETAILS_NO_PUBLIC_REPLACE);
					
					details = details .. "</p></body></html>"
					
					button.Details:SetHyperlinksEnabled(true);
					button.Details:SetText(details);
					heightStuff = LISTITEM_HEIGHT + LISTITEM_EXPAND_MARGIN + button.Details:GetContentHeight();
					
					button:SetHeight(heightStuff);
					HybridScrollFrame_ExpandButton(APIIListsSystemList, ((displayIndex-1) * LISTITEM_HEIGHT), heightStuff);
				end
			end
		else
			button:Hide();
		end
	end
	
	
	
	local extra = APIIListsSystemList.largeButtonHeight or heightStuff;
	local totalHeight = #list * LISTITEM_HEIGHT
	totalHeight = totalHeight + (extra - LISTITEM_HEIGHT)
	
	HybridScrollFrame_Update(scrollFrame, totalHeight, scrollFrame:GetHeight());

end

function APII:UpdateEventTraceTooltip()
	local tooltip = _G["EventTraceTooltip"];
	local index = 1;
	local line = _G["EventTraceTooltipTextLeft"..index];
	local eventName = line:GetText();
	
	if (not eventName or not _EventArgLookup[eventName]) then
		return;
	end
	local args = _EventArgLookup[eventName];
	
	while (line) do
		local lineText = line:GetText();
		if (not lineText) then return; end
		local argIndex = tonumber(lineText:match(ARGUMENT_LABEL_FORMAT));
		if (argIndex and args[argIndex]) then 
			line:SetText(ARGUMENT_LABEL_FORMAT_NEW:format(argIndex, args[argIndex].Name));
		end
		
		index = index + 1;
		line = _G["EventTraceTooltipTextLeft"..index];
	end
end

function APII:OnInitialize()
	APII_Core:SetScript("OnDragStart", function(self)
					self:StartMoving();
				end
			);
	APII_Core:SetScript("OnDragStop", function(self)
					self:StopMovingOrSizing();
				end
			);
end

function APII:OnEnable()
	if not APIDocumentation then
		LoadAddOn("Blizzard_APIDocumentation");
	end

	HybridScrollFrame_CreateButtons(APIIListsSystemList, "APII_ListSystemTemplate", 1, 0);
	HybridScrollFrame_Update(APIIListsSystemList, #APIDocumentation.systems * LISTITEM_HEIGHT, APIIListsSystemList:GetHeight());
	APIIListsSystemListScrollBar.doNotHide = true;
	APIIListsSystemListScrollBar:Show();
	
	APIIListsSystemList.update = function() 
				APII:UpdateSystemList();
		end;
	APIIListsSystemList.SearchString = "";
	APIIListsSystemList.SearchResults = {};
	APIIListsSystemList.Undocumented = {};
	APIIListsSystemList.Opened = "";
	APII:UpdateSystemList();
	
	for k, system in ipairs(APIDocumentation.systems) do
		APII:GetUndocumentedFunctions(system);
	end
	
	for k, v in ipairs(APIDocumentation.events) do
		_EventArgLookup[v.LiteralName] = v.Payload
	end
	
	if (LDHDebug) then
		LDHDebug:Monitor(_addonName);
	end
end

----------
-- Events
----------

APII.events = CreateFrame("FRAME", "APII_EventFrame"); 
APII.events:RegisterEvent("PLAYER_REGEN_DISABLED");
APII.events:RegisterEvent("PLAYER_REGEN_ENABLED");
APII.events:RegisterEvent("ADDON_LOADED");
APII.events:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)

function APII.events:ADDON_LOADED(addonName)
	if (addonName == "Blizzard_DebugTools") then
		hooksecurefunc("EventTraceFrameEvent_DisplayTooltip", function() APII:UpdateEventTraceTooltip() end);
	end
end

function APII.events:PLAYER_REGEN_DISABLED(loaded_addon)
	HideUIPanel(APII_Core);
end

function APII.events:PLAYER_REGEN_ENABLED(loaded_addon)
	if APII.openDuringCombat then
		ShowUIPanel(APII_Core);
		APII.openDuringCombat = false;
	end
end
----------
-- Slash
----------

SLASH_APIISLASH1 = '/apii';
SLASH_APIISLASH2 = '/apiinterface';
local function slashcmd(msg, editbox)
	if (msg == "reset") then
		APII:ResetFrame();
	elseif msg:match("^limit ") then
		local amount = tonumber(msg:match("limit (%d+)"));
		if not amount or amount < 1 then return; end
		SEARCH_CUTOFF_AMOUNT = amount;
		print(FORMAT_SEARCH_CUTOFF_CHANGED:format(SEARCH_CUTOFF_AMOUNT));
	else
		if (not InCombatLockdown()) then
			ShowUIPanel(APII_Core);
		else
			print(ERROR_COMBAT:format(_addonName));
			APII.openDuringCombat = true;
		end
	end
end
SlashCmdList["APIISLASH"] = slashcmd



-- local l_debug = CreateFrame("frame", _addonName .. "Debug", UIParent);

-- local function GetDebugLine(lineIndex)
	-- local lineContainer = l_debug.DependencyLines and l_debug.DependencyLines[lineIndex];
	-- if lineContainer then
		-- lineContainer:Show();
		-- return lineContainer;
	-- end
	-- lineContainer = CreateFrame("FRAME", nil, l_debug, "APII_DebugLine");

	-- return lineContainer;
-- end

-- local function ShowDebugHistory()
	-- local mem = floor(l_debug.history[#l_debug.history]*100)/100;
	-- for i=1, #l_debug.history-1, 1 do
		-- local line = GetDebugLine(i);
		-- line.Fill:SetStartPoint("BOTTOMLEFT", l_debug, (i-1)*1.4, l_debug.history[i]/10);
		-- line.Fill:SetEndPoint("BOTTOMLEFT", l_debug, i*1.4, l_debug.history[i+1]/10);
		-- line.Fill:SetVertexColor(1, 1, 1);
		-- line.Fill:Show();
	-- end
	-- l_debug.text:SetText(mem)
-- end

-- l_debug:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      -- edgeFile = nil,
	  -- tileSize = 0, edgeSize = 16,
      -- insets = { left = 0, right = 0, top = 0, bottom = 0 }
	  -- })
-- l_debug:SetFrameLevel(5)
-- l_debug:SetMovable(true)
-- l_debug:SetPoint("Center", 250, 0)
-- l_debug:RegisterForDrag("LeftButton")
-- l_debug:EnableMouse(true);
-- l_debug:SetScript("OnDragStart", l_debug.StartMoving)
-- l_debug:SetScript("OnDragStop", l_debug.StopMovingOrSizing)
-- l_debug:SetWidth(100)
-- l_debug:SetHeight(100)
-- l_debug:SetClampedToScreen(true)
-- l_debug.text = l_debug:CreateFontString(nil, nil, "GameFontWhiteSmall")
-- l_debug.text:SetPoint("BOTTOMLEFT", 2, 2)
-- l_debug.text:SetText("0000")
-- l_debug.text:SetJustifyH("left")
-- l_debug.time = 0;
-- l_debug.interval = 0.2;
-- l_debug.history = {}
-- l_debug:SetScript("OnUpdate", function(self,elapsed) 
		-- self.time = self.time + elapsed;
		-- if(self.time >= self.interval) then
			-- self.time = self.time - self.interval;
			-- UpdateAddOnMemoryUsage();
			-- table.insert(self.history, GetAddOnMemoryUsage(_addonName));
			-- if(#self.history > 50) then
				-- table.remove(self.history, 1)
			-- end
			-- ShowDebugHistory()
		-- end
	-- end)
-- l_debug:Show()

