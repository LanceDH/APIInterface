
local _addonName, _addon = ...;

APII = LibStub("AceAddon-3.0"):NewAddon(_addonName);

local HISTORY_MAX = 50;
local LISTITEM_HEIGHT = 34;
local LISTITEM_EXPAND_MARGIN = 52;
local SEARCH_CUTOFF_AMOUNT = 1000;
local TEXT_IMPUT_SEARCH_DELAY = 0.3;
local FORMAT_SEARCH_CUTOFF_CHANGED = "Search cutoff changed to %d for this session.";
local FORMAT_SEARCH_CUTOFF = "Searched stopped after %d results."
local FORMAT_NO_RESULTS = "No global variables found containing \"%s\"."
local FORMAT_RESULTS_TITLE = "%d %ss containing \"%s\"";
local FORMAT_IN_SYSTEMS = "In system: %s";
local FORMAT_UNDOCUMENTED = "(|cffff3333%d undocumented|r)";
local FORMAT_UNDOCUMENTED_TITLE = "function |cffff3333%s|r (Undocumented)";
local TOOLTIP_GLOBAL_FORMAT = "Search global %ss whose name match the given search string.";
local TOOLTIP_GLOBAL_FRAME = "Can cause errors trying to access variables considered forbidden.";
local TOOLTIP_GLOBAL_STRING1 = "Hold shift: search in both name and value.";
local TOOLTIP_GLOBAL_STRING2 = "Hold control: search only in value.";
local TOOLTIP_UNDOCUMENTED = "Include undocumented system functions in systems and search.";
local TOOLTIP_UNDOCUMENTED_WARNING = "Enabling this will cause increase memory usage.";
local ERROR_COMBAT = "Can't open %s during combat. The frame will open once you leave combat.";
local DETAILS_NO_PUBLIC = "This function does nothing in public clients";
local DETAILS_NO_PUBLIC_REPLACE = "|cffff0000This function does nothing in public clients|r";
local ARGUMENT_LABEL_FORMAT = "Arg (%d+):";
local ARGUMENT_LABEL_FORMAT_NEW = "%d. %s:";
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
	self.background:SetVertexColor(.5, .5, .5);
	self.titleBar:SetVertexColor(.9, .9, .9);
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
	local searchString = APIIListsSystemList.SearchString;
	local searchStringIsEmpty = #searchString == 0;
	local results = APIIListsSystemList.SearchResults;
	local undocumented = APIIListsSystemList.undocumented;
	local matches;
	
	wipe(results);
	wipe(undocumented);
	APIIListsSystemList.numUndocumented = 0;
	
	if APIIListsSystemList.InSystem then
		local namespace = APIIListsSystemList.InSystem.Namespace;
		undocumented = self:GetUndocumentedFunctions(APIIListsSystemList.InSystem);
		if (searchStringIsEmpty) then
			matches = APIIListsSystemList.InSystem:ListAllAPI();
		else
			matches = APIIListsSystemList.InSystem:FindAllAPIMatches(searchString);
		end
	else
		if (searchStringIsEmpty) then return; end
		matches = APIDocumentation:FindAllAPIMatches(APIIListsSystemList.SearchString);
		
		if (self.includeUndocumented) then
			for k, system in ipairs(APIDocumentation.systems) do
				local result = self:GetUndocumentedFunctions(system);
				if (result) then
					for k, info in pairs(result) do
						if (searchStringIsEmpty or info.Name:lower():find(searchString)) then
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
				if (searchStringIsEmpty or info.Name:lower():find(searchString)) then
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

