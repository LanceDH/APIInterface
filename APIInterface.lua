
local _addonName, _addon = ...;

APII = LibStub("AceAddon-3.0"):NewAddon(_addonName);

local HISTORY_MAX = 50;
local LISTITEM_HEIGHT = 34;
local LISTITEM_EXPAND_MARGIN = 48;
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
local SIMPLEHTML_SPACE = "|c00000000 |r";

local _includeUndocumented = true;

------------------------------------
-- General
------------------------------------
-- APII_Resize_OnMouseUp(self, button)
-- APII_Resize_OnMouseDown(self, button)
-- APII_List_OnClick(self, button)
-- MatchContainsFunction(list, entry)
-- APII:GetUndocumentedFunctions(system)
-- APII:UpdateSearchResults()
-- IsSearchMatch(key, value, search, objType, wantFrames)

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
			self:SetHeight(LISTITEM_HEIGHT);
			HybridScrollFrame_CollapseButton(APIIListsSystemList);
			-- Stay in the same system but clear the current open
			APIILists:OpenSystem(APIIListsSystemList.InSystem);
		else
			self.Details:SetText(table.concat(self.Api:GetDetailedOutputLines(), "\n", 2));
			self:SetHeight(LISTITEM_HEIGHT + LISTITEM_EXPAND_MARGIN + self.Details:GetHeight());
			APIILists:OpenSystem(self.Api);
			APII:AdjustSelection();
		end
	else
		APIIListsSystemList.SystemScroll = APIIListsSystemListScrollBar:GetValue();
		APIIListsSystemList.InSystem = self.Api
		APIILists:OpenSystem(self.Api);
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
				tinsert(APII[namespace], {["Name"] = namespace.."."..name, ["Type"] = "Function", ["undocumented"] = true});
			end
		end
	end
	
	return APII[namespace];
end

function APII:UpdateSearchResults()
	if (not APIIListsSystemList.undocumented) then
		APIIListsSystemList.undocumented = {}
	end
	
	local results = APIIListsSystemList.SearchResults;
	local matches;
	local undocumented = APIIListsSystemList.undocumented ;
	
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

------------------------------------
-- APII_COREMIXIN
------------------------------------
-- OnLoad()
-- UpdateHistoryButtons()
-- AddHistory()
-- StepHistory(delta)
-- OpenSystem(api)

APII_LISTSMIXIN = {};

function APII_LISTSMIXIN:OnLoad()
	self.history = {{}};
	self.historyIndex = 1;
	self:UpdateHistoryButtons();
end

