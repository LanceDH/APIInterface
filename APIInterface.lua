
local _addonName, _addon = ...;

APII = LibStub("AceAddon-3.0"):NewAddon(_addonName);

local HISTORY_MAX = 50;
local LISTITEM_HEIGHT = 34;
local LISTITEM_EXPAND_MARGIN = 52;
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
local DETAILS_NO_PUBLIC = "This function does nothing in public clients";
local DETAILS_NO_PUBLIC_REPLACE = "|cffff0000This function does nothing in public clients|r";
local SIMPLEHTML_SPACE = "|c00000000 |r";

------------------------------------
-- Local functions
------------------------------------
-- MatchContainsFunction(list, entry)
-- IsSearchMatch(key, value, search, objType, wantFrames)

local function MatchContainsFunction(list, entry)
	for k, v in pairs(list) do
		if (v.Name == entry) then return true end;
	end
	return false;
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
-- APII_LISTBUTTONMIXIN
------------------------------------
-- OnClick()
-- Reset()
-- isexpanded = SetupAPI(info)

APII_LISTBUTTONMIXIN = CreateFromMixins(BackdropTemplateMixin);

function APII_LISTBUTTONMIXIN:OnClick()
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
			APIILists:AdjustSelection();
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

function APII_LISTBUTTONMIXIN:Reset()
	self:Hide();
	self:SetHeight(LISTITEM_HEIGHT);
	self.ClipboardString:Hide();
	self.ClipboardInfo:Hide();
	self.Details:Hide();
	self.Api = nil;
	self.Type = "";
	self.Name:SetText("");
	self.Key = 0;
	self.ClipboardString:SetTextColor(0.7, 0.7, 0.7, 1);
	self.selected = false;
	self.highlight:Hide();
	self:SetEnabled(false);
	self.background:SetVertexColor(.4, .4, .4);
	self.titleBar:SetVertexColor(.6, .6, .6);
	self.highlight.tl:SetVertexColor(.6, .6, .6);
	self.highlight.l:SetVertexColor(.6, .6, .6);
	self.highlight.bl:SetVertexColor(.6, .6, .6);
	self.highlight.t:SetVertexColor(.6, .6, .6);
	self.highlight.b:SetVertexColor(.6, .6, .6);
	self.highlight.tr:SetVertexColor(.6, .6, .6);
	self.highlight.r:SetVertexColor(.6, .6, .6);
	self.highlight.br:SetVertexColor(.6, .6, .6);
end

function APII_LISTBUTTONMIXIN:SetupAPI(info)
	self:Show();
	self.Api = info;
	self.Key = displayIndex;
	self.index = displayIndex;
	self:SetEnabled(not info.undocumented);
	if(info.undocumented) then
		self.Name:SetText(FORMAT_UNDOCUMENTED_TITLE:format(info.Name));
		self.background:SetVertexColor(.25, .25, .25);
	else
		self.Type = info:GetType();
		self.Name:SetText(info:GetSingleOutputLine())
		if (info.Type ~= "System" and self:GetParent():GetParent().Opened == info)  then
			self.selected = true;
			self.ClipboardString:Show();
			self.ClipboardString:SetText(info.LiteralName and info.LiteralName or info:GetClipboardString());
			self.ClipboardInfo:Show();
			self.Details:Show();
			self.highlight:Show();
			
			local details = "<html><body><p>";
			local outputLines = info:GetDetailedOutputLines();
			self.outputLines = outputLines;
			self.info = info;
			-- We don't care for the name line
			tremove(outputLines, 1);
			-- Redo indentation to work in simplehtml
			for k, line in ipairs(outputLines) do
				line = line:gsub("(   )([ ]*)", function (a, b)
					return SIMPLEHTML_SPACE:rep(b:len());
				end);
				outputLines[k] = line;
			end
			
			-- Re-color documentation info
			if (info.Documentation) then
				for i, documentation in ipairs(info.Documentation) do
					if (documentation == DETAILS_NO_PUBLIC) then
						documentation = DETAILS_NO_PUBLIC_REPLACE;
					else
						documentation = "|cFFffdd55".. documentation .."|r";
					end
					outputLines[1+i] = documentation;
				end
			end
			
			-- Find arguments index
			local argStart = -1;
			local retStart = -1;
			for k, text in ipairs(outputLines) do
				if (text == "Arguments") then
					argStart = k;
				elseif (text == "Returns") then
					retStart = k;
				end
			end

			-- Add Mixin info
			if (info.Arguments) then
				for k, arg in ipairs(info.Arguments) do
					if (arg.Mixin) then
						outputLines[argStart + k] = outputLines[argStart + k] .. " (" .. arg.Mixin .. ")";
					end
				end
			end
			
			if (info.Returns) then
				for k, arg in ipairs(info.Returns) do
					if (arg.Mixin) then
						outputLines[retStart + k] = outputLines[retStart + k] .. " (" .. arg.Mixin .. ")";
					end
				end
			end
			
			
			details = details .. table.concat(outputLines, "<br/>")
			details = details .. "</p></body></html>"
			
			self.Details:SetHyperlinksEnabled(true);
			self.Details:SetText(details);
			local expandedHeight = LISTITEM_HEIGHT + LISTITEM_EXPAND_MARGIN + self.Details:GetContentHeight();
			
			self:SetHeight(expandedHeight);
			
			return true;
		end
	end
	
	return false;