function APII_COREMIXIN:OnShow()
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN);
	
	if (not self.initialized) then
		self.initialized = true;
		if (not APIDocumentation) then
			--C_AddOns.LoadAddOn("Blizzard_APIDocumentationGenerated");
		end

		HybridScrollFrame_CreateButtons(APIIListsSystemList, "APII_ListSystemTemplate", 1, 0);
		-- Change valueStep to allow for more accurate scroll when jumping to api
		APIIListsSystemListScrollBar:SetValueStep(1);
		HybridScrollFrame_Update(APIIListsSystemList, #APIDocumentation.systems * LISTITEM_HEIGHT, APIIListsSystemList:GetHeight());
		APIIListsSystemListScrollBar.doNotHide = true;
		APIIListsSystemListScrollBar:Show();

		for k, v in ipairs(APIDocumentation.events) do
			APII.eventArgLookup[v.LiteralName] = v.Payload
		end
	end
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

function APII_COREMIXIN:OnUpdate()
	if (self.textInputTimer > 0) then
		local diff = GetTimePreciseSec() - self.textInputTimer;
		if (diff > TEXT_IMPUT_SEARCH_DELAY and not APIILists.searchBox.holdingDownKey) then
			self.textInputTimer = 0;
			self:SearchTrigger(APIILists.searchBox, true);
		end
	end
end

function APII_COREMIXIN:Search_OnTextChanged(searchBox, userInput)
	-- Make 'Search' text disappear when needed
	SearchBoxTemplate_OnTextChanged(searchBox);
	if(userInput) then
		self.textInputTimer = GetTimePreciseSec();
	else
		self.textInputTimer = 0;
		self:SearchTrigger(searchBox, userInput);
	end
end

function APII_COREMIXIN:SearchTrigger(searchBox, userInput)
	local searchString = searchBox:GetText();
	APIIListsSystemList.SearchString = searchString;
	-- protect against malformed pattern
	if (not pcall(function() searchString:match(searchString) end)) then 
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
	end
	APIILists:AdjustSelection();
	
	local enableSearchBoxes = #searchString > 0;
	APIILists.buttonFunctions:SetEnabled(enableSearchBoxes);
	APIILists.buttonTables:SetEnabled(enableSearchBoxes);
	APIILists.buttonFrames:SetEnabled(enableSearchBoxes);
	APIILists.buttonStrings:SetEnabled(enableSearchBoxes);
	APIILists.ButtonValues:SetEnabled(enableSearchBoxes);
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
-- UpdateEventTraceTooltip()
-- OnInitialize()
-- OnEnable()

-- Replace evetrace args index with descriptive text from API
function APII:UpdateEventTraceTooltip()
	-- Prevent endless loop
	if (EventTraceTooltip.APIIHandling) then
		EventTraceTooltip.APIIHandling = nil;
		return;
	end
	
	local line = _G["EventTraceTooltipTextLeft1"];
	local eventName = line:GetText();
	if (not eventName) then
		EventTraceTooltip.APIIHandling = nil;
		return;
	end
	
	-- No arguments, don't do anything
	local args = self.eventArgLookup[eventName];
	if (not args) then
		EventTraceTooltip.APIIHandling = nil;
		return;
	end
	
	EventTraceTooltip.APIIHandling = true;

	local lineIndex = 2;
	line = _G["EventTraceTooltipTextLeft"..lineIndex];
	while (line) do
		local leftText = line:GetText();
		if (not leftText) then break; end
		local argIndex = tonumber(leftText:match(ARGUMENT_LABEL_FORMAT));
		
		if (argIndex and args[argIndex]) then 
			line:SetText(ARGUMENT_LABEL_FORMAT_NEW:format(argIndex, args[argIndex].Name));
		end

		lineIndex = lineIndex + 1;
		line = _G["EventTraceTooltipTextLeft"..lineIndex];
	end

	EventTraceTooltip.APIIHandling = nil;
	
	EventTraceTooltip:Show();
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

	APII.openedSystem = nil;
	APII.openedAPIs = {};
end

function APII:OnEnable()
	APIIListsSystemList.update = function() 
				APIILists:UpdateSystemList(true);
		end;
	APIIListsSystemList.SearchString = "";
	APIIListsSystemList.SearchResults = {};
	APIIListsSystemList.undocumented = {};
	APIIListsSystemList.Opened = nil;
	APIILists:UpdateSystemList();
	
	self.eventArgLookup = {};

	ShowUIPanel(APII_Frame);
end


----------
-- Events
----------

-- APII.events = CreateFrame("FRAME", "APII_EventFrame"); 
-- APII.events:RegisterEvent("PLAYER_REGEN_DISABLED");
-- APII.events:RegisterEvent("PLAYER_REGEN_ENABLED");
-- APII.events:RegisterEvent("ADDON_LOADED");
-- APII.events:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)

-- function APII.events:ADDON_LOADED(addonName)
-- 	if (addonName == "Blizzard_EventTrace") then
-- 		EventTraceTooltip:HookScript("OnShow", function() APII:UpdateEventTraceTooltip() end);
-- 	end
-- end

-- function APII.events:PLAYER_REGEN_DISABLED(loaded_addon)
-- 	HideUIPanel(APII_Core);
-- end

-- function APII.events:PLAYER_REGEN_ENABLED(loaded_addon)
-- 	if APII.openDuringCombat then
-- 		ShowUIPanel(APII_Core);
-- 		APII.openDuringCombat = false;
-- 	end
-- end

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

		ShowUIPanel(APII_Frame);

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





local APII_COMMENT_COLOR = LIGHTGRAY_FONT_COLOR;
local APII_SYSTEM_SOURCE_COLOR = LIGHTGRAY_FONT_COLOR;
local APII_NO_PUBLIC_COLOR = RED_FONT_COLOR;
local APII_MIXIN_COLOR = BATTLENET_FONT_COLOR;




APII_SearchboxMixin = CreateFromMixins(CallbackRegistryMixin);

APII_SearchboxMixin:GenerateCallbackEvents(
	{
		"OnTextChanged";
	}
);

function APII_SearchboxMixin:OnLoad()
	CallbackRegistryMixin.OnLoad(self);
	SearchBoxTemplate_OnLoad(self);
end