function APII_LISTSMIXIN:UpdateHistoryButtons()
	self.HistoryBackButton:SetEnabled(#self.history - self.historyIndex > 0);
	self.HistoryForwardButton:SetEnabled(self.historyIndex > 1);
end

function APII_LISTSMIXIN:AddHistory()
	tinsert(self.history, 1, {["system"] = APIIListsSystemList.InSystem, ["api"] = APIIListsSystemList.Opened, ["search"] = APIILists.searchBox:GetText()});
	if (#self.history > HISTORY_MAX) then
		self.history[#self.history] = nil
	end
	
	self:UpdateHistoryButtons();
end

function APII_LISTSMIXIN:StepHistory(delta)
	if (IsShiftKeyDown()) then
		if (delta > 0) then
			self.historyIndex = #self.history;
		else
			self.historyIndex = 1;
		end
	else
		self.historyIndex = self.historyIndex + delta;
		self.historyIndex = max(1, min(self.historyIndex, #self.history));
	end
	
	APIIListsSystemList.InSystem = self.history[self.historyIndex].system;
	APIIListsSystemList.Opened = self.history[self.historyIndex].api;
	APIILists.searchBox:SetText(self.history[self.historyIndex].search or "")
	APII:UpdateSystemList();
	APII:AdjustSelection();
	APII:UpdateFilterBar();
	self:UpdateHistoryButtons();
end

function APII_LISTSMIXIN:OpenSystem(api)
	for i= self.historyIndex-1, 1, -1 do
		tremove(self.history, i);
	end

	self.historyIndex = 1;
	if (not api) then
		APIIListsSystemList.Opened = nil;
		APIIListsSystemList.InSystem = nil;
	elseif (api.Type == "System") then
		APIIListsSystemList.Opened = nil;
		APIIListsSystemList.InSystem = api;
	else
		APIIListsSystemList.Opened = api;
		APIIListsSystemList.InSystem = api.System;
	end

	self:AddHistory();
	APII:UpdateSystemList();
	APII:UpdateFilterBar();
end

------------------------------------
-- APII_COREMIXIN
------------------------------------
-- OnLoad()
-- HandleHyperlink(self, link, text, button)
-- Search_OnTextChanged(searchBox, userInput)
-- GlobalSearch_OnClick(objType, wantFrames)
-- GlobalSearch_OnEnter(frame, objType)
-- CheckDocumented_OnClick(button)
-- CheckDocumented_OnEnter(button)
-- FilterClearButton_OnClick(self)

APII_COREMIXIN = {};

function APII_COREMIXIN:OnLoad()
	self:SetClampedToScreen(true);
	self.TitleText:SetText("APIInterface");
	self:RegisterForDrag("LeftButton");
	self:SetMinResize(250, 200);
end

function APII_COREMIXIN:HandleHyperlink(self, link, text, button)
	local apiType, name, system = link:match("api:(%a+):(%a+):(%a*):?") ;
	local apiInfo = APIDocumentation:FindAPIByName(apiType, name, system);
	
	if apiType == "system"  and APIIListsSystemList.InSystem ~= apiInfo then
		APIILists:OpenSystem(apiInfo)
		APIILists.searchBox:SetText("");
		APIIListsSystemListScrollBar:SetValue(0);
	elseif apiType == "table" then
		APIILists:OpenSystem(apiInfo)
		
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
	-- Make 'Search' text disappear when needed
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
		APIILists:AddHistory();
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
	HybridScrollFrame_CollapseButton(APIIListsSystemList);
	APIILists:OpenSystem();
	APII:UpdateFilterBar();
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	APIIListsSystemListScrollBar:SetValue(APIIListsSystemList.SystemScroll or 0);
end

------------------------------------
-- APII
------------------------------------
-- ResetFrame()
-- FindSelection()
-- AdjustSelection()
-- ResetListButtons()
-- UpdateFilterBar()
-- UpdateSystemList()

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
		if (not info.undocumented and info == APIIListsSystemList.Opened) then
			return (i-1) * LISTITEM_HEIGHT;
		end
	end

	return nil;
end

function APII:AdjustSelection()
	if (not APIIListsSystemList.Opened or APIIListsSystemList.Adjusting) then return; end
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
	APIIListsSystemList.Opened = nil;
	
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
		button.background:SetVertexColor(.6, .6, .6);
		
		if ( displayIndex <= #list) then
			button:Show();
			local info = list[displayIndex];
			button.Api = info;
			button.Key = displayIndex;
			button.index = displayIndex;
			button:SetEnabled(not info.undocumented);
			if(info.undocumented) then
				button.Name:SetText(FORMAT_UNDOCUMENTED_TITLE:format(info.Name));
				button.background:SetVertexColor(.25, .25, .25);
			else
				button.Type = info:GetType();
				button.Name:SetText(info:GetSingleOutputLine())
				if (info.Type ~= "System" and scrollFrame.Opened == info)  then
					button.selected = true;
					button.ClipboardString:Show();
					button.ClipboardString:SetText(info.LiteralName and info.LiteralName or  info:GetClipboardString());
					button.ClipboardInfo:Show();
					button.Details:Show();
					button.highlight:Show();
					local details = "<html><body><p>";
					
					details = details .. table.concat(info:GetDetailedOutputLines(), "<br/>", 2)
					details = details:gsub(DETAILS_NO_PUBLIC, DETAILS_NO_PUBLIC_REPLACE);
					-- Redo indentation to work in simplehtml
					-- We want to remove 1 (3 spaces) because each line has a default of 1 indentation
					details = details:gsub("(    +)", function (a)
						local spaces = a:len();
						spaces = spaces - 3;
						return SIMPLEHTML_SPACE:rep(spaces);
					end);
					
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

local _eventArgLookup = {};

function APII:UpdateEventTraceTooltip()
	local tooltip = _G["EventTraceTooltip"];
	local lineIndex = 1;
	local line = _G["EventTraceTooltipTextLeft"..lineIndex];
	local eventName = line:GetText();
	
	if (not eventName or not _eventArgLookup[eventName]) then
		return;
	end

	local args = _eventArgLookup[eventName];

	while (line) do
		local lineText = line:GetText();
		if (not lineText) then return; end
		local argIndex = tonumber(lineText:match(ARGUMENT_LABEL_FORMAT));
		if (argIndex and args[argIndex]) then 
			line:SetText(ARGUMENT_LABEL_FORMAT_NEW:format(argIndex, args[argIndex].Name));
		end
		
		lineIndex = lineIndex + 1;
		line = _G["EventTraceTooltipTextLeft"..lineIndex];
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
	APIIListsSystemList.undocumented = {};
	APIIListsSystemList.Opened = nil;
	APII:UpdateSystemList();
	
	for k, system in ipairs(APIDocumentation.systems) do
		APII:GetUndocumentedFunctions(system);
	end
	
	for k, v in ipairs(APIDocumentation.events) do
		_eventArgLookup[v.LiteralName] = v.Payload
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

local function addArgs(args, index, ...)
   for i = 1, select("#", ...) do
      if not args[i] then
         args[i] = {}
      end
      args[i][index] = select(i, ...)
   end
end

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
			if (msg ~= "") then
				APII_Core:FilterClearButton_OnClick()
				APIILists.searchBox:SetText(msg)
				APIILists:AddHistory();
			end
		else
			print(ERROR_COMBAT:format(_addonName));
			APII.openDuringCombat = true;
		end
	end
end
SlashCmdList["APIISLASH"] = slashcmd
