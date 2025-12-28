
local _addonName, _addon = ...;

APII = LibStub("AceAddon-3.0"):NewAddon(_addonName);

local HISTORY_MAX = 50;
local LISTITEM_HEIGHT = 34;
local LISTITEM_EXPAND_MARGIN = 52;
local SEARCH_CUTOFF_AMOUNT = 1000;
local TEXT_IMPUT_SEARCH_DELAY = 0.3;
local FORMAT_SEARCH_CUTOFF_CHANGED = "Search cutoff changed to %d for this session.";
local FORMAT_SEARCH_CUTOFF = "Searched stopped after %d results."
local FORMAT_NO_RESULTS = "No \"%s\" found in _G matching \"%s\"."
local FORMAT_RESULTS_TITLE = "%d \"%s\" matching \"%s\"";
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



local function MatchContainsFunction(list, entry)
	for k, v in pairs(list) do
		if (v.Name == entry) then return true end;
	end
	return false;
end

local function AddonPrint(...)
	print("APII:", ...);
end


local GlobalSearchTypes = EnumUtil.MakeEnum("Functions", "Tables", "Frames", "Strings", "Values");
local GlobalSearchTypesTranslation = EnumUtil.GenerateNameTranslation(GlobalSearchTypes)

local function IsSearchMatch(key, value, search, objType, wantFrames)
	if type(key) ~= "string" then return false; end
	if (objType == "value") then
		return key:lower():find(search:lower()) and (type(value) == "number" or type(value) == "boolean");
	else
		if (type(value) ~= objType) then return false; end
	end
	if objType.GetDebugName and objType:IsProtected() then return false; end
	if (objType == "table") then
		if wantFrames then
			return value.GetDebugName ~= nil and key:lower():find(search:lower());
		end
		return value.GetDebugName == nil and key:lower():find(search:lower());
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

	self:SetEnabled(not info.isUndocumented);
	if(info.isUndocumented) then
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


local APII_FilterType = EnumUtil.MakeEnum("Function", "Event", "CallbackType", "Constants", "Enumeration", "Structure", "Undocumented");

local APII_DefaultSavedVariables = {
	global = {
		versionCheck = 1;
		filters = {};
	}
}

for filterType in pairs(APII_FilterType) do
	APII_DefaultSavedVariables.global.filters[filterType] = true;
end