function APII_SearchboxMixin:OnTextChanged(userInput)
	SearchBoxTemplate_OnTextChanged(self);
	self:TriggerEvent(APII_SearchboxMixin.Event.OnTextChanged, self:GetText(), userInput);
end






local function AlterOfficialDocumentation()
	APII_ValueAPIMixin = CreateFromMixins(BaseAPIMixin);

	function APII_ValueAPIMixin:GetParentName()
		if self.Table then
			return self.Table:GetName();
		end
		return "";
	end

	function APII_ValueAPIMixin:GetType()
		return "value";
	end

	function APII_ValueAPIMixin:GetLinkHexColor()
		return "ffdd55";
	end

	function APII_ValueAPIMixin:MatchesSearchString(searchString)
		if self:GetLoweredName():match(searchString) then
			return true;
		end

		if self:MatchesAnyDocumentation(searchString) then
			return true;
		end

		return false;
	end

	function APII_ValueAPIMixin:GetSingleOutputLine()
		local valueString = "";
		if (self.Type == "string" or self.Type == "number" or self.Type == "boolean") then
			valueString = string.format("%s (%s)", tostring(self.Value), self.Type);
		else
			-- This data makes no sense, so just get the value from the constant itself;

			local constant = Constants[self:GetParentName()];
			if (constant) then
				local value = constant[self:GetName()];
				
				local typeApi = APIDocumentation:FindAPIByName("table", self.Type);
				print(constant, self:GetName(), typeApi);
				valueString = string.format("%s (%s)", value, typeApi and typeApi:GenerateAPILink() or self.Type);
			end
			

			-- local enum = Enum[self.Type];
			-- if (enum) then
			-- 	local enumValue = enum[self.Value];
			-- 	print(self.Type, self.Value, enumValue)
			-- end
			
		end
		
		return string.format("%s %s", self:GenerateAPILink(), valueString);
	end



	local function ReplacerMatchFunc(self, searchString)
		local succes = self:originalMatchesSearchString(searchString);
		if (succes) then return true; end

		if (self:MatchesAnyAPI(self.Values, searchString)) then
			return true
		end

		return false;
	end



	if (not APIDocumentation.values) then
		for k, tableApi in ipairs(APIDocumentation.tables) do
			if (tableApi.Values) then
				for i, value in ipairs(tableApi.Values) do
					value.Table = tableApi;

					Mixin(value, APII_ValueAPIMixin);
					if (not APIDocumentation.apiiValues) then
						APIDocumentation.apiiValues = {};
					end
					table.insert(APIDocumentation.apiiValues, value);
				end

				tableApi.originalMatchesSearchString = tableApi.MatchesSearchString;
				tableApi.MatchesSearchString = ReplacerMatchFunc;
			end
		end
	end

	local noSystemContent = CreateFromMixins(SystemsAPIMixin);
	noSystemContent.isFake = true;
	noSystemContent.Name = "Systemless";
	noSystemContent.Type = "System";

	local tableKeys = {
		"Functions",
		"Events",
		"Tables",
		"Callbacks",
	}

	for _, tableKey in ipairs(tableKeys) do
		local lowerKey = tableKey:lower();
		local docTable = APIDocumentation[lowerKey];
		if (docTable) then
			local systemTable = noSystemContent[tableKey];
			for _, api in ipairs(docTable) do
				if (not api.System) then
					api.System = noSystemContent;
					if (not systemTable) then
						systemTable = {};
						noSystemContent[tableKey] = systemTable;
					end
					tinsert(systemTable, api);
				end
			end
			if (systemTable) then
				table.sort(systemTable, function(a, b)
					if (a.Type ~= b.Type) then
						return a.Type < b.Type;
					end
					return a.Name < b.Name;
				end);
			end
		end
	end



	-- for k, info in ipairs(APIDocumentation.events) do
	-- 	if (not info.System) then
	-- 		print(info.Name);
	-- 		tinsert(noSystemContent.events, info);
	-- 	end
	-- end

	-- for k, info in ipairs(APIDocumentation.tables) do
	-- 	if (not info.System) then
	-- 		print(info.Name);
	-- 		tinsert(noSystemContent.tables, info);
	-- 	end
	-- end

	-- for k, info in ipairs(APIDocumentation.callbacks) do
	-- 	if (not info.System) then
	-- 		print(info.Name);
	-- 		tinsert(noSystemContent.callbacks, info);
	-- 	end
	-- end

	tinsert(APIDocumentation.systems, 1, noSystemContent);
end



local activeSize = 1;

local fontTest = {
	[1] = {
		["normal"] = "GameFontHighlight";
		["big"] = "GameFontHighlightMedium";
	};
	[2] = {
		["normal"] = "GameFontHighlightMedium";
		["big"] = "GameFontHighlightLarge";
	};
}

local function GetFont(size)
	return fontTest[activeSize][size];
end


APII_TextAreaMixin = {};

function APII_TextAreaMixin:GetEditBox()
	return self.EditBox;
end