end

------------------------------------
-- APII_LISTSMIXIN
------------------------------------
-- OnLoad()
-- UpdateHistoryButtons()
-- AddHistory()
-- StepHistory(delta)
-- OpenSystem(api)
-- FindSelection()
-- AdjustSelection()
-- UpdateSystemList(skipSearchUpdate)
-- UpdateFilterBar()
-- GetUndocumentedFunctions(system)
-- UpdateSearchResults()

APII_LISTSMIXIN = {};

function APII_LISTSMIXIN:OnLoad()
	self.includeUndocumented = true;
	self.undocumented = {};
	self.history = {{}};
	self.historyIndex = 1;
	self:UpdateHistoryButtons();
end

function APII_LISTSMIXIN:UpdateHistoryButtons()
	self.HistoryBackButton:SetEnabled(#self.history - self.historyIndex > 0);
	self.HistoryForwardButton:SetEnabled(self.historyIndex > 1);
end

function APII_LISTSMIXIN:AddHistory()
	local currSys = APIIListsSystemList.InSystem;
	local currApi =  APIIListsSystemList.Opened;
	local currSearch = APIILists.searchBox:GetText();
	
	-- Remove any history after the current point. We're rewriting history.
	for i= self.historyIndex-1, 1, -1 do
		tremove(self.history, i);
	end
	
	tinsert(self.history, 1, {["system"] = currSys, ["api"] = currApi, ["search"] = currSearch});
	if (#self.history > HISTORY_MAX) then
		self.history[#self.history] = nil
	end
	
	-- Remove in between search changes
	if (self.historyIndex == 1 and #self.history > 3) then
		local first = self.history[1];
		local second = self.history[2];
		local third = self.history[3];
		if (first.system == second.system and first.system == third.system and first.api == second.api and first.api == third.api) then
			tremove(self.history, 2);
			-- If start and end search is the same (typed and then deleted) remove one of them
			if (first.search == third.search) then
				tremove(self.history, 2);
			end
		end
	end
	self.historyIndex = 1;
	self:UpdateHistoryButtons();
end

function APII_LISTSMIXIN:StepHistory(delta)
	if (IsShiftKeyDown()) then
		if (delta > 0) then
			self.historyIndex = #self.history;
		else
			self.historyIndex = 1;
		end
	elseif (delta ~= 0) then
		self.historyIndex = self.historyIndex + delta;
		self.historyIndex = max(1, min(self.historyIndex, #self.history));
	end

	APIIListsSystemList.InSystem = self.history[self.historyIndex].system;
	APIIListsSystemList.Opened = self.history[self.historyIndex].api;
	APIILists.searchBox:SetText(self.history[self.historyIndex].search or "")
	self:AdjustSelection();
	APIILists:UpdateFilterBar();
	self:UpdateHistoryButtons();
end

function APII_LISTSMIXIN:OpenSystem(api)
	if (not api) then
		APIIListsSystemList.Opened = nil;
		APIIListsSystemList.InSystem = nil;
	elseif (api.Type == "System") then
		APIIListsSystemList.Opened = nil;
		APIIListsSystemList.InSystem = api;
	else
		APIIListsSystemList.Opened = api;
		APIIListsSystemList.InSystem = api.System;
		-- If api is not part of a system, search for it instead
		if (not api.System) then
			APIILists.searchBox:SetText(api.Name);
		end
	end

	self:AddHistory();
	self:UpdateSystemList();
	APIILists:UpdateFilterBar();
end

function APII_LISTSMIXIN:FindSelection()
	local scrollHeight = APIIListsSystemList:GetHeight();
	local newHeight = 0;
	local info;
	
	-- Searching backwards as we are most likely looking for a table, which are at the back = less looping
	for i=#self.currentList, 1, -1 do
		info = self.currentList[i];
		if (not info.undocumented and info == APIIListsSystemList.Opened) then
			return (i-1) * LISTITEM_HEIGHT;
		end
	end

	return nil;
end

function APII_LISTSMIXIN:AdjustSelection()
	self:UpdateSystemList();
	local scrollFrame = self.ScrollFrame;
	if (not scrollFrame.Opened) then return; end
	local selectedButton = scrollFrame.selectedButton;	
	
	-- If it's not currently visible, make it be
	if ( not selectedButton ) then
		local scrollToHeight = self:FindSelection();
		if ( scrollToHeight ) then
			-- Set the new scroll
			local _, maxVal = scrollFrame.scrollBar:GetMinMaxValues();
			scrollToHeight = min(scrollToHeight, maxVal);
			scrollFrame.scrollBar:SetValue(scrollToHeight);	
			-- Update the list (expands the button)
			self:UpdateSystemList();	
			selectedButton = scrollFrame.selectedButton;
		end
	end
	
	if (selectedButton) then
		local scrollToHeight;
		-- One of the visible buttons, make it fit in the display window
		if ( selectedButton:GetTop() > scrollFrame:GetTop() ) then
			scrollToHeight = scrollFrame.scrollBar:GetValue() + scrollFrame:GetTop() - selectedButton:GetTop();
		elseif ( selectedButton:GetBottom() < scrollFrame:GetBottom() ) then
			if ( selectedButton:GetHeight() > scrollFrame:GetHeight() ) then
				scrollToHeight = scrollFrame.scrollBar:GetValue() + scrollFrame:GetTop() - selectedButton:GetTop();
			else
				scrollToHeight = scrollFrame.scrollBar:GetValue() + scrollFrame:GetBottom() -  selectedButton:GetBottom();
			end
		end
		
		if ( scrollToHeight ) then
			local _, maxVal = scrollFrame.scrollBar:GetMinMaxValues();
			scrollToHeight = min(scrollToHeight, maxVal);
			scrollFrame.scrollBar:SetValue(scrollToHeight);
		end
	end
end

function APII_LISTSMIXIN:UpdateSystemList(skipSearchUpdate)
	local scrollFrame = self.ScrollFrame;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	if buttons == nil then return; end
	if (not skipSearchUpdate) then
		self:UpdateSearchResults();
	end
	local list = (APIIListsSystemList.SearchString == "" and #APIIListsSystemList.SearchResults == 0) and APIDocumentation.systems or APIIListsSystemList.SearchResults;
	self.currentList = list;
	local heightStuff = LISTITEM_HEIGHT;
	scrollFrame.selectedButton = nil;

	if (not scrollFrame.Opened) then
		HybridScrollFrame_CollapseButton(scrollFrame);
	end
	
	for i=1, #buttons do
		local button = buttons[i];
		local displayIndex = i + offset;
		
		button:Reset();

		if ( displayIndex <= #list) then
			local info = list[displayIndex];
			local isExpanded = button:SetupAPI(info)
			
			if (isExpanded) then
				local expandedHeight = button:GetHeight();
				HybridScrollFrame_ExpandButton(scrollFrame, ((displayIndex-1) * LISTITEM_HEIGHT), expandedHeight);
				scrollFrame.selectedButton = button;
				heightStuff = expandedHeight;
			end
		end
	end

	local extra = scrollFrame.largeButtonHeight or heightStuff;
	local totalHeight = #list * LISTITEM_HEIGHT
	totalHeight = totalHeight + (extra - LISTITEM_HEIGHT)
	
	HybridScrollFrame_Update(scrollFrame, totalHeight, scrollFrame:GetHeight());
end

function APII_LISTSMIXIN:UpdateFilterBar()
	self.filterBar:SetHeight(APIIListsSystemList.InSystem and 20 or 0.1);
	local system = APIIListsSystemList.InSystem and FORMAT_IN_SYSTEMS:format(APIIListsSystemList.InSystem.Name);
	if (system) then
		local undocumented = APIIListsSystemList.numUndocumented > 0 and FORMAT_UNDOCUMENTED:format(APIIListsSystemList.numUndocumented);
		if (undocumented) then
			system = string.format("%s %s", system , undocumented);
		end
	end
	self.filterBar.text:SetText(system or "")
	self.filterBar.clearButton:SetShown(APIIListsSystemList.InSystem)
end

function APII_LISTSMIXIN:GetUndocumentedFunctions(system)
	local namespace = system.Namespace;
	local documented = system:ListAllAPI();
	local list = documented and documented.functions;	
	if (not namespace or not list) then return nil; end
	
	-- We've already done it before
	if (self.undocumented[namespace]) then 
		return self.undocumented[namespace]; 
	end

	self.undocumented[namespace] = {};
	local global = _G[namespace];
	
	if(global) then
		for name, v in pairs(global) do
			if (not MatchContainsFunction(list, name)) then
				tinsert(self.undocumented[namespace], {["Name"] = namespace.."."..name, ["Type"] = "Function", ["undocumented"] = true});
			end
		end
	end
	
	return self.undocumented[namespace];
end

function APII_LISTSMIXIN:UpdateSearchResults()
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
		if (APIIListsSystemList.SearchString == "") then
			matches = APIIListsSystemList.InSystem:ListAllAPI();
		else
			matches = APIIListsSystemList.InSystem:FindAllAPIMatches(APIIListsSystemList.SearchString);
		end
	else
		if (APIIListsSystemList.SearchString == "") then return; end
		matches = APIDocumentation:FindAllAPIMatches(APIIListsSystemList.SearchString);
		
		if (self.includeUndocumented) then
			for k, system in ipairs(APIDocumentation.systems) do
				local result = self:GetUndocumentedFunctions(system);
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
		if (self.includeUndocumented) then
			for k, info in ipairs(undocumented) do
				if (APIIListsSystemList.SearchString == "" or info.Name:lower():find(APIIListsSystemList.SearchString)) then
					table.insert(results, info);
				end
			end
		end
	end
	
	APIILists:UpdateFilterBar();
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
	ButtonFrameTemplate_HidePortrait(self)
	self:SetClampedToScreen(true);
	self:SetTitle("APIInterface");
	self:SetResizeBounds(250, 200);
end

function APII_COREMIXIN:HandleHyperlink(self, link, text, button)
	local apiType, name, system = link:match("api:(%a+):(%a+):(%a*):?") ;
	local apiInfo = APIDocumentation:FindAPIByName(apiType, name, system);
	
	if apiType == "system"  and APIIListsSystemList.InSystem ~= apiInfo then
		APIILists:OpenSystem(apiInfo);
		APIILists.searchBox:SetText("");
		APIIListsSystemListScrollBar:SetValue(0);
	elseif apiType == "table" then
		APIILists.searchBox:SetText("");
		APIILists:OpenSystem(apiInfo);
		APIILists:AdjustSelection();
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

	if (searchString == "" and not APIIListsSystemList.InSystem) then
		APIIListsSystemList.Opened = nil;
	end
	
	if (userInput) then
		APIILists:AddHistory();
		APIIListsSystemListScrollBar:SetValue(0);
		APIILists:UpdateSearchResults();
	end
	APIILists:AdjustSelection();
	
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
	APIILists.includeUndocumented =  button:GetChecked();
	APIILists:UpdateSystemList();
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
	APIILists:UpdateFilterBar();
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	APIIListsSystemListScrollBar:SetValue(APIIListsSystemList.SystemScroll or 0);
end

------------------------------------
-- APII_COREMIXIN
------------------------------------
-- OnInitialize()
-- OnEnable()

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
	if (not APIDocumentation) then
		C_AddOns.LoadAddOn("Blizzard_APIDocumentationGenerated");
	end

	HybridScrollFrame_CreateButtons(APIIListsSystemList, "APII_ListSystemTemplate", 1, 0);
	-- Change valueStep to allow for more accurate scroll when jumping to api
	APIIListsSystemListScrollBar:SetValueStep(1);
	HybridScrollFrame_Update(APIIListsSystemList, #APIDocumentation.systems * LISTITEM_HEIGHT, APIIListsSystemList:GetHeight());
	APIIListsSystemListScrollBar.doNotHide = true;
	APIIListsSystemListScrollBar:Show();
	
	APIIListsSystemList.update = function() 
				APIILists:UpdateSystemList(true);
		end;
	APIIListsSystemList.SearchString = "";
	APIIListsSystemList.SearchResults = {};
	APIIListsSystemList.undocumented = {};
	APIIListsSystemList.Opened = nil;
	APIILists:UpdateSystemList();
	
	self.eventArgLookup = {};
	
	for k, v in ipairs(APIDocumentation.events) do
		self.eventArgLookup[v.LiteralName] = v.Payload
	end
end

----------
-- Events
----------

APII.events = CreateFrame("FRAME", "APII_EventFrame"); 
APII.events:RegisterEvent("PLAYER_REGEN_DISABLED");
APII.events:RegisterEvent("PLAYER_REGEN_ENABLED");
APII.events:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)

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
		if (not amount or amount < 1) then return; end
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