local function InfoPassesFilters(apiInfo)
	if (apiInfo.isUndocumented and not APII.db.global.filters["Undocumented"]) then
		return false;
	end

	if (APII_FilterType[apiInfo.Type]) then
		return APII.db.global.filters[apiInfo.Type];
	end

	print("Type not covered:", apiInfo.Type);
	return true;
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

	self.db = LibStub("AceDB-3.0"):New("APIIDB", APII_DefaultSavedVariables, true);
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
		if (#msg > 0) then
			APII_Frame:SetGeneralSearchText(msg);
		end

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



local function dprint(...)
	if true then return; end
	print(...);
end


local APII_UNDOCUMENTED_MESSAGE = "This function is not officially documented but exists in this namespace.";
local DOCUMENTATION_TO_COLOR_RED = {
	["This function does nothing in public clients"] = true;
	["Unavailable in public builds"] = true;
	[APII_UNDOCUMENTED_MESSAGE] = true;
}


local APII_COMMENT_COLOR = LIGHTGRAY_FONT_COLOR;
local APII_SYSTEM_SOURCE_COLOR = LIGHTGRAY_FONT_COLOR;
local APII_NO_PUBLIC_COLOR = CreateColor(1, .2, .2);
local APII_MIXIN_COLOR = BATTLENET_FONT_COLOR;
local APII_NAMESPACE_COLOR = DISABLED_FONT_COLOR;

APII_VerticalLayoutMixin = {};

function APII_VerticalLayoutMixin:OnLoad()
	self.children = { self:GetChildren() };

	for k, child in ipairs(self.children) do
		child:HookScript("OnShow", function() self:ReAnchorChildren() end);
		child:HookScript("OnHide", function() self:ReAnchorChildren() end);
	end
end

do
	local function GetChildPadding(child)
		return child.leftPadding or 0,
			child.rightPadding or 0,
			child.topPadding or 0,
			child.bottomPadding or 0;
	end

	function APII_VerticalLayoutMixin:ReAnchorChildren()
		local visibleChildren = {};
		for k, child in ipairs(self.children) do
			child:ClearAllPoints();
			if (child:IsVisible()) then
				tinsert(visibleChildren, child);
			end
		end

		local anchor = nil;
		for k, child in ipairs(visibleChildren) do
			local lPadding, rPadding, tPadding, bPadding = GetChildPadding(child);
			child:SetPoint("LEFT", self, lPadding, 0);
			child:SetPoint("RIGHT", self, -rPadding, 0);
			if (anchor) then
				child:SetPoint("TOP", anchor, "BOTTOM", 0, -tPadding);
			else
				child:SetPoint("TOP", self, 0, -tPadding);
			end
			
			anchor = child;

			if (k == #visibleChildren) then
				child:SetPoint("BOTTOM", self, 0, bPadding);
			end
		end
	end
end


APII_SearchboxMixin = CreateFromMixins(CallbackRegistryMixin);

APII_SearchboxMixin:GenerateCallbackEvents(
	{
		"OnTextChanged";
		"OnClearButtonClicked";
		"OnEditFocusChanged";
	}
);

function APII_SearchboxMixin:OnLoad()
	CallbackRegistryMixin.OnLoad(self);
	SearchBoxTemplate_OnLoad(self);
	local function OnClearButtonClicked()
		self:TriggerEvent(APII_SearchboxMixin.Event.OnClearButtonClicked);
	end

	self.clearButton:HookScript("OnClick", OnClearButtonClicked);
end

function APII_SearchboxMixin:OnTextChanged(userInput)
	SearchBoxTemplate_OnTextChanged(self);

	local text = self:GetText();
	-- Color text on malformed patterns
	if (not pcall(function() text:match(text) end)) then
		self:SetTextColor(RED_FONT_COLOR:GetRGB());
		return;
	else
		self:SetTextColor(WHITE_FONT_COLOR:GetRGB());
	end

	self:TriggerEvent(APII_SearchboxMixin.Event.OnTextChanged, self:GetText(), userInput);
end

function APII_SearchboxMixin:OnEditFocusGained()
	self:TriggerEvent(APII_SearchboxMixin.Event.OnEditFocusChanged, true);
end

function APII_SearchboxMixin:OnEditFocusLost()
	self:TriggerEvent(APII_SearchboxMixin.Event.OnEditFocusChanged, false);
end


APII_HistoryButtonMixin = CreateFromMixins(CallbackRegistryMixin);

APII_HistoryButtonMixin:GenerateCallbackEvents(
	{
		"OnClick";
	}
);

function APII_HistoryButtonMixin:OnLoad()
	WowStyle2IconButtonMixin.OnLoad(self);
	CallbackRegistryMixin.OnLoad(self);
end

function APII_HistoryButtonMixin:OnClick()
	self:TriggerEvent(APII_HistoryButtonMixin.Event.OnClick, self.delta);
end

function APII_HistoryButtonMixin:OnEnter()
	WowStyle2IconButtonMixin.OnEnter(self);
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText(self.tooltipTitle);
	GameTooltip:AddLine(self.tooltipText, 1, 1, 1, true);
	GameTooltip:Show();
end

function APII_HistoryButtonMixin:OnLeave()
	WowStyle2IconButtonMixin.OnLeave(self);
	GameTooltip:Hide();
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
				dprint(constant, self:GetName(), typeApi);
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
			if (not systemTable) then
				systemTable = {};
				noSystemContent[tableKey] = systemTable;
			end
			for _, api in ipairs(docTable) do
				if (lowerKey == "tables" and api.Type == "Constants") then
					if (not api.Documentation) then
						api.Documentation = {};
					end
					tinsert(api.Documentation, "Constants are not officially supported. This data is an attempt at parsing the existing documentation.");
				end


				if (not api.System) then
					api.System = noSystemContent;
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


	APII_UndocumentedAPIMixin = CreateFromMixins(FunctionsAPIMixin);

	function APII_UndocumentedAPIMixin:GetType()
		return "function";
	end
	
	function APII_UndocumentedAPIMixin:GetLinkHexColor()
		return "ff4444";
	end
	
	function APII_UndocumentedAPIMixin:GetSingleOutputLine()
		local text = FunctionsAPIMixin.GetSingleOutputLine(self);
		return text .. " (Undocumented)";
	end

	local function FunctionListSort(a, b)
		return a.Name < b.Name;
	end

	for systemIndex, system in ipairs(APIDocumentation.systems) do
		local global = _G[system.Namespace];
		if (global) then
			local undocumented = {};
			for name in pairs(global) do
				undocumented[name] = true;
			end
			if (system.Functions) then
				for funcIndex, func in ipairs(system.Functions) do
					undocumented[func.Name] = nil;
				end
			end

			local madeChange = false;
			--local count = 0;
			for name in pairs(undocumented) do
				
				local newAPI = CreateFromMixins(APII_UndocumentedAPIMixin);
				newAPI.isUndocumented = true;
				newAPI.Name = name;
				newAPI.Type = "Function";
				newAPI.System = system;
				newAPI.Documentation = { APII_UNDOCUMENTED_MESSAGE; };
				tinsert(system.Functions, newAPI);
				tinsert(APIDocumentation.functions, newAPI);
				madeChange = true;
				--count = count + 1;
			end

			if (madeChange) then
				table.sort(system.Functions, FunctionListSort);
				--print(system.Namespace, "->", count)
			end
		end
	end

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
	local editBox = self:GetEditBox();
	if (enable) then
		html:Show(enable);

		editBox:ClearFocus();
		editBox:ClearHighlightText();
		editBox:Hide();
	else
		-- Editbox text doesn't update until 1 frame after it is shown
		-- Text can change while inivisble when content text gets re-used by the scrollview while hyperlinking is enabled (i.e. clicking a hyperlink)
		-- Keep html visible and show editbox with 0 opacity for 1 frame before actually switching
		-- Fixing highlight color being visible for 1 frame by changing its alpha to 0;
		editBox:Show();
		editBox:SetAlpha(0);
		local r, g, b, a = editBox:GetHighlightColor();
		editBox:SetHighlightColor(r, g, b, 0);

		C_Timer.After(0, function()
			html:Hide();
			editBox:SetAlpha(1);
			editBox:SetHighlightColor(r, g, b, a);
		end);
	end
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
	local namespace = data.Namespace and APII_NAMESPACE_COLOR:WrapTextInColorCode(data.Namespace) or "";
	self.Namespace:SetText(namespace);

	self.SelectedHighlight:SetShown(APII.openedSystem == data);
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
	dprint("datamanager", apiInfo)
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
			if (DOCUMENTATION_TO_COLOR_RED[documentation]) then
				documentation = APII_NO_PUBLIC_COLOR:WrapTextInColorCode(documentation);
			end
			tinsert(lines, documentation);
		end
		local content = table.concat(lines, "|n");
		self:AddIndentedBlock(content);
	end

	-- if (dataType == "function") then
	-- 	self:AddTitleBlock("Wiki URL");
	-- 	local url = "https://warcraft.wiki.gg/wiki/API_";
	-- 	if (apiInfo.System and apiInfo.System.Namespace) then
	-- 		url = url .. apiInfo.System.Namespace .. ".";
	-- 	end
	-- 	url = url .. apiInfo.Name;
	-- 	self:AddIndentedBlock(url);
	-- end

end

function APII_ContentBlockDataManagerMixin:EnumerateData()
	return ipairs(self.dataBlocks);
end

function APII_ContentBlockDataManagerMixin:AddBasicBlock(text, font)
	local block = {};
	block.template = "APII_TextBlockTemplate";
	block.textString = text;
	block.font = font or GetFont("normal")
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
	local block = self:AddBasicBlock(text, GetFont("big"))
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
	self:TriggerEvent(APII_SystemContentMixin.Event.OnHyperlinkClick, link, self.data);
end

do
	local function SetBlockHyperlinkingEnabled(block, enable)
		block:SetHyperlinkingEnabled(enable);
	end

	function APII_SystemContentMixin:SetHyperlinkingEnabled(enable)
		if (not self.contentBlockManager) then return; end

		self.contentBlockManager:DoForEveryActiveBlock(SetBlockHyperlinkingEnabled, enable);

		self.HyperlinkGlow:SetShown(self.isExpanded and enable);
	end
end

function APII_SystemContentMixin:Initialize(data, contentBlockFactory, expanded)
	self.data = data;
	local apiInfo = data;
	local totalHeight = 0;
	self.isExpanded = expanded;

	if (not self.contentBlockManager) then
		self.contentBlockManager = CreateAndInitFromMixin(APII_ContentBlockManagerMixin, self, contentBlockFactory);
	end

	self.TitleButton.Label:SetText(data:GetSingleOutputLine());
	self.TitleButton.BGRight:SetAtlas(expanded and "Options_ListExpand_Right_Expanded" or "Options_ListExpand_Right");

	totalHeight = totalHeight + self.TitleButton:GetHeight();

	self.contentBlockManager:MakeBlocksActiveReusable();

	if (expanded) then
		if (not apiInfo.apiiData) then
			apiInfo.apiiData = CreateAndInitFromMixin(APII_ContentBlockDataManagerMixin, apiInfo);
		end
		local anchor = self.TitleButton;
		local yOffset = 10;
		local bottomPadding = 8;
		totalHeight = totalHeight + yOffset + bottomPadding;

		if (apiInfo.apiiData) then
			local frameWidth = floor(self:GetWidth());
			for k, blockData in apiInfo.apiiData:EnumerateData() do
				local block = self.contentBlockManager:GetBlockOfType(blockData.template);
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
	end

	self.contentBlockManager:ReleaseReusable();
	self:SetHeight(totalHeight);
end


APII_CoreMixin = {};

function APII_CoreMixin:GetInSystemBanner()
	return self.SystemContent.InSystemBanner;
end

function APII_CoreMixin:GetSystemContentSearch()
	return self.SystemContent.SystemContentSearch;
end

function APII_CoreMixin:GetSystemContentScrollBox()
	return self.SystemContent.SystemContentScrollBox;
end

function APII_CoreMixin:GetSystemScrollBox()
	return self.SystemContainer.SystemScrollBox;
end

function APII_CoreMixin:GetSystemSearch()
	return self.SystemContainer.SystemSearch;
end

function APII_CoreMixin:GetGeneralSearch()
	return self.TopBar.GeneralSearch;
end

function APII_CoreMixin:GetHistoryBackButton()
	return self.TopBar.HistoryBackButton;
end

function APII_CoreMixin:GetHistoryForwardButton()
	return self.TopBar.HistoryForwardButton;
end

function APII_CoreMixin:GetFilterDropdown()
	return self.TopBar.FilterDropdown;
end

function APII_CoreMixin:GetGlobalSearchDropdown()
	return self.TopBar.SearchGlobalDropdown;
end

function APII_CoreMixin:OnSizeChanged()
	local newWidth = self:GetWidth();
	--print(newWidth);
	-- if (not self.oldWidth or not ApproximatelyEqual(self.oldWidth, newWidth, 2)) then
	-- 	print("- - New Width");
	-- 	self.oldWidth = newWidth;
	-- end

	--self:UpdateSystemContent();
end

function APII_CoreMixin:OnDragStop()
	local scrollBox = self:GetSystemContentScrollBox();
	if (not scrollBox:GetView()) then return; end

	-- Update content to match the new size
	-- New size can mean different text lines and different frame heights
	-- We don't just rebuild the scrollbox on size change because it's too expensive
	self:UpdateSystemContent()
end

local function OpenTableInspect(table, label)
	UIParentLoadAddOn("Blizzard_DebugTools");
	DisplayTableInspectorWindow(table, label);
end

function APII_CoreMixin:UpdateSearchBoxVisibility()
	local hasGeneralSearchText = self:GetGeneralSearch():HasText();

	local systemSearch = self:GetSystemSearch();
	systemSearch:SetShown(not hasGeneralSearchText);

	local systemContentSearch = self:GetSystemContentSearch();
	systemContentSearch:SetShown(not hasGeneralSearchText);
end

function APII_CoreMixin:UpdateHistoryButtons()
	local backButton = self:GetHistoryBackButton();
	local forwardButton = self:GetHistoryForwardButton();

	backButton:SetEnabled(self.historyIndex > 1);
	forwardButton:SetEnabled(self.historyIndex < #self.history);
end

local APII_HistoryReason = EnumUtil.MakeEnum("GeneralSearch", "SystemSearch", "ContentSearch", "SystemOpen", "APIOpen", "APIClose", "GlobalSearch");
do
	local APIIReasonFunctions = {
		[APII_HistoryReason.GeneralSearch] = function(core, previousHistory, api)
			local previousReason = previousHistory.reason;
			if (previousReason == APII_HistoryReason.GeneralSearch) then
				local generalSearchText = core:GetGeneralSearch():GetText();
				if (#generalSearchText == 0) then
					tremove(core.history, core.historyIndex);
					core.historyIndex = core.historyIndex - 1;
					dprint("removed GeneralSearch")
				else
					previousHistory.generalSearch = generalSearchText;
					dprint("changed GeneralSearch", generalSearchText);
				end
				return true;
			end
			return false;
		end,
		[APII_HistoryReason.SystemSearch] = function(core, previousHistory, api)
			local previousReason = previousHistory.reason;
			if (previousReason == APII_HistoryReason.SystemSearch) then
				local systemSearchText = core:GetSystemSearch():GetText();
				if (#systemSearchText == 0) then
					tremove(core.history, core.historyIndex);
					core.historyIndex = core.historyIndex - 1;
					dprint("removed SystemSearch")
				else
					previousHistory.systemSearch = systemSearchText;
					dprint("changed SystemSearch", systemSearchText);
				end
				return;
			end
			return false;
		end;
		[APII_HistoryReason.ContentSearch] = function(core, previousHistory, api)
			local previousReason = previousHistory.reason;
			if (previousReason == APII_HistoryReason.ContentSearch) then
				local contentSearchText = core:GetSystemContentSearch():GetText();
				if (#contentSearchText == 0) then
					tremove(core.history, core.historyIndex);
					core.historyIndex = core.historyIndex - 1;
					dprint("removed ContentSearch")
				else
					previousHistory.contentSearch = contentSearchText;
					dprint("changed ContentSearch", contentSearchText);
				end
				return true;
			end
			return false;
		end;
		[APII_HistoryReason.SystemOpen] = function(core, previousHistory, api)
			local previousReason = previousHistory.reason;
			if (previousReason == APII_HistoryReason.SystemOpen and previousHistory.openSystem == APII.openedSystem) then
				return true;
			end
			return false;
		end;
		[APII_HistoryReason.APIOpen] = function(core, previousHistory, api)
			local previousReason = previousHistory.reason;
			if (previousReason == APII_HistoryReason.APIOpen and previousHistory.changedAPI == api) then
				return true;
			elseif (previousReason == APII_HistoryReason.SystemOpen) then
				previousHistory.reason = APII_HistoryReason.APIOpen;
				previousHistory.changedAPI = api;
				previousHistory.openedAPIs[api] = true;
				return true;
			end
			return false;
		end;
		-- [APII_HistoryReason.APIClose] = function(core, previousHistory, api)
		-- 	local previousReason = previousHistory.reason;
		-- 	if (previousReason == APII_HistoryReason.APIOpen and previousReason.changedAPI == api and core.historyIndex == #core.history) then
		-- 		tremove(core.history, core.historyIndex);
		-- 		core.historyIndex = core.historyIndex - 1;
		-- 		print("removed ContentSearch")
		-- 	end
		-- 	-- This should never actually make a history snapshot
		-- 	return true;
		-- end
		[APII_HistoryReason.GlobalSearch] = function(core, previousHistory, api)
			local previousReason = previousHistory.reason;
			if (previousReason == APII_HistoryReason.GlobalSearch) then
				local generalSearchText = core:GetGeneralSearch():GetText();
				if (previousHistory.generalSearch == generalSearchText) then
					return true;
				end
			elseif (previousReason == APII_HistoryReason.GeneralSearch) then
				local generalSearchText = core:GetGeneralSearch():GetText();
				if (previousHistory.generalSearch == generalSearchText) then
					tremove(core.history, core.historyIndex);
					core.historyIndex = core.historyIndex - 1;
					dprint("removed GlobalSearch");
				end
			end
			return false;
		end;
	}

	function APII_CoreMixin:AddHistory(reason, api)
		if (self.loadingHistory) then return; end
		dprint(reason)

		local generalSearchText = self:GetGeneralSearch():GetText();
		local systemSearchText = self:GetSystemSearch():GetText();
		local contentSearchText = self:GetSystemContentSearch():GetText();

		local reasonFunc = APIIReasonFunctions[reason];
		local skipAdd = false;
		if (reasonFunc and #self.history > 0) then
			local previousHistory = self.history[self.historyIndex];
			skipAdd = reasonFunc(self, previousHistory, api) or false;
		end

		local removeStart = self.historyIndex + 1;
		if (removeStart <= #self.history) then
			table.removemulti(self.history, removeStart, #self.history - removeStart + 1);
		end

		if (not skipAdd) then
			local snapshot = {
				reason = reason;
				openSystem = APII.openedSystem;
				generalSearch = generalSearchText;
				systemSearch = systemSearchText;
				contentSearch = contentSearchText;
				openedAPIs = CopyTable(APII.openedAPIs, true);
				changedAPI = api;
			};

			tinsert(self.history, snapshot);
			self.historyIndex = #self.history;
			dprint("Added history", #self.history, reason);
		end
		self:UpdateHistoryButtons();

		
	end
end

function APII_CoreMixin:StepHistory(delta)
	if (#self.history <= 1) then return; end
	self.loadingHistory = true;

	if (IsShiftKeyDown()) then
		self.historyIndex = (delta < 0) and 1 or #self.history;
	else
		self.historyIndex = Clamp(self.historyIndex + delta, 1, #self.history);
	end

	local snapshot = self.history[self.historyIndex];

	self:GetGeneralSearch():SetText(snapshot.generalSearch);
	self:GetSystemSearch():SetText(snapshot.systemSearch);
	self:GetSystemContentSearch():SetText(snapshot.contentSearch);
	self:UpdateSearchBoxVisibility();

	APII.openedSystem = snapshot.openSystem;
	wipe(APII.openedAPIs);

	self:UpdateSystemsList();

	for api in pairs(snapshot.openedAPIs) do
		APII.openedAPIs[api] = true;
	end

	self:UpdateSystemContent();

	if (APII.openedSystem) then
		local systemScroll = self:GetSystemScrollBox();
		systemScroll:ScrollToElementData(APII.openedSystem);
	end

	if (snapshot.changedAPI) then
		local contentScroll = self:GetSystemContentScrollBox();
		contentScroll:ScrollToElementData(snapshot.changedAPI);
	end

	--print(delta, self.historyIndex, snapshot.openSystem and snapshot.openSystem.Name);
	self:UpdateHistoryButtons();
	self.loadingHistory = false;
end

local function OnGeneralSearchChanged(coreFrame)
	local systemSearch = coreFrame:GetSystemSearch();
	SearchBoxTemplate_ClearText(systemSearch);
	local systemContentSearch = coreFrame:GetSystemContentSearch();
	SearchBoxTemplate_ClearText(systemContentSearch);

	coreFrame:UpdateSearchBoxVisibility();
	coreFrame:UpdateGlobalSearchDropdown();

	APII.openedSystem = nil;
	coreFrame:UpdateSystemsList();
	coreFrame:UpdateSystemContent(true);

	coreFrame:AddHistory(APII_HistoryReason.GeneralSearch);
end

function APII_CoreMixin:SetGeneralSearchText(text)
	local generalSearch = self:GetGeneralSearch();
	generalSearch:SetText(text);

	OnGeneralSearchChanged(self);
end

function APII_CoreMixin:UpdateGlobalSearchDropdown()
	local generalSearch = self:GetGeneralSearch();
	local dropdown = self:GetGlobalSearchDropdown();
	dropdown:SetEnabled(generalSearch:HasText());
	-- Disbaling text resets the offset
	dropdown.Text:SetPoint("TOP", 0, 1);
end

function APII_CoreMixin:OnLoad()
	self.debug = APII;

	self.history = {};
	self.historyIndex = 0;
	self:UpdateHistoryButtons();
	self:UpdateGlobalSearchDropdown();
	--self:AddHistory();

	ButtonFrameTemplate_HidePortrait(self)
	self:SetClampedToScreen(true);
	self:SetTitle("APIInterface");
	self:SetResizeBounds(250, 200);

	self.Bg:SetPoint("BOTTOMRIGHT", self, -2, 3);

	self.contentBlockFactory = CreateFrameFactory();

	local generalSearch = self:GetGeneralSearch();
	

	do
		local view = CreateScrollBoxListLinearView();
		view:SetElementInitializer("APII_SystemButtonTemplate", function(frame, data)
			frame.parentFrame = self;
			frame:Initialize(data);
			
		end);
		local systemScrollBox = self:GetSystemScrollBox();
		ScrollUtil.InitScrollBoxListWithScrollBar(systemScrollBox, self.SystemScrollBar, view);
	end

	do
		local padding = 0;
		local spacing = 0;
		local view = CreateScrollBoxListLinearView(padding, padding, padding, padding, spacing);
		local systemContentScrollBox = self:GetSystemContentScrollBox();

		local function ToggleAPI(_, api)
			if (APII.openedAPIs[api]) then
				APII.openedAPIs[api] = nil;
				self:AddHistory(APII_HistoryReason.APIClose, api);
			else
				APII.openedAPIs[api] = true;
				self:AddHistory(APII_HistoryReason.APIOpen, api);
			end

			systemContentScrollBox:SetDataProvider(systemContentScrollBox:GetDataProvider(), ScrollBoxConstants.RetainScrollPosition);
		end

		local function OnHyperlinkClick(_, link, sourceAPI)
			local apiType, name, system = link:match("api:(%w+):(%w+):?(%w*)") ;
			local apiInfo = APIDocumentation:FindAPIByName(apiType, name, system);
			dprint("here", link, apiType, name, system, apiInfo);


			if (apiType == "mixin") then
				dprint("Mixin", name, _G[name]);
				local mixin = _G[name];
				if (type(mixin) == "table") then
					OpenTableInspect(mixin, name);
				end
				return;
			end

			SearchBoxTemplate_ClearText(generalSearch);
			local systemSearch = self:GetSystemSearch();
			SearchBoxTemplate_ClearText(systemSearch);
			local contentSearch = self:GetSystemContentSearch();
			SearchBoxTemplate_ClearText(contentSearch);

			if (apiInfo) then
				local systemToOpen = nil;
				local apiToShow = sourceAPI;
				if (apiInfo:GetType() == "system") then
					systemToOpen = apiInfo;
				else
					if (apiInfo.System) then
						systemToOpen = apiInfo.System;
						apiToShow = apiInfo;
						
					end
				end

				if(systemToOpen) then
					local differentSystem = systemToOpen ~= APII.openedSystem;
					self:OpenSystem(systemToOpen);
					if (differentSystem) then
						local systemScroll = self:GetSystemScrollBox();
						systemScroll:ScrollToElementData(systemToOpen);
					end
				end

				if (apiToShow) then
					APII.openedAPIs[apiInfo] = true;
					self:AddHistory(APII_HistoryReason.APIOpen, apiInfo);
					systemContentScrollBox:SetDataProvider(systemContentScrollBox:GetDataProvider(), ScrollBoxConstants.RetainScrollPosition);
					systemContentScrollBox:ScrollToElementData(apiToShow);
				end
			end
		end

		view:SetElementInitializer("APII_SystemContentTemplate", function(frame, data)
			frame:RegisterCallback(APII_SystemContentMixin.Event.ExpandToggled, ToggleAPI, self);
			frame:RegisterCallback(APII_SystemContentMixin.Event.OnHyperlinkClick, OnHyperlinkClick, self);
			frame:Initialize(data, self.contentBlockFactory, APII.openedAPIs[data]);
			frame:SetHyperlinkingEnabled(IsShiftKeyDown());
		end);
		view:SetElementResetter(function(frame, data)
			frame:UnregisterCallback(APII_SystemContentMixin.Event.ExpandToggled, self);
			frame:UnregisterCallback(APII_SystemContentMixin.Event.OnHyperlinkClick, self);
		end);
		view:SetElementExtentCalculator(function (index, data)
			local dummy = systemContentScrollBox.ContentDummy;
			dummy:Initialize(data, self.contentBlockFactory, APII.openedAPIs[data]);
			return dummy:GetHeight();
		end);
		-- view:SetElementFactory(function(factory, elementData)
		-- 	factory("APII_SystemContentTemplate", function(frame, data)
		-- 		frame.parentFrame = self;
		-- 		frame:Initialize(data);
		-- 	end);
		-- end);

		ScrollUtil.InitScrollBoxListWithScrollBar(systemContentScrollBox, self.SystemContentScrollBar, view);

	end

	local systemSearch = self:GetSystemSearch();
	systemSearch:RegisterCallback(APII_SearchboxMixin.Event.OnTextChanged, function(_, text, userInput)
		if (not userInput) then return; end
		self:UpdateSystemsList();
		self:AddHistory(APII_HistoryReason.SystemSearch);
	end, self);

	systemSearch:RegisterCallback(APII_SearchboxMixin.Event.OnClearButtonClicked, function()
		self:UpdateSystemsList();
		self:AddHistory(APII_HistoryReason.SystemSearch);
	end, self);
	
	do
		generalSearch:RegisterCallback(APII_SearchboxMixin.Event.OnTextChanged, function(_, text, userInput)
			self:UpdateGlobalSearchDropdown();
			if (not userInput) then return; end
			OnGeneralSearchChanged(self);
		end, self);
		
		generalSearch:RegisterCallback(APII_SearchboxMixin.Event.OnClearButtonClicked, function()
			OnGeneralSearchChanged(self);
			-- systemSearch:Show();
			-- self:UpdateSystemsList();
			-- self:UpdateSystemContent(true);
			-- self:AddHistory(APII_HistoryReason.GeneralSearch);
		end, self);
	end

	local systemContentSearch = self:GetSystemContentSearch();
	systemContentSearch:RegisterCallback(APII_SearchboxMixin.Event.OnTextChanged, function(_, text, userInput)
		if (not userInput) then return; end
		self:UpdateSystemContent(true);
		self:AddHistory(APII_HistoryReason.ContentSearch);
	end, self);

	systemContentSearch:RegisterCallback(APII_SearchboxMixin.Event.OnClearButtonClicked, function()
		self:UpdateSystemContent(true);
		self:AddHistory(APII_HistoryReason.ContentSearch);
	end, self);


	local backButton = self:GetHistoryBackButton();
	backButton:RegisterCallback(APII_HistoryButtonMixin.Event.OnClick, function(_, delta) self:StepHistory(delta); end);
	
	local forwardButton = self:GetHistoryForwardButton();
	forwardButton:RegisterCallback(APII_HistoryButtonMixin.Event.OnClick, function(_, delta) self:StepHistory(delta); end);


	-- do
	-- 	local function FilterDropdownSetup(dropdown, rootDescription)
	-- 		rootDescription:SetTag("APII_FILTERS_DROPDOWN");
	-- 	end

	-- 	self.FilterDropdown:SetupMenu(FilterDropdownSetup);
	-- end

	do
		

		local sortedFilters = {};
		for filterType in pairs(APII_FilterType) do
			tinsert(sortedFilters, filterType);
		end

		table.sort(sortedFilters, function(a, b) return a < b; end);

		local function FilterDropdownSetup(dropdown, rootDescription)
			rootDescription:SetTag("APII_FILTERS_DROPDOWN");

			for k, filterType in ipairs(sortedFilters) do
				local function GetFilterChecked()
					return APII.db and APII.db.global.filters[filterType];
				end
				local function OnFilterSelect(...)
					APII.db.global.filters[filterType] = not APII.db.global.filters[filterType];
					self:UpdateSystemContent();
				end
				rootDescription:CreateCheckbox(filterType, GetFilterChecked, OnFilterSelect);
			end
		end

		local filterDropdown = self:GetFilterDropdown();
		filterDropdown.Text:SetPoint("TOP", 0, 1);
		filterDropdown:SetupMenu(FilterDropdownSetup);

		filterDropdown:SetIsDefaultCallback(function()
			if (not APII.db) then return true; end
			for filterType in pairs(APII_DefaultSavedVariables.global.filters) do
				if (not APII.db.global.filters[filterType]) then
					return false;
				end
			end
			return true;
		end);

		filterDropdown:SetDefaultCallback(function()
			if (not APII.db) then return true; end
			wipe(APII.db.global.filters);
			for filterType in pairs(APII_DefaultSavedVariables.global.filters) do
				APII.db.global.filters[filterType] = true;
			end
			self:UpdateSystemContent();
			return true;
		end);
	end

	do
		local function IsGlobalSearchMatch(key, value, search, searchType)
			if (type(key) ~= "string") then return false; end

			local keyMatched = key:lower():find(search:lower());
			local valueType = type(value)

			if (searchType == GlobalSearchTypes.Values) then
				return keyMatched and (valueType == "number" or valueType == "boolean");
			end

			if (valueType == "table" and value.IsForbidden and value:IsForbidden()) then return false; end

			if (searchType == GlobalSearchTypes.Tables) then
				return keyMatched and valueType == "table" and value.GetDebugName == nil;
			elseif (searchType == GlobalSearchTypes.Frames) then
				return keyMatched and valueType == "table" and value.GetDebugName ~= nil;
			elseif (searchType == GlobalSearchTypes.Functions) then
				return keyMatched and valueType == "function";
			elseif (searchType == GlobalSearchTypes.Strings) then
				if (valueType ~= "string") then
					return false;
				end
				local valueMatch = value:lower():find(search:lower());
				if (IsShiftKeyDown()) then
					return keyMatched or valueMatch;
				elseif (IsControlKeyDown()) then
					return valueMatch;
				end
			end

			return keyMatched;
		end


		local function SearchGlobal(searchType)
			if (not generalSearch:HasText()) then return; end
			local searchText = generalSearch:GetText();
			local numResults = 0;
			local results = {};
			for k,v in pairs(_G)do
				if (IsGlobalSearchMatch(k, v, searchText, searchType)) then
					results[k] = v;
					numResults = numResults + 1;
					if (numResults >= SEARCH_CUTOFF_AMOUNT) then
						AddonPrint(FORMAT_SEARCH_CUTOFF:format(SEARCH_CUTOFF_AMOUNT));
						break;
					end
				end
			end;

			local label = GlobalSearchTypesTranslation(searchType);
			if (numResults > 0) then
				OpenTableInspect(results, FORMAT_RESULTS_TITLE:format(numResults, label, searchText));
			else
				AddonPrint(FORMAT_NO_RESULTS:format(label, searchText));
			end
			self:AddHistory(APII_HistoryReason.GlobalSearch);
		end

		local function DropdownSetup(dropdown, rootDescription)
			rootDescription:SetTag("APII_GLOBAL_SEARCH_DROPDOWN");

			do
				local button = rootDescription:CreateButton("Functions", SearchGlobal, GlobalSearchTypes.Functions);
				button:SetTooltip(function(tooltip, description)
						GameTooltip_SetTitle(tooltip, description.text);
						GameTooltip_AddNormalLine(tooltip, "Search functions with matching keys");
					end);
			end

			do
				local button = rootDescription:CreateButton("Tables", SearchGlobal, GlobalSearchTypes.Tables);
				button:SetTooltip(function(tooltip, description)
						GameTooltip_SetTitle(tooltip, description.text);
						GameTooltip_AddNormalLine(tooltip, "Search tables with matching keys");
					end);
			end

			do
				local button = rootDescription:CreateButton("Frames", SearchGlobal, GlobalSearchTypes.Frames);
				button:SetTooltip(function(tooltip, description)
						GameTooltip_SetTitle(tooltip, description.text);
						GameTooltip_AddNormalLine(tooltip, "Search frames with matching keys");
						GameTooltip_AddColoredLine(tooltip, "Does not include frames marked as \"Forbidden\"", RED_FONT_COLOR);
					end);
			end

			do
				local button = rootDescription:CreateButton("Strings", SearchGlobal, GlobalSearchTypes.Strings);
				button:SetTooltip(function(tooltip, description)
						GameTooltip_SetTitle(tooltip, description.text);
						GameTooltip_AddNormalLine(tooltip, "Search strings with matching key");
						GameTooltip_AddInstructionLine(GameTooltip, "<Control Click to match value>");
						GameTooltip_AddInstructionLine(GameTooltip, "<Shift Click to match either key or value>");
					end);
			end

			do
				local button = rootDescription:CreateButton("Values", SearchGlobal, GlobalSearchTypes.Values);
				button:SetTooltip(function(tooltip, description)
						GameTooltip_SetTitle(tooltip, description.text);
						GameTooltip_AddNormalLine(tooltip, "Search values with matching keys");
					end);
			end
		end

		local dropdown = self:GetGlobalSearchDropdown();
		dropdown.Text:SetPoint("TOP", 0, 1);
		dropdown:SetupMenu(DropdownSetup);
	end


	-- This has to be last
	local minWidth = 700;
	local minHeight = 450;
	local maxWidth, maxHeight = GetPhysicalScreenSize();
	self.ResizeButton:Init(self, minWidth, minHeight, maxWidth, maxHeight);
	self.ResizeButton:SetOnResizeStoppedCallback(function() self:OnDragStop() end)

	self.g = true;

end

function APII_CoreMixin:OnUpdate()
	-- Doing this in OnUpdate because the event doesn't trigger with an editbox focused or clicking outside the game
	if (self.shiftDown ~= IsShiftKeyDown()) then
		self.shiftDown = IsShiftKeyDown();
		local systemContentScrollBox = self:GetSystemContentScrollBox();
		for k, frame in systemContentScrollBox:EnumerateFrames() do
			frame:SetHyperlinkingEnabled(self.shiftDown);
		end
	end
end

function APII_CoreMixin:OnShow()
	if (not self.initialized) then
		self.initialized = true;
		if (not APIDocumentation) then
			C_AddOns.LoadAddOn("Blizzard_APIDocumentationGenerated");
		end

		AlterOfficialDocumentation();
		self:UpdateSystemsList();
	end
end

function APII_CoreMixin:UpdateSystemsList()
	local dataProvider = CreateDataProvider();

	local generalSearch = self:GetGeneralSearch();

	local searchString = generalSearch:GetText();
	if (#searchString == 0) then
		local systemSearch = self:GetSystemSearch();
		searchString = systemSearch:GetText();
	end

	local systemList = APIDocumentation.systems;
	if (searchString and #searchString > 0) then
		systemList = {};
		APIDocumentation:AddAllMatches(APIDocumentation.systems, systemList, searchString);
	end

	for k, system in ipairs(systemList) do
		dataProvider:Insert(system);
	end

	local systemScrollBox = self:GetSystemScrollBox();
	systemScrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition);
end

function APII_CoreMixin:OpenSystem(system)
	dprint("Opening", system and system.Name)
	for api in pairs(APII.openedAPIs) do
		if (api.System ~= system) then
			APII.openedAPIs[api] = nil;
		end
	end

	if (APII.openedSystem == system) then return; end

	APII.openedSystem = system;
	
	if (not system) then return; end

	local generalSearch = self:GetGeneralSearch();
	SearchBoxTemplate_ClearText(generalSearch);
	local systemContentSearch = self:GetSystemContentSearch();
	SearchBoxTemplate_ClearText(systemContentSearch);

	self:UpdateSearchBoxVisibility();

	self:UpdateSystemsList();
	self:UpdateSystemContent();

	self:AddHistory(APII_HistoryReason.SystemOpen);
end

do
	local total = 0;
	local passed = 0;

	local function AddSystemContentToDateprovider(dataProvider, info)
		total = total + 1;
		if (InfoPassesFilters(info)) then
			dataProvider:Insert(info);
			passed = passed + 1;
		end
	end

	function APII_CoreMixin:UpdateSystemContent(resetPosition)
		if (not self.g) then return; end

		local dataProvider = CreateDataProvider();

		local generalSearch = self:GetGeneralSearch();
		local systemContentSearch = self:GetSystemContentSearch();
		systemContentSearch:SetShown(APII.openedSystem ~= nil);

		local searchString = generalSearch:GetText();
		if (#searchString == 0) then
			searchString = systemContentSearch:GetText();
		end

		local apiMatches = nil;
		if (APII.openedSystem) then
			local searchInstructionText = string.format("Search In %s", APII.openedSystem.Name);
			systemContentSearch.Instructions:SetText(searchInstructionText);
			InputBoxInstructions_OnTextChanged(systemContentSearch);

			local bannerText = APII.openedSystem.Name;
			if (APII.openedSystem.Namespace) then
				bannerText = string.format("%s (%s)", bannerText,
					APII_NAMESPACE_COLOR:WrapTextInColorCode(APII.openedSystem.Namespace));
			end
			--inSystemBanner.Text:SetText(bannerText);


			if (searchString and #searchString > 0) then
				apiMatches = APII.openedSystem:FindAllAPIMatches(searchString);
			else
				apiMatches = APII.openedSystem:ListAllAPI();
			end

			--apiMatches = APIDocumentation:FindAllAPIMatches("quest");
			dprint("- - - -")
			dprint(apiMatches, apiMatches and #apiMatches or "");
		else
			if (searchString and #searchString > 0) then
				apiMatches = APIDocumentation:FindAllAPIMatches(searchString);
			end
		end

		total = 0;
		passed = 0;

		if (apiMatches) then
			for k, info in ipairs(apiMatches.functions) do
				AddSystemContentToDateprovider(dataProvider, info);
			end

			for k, info in ipairs(apiMatches.events) do
				AddSystemContentToDateprovider(dataProvider, info);
			end

			for k, info in ipairs(apiMatches.tables) do
				AddSystemContentToDateprovider(dataProvider, info);
			end
		end
		dprint(passed, "/", total);

		local systemContentScrollBox = self:GetSystemContentScrollBox();
		systemContentScrollBox:SetDataProvider(dataProvider,
			resetPosition and ScrollBoxConstants.DiscardScrollPosition or ScrollBoxConstants.RetainScrollPosition);
	end
end

function APII_CoreMixin:CloseAllAPI()
	wipe(APII.openedAPIs);
end