function APII_TextAreaMixin:GetHtml()
	return self.Html;
end

function APII_TextAreaMixin:GetFontString()
	return self.Text;
end

function APII_TextAreaMixin:SetHyperlinkingEnabled(enable)
	local html = self:GetHtml();
	html:SetShown(enable);

	local editBox = self:GetEditBox();
	editBox:ClearFocus();
	editBox:ClearHighlightText();
	editBox:SetShown(not enable);
end

function APII_TextAreaMixin:SetAvailableWidth(width)
	local editBox = self:GetEditBox();
	local html = self:GetHtml();
	local fonsString = self:GetFontString();

	self:SetWidth(width);
	editBox:SetWidth(width);
	html:SetWidth(width);
	fonsString:SetWidth(width);
end

function APII_TextAreaMixin:SetText(text, font)
	local editBox = self:GetEditBox();
	local html = self:GetHtml();
	local fonsString = self:GetFontString();

	editBox:SetText(text);
	editBox:SetFontObject(font);
	editBox.originalText = text;

	html:SetHyperlinksEnabled(true);
	html:SetText(text);
	html:SetFontObject("p", font);

	fonsString:SetFontObject(font);
	-- Set absurd height to ensure correct string height
	-- This needs to be *really* absurd because some enums have *a lot* of values like Enum.PlayerInteractionType
	fonsString:SetHeight(3000);
	fonsString:SetText(text);
	local height = self.Text:GetStringHeight();
	fonsString:SetHeight(height);

	self:SetHeight(height);
end


APII_TextBlockMixin = {};

function APII_TextBlockMixin:OnLoad()
	-- self.Html:SetIndentedWordWrap("p", true);
	-- self.EditBox:SetIndentedWordWrap(true);
	-- self.Text:SetIndentedWordWrap(true);
end

function APII_TextBlockMixin:OnHyperlinkClick(...)
	self:GetParent():OnHyperlinkClick(...);
end

function APII_TextBlockMixin:GetTextArea()
	return self.TextArea;
end

function APII_TextBlockMixin:SetHyperlinkingEnabled(enable)
	self:GetTextArea():SetHyperlinkingEnabled(enable);
end

function APII_TextBlockMixin:GetPadding()
	if (not self.blockData) then
		return 0, 0, 0, 0;
	end
	return (self.blockData.leftPadding or 0)
			,(self.blockData.rightPadding or 0)
			,(self.blockData.topPadding or 0)
			,(self.blockData.bottomPadding or 0)
end

function APII_TextBlockMixin:Initialize(blockData)
	self.blockData = blockData;

	local basicString = blockData.textString;
	local leftPadding, rightPadding, topPadding, bottomPadding = self:GetPadding();
	local width = self:GetWidth() - leftPadding - rightPadding;

	local textArea = self:GetTextArea();
	textArea:SetPoint("TOPLEFT", leftPadding, -topPadding);
	textArea:SetAvailableWidth(width);
	textArea:SetText(basicString, blockData.font);

	local totalHeight = textArea:GetHeight() + topPadding + bottomPadding;
	self:SetHeight(totalHeight);
end

APII_TextBlockCopyStringMixin = CreateFromMixins(APII_TextBlockMixin);

local COPY_STRING_PADDING = 10;

function APII_TextBlockCopyStringMixin:Initialize(blockData)
	self.blockData = blockData;

	local basicString = blockData.textString;
	local leftPadding, rightPadding, topPadding, bottomPadding = self:GetPadding();
	local width = self:GetWidth() - leftPadding - rightPadding;
	local textAreaWidth = width - COPY_STRING_PADDING * 2;

	local textArea = self:GetTextArea()
	textArea:SetPoint("TOPLEFT", leftPadding + COPY_STRING_PADDING, -topPadding - COPY_STRING_PADDING);
	textArea:SetAvailableWidth(textAreaWidth);
	textArea:SetText(basicString, blockData.font);

	self.Background:SetPoint("TOPLEFT", leftPadding, -topPadding);
	self.Background:SetWidth(width);
	self.Background:SetHeight(textArea:GetHeight() + COPY_STRING_PADDING * 2);

	local totalHeight = textArea:GetHeight() + topPadding + bottomPadding + COPY_STRING_PADDING * 2;
	self:SetHeight(totalHeight);
end



APII_SystemButtonMixin = {};

function APII_SystemButtonMixin:Initialize(data)
	self.data = data;
	self.Name:SetText(data.Name);
	self.Namespace:SetText(data.Namespace);
	self.Namespace:SetTextColor(DISABLED_FONT_COLOR:GetRGB());
end

function APII_SystemButtonMixin:OnClick()
	
	if (not self.parentFrame or not self.data) then return; end

	self.parentFrame:OpenSystem(self.data);
end



local function CreateFieldString(field)
	local text = ("%s - %s"):format(field:GenerateAPILink(), field:GetLuaType());
	if (field.Mixin) then
		local mixinString = string.format(" (|Hapi:mixin:%s|h%s|h)", field.Mixin, field.Mixin);
		text = text .. APII_MIXIN_COLOR:WrapTextInColorCode(mixinString);
	end
	if (field:IsOptional()) then
		if (field.Default ~= nil) then
			text = ("%s (default:%s)"):format(text, tostring(field.Default));
		else
			text = text .. APII_COMMENT_COLOR:WrapTextInColorCode(" (optional)");
		end
	end
	if (field.Documentation) then
		local documentationString = table.concat(field.Documentation, " ");
		documentationString = APII_COMMENT_COLOR:WrapTextInColorCode(documentationString);
		text = ("%s  %s"):format(text, documentationString);
	end
	return text;
end

APII_ContentBlockDataManagerMixin = {};

local LEFT_PADDING_DEFAULT = 40;
local LEFT_PADDING_INDENTED = 50;
local LEFT_PADDING_COPYSTRING = 38;
local RIGHT_PADDING_DEFAULT = 40;
local BOTTOM_PADDING_DEFAULT = 14;
local BOTTOM_PADDING_TITLE = 6;

function APII_ContentBlockDataManagerMixin:Init(apiInfo)
	print("datamanager", apiInfo)
	self.dataBlocks = {};

	local isConstant = apiInfo.Type == "Constants";

	do
		local text = "Not part of a system";
		if (apiInfo.System and not apiInfo.System.isFake) then
			text = string.format("Part of the %s system", apiInfo.System:GenerateAPILink());
		end
		self:AddBasicBlock(APII_SYSTEM_SOURCE_COLOR:WrapTextInColorCode(text));
	end

	do
		local clipboardString = apiInfo.LiteralName and apiInfo.LiteralName or apiInfo:GetClipboardString();

		if (isConstant) then
			clipboardString = "Constants." .. clipboardString;
		end

		self:AddCopyStringBlock(clipboardString);
	end

	local dataType = apiInfo:GetType();
	if (dataType == "function") then
		self:AddFunctionArguments("Arguments", apiInfo.Arguments);
		self:AddFunctionArguments("Returns", apiInfo.Returns);

	elseif (dataType == "table" and (apiInfo.Fields or apiInfo.Values)) then
		if (apiInfo.Fields and #apiInfo.Fields > 0) then
			local titleText = "Fields";
			if (apiInfo.Type == "Enumeration") then
				local lines = {};
				tinsert(lines, "Num Values: " .. apiInfo.NumValues);
				tinsert(lines, "Min Value: " .. apiInfo.MinValue);
				tinsert(lines, "Max Value: " .. apiInfo.MaxValue);
				local content = table.concat(lines, "|n");
				self:AddIndentedBlock(content);

				titleText = "Values";
			end
			self:AddTitleBlock(titleText);

			local lines = {};
			if (apiInfo.Fields) then
				for i, fieldInfo in ipairs(apiInfo.Fields) do
					local text = (apiInfo.Type == "Enumeration") and fieldInfo:GetSingleOutputLine() or
					CreateFieldString(fieldInfo);
					tinsert(lines, text);
				end
			end
			local content = table.concat(lines, "|n");
			self:AddIndentedBlock(content);
		end

		if (apiInfo.Values and #apiInfo.Values > 0) then
			self:AddTitleBlock("Values");

			local lines = {};
			if (apiInfo.Values) then

				for i, valueInfo in ipairs(apiInfo.Values) do
					local text = valueInfo:GetSingleOutputLine()
					tinsert(lines, text);
				end
			end
			local content = table.concat(lines, "|n");
			self:AddIndentedBlock(content);
		end

	elseif (dataType == "event" and apiInfo.Payload) then
		self:AddTitleBlock("Payload");
		local lines = {};
		for i, payloadInfo in ipairs(apiInfo.Payload) do
			local text = ("%d. %s"):format(i, CreateFieldString(payloadInfo));
			tinsert(lines, text);
		end
		local content = table.concat(lines, "|n");
		self:AddIndentedBlock(content);
	end

	if (apiInfo.Documentation) then
		self:AddTitleBlock("Notes");
		local lines = {};
		for i, documentation in ipairs(apiInfo.Documentation) do
			if (documentation == DETAILS_NO_PUBLIC) then
				documentation = APII_NO_PUBLIC_COLOR:WrapTextInColorCode(documentation);
			end
			tinsert(lines, documentation);
		end
		local content = table.concat(lines, "|n");
		self:AddIndentedBlock(content);
	end
end

function APII_ContentBlockDataManagerMixin:EnumerateData()
	return ipairs(self.dataBlocks);
end

function APII_ContentBlockDataManagerMixin:AddBasicBlock(text, font)
	local block = {};
	block.template = "APII_TextBlockTemplate";
	block.textString = text;
	block.font = font or GetFont("normal") -- "GameFontHighlight";
	block.leftPadding = LEFT_PADDING_DEFAULT;
	block.rightPadding = RIGHT_PADDING_DEFAULT;
	block.bottomPadding = BOTTOM_PADDING_DEFAULT;
	tinsert(self.dataBlocks, block);
	return block;
end

function APII_ContentBlockDataManagerMixin:AddIndentedBlock(text)
	local block = self:AddBasicBlock(text);
	block.leftPadding = LEFT_PADDING_INDENTED;
	return block;
end

function APII_ContentBlockDataManagerMixin:AddTitleBlock(text)
	local block = self:AddBasicBlock(text, GetFont("big")) -- "GameFontHighlightMedium");
	block.bottomPadding = BOTTOM_PADDING_TITLE;
	return block;
end

function APII_ContentBlockDataManagerMixin:AddCopyStringBlock(text)
	local block = self:AddBasicBlock(text);
	block.template = "APII_TextBlockCopyStringTemplate";
	block.leftPadding = LEFT_PADDING_COPYSTRING;
	return block;
end

function APII_ContentBlockDataManagerMixin:AddFunctionArguments(label, argumentTable)
	if (argumentTable) then
		self:AddTitleBlock(label);

		local lines = {};
		for i, argumentInfo in ipairs(argumentTable) do
			if (argumentInfo:GetStrideIndex() == 1) then
				local strideLine = "(Variable arguments)";
				table.insert(lines, strideLine);
			end
			local text = ("%d. %s"):format(i, CreateFieldString(argumentInfo));
			table.insert(lines, text);
		end

		local content = table.concat(lines, "|n");
		self:AddIndentedBlock(content);
	end
end


APII_ContentBlockManagerMixin = {};

function APII_ContentBlockManagerMixin:Init(ownerFrame, contentBlockFactory)
	self.ownerFrame = ownerFrame;
	self.contentBlockFactory = contentBlockFactory;
	self.activeBlocks = {};
	self.reusableBlocks = {};
end

function APII_ContentBlockManagerMixin:MakeBlocksActiveReusable()
	local temp = self.reusableBlocks;
	self.reusableBlocks = self.activeBlocks;
	self.activeBlocks = temp;
end

function APII_ContentBlockManagerMixin:GetBlockOfType(frameTemplate)
	if (not self.ownerFrame or not self.contentBlockFactory) then return; end

	local block = nil;
	local reusableBlocks = self.reusableBlocks[frameTemplate];
	if (reusableBlocks and #reusableBlocks > 0) then
		block = reusableBlocks[1];
		block:ClearAllPoints();
		tremove(reusableBlocks, 1);
	end

	if (not block) then
		block = self.contentBlockFactory:Create(self.ownerFrame, frameTemplate);
	end

	local activeBlocks = self.activeBlocks[frameTemplate];
	if (not activeBlocks) then
		activeBlocks = {};
		self.activeBlocks[frameTemplate] = activeBlocks;
	end
	tinsert(activeBlocks, block);

	return block;
end

function APII_ContentBlockManagerMixin:ReleaseReusable()
	if (not self.ownerFrame or not self.contentBlockFactory) then return; end

	for template, templateBlocks in pairs(self.reusableBlocks) do
		for k, block in ipairs(templateBlocks) do
			self.contentBlockFactory:Release(block);
		end
		wipe(templateBlocks);
	end
end

function APII_ContentBlockManagerMixin:DoForEveryActiveBlock(func, ...)
	if (type(func) ~= "function") then return; end
	
	for template, templateBlocks in pairs(self.activeBlocks) do
		for k, block in ipairs(templateBlocks) do
			func(block, ...);
		end
	end
end



APII_SystemContentMixin = CreateFromMixins(CallbackRegistryMixin);

APII_SystemContentMixin:GenerateCallbackEvents(
	{
		"ExpandToggled";
		"OnHyperlinkClick";
	}
);

function APII_SystemContentMixin:OnClick()
	self:TriggerEvent(APII_SystemContentMixin.Event.ExpandToggled, self.data);
end

function APII_SystemContentMixin:OnHyperlinkClick(link, text, button)
	self:TriggerEvent(APII_SystemContentMixin.Event.OnHyperlinkClick, link);
end

do
	local function SetBlockHyperlinkingEnabled(block, enable)
		block:SetHyperlinkingEnabled(enable);
	end

	function APII_SystemContentMixin:SetHyperlinkingEnabled(enable)
		if (not self.contentBlockManager) then return; end

		self.contentBlockManager:DoForEveryActiveBlock(SetBlockHyperlinkingEnabled, enable);
	end
end

function APII_SystemContentMixin:Initialize(data, contentBlockFactory, expanded)
	self.data = data;
	local apiInfo = data;
	local totalHeight = 0;

	if (not self.contentBlockManager) then
		self.contentBlockManager = CreateAndInitFromMixin(APII_ContentBlockManagerMixin, self, contentBlockFactory);
	end

	self.TitleButton.Label:SetText(data:GetSingleOutputLine());
	self.TitleButton.BGRight:SetAtlas(expanded and "Options_ListExpand_Right_Expanded" or "Options_ListExpand_Right");

	totalHeight = totalHeight + self.TitleButton:GetHeight();

	self.contentBlockManager:MakeBlocksActiveReusable();


	local function GetOrCreateContentBlock(frameTemplate)
		return self.contentBlockManager:GetBlockOfType(frameTemplate);
	end

	self.ClipboardString:Hide();
	self.EditBox:Hide();
	self.Html:Hide();

	if (expanded) then
		if (not apiInfo.apiiData) then
			apiInfo.apiiData = CreateAndInitFromMixin(APII_ContentBlockDataManagerMixin, apiInfo);
		end
		local anchor = self.TitleButton;
		local yOffset = 8;
		totalHeight = totalHeight + yOffset;

		if (apiInfo.apiiData) then
			local frameWidth = floor(self:GetWidth());
			for k, blockData in apiInfo.apiiData:EnumerateData() do
				local block = GetOrCreateContentBlock(blockData.template);
				if (block) then
					block:SetParent(self);
					block:SetPoint("TOP", anchor, "BOTTOM", 0, -yOffset);
					block:SetPoint("LEFT", self);
					block:SetWidth(frameWidth)
					block:Initialize(blockData);
					block:Show();
					totalHeight = totalHeight + block:GetHeight();
					anchor = block;
				end

				yOffset = 0;
			end
		end
	else
		self.ClipboardString:Hide();
		self.EditBox:Hide();
		self.Html:Hide();
	end

	self.contentBlockManager:ReleaseReusable();
	self:SetHeight(totalHeight);
end


APII_CoreMixin = {};

function APII_CoreMixin:OnDragStop()
	if (not self.SystemContentScrollBox:GetView()) then return; end

	self:UpdateSystemContent()

	--self.SystemContentScrollBox


	-- local newWidth = self.SystemContentScrollBox:GetWidth();
	-- for k, frame in self.SystemContentScrollBox:EnumerateFrames() do
	-- 	frame:SetFixedWidth(newWidth);
	-- end

	-- local numChildren = self.SystemContentScrollBox:GetNumChildren()
end

function APII_CoreMixin:OnLoad()
	self.debug = APII;

	


	ButtonFrameTemplate_HidePortrait(self)
	self:SetClampedToScreen(true);
	self:SetTitle("APIInterface");
	self:SetResizeBounds(250, 200);

	self.Bg:SetPoint("BOTTOMRIGHT", self, -2, 3);

	self.contentBlockFactory = CreateFrameFactory();

	do
		local view = CreateScrollBoxListLinearView();
		view:SetElementInitializer("APII_SystemButtonTemplate", function(frame, data)
			frame.parentFrame = self;
			frame:Initialize(data);
			
		end);
		ScrollUtil.InitScrollBoxListWithScrollBar(self.SystemScrollBox, self.SystemScrollBar, view);
	end

	do
		local padding = 0;
		local spacing = 0;
		local view = CreateScrollBoxListLinearView(padding, padding, padding, padding, spacing);

		local function ToggleAPI(_, api)
			if (APII.openedAPIs[api]) then
				APII.openedAPIs[api] = nil;
			else
				APII.openedAPIs[api] = true;
			end
			--self:UpdateSystemContent();
			--self.SystemContentScrollBox:Rebuild();
			self.SystemContentScrollBox:SetDataProvider(self.SystemContentScrollBox:GetDataProvider(), ScrollBoxConstants.RetainScrollPosition);
		end

		local function OnHyperlinkClick(_, link)
			local apiType, name, system = link:match("api:(%a+):(%a+):(%a*):?") ;
			local apiInfo = APIDocumentation:FindAPIByName(apiType, name, system);
			print("here", apiType, name, system, apiInfo);

			SearchBoxTemplate_ClearText(self.TopBar.GeneralSearch);
			SearchBoxTemplate_ClearText(self.SystemSearch);

			if (apiInfo) then
				local systemToOpen = nil;
				local apiToShow = nil;
				if (apiInfo:GetType() == "system") then
					systemToOpen = apiInfo;
				else
					if (apiInfo.System) then
						systemToOpen = apiInfo.System;
						apiToShow = apiInfo;
						APII.openedAPIs[apiInfo] = true;
					end
				end

				if(systemToOpen and APII.openedSystem ~= systemToOpen) then
					APII.openedSystem = systemToOpen;
					self:UpdateSystemContent("", true);
				end

				if (apiToShow) then
					self.SystemContentScrollBox:SetDataProvider(self.SystemContentScrollBox:GetDataProvider(), ScrollBoxConstants.RetainScrollPosition);
					self.SystemContentScrollBox:ScrollToElementData(apiToShow);
				end
			end
			
			

		end

		view:SetElementInitializer("APII_SystemContentTemplate", function(frame, data)
			frame:RegisterCallback(APII_SystemContentMixin.Event.ExpandToggled, ToggleAPI, self);
			frame:RegisterCallback(APII_SystemContentMixin.Event.OnHyperlinkClick, OnHyperlinkClick, self);
			frame:Initialize(data, self.contentBlockFactory, APII.openedAPIs[data]);
		end);
		view:SetElementResetter(function(frame, data)
			frame:UnregisterCallback(APII_SystemContentMixin.Event.ExpandToggled, self);
			frame:UnregisterCallback(APII_SystemContentMixin.Event.OnHyperlinkClick, self);
		end);
		view:SetElementExtentCalculator(function (index, data)
			local dummy = self.SystemContentScrollBox.ContentDummy;
			dummy:Initialize(data, self.contentBlockFactory, APII.openedAPIs[data]);
			return dummy:GetHeight();
		end);
		-- view:SetElementFactory(function(factory, elementData)
		-- 	factory("APII_SystemContentTemplate", function(frame, data)
		-- 		frame.parentFrame = self;
		-- 		frame:Initialize(data);
		-- 	end);
		-- end);

		ScrollUtil.InitScrollBoxListWithScrollBar(self.SystemContentScrollBox, self.SystemContentScrollBar, view);

	end

	self.SystemSearch:RegisterCallback(APII_SearchboxMixin.Event.OnTextChanged, function(_, text, userInput)
		if (not userInput) then return; end
		self:UpdateSystemsList(text);
	 end, self);
	self.TopBar.GeneralSearch:RegisterCallback(APII_SearchboxMixin.Event.OnTextChanged, function(_, text, userInput)
		if (not userInput) then return; end
		APII.openedSystem = nil;
		self:UpdateSystemsList(text);
		self:UpdateSystemContent(text);
		print(text, userInput) end
		, self);
	


	-- This has to be last
	local minWidth = 700;
	local minHeight = 450;
	local maxWidth, maxHeight = GetPhysicalScreenSize();
	self.ResizeButton:Init(self, minWidth, minHeight, maxWidth, maxHeight);
	self.ResizeButton:SetOnResizeStoppedCallback(function() self:OnDragStop() end)

	self.g = true;

end

function APII_CoreMixin:OnUpdate()
	if (self.shiftDown ~= IsShiftKeyDown()) then
		self.shiftDown = IsShiftKeyDown();

		for k, frame in self.SystemContentScrollBox:EnumerateFrames() do
			frame:SetHyperlinkingEnabled(self.shiftDown);
		end
		--print("Shift", self.shiftDown)
	end
end

function APII_CoreMixin:OnShow()
	if (not self.initialized) then
		self.initialized = true;
		if (not APIDocumentation) then
			C_AddOns.LoadAddOn("Blizzard_APIDocumentationGenerated");
		end

		AlterOfficialDocumentation();
	end



	


	

	self:UpdateSystemsList();
end

function APII_CoreMixin:UpdateSystemsList(searchString)
	local dataProvider = CreateDataProvider();

	local systemList = APIDocumentation.systems;
	if (searchString and #searchString > 0) then
		systemList = {};
		APIDocumentation:AddAllMatches(APIDocumentation.systems, systemList, searchString);
	end

	for k, system in ipairs(systemList) do
		dataProvider:Insert(system);
	end

	self.SystemScrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition);
end

function APII_CoreMixin:OpenSystem(system)
	APII.openedSystem = system;
	wipe(APII.openedAPIs);

	if (not system) then return; end

	self:UpdateSystemContent();
end

function APII_CoreMixin:OnSizeChanged()
	--self:UpdateSystemContent();
end

function APII_CoreMixin:UpdateSystemContent(searchString, resetPosition)
	if (not self.g) then return; end

	local dataProvider = CreateDataProvider();

	local apiMatches = nil;
	if (APII.openedSystem) then
		
		if (searchString and #searchString > 0) then
			apiMatches = APII.openedSystem:FindAllAPIMatches(searchString);
		else
			apiMatches = APII.openedSystem:ListAllAPI();
		end
		
		--apiMatches = APIDocumentation:FindAllAPIMatches("quest");
		print("- - - -")
		print(apiMatches, apiMatches and #apiMatches or "");
	else
		if (searchString and #searchString > 0) then
			apiMatches = APIDocumentation:FindAllAPIMatches(searchString);
		end
	end

	if (apiMatches) then
			for k, info in ipairs(apiMatches.functions) do
				dataProvider:Insert(info);
			end

			for k, info in ipairs(apiMatches.events) do
				dataProvider:Insert(info);
			end

			for k, info in ipairs(apiMatches.tables) do
				dataProvider:Insert(info);
			end
		end

	self.SystemContentScrollBox:SetDataProvider(dataProvider, resetPosition and ScrollBoxConstants.DiscardScrollPosition or ScrollBoxConstants.RetainScrollPosition);
end

function APII_CoreMixin:CloseAllAPI()
	wipe(APII.openedAPIs);
end
