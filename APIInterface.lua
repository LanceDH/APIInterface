
local _addonName, _addon = ...;

APII = LibStub("AceAddon-3.0"):NewAddon(_addonName);

local MIN_FRAME_WIDTH = 800;
local MIN_FRAME_HEIGHT = 500;
local SEARCH_CUTOFF_AMOUNT = 1000;
local CHAT_MESSAGE_PREFIX = "APII: %s";
local FORMAT_SEARCH_CUTOFF_CHANGED = "Search cutoff changed to %d for this session.";
local FORMAT_SEARCH_CUTOFF = "Searched stopped after %d results. Use /apii limit x if to change the limit."
local FORMAT_NO_RESULTS = "No \"%s\" found in _G matching \"%s\"."
local FORMAT_RESULTS_TITLE = "%d \"%s\" matching \"%s\"";
local ERROR_COMBAT = "Can't open %s during combat.";
local VARIABLE_REPEATS = "Variable repeats of the last row";
local VARIABLE_REPEATS_MULTIPLE = "Variable repeats of the last %d rows";
local PART_OF_SYSTEM = "Part of the %s system";
local PART_OF_NO_SYSTEM = "Not part of a system";
local TT_SEARCH_FUNCTIONS = "Search functions with matching keys";
local TT_SEARCH_TABLES = "Search tables with matching keys";
local TT_SEARCH_FRAMES = "Search frames with matching keys";
local TT_SEARCH_FRAMES_FORBIDDEN = "Does not include frames marked as \"Forbidden\"";
local TT_SEARCH_STRINGS = "Search strings with matching key";
local TT_SEARCH_STRINGS_VALUE = "<Control Click to match value>";
local TT_SEARCH_STRINGS_BOTH = "<Shift Click to match either key or value>";
local TT_SEARCH_VALUES = "Search values with matching keys";
local HISTORY_BACKWARDS = "Back In History";
local HISTORY_BACKWARDS_TT = "<Hold Shift to go to the very end>";
local HISTORY_FORWARDS = "Forward In History";
local HISTORY_FORWARDS_TT = "<Hold Shift to go to the very front>";
local TOGGLE_HYPERLINKS = "Toggle Hyperlinks";
local TOGGLE_HYPERLINKS_TT = "Make API text clickable to hyperlink to other API.";
local TOGGLE_HYPERLINKS_TT_SHIFT = "<Hold Shift to temporary enable hyperlinks>";
local UNDOCUMENTED_LABEL = "apii_IsUndocumented";
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
local APII_VARIABLE_FIELD_COLOR = LIGHTYELLOW_FONT_COLOR;
local APII_FIELDS_COLOR = NORMAL_FONT_COLOR;-- overwitten with actual color once API gets loaded

local GlobalSearchTypes = EnumUtil.MakeEnum("Functions", "Tables", "Frames", "Strings", "Values");
local GlobalSearchTypesTranslation = EnumUtil.GenerateNameTranslation(GlobalSearchTypes);
local SecretAspectTranslator = EnumUtil.GenerateNameTranslation(Enum.SecretAspect);


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

function APII:OnInitialize()
	APII.openedSystem = nil;
	APII.openedAPIs = {};

	self.db = LibStub("AceDB-3.0"):New("APIIDB", APII_DefaultSavedVariables, true);
end

local function AddonPrint(message)
	print(CHAT_MESSAGE_PREFIX:format(message));
end

local function dprint(...)
	if true then return; end
	print(...);
end

----------
-- Slash
----------

SLASH_APIISLASH1 = '/apii';
SLASH_APIISLASH2 = '/apiinterface';
local function slashcmd(msg, editbox)
	if (msg == "reset") then
		APII_Frame:Reset();
	elseif msg:match("^limit ") then
		local amount = tonumber(msg:match("limit (%d+)"));
		if (not amount or amount < 1) then return; end
		SEARCH_CUTOFF_AMOUNT = amount;
		AddonPrint(FORMAT_SEARCH_CUTOFF_CHANGED:format(SEARCH_CUTOFF_AMOUNT));
	else
		APII_Frame:RequestShow(msg);
	end
end
SlashCmdList["APIISLASH"] = slashcmd

local TextScaleCategoryEnum = EnumUtil.MakeEnum("Medium", "Large");
local TextScaleEnum = EnumUtil.MakeEnum("Normal", "Big");

local activeTextScaleCategory = TextScaleEnum.Normal;

local fontSizeTable = {
	[TextScaleCategoryEnum.Medium] = {
		[TextScaleEnum.Normal] = "GameFontHighlight";
		[TextScaleEnum.Big] = "GameFontHighlightMedium";
	};
	[TextScaleCategoryEnum.Large] = {
		[TextScaleEnum.Normal] = "GameFontHighlightMedium";
		[TextScaleEnum.Big] = "GameFontHighlightLarge";
	};
}

local function GetFont(scale)
	local category = fontSizeTable[activeTextScaleCategory];
	return category[scale] or category[TextScaleEnum.Normal]
end

local APII_FrameFactory = CreateFrameFactory();

local function InfoPassesFilters(apiInfo)
	if (apiInfo[UNDOCUMENTED_LABEL] and not APII.db.global.filters["Undocumented"]) then
		return false;
	end

	if (APII_FilterType[apiInfo.Type]) then
		return APII.db.global.filters[apiInfo.Type];
	end

	dprint("Type not covered:", apiInfo.Type);
	return true;
end

local function AlterOfficialDocumentation()
	APII_ValueAPIMixin = CreateFromMixins(FieldsAPIMixin);

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

	function APII_ValueAPIMixin:GetValue()
		local result;
		-- This data makes no sense, so just get the value from the constant itself;
		local constant = Constants[self:GetParentName()];
		if (constant) then
			result = constant[self:GetName()];
		end

		return result == nil and "unknown" or result;
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
			for name in pairs(undocumented) do
				local newAPI = CreateFromMixins(APII_UndocumentedAPIMixin);
				newAPI[UNDOCUMENTED_LABEL] = true;
				newAPI.Name = name;
				newAPI.Type = "Function";
				newAPI.System = system;
				newAPI.Documentation = { APII_UNDOCUMENTED_MESSAGE; };
				tinsert(system.Functions, newAPI);
				tinsert(APIDocumentation.functions, newAPI);
				madeChange = true;
			end

			if (madeChange) then
				table.sort(system.Functions, FunctionListSort);
			end
		end
	end

	tinsert(APIDocumentation.systems, 1, noSystemContent);
end

--------------------------------
-- String Tester
--------------------------------

local APII_StringTesterMixin = {};

function APII_StringTesterMixin:Init()
	self.frame = CreateFrame("Frame", nil, UIParent);
	self.fontString = self.frame:CreateFontString(nil, nil, "GameFontHighlight");
end

function APII_StringTesterMixin:TestUnboundWidth(text, textSize)
	textSize = textSize or TextScaleEnum.Normal;
	local font = GetFont(textSize);
	self.fontString:SetFontObject(font);
	self.fontString:SetText(text);
	return self.fontString:GetUnboundedStringWidth();
end

local StringTester = CreateAndInitFromMixin(APII_StringTesterMixin);

--------------------------------
-- Vertical layout
--------------------------------

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
			local lChildPadding, rChildPadding, tChildPadding, bChildPadding = GetChildPadding(child);
			child:SetPoint("LEFT", self, lChildPadding, 0);
			child:SetPoint("RIGHT", self, -rChildPadding, 0);
			if (anchor) then
				child:SetPoint("TOP", anchor, "BOTTOM", 0, -tChildPadding);
			else
				child:SetPoint("TOP", self, 0, -tChildPadding);
			end
			
			anchor = child;

			if (k == #visibleChildren) then
				child:SetPoint("BOTTOM", self, 0, bChildPadding);
			end
		end
	end
end

--------------------------------
-- Editbox
--------------------------------

APII_EditBoxMixin = CreateFromMixins(CallbackRegistryMixin);

APII_EditBoxMixin:GenerateCallbackEvents(
	{
		"OnTextChanged";
	}
);

function APII_EditBoxMixin:OnLoad()
	CallbackRegistryMixin.OnLoad(self);
	self.defaultHighlightColor = CreateColor(self:GetHighlightColor());
end

function APII_EditBoxMixin:OnEnterPressed()
	self:ClearFocus();
end

function APII_EditBoxMixin:OnEditFocusLost()
	self:ClearHighlightText();
end

function APII_EditBoxMixin:OnKeyDown(key)
	if (IsControlKeyDown() and (key == "C" or key == "X")) then
		self:StartCopyHighlight();
		PlaySound(SOUNDKIT.TUTORIAL_POPUP);
	end
end

function APII_EditBoxMixin:OnTextChanged(userInput)
	if (userInput) then
		self:SetAlpha(0);
		C_Timer.After(0, function()
			self:SetAlpha(1);
		end);
		self:SetText(self.originalText);
		self:ClearFocus();
	end
	self:TriggerEvent(APII_EditBoxMixin.Event.OnTextChanged, userInput);
end

function APII_EditBoxMixin:OnHide()
	self:StopCopyHighlight();
end

function APII_EditBoxMixin:OnShow()
	self:SetHighlightColor(0, 0 , 0, 0);

	C_Timer.After(0, function()
		self:SetHighlightColor(self.defaultHighlightColor:GetRGB());
	end);
end

do
	local COPY_HIGHLIGHT_DURATION = 0.3;
	local COPY_HIGHLIGHT_COLOR = CreateColor(0.6, 0.6, 0.2);

	function APII_EditBoxMixin:StartCopyHighlight()
		self:SetHighlightColor(COPY_HIGHLIGHT_COLOR:GetRGB());
		self.highlightTimer = COPY_HIGHLIGHT_DURATION;
		if (not self.updateScriptSet) then
			self:SetScript("OnUpdate", self.OnUpdate);
			self.updateScriptSet = true;
		end
	end

	function APII_EditBoxMixin:StopCopyHighlight()
		self:SetHighlightColor(self.defaultHighlightColor:GetRGB());
		self:SetScript("OnUpdate", nil);
		self.updateScriptSet = false;
	end

	function APII_EditBoxMixin:OnUpdate(elapsed)
		self.highlightTimer = Clamp(self.highlightTimer - elapsed, 0, COPY_HIGHLIGHT_DURATION);

		local r, g, b = COPY_HIGHLIGHT_COLOR:GetRGB();
		local rd, gd, bd = self.defaultHighlightColor:GetRGB();
		local t = 1 - (self.highlightTimer / COPY_HIGHLIGHT_DURATION);
		t = t * t * t;

		self:SetHighlightColor(Lerp(r, rd, t), Lerp(g, gd, t), Lerp(b, bd, t));

		if (self.highlightTimer <= 0) then
			self:StopCopyHighlight();
		end
	end
end

--------------------------------
-- Searchbox
--------------------------------

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

--------------------------------
-- Tooltip mixin
--------------------------------

local APII_TooltipMixin = {};

function APII_TooltipMixin:SetTooltip(func)
	self.tooltipFunc = func;
end

function APII_TooltipMixin:OnEnter()
	if (self.tooltipFunc) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		self.tooltipFunc(GameTooltip);
		GameTooltip:Show();
	end
end

function APII_TooltipMixin:OnLeave()
	GameTooltip:Hide();
end

--------------------------------
-- History Button
--------------------------------

APII_HistoryButtonMixin = CreateFromMixins(CallbackRegistryMixin, APII_TooltipMixin);

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
	APII_TooltipMixin.OnEnter(self);
end

function APII_HistoryButtonMixin:OnLeave()
	WowStyle2IconButtonMixin.OnLeave(self);
	APII_TooltipMixin.OnLeave(self);
end

--------------------------------
-- Checkbutton
--------------------------------

APII_CheckButtonMixin = CreateFromMixins(WowStyle2IconButtonMixin, CallbackRegistryMixin, APII_TooltipMixin);

APII_CheckButtonMixin:GenerateCallbackEvents(
	{
		"OnClick";
	}
);

function APII_CheckButtonMixin:OnLoad()
	WowStyle2IconButtonMixin.OnLoad(self);
	CallbackRegistryMixin.OnLoad(self);
end

function APII_CheckButtonMixin:OnButtonStateChanged()
	self.Background:SetAtlas(self:GetBackgroundAtlas(), TextureKitConstants.UseAtlasSize);

	local icon = self.normalAtlas;
	local useAtlasSize = (not self.iconWidth or not self.iconHeight) and TextureKitConstants.UseAtlasSize or TextureKitConstants.IgnoreAtlasSize;
	local alpha = self:GetIconHighlighted() and 1 or 0.5;
	alpha = 1;
	local saturation = self:GetIconHighlighted() and 1 or 0.5;
	if (self.disabledAtlas) then
		icon = self:IsEnabled() and self.normalAtlas or self.disabledAtlas;
	end
	self.Icon:SetAtlas(icon, useAtlasSize);
	self.Icon:SetVertexColor(saturation, saturation, saturation);
	self.Icon:SetAlpha(alpha);
	if (not useAtlasSize) then
		self.Icon:SetSize(self.iconWidth, self.iconHeight);
	end
end

function APII_CheckButtonMixin:SetIconHighlighted(value)
	self.highlightOverriden = value;
	self:OnButtonStateChanged();
end

function APII_CheckButtonMixin:GetIconHighlighted()
	return self:GetChecked() or self.highlightOverriden;
end

function APII_CheckButtonMixin:OnClick()
	self:OnButtonStateChanged();
	self:TriggerEvent(APII_CheckButtonMixin.Event.OnClick);
end

function APII_CheckButtonMixin:OnEnter()
	WowStyle2IconButtonMixin.OnEnter(self);
	APII_TooltipMixin.OnEnter(self);
end

function APII_CheckButtonMixin:OnLeave()
	WowStyle2IconButtonMixin.OnLeave(self);
	APII_TooltipMixin.OnLeave(self);
end

--------------------------------
-- TextArea mixins
--------------------------------

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

function APII_TextAreaMixin:GetEditBoxInsets()
	return self.HitInsetLeft or 0
			, self.HitInsetRight or 0
			, self.HitInsetTop or 0
			, self.HitInsetBottom or 0;
end

function APII_TextAreaMixin:OnLoad()
	local editBox = self:GetEditBox();
	editBox:RegisterCallback(APII_EditBoxMixin.Event.OnTextChanged, function(_, userInput)
			if (userInput) then
				local html = self:GetHtml();
				html:Show();
				C_Timer.After(0, function() html:Hide(); end);
			end
		end, self);

	editBox:SetHitRectInsets(self:GetEditBoxInsets());
end

function APII_TextAreaMixin:SetHyperlinkingEnabled(enable)
	local html = self:GetHtml();
	local editBox = self:GetEditBox();
	html:Show();

	if (enable) then
		html:Show(enable);

		editBox:ClearFocus();
		editBox:ClearHighlightText();
		editBox:Hide();
	else
		-- Editbox text doesn't update until 1 frame after it is shown
		-- Text can change while invisble when content text gets re-used by the scrollview while hyperlinking is enabled (i.e. clicking a hyperlink)
		-- Keep html visible and show editbox with 0 opacity for 1 frame before actually switching
		-- TextHighlight issues are sorted in editbox mixin
		editBox:Show();
		editBox:SetAlpha(0);

		C_Timer.After(0, function()
			html:Hide();
			editBox:SetAlpha(1);
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

-- Padding

local APII_TextAreaPaddingMixin = {};

function APII_TextAreaPaddingMixin:GetPadding()
	return self.leftPadding or 0,
		self.rightPadding or 0,
		self.topPadding or 0,
		self.bottomPadding or 0;
end

function APII_TextAreaPaddingMixin:SetPadding(left, right, top, bottom)
	self.leftPadding = left or 0;
	self.rightPadding = right or 0;
	self.topPadding = top or 0;
	self.bottomPadding = bottom or 0;
	self:UpdateTextArea();
end

function APII_TextAreaPaddingMixin:SetAvailableWidth(width)
	self:SetWidth(width);
	self:UpdateTextArea();
end

function APII_TextAreaPaddingMixin:UpdateTextArea()
	local editBox = self:GetEditBox();
	local html = self:GetHtml();
	local fonsString = self:GetFontString();
	local leftPadding, rightPadding, topPadding, bottomPadding = self:GetPadding();
	local width = self:GetWidth() - leftPadding - rightPadding;
	editBox:SetWidth(width);
	html:SetWidth(width);
	fonsString:SetWidth(width);

	editBox:SetPoint("TOPLEFT", leftPadding, -topPadding);
	editBox:SetPoint("BOTTOM", 0, bottomPadding);
	html:SetPoint("TOPLEFT", leftPadding, -topPadding);
	html:SetPoint("BOTTOM", 0, bottomPadding);
	fonsString:SetPoint("TOPLEFT", leftPadding, -topPadding);

	editBox:SetHitRectInsets(-leftPadding, -rightPadding, -topPadding, -bottomPadding);
end

function APII_TextAreaPaddingMixin:SetText(text, font)
	APII_TextAreaMixin.SetText(self, text, font);
	local leftPadding, rightPadding, topPadding, bottomPadding = self:GetPadding();
	local height = self:GetHeight() + topPadding + bottomPadding;
	self:SetHeight(height);
end

-- Background

APII_TableTextAreaMixin = CreateFromMixins(APII_TextAreaMixin, APII_TextAreaPaddingMixin)

function APII_TableTextAreaMixin:GetBackground()
	return self.Background;
end

function APII_TableTextAreaMixin:SetBackgroundColor(color)
	if (not color or not color.GetRGBA) then return; end
	local background = self:GetBackground();
	background:SetColorTexture(color:GetRGBA());
end

-- Nineslice

APII_TextBlockNineSliceMixin = CreateFromMixins(APII_TextAreaMixin, APII_TextAreaPaddingMixin);


--------------------------------
-- TextBlock mixins
--------------------------------

APII_TextBlockMixin = {};

function APII_TextBlockMixin:OnLoad()

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

-- CopyString Textblock

APII_TextBlockCopyStringMixin = CreateFromMixins(APII_TextBlockMixin);

do
	local COPY_STRING_PADDING = 10;

	function APII_TextBlockCopyStringMixin:Initialize(blockData)
		self.blockData = blockData;

		local basicString = blockData.textString;
		local leftPadding, rightPadding, topPadding, bottomPadding = self:GetPadding();
		local width = self:GetWidth() - leftPadding - rightPadding;
		local textAreaWidth = width;

		local textArea = self:GetTextArea()
		textArea:SetPadding(COPY_STRING_PADDING, COPY_STRING_PADDING, COPY_STRING_PADDING, COPY_STRING_PADDING);
		textArea:SetPoint("TOPLEFT", leftPadding , -topPadding);
		textArea:SetAvailableWidth(textAreaWidth);
		textArea:SetText(basicString, blockData.font);

		local totalHeight = textArea:GetHeight() + topPadding + bottomPadding;
		self:SetHeight(totalHeight);
	end
end

-- Table Textblock

APII_TextBlockTableMixin = CreateFromMixins(APII_TextBlockMixin);

do
	local TABLE_SPACING_HORIZONTAL = 8;
	local TABLE_SPACING_VERTICAL = 5;
	local TABLE_SEPARATOR_WIDTH = 2;

	local TABLE_BORDER_COLOR = CreateColor(0.0, 0.0, 0.0, 0.45);
	local TABLE_HEADER_COLOR = CreateColor(0.09, 0.09, 0.09, 1);
	local TABLE_ALTERNATE_LIGHT_COLOR = CreateColor(0.15, 0.15, 0.15, 1);
	local TABLE_ALTERNATE_DARK_COLOR = CreateColor(0.12, 0.12, 0.12, 1);

	function APII_TextBlockTableMixin:OnLoad()
		APII_TextBlockMixin.OnLoad(self);
		self.textAreas = {};
	end

	function APII_TextBlockTableMixin:SetHyperlinkingEnabled(enable)
		for k, frame in ipairs(self.textAreas) do
			frame:SetHyperlinkingEnabled(enable);
		end
	end

	function APII_TextBlockTableMixin:Initialize(blockData)
		self.blockData = blockData;

		for k, frame in ipairs(self.textAreas) do
			APII_FrameFactory:Release(frame);
		end
		wipe(self.textAreas);

		if (not blockData.tableData) then
			self:SetHeight(10);
			return;
		end

		local leftPadding, rightPadding, topPadding, bottomPadding = self:GetPadding();
		local width = self:GetWidth() - leftPadding - rightPadding;

		-- Gather minimum width of each column
		local columnWidthData = {};
		for rowIndex, row in ipairs(blockData.tableData.rowData) do
			for contentIndex, content in ipairs(row.content) do
				local contentWidth = content.width;
				local widthData = columnWidthData[contentIndex];
				if (not widthData) then
					widthData = {
						contentWidth = 0;
						finalWidth = 0;
					}
					columnWidthData[contentIndex] = widthData;
				end

				widthData.preventScale = widthData.preventScale or content.preventScale;
				if (not content.colSpan and widthData.contentWidth < contentWidth) then
					widthData.contentWidth = Round(contentWidth);
				end
			end
		end

		local totalColumnWidth = 0
		local totalBorderWidth = TABLE_SEPARATOR_WIDTH * (#columnWidthData + 1);
		local availableTextSpace = width - totalBorderWidth;
		local scalableSpace = availableTextSpace;
		local contentToScale = {};
		for k, data in ipairs(columnWidthData) do
			local contentWidth = data.contentWidth + TABLE_SPACING_HORIZONTAL * 2;
			totalColumnWidth = totalColumnWidth + contentWidth;
			tinsert(contentToScale, k);
		end

		-- Every cell gets 1/cells of the available space
		-- Any cell that needs less space gets their space, the left over space is made available for the remaining cells
		-- Repeat with new available space and remaining cells
		-- If no cells need less space than available, give remaining cells 1/cells of the available space
		if (#contentToScale > 0) then
			local hadSmallerThanScale = true;
			while hadSmallerThanScale do
				hadSmallerThanScale = false;
				local minColPerc = 1 / #contentToScale;
				local smallestScaleSize = minColPerc * scalableSpace;
				local beforeCount = #contentToScale;
				for k, columnIndex in ipairs(contentToScale) do
					local data = columnWidthData[columnIndex];
					local contentWidth = data.contentWidth + TABLE_SPACING_HORIZONTAL * 2;
					if (contentWidth < smallestScaleSize) then
						hadSmallerThanScale = true;
						data.finalWidth = contentWidth;
						scalableSpace = scalableSpace - contentWidth;
						tremove(contentToScale, k);
					end
				end

				if (#contentToScale == 0) then
					-- Everything fit;
					break;
				end

				if (beforeCount == #contentToScale) then
					for k, columnIndex in ipairs(contentToScale) do
						local data = columnWidthData[columnIndex];
						local ceiled = ceil(smallestScaleSize)
						data.finalWidth = ceiled;
						scalableSpace = scalableSpace - ceiled;
					end
					break;
				end
			end
		end

		-- Add any left over space to the last column to all tables are full width
		-- if (scalableSpace > 0) then
		-- 	local lastColumnData = columnWidthData[#columnWidthData];
		-- 	lastColumnData.finalWidth = lastColumnData.finalWidth + scalableSpace;
		-- end
		
		local xOffset = 0;
		local yOffset = topPadding + TABLE_SEPARATOR_WIDTH;
		local rowFrames = {};
		for rowIndex, row in ipairs(blockData.tableData.rowData) do
			xOffset = leftPadding + TABLE_SEPARATOR_WIDTH;
			yOffset = yOffset;
			local rowHeight = 0
			local rowColor = TABLE_HEADER_COLOR;
			if (not row.isHeader) then
				rowColor = rowIndex % 2 == 1 and TABLE_ALTERNATE_DARK_COLOR or TABLE_ALTERNATE_LIGHT_COLOR;
			end

			-- Doing this with a while loop so we can skip columns for colSpan
			local columnIndex = 1;
			while columnIndex <= #columnWidthData do
				local columnData = columnWidthData[columnIndex];
				if (columnIndex ~= 1) then
					xOffset = xOffset + TABLE_SEPARATOR_WIDTH;
				end

				local content = row.content[columnIndex];
				local columnWidth = columnData.finalWidth;
				if (content and content.colSpan and content.colSpan > 1) then
					for i = 1, content.colSpan - 1, 1 do
						local col = columnWidthData[columnIndex + 1];
						if (not col) then break; end
						columnIndex = columnIndex + 1;
						columnWidth = columnWidth + TABLE_SEPARATOR_WIDTH + col.finalWidth;
					end
				end

				local textArea = APII_FrameFactory:Create(self, "APII_TableTextAreaTemplate");
				textArea:SetParent(self);
				textArea:Show();
				PixelUtil.SetPoint(textArea, "TOPLEFT", self, "TOPLEFT", xOffset, -yOffset);
				textArea:SetAvailableWidth(columnWidth);
				textArea:SetPadding(TABLE_SPACING_HORIZONTAL, TABLE_SPACING_HORIZONTAL, TABLE_SPACING_VERTICAL, TABLE_SPACING_VERTICAL);
				local text = content and content.text or "";
				textArea:SetText(text, blockData.font);
				textArea:SetBackgroundColor(rowColor);
				tinsert(self.textAreas, textArea);
				tinsert(rowFrames, textArea);
				local areaHeight = textArea:GetHeight();
				rowHeight = max(rowHeight, areaHeight);
				xOffset = xOffset + columnWidth;

				columnIndex = columnIndex + 1;
			end

			for k, frame in ipairs(rowFrames) do
				frame:SetHeight(rowHeight);
			end
			wipe(rowFrames);

			yOffset = yOffset + rowHeight;
		end

		local totalWidth = width - scalableSpace;
		self.Background:SetHeight(yOffset + TABLE_SEPARATOR_WIDTH);
		self.Background:SetWidth(totalWidth);
		self.Background:ClearAllPoints();
		self.Background:SetPoint("TOPLEFT", leftPadding, 0);
		self.Background:SetColorTexture(TABLE_BORDER_COLOR:GetRGBA());

		self:SetHeight(yOffset + topPadding + bottomPadding + TABLE_SEPARATOR_WIDTH * 2);
	end
end

--------------------------------
-- SystemButton
--------------------------------

APII_SystemButtonMixin = CreateFromMixins(CallbackRegistryMixin);

APII_SystemButtonMixin:GenerateCallbackEvents(
	{
		"OnClick";
	}
);

function APII_SystemButtonMixin:Initialize(data)
	self.data = data;
	self.Name:SetText(data.Name);
	local namespace = data.Namespace and APII_NAMESPACE_COLOR:WrapTextInColorCode(data.Namespace) or "";
	self.Namespace:SetText(namespace);

	self.SelectedHighlight:SetShown(APII.openedSystem == data);
end

function APII_SystemButtonMixin:OnClick()
	self:TriggerEvent(APII_SystemButtonMixin.Event.OnClick, self.data);
end

local APII_TableContstants = {
	IsHeader = true;
}

local APII_TableContentMixin = {};
do
	local function CreateRowTable(isHeader)
		local t = {
			content = {};
			isHeader = isHeader;
		}
		return t;
	end

	function APII_TableContentMixin:Init()
		self.rowData = {};
		self.currentRow = nil;
	end

	function APII_TableContentMixin:StartRow(isHeader)
		self.currentRow = CreateRowTable(isHeader);
		tinsert(self.rowData, isHeader and 1 or (#self.rowData + 1), self.currentRow);
	end

	function APII_TableContentMixin:AddRowText(text, colSpan, preventScale)
		if (not self.currentRow) then
			self:StartRow();
		end

		local stringWidth = StringTester:TestUnboundWidth(text);
		local entry = {
			text = text;
			width = stringWidth;
			colSpan = colSpan;
			preventScale = preventScale;
		};
		tinsert(self.currentRow.content, entry);
	end

	function APII_TableContentMixin:SetRowStride(stride)
		self.currentRow.stride = stride;
	end
end

--------------------------------
-- Content Block Data Manager
--------------------------------

APII_ContentBlockDataManagerMixin = {};

do
	local LEFT_PADDING_DEFAULT = 40;
	local LEFT_PADDING_INDENTED = 50;
	local RIGHT_PADDING_DEFAULT = 40;
	local BOTTOM_PADDING_DEFAULT = 14;
	local BOTTOM_PADDING_NEWLINE = 4;
	local BOTTOM_PADDING_TITLE = 6;

	local function AddFieldSecretToTableData(tableData, fieldInfo)
		local line = "";
		if (fieldInfo.ConditionalSecret) then
			line = APII_COMMENT_COLOR:WrapTextInColorCode("ConditionalSecret");
		elseif (fieldInfo.NeverSecret) then
			line = APII_COMMENT_COLOR:WrapTextInColorCode("NeverSecret");
		elseif (fieldInfo.ConditionalSecretContents) then
			line = APII_COMMENT_COLOR:WrapTextInColorCode("ConditionalSecretContents");
		elseif ( fieldInfo.NeverSecretContents) then
			line = APII_COMMENT_COLOR:WrapTextInColorCode("NeverSecretContents");
		end
		tableData:AddRowText(line);
	end

	local function AddFieldRowToTableData(tableData, index, fieldInfo, hasSecret)
		tableData:StartRow();

		if (index) then
			tableData:AddRowText(index..".");
		end

		tableData:AddRowText(fieldInfo:GenerateAPILink());

		local typeText = fieldInfo:GetLuaType();
		if (fieldInfo.Mixin) then
			local mixinString = string.format(" (|Hapi:mixin:%s|h%s|h)", fieldInfo.Mixin, fieldInfo.Mixin);
			typeText = typeText .. APII_MIXIN_COLOR:WrapTextInColorCode(mixinString);
		end
		if (fieldInfo:IsOptional()) then
			if (fieldInfo.Default ~= nil) then
				local line = string.format(" (default:%s)", tostring(fieldInfo.Default));
				typeText = typeText .. APII_COMMENT_COLOR:WrapTextInColorCode(line);
			else
				typeText = typeText .. APII_COMMENT_COLOR:WrapTextInColorCode(" (optional)");
			end
		end
		tableData:AddRowText(typeText);

		if (hasSecret) then
			AddFieldSecretToTableData(tableData, fieldInfo);
		end

		if (fieldInfo.Documentation) then
			local documentationString = table.concat(fieldInfo.Documentation, " ");
			documentationString = APII_COMMENT_COLOR:WrapTextInColorCode(documentationString);
			tableData:AddRowText(documentationString);
		end

		local stride = fieldInfo:GetStrideIndex() or 0;
		if (stride > 0) then
			tableData:SetRowStride(stride);
		end
	end

	local function GenerateSecretAspectString(aspectTable)
		if (not aspectTable) then return; end
		
		local secretAspectAPI = APIDocumentation:FindAPIByName("table", "SecretAspect");
		local labels = {};
		for k, v in ipairs(aspectTable) do
			local label = "Enum.SecretAspect." .. SecretAspectTranslator(v);
			label = string.format("|cff%s|Hapi:%s:%s:%s|h%s|h|r", secretAspectAPI:GetLinkHexColor(), secretAspectAPI:GetType(), secretAspectAPI:GetName(), secretAspectAPI:GetParentName(), label);
			tinsert(labels, label);
		end
		return table.concat(labels, ", ");
	end

	local function CreateFieldsTableData(fieldsTable, fieldFunc, defaultLabels)
		local tableData = CreateAndInitFromMixin(APII_TableContentMixin);
		defaultLabels = defaultLabels or {};
		local hasNote = false;
		local hasSecret = false;
		for i, fieldInfo in ipairs(fieldsTable) do
			hasNote = hasNote or fieldInfo.Documentation ~= nil;
			hasSecret = hasSecret or fieldInfo.ConditionalSecret or fieldInfo.NeverSecret or fieldInfo.ConditionalSecretContents or fieldInfo.NeverSecretContents;
		end

		local variableStride = 0;
		for index, fieldInfo in ipairs(fieldsTable) do
			local stride = fieldInfo.GetStrideIndex and fieldInfo:GetStrideIndex() or 0;
			variableStride = stride or variableStride;
			fieldFunc(index, fieldInfo, tableData, hasSecret);
		end

		if (variableStride > 0) then
			tableData:StartRow();
			tableData:SetRowStride(variableStride);
			tableData:AddRowText(APII_VARIABLE_FIELD_COLOR:WrapTextInColorCode("..."));
			local strideText = VARIABLE_REPEATS;
			if (variableStride > 1) then
				strideText = string.format(VARIABLE_REPEATS_MULTIPLE, variableStride);
			end
			tableData:AddRowText(APII_VARIABLE_FIELD_COLOR:WrapTextInColorCode(strideText), 5);
		end

		if (hasSecret) then
			tinsert(defaultLabels, ARENA_NAME_FONT_COLOR:WrapTextInColorCode("Secret"));
		end
		if (hasNote) then
			tinsert(defaultLabels, ARENA_NAME_FONT_COLOR:WrapTextInColorCode("Note"));
		end

		if (#defaultLabels > 0) then
			tableData:StartRow(APII_TableContstants.IsHeader);
			for k, label in ipairs(defaultLabels) do
				tableData:AddRowText(ARENA_NAME_FONT_COLOR:WrapTextInColorCode(label));
			end
		end

		return tableData;
	end

	function APII_ContentBlockDataManagerMixin:Init(apiInfo)
		self.dataBlocks = {};

		local isConstant = apiInfo.Type == "Constants";

		do
			local text = PART_OF_NO_SYSTEM;
			if (apiInfo.System and not apiInfo.System.isFake) then
				text = string.format(PART_OF_SYSTEM, apiInfo.System:GenerateAPILink());
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
				if (apiInfo.Type == "Enumeration") then
					self:AddFieldBlock("Num Values: " .. apiInfo.NumValues);
					self:AddFieldBlock("Min Value: " .. apiInfo.MinValue);
					self:AddFieldBlock("Max Value: " .. apiInfo.MaxValue, true);
					self:AddTitleBlock("Values");

					local function fieldsFunc(index, fieldInfo, tableData, hasSecret)
						tableData:StartRow();
						tableData:AddRowText(fieldInfo:GetLuaType());
						tableData:AddRowText(fieldInfo:GenerateAPILink());
						if (hasSecret) then
							AddFieldSecretToTableData(tableData, fieldInfo);
						end
						if (fieldInfo.Documentation) then
							local documentationString = table.concat(fieldInfo.Documentation, " ");
							documentationString = APII_COMMENT_COLOR:WrapTextInColorCode(documentationString);
							tableData:AddRowText(documentationString);
						end
					end

					local tableData = CreateFieldsTableData(apiInfo.Fields, fieldsFunc, {"Value", "Name"});

					self:AddTableDataBlock(tableData);
				else
					self:AddTitleBlock("Fields");

					local function fieldsFunc(index, fieldInfo, tableData, hasSecret)
						AddFieldRowToTableData(tableData, nil, fieldInfo, hasSecret);
					end

					local tableData = CreateFieldsTableData(apiInfo.Fields, fieldsFunc, {"Name", "Type"});

					self:AddTableDataBlock(tableData);
				end
			end

			if (apiInfo.Values and #apiInfo.Values > 0) then
				self:AddTitleBlock("Values");

				local function fieldsFunc(index, fieldInfo, tableData, hasSecret)
					tableData:StartRow();
					tableData:AddRowText(fieldInfo:GenerateAPILink());
					local value = tostring(fieldInfo:GetValue());
					tableData:AddRowText(value);
					tableData:AddRowText(fieldInfo:GetLuaType());
				end

				local tableData = CreateFieldsTableData(apiInfo.Values, fieldsFunc, { "Name", "Value", "Type" });

				self:AddTableDataBlock(tableData);
			end

		elseif (dataType == "event" and apiInfo.Payload) then
			self:AddTitleBlock("Payload");

			local function fieldsFunc(index, fieldInfo, tableData, hasSecret)
				AddFieldRowToTableData(tableData, index, fieldInfo, hasSecret);
			end

			local tableData = CreateFieldsTableData(apiInfo.Payload, fieldsFunc, { "#", "Name", "Type" });

			self:AddTableDataBlock(tableData);
		end

		do
			local metaTable = {};
			local predicateLabels = {};

			for key, value in pairs(apiInfo) do
				if (type(value) == "boolean" and key ~= UNDOCUMENTED_LABEL) then
					local label = key;
					if (not value) then
						label = label .. APII_COMMENT_COLOR:WrapTextInColorCode(" (false)");
					end
					tinsert(predicateLabels, label);
				end
			end

			if (#predicateLabels > 0) then
				local t = {
					APII_FIELDS_COLOR:WrapTextInColorCode("Predicates");
					table.concat(predicateLabels, ", ");
				}
				tinsert(metaTable, t);
			end

			if (apiInfo.SecretArgumentsAddAspect) then
				local t = {
					APII_FIELDS_COLOR:WrapTextInColorCode("SecretArgumentsAddAspect");
					GenerateSecretAspectString(apiInfo.SecretArgumentsAddAspect);
				}
				tinsert(metaTable, t);
			end

			if (apiInfo.SecretReturnsForAspect) then
				local t = {
					APII_FIELDS_COLOR:WrapTextInColorCode("SecretReturnsForAspect");
					GenerateSecretAspectString(apiInfo.SecretReturnsForAspect);
				}
				tinsert(metaTable, t);
			end

			if (apiInfo.SecretArguments) then
				local t = {
					APII_FIELDS_COLOR:WrapTextInColorCode("SecretArguments");
					apiInfo.SecretArguments;
				}
				tinsert(metaTable, t);
			end

			if (#metaTable > 0) then
				self:AddTitleBlock("Metadata");

				local function fieldsFunc(index, fieldInfo, tableData, hasSecret)
					tableData:StartRow();
					for k, v in ipairs(fieldInfo) do
						tableData:AddRowText(v);
					end
				end

				local tableData = CreateFieldsTableData(metaTable, fieldsFunc);
				self:AddTableDataBlock(tableData);
			end
		end

		if (apiInfo.Documentation) then
			self:AddTitleBlock("Notes");
			for i, documentation in ipairs(apiInfo.Documentation) do
				if (DOCUMENTATION_TO_COLOR_RED[documentation]) then
					documentation = APII_NO_PUBLIC_COLOR:WrapTextInColorCode(documentation);
				end
				self:AddFieldBlock(documentation, i == #apiInfo.Documentation);
			end
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
		block.font = font or GetFont(TextScaleEnum.Normal);
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

	function APII_ContentBlockDataManagerMixin:AddFieldBlock(text, isLast)
		local block = self:AddIndentedBlock(text);
		if (not isLast) then
			block.bottomPadding = BOTTOM_PADDING_NEWLINE;
		end
		return block;
	end

	function APII_ContentBlockDataManagerMixin:AddTitleBlock(text)
		local block = self:AddBasicBlock(text, GetFont(TextScaleEnum.Big))
		block.bottomPadding = BOTTOM_PADDING_TITLE;
		return block;
	end

	function APII_ContentBlockDataManagerMixin:AddCopyStringBlock(text)
		local block = self:AddBasicBlock(text);
		block.template = "APII_TextBlockCopyStringTemplate";
		return block;
	end

	function APII_ContentBlockDataManagerMixin:AddTableBlock(text, tableContent, index, isLast)
		local block = self:AddBasicBlock(text);
		block.template = "APII_TextBlockTableTemplate";
		block.tableContent = tableContent;
		block.index = index;
		block.leftPadding = LEFT_PADDING_INDENTED;
		if (not isLast) then
			block.bottomPadding = 0;
		end
		return block;
	end

	function APII_ContentBlockDataManagerMixin:AddTableDataBlock(tableData)
		local block = self:AddBasicBlock();
		block.template = "APII_TextBlockTableTemplate";
		block.tableData = tableData;
		block.leftPadding = LEFT_PADDING_INDENTED;
		return block;
	end

	function APII_ContentBlockDataManagerMixin:AddFunctionArguments(label, argumentTable)
		if (not argumentTable or #argumentTable == 0) then return; end
		self:AddTitleBlock(label);

		local function fieldsFunc(index, fieldInfo, tableData, hasSecret)
			AddFieldRowToTableData(tableData, index, fieldInfo, hasSecret);
		end

		local tableData = CreateFieldsTableData(argumentTable, fieldsFunc, { "#", "Param", "Type" });


		self:AddTableDataBlock(tableData);
	end
end

--------------------------------
-- Content Block Manager
--------------------------------

APII_ContentBlockManagerMixin = {};

function APII_ContentBlockManagerMixin:Init(ownerFrame)
	self.ownerFrame = ownerFrame;
	self.activeBlocks = {};
	self.reusableBlocks = {};
end

function APII_ContentBlockManagerMixin:MakeBlocksActiveReusable()
	local temp = self.reusableBlocks;
	self.reusableBlocks = self.activeBlocks;
	self.activeBlocks = temp;
end

function APII_ContentBlockManagerMixin:GetBlockOfType(frameTemplate)
	if (not self.ownerFrame) then return; end

	local block = nil;
	local reusableBlocks = self.reusableBlocks[frameTemplate];
	if (reusableBlocks and #reusableBlocks > 0) then
		block = reusableBlocks[1];
		block:ClearAllPoints();
		tremove(reusableBlocks, 1);
	end

	if (not block) then
		block = APII_FrameFactory:Create(self.ownerFrame, frameTemplate);
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
	if (not self.ownerFrame) then return; end

	for template, templateBlocks in pairs(self.reusableBlocks) do
		for k, block in ipairs(templateBlocks) do
			APII_FrameFactory:Release(block);
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

--------------------------------
-- System Content Mixin
--------------------------------

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

function APII_SystemContentMixin:Initialize(data, expanded)
	self.data = data;
	local apiInfo = data;
	local totalHeight = 0;
	self.isExpanded = expanded;

	if (not self.contentBlockManager) then
		self.contentBlockManager = CreateAndInitFromMixin(APII_ContentBlockManagerMixin, self);
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

--------------------------------
-- Core mixin
--------------------------------

APII_CoreMixin = {};

function APII_CoreMixin:GetInSystemBanner()
	return self.SystemContent.InSystemBanner;
end

function APII_CoreMixin:GetSystemContentSearch()
	return self.SystemContentScrollInset.SystemContent.SystemContentSearch;
end

function APII_CoreMixin:GetSystemContentScrollBox()
	return self.SystemContentScrollInset.SystemContent.SystemContentScrollBox;
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

function APII_CoreMixin:GetHighlightToggleButton()
	return self.TopBar.HighlightToggleButton;
end

function APII_CoreMixin:OnSizeChanged()
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
				else
					previousHistory.generalSearch = generalSearchText;
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
				else
					previousHistory.systemSearch = systemSearchText;
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
				else
					previousHistory.contentSearch = contentSearchText;
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
	coreFrame:UpdateSystemContent(ScrollBoxConstants.DiscardScrollPosition);

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
	self:RegisterEvent("PLAYER_REGEN_DISABLED");
	self:SetScript("OnEvent", function(_, event, ...) self[event](self, ...) end)

	self.debug = APII;

	self.history = {};
	self.historyIndex = 0;
	self:UpdateHistoryButtons();
	self:UpdateGlobalSearchDropdown();

	ButtonFrameTemplate_HidePortrait(self)
	self:SetClampedToScreen(true);
	self:SetTitle("APIInterface");
	self:SetResizeBounds(250, 200);

	self.Bg:SetPoint("BOTTOMRIGHT", self, -2, 3);

	local generalSearch = self:GetGeneralSearch();

	do
		local function OnSystemClick(_, systemData)
			local scrollTo = APII.openedSystem == nil;
			self:OpenSystem(systemData);
			if (scrollTo) then
				local systemScroll = self:GetSystemScrollBox();
				systemScroll:ScrollToElementData(systemData, ScrollBoxConstants.AlignNearest);
			end
		end

		local view = CreateScrollBoxListLinearView();
		view:SetElementInitializer("APII_SystemButtonTemplate", function(frame, data)
			frame:Initialize(data);
			frame:RegisterCallback(APII_SystemButtonMixin.Event.OnClick, OnSystemClick, self);
		end);
		view:SetElementResetter(function(frame, data)
			frame:UnregisterCallback(APII_SystemButtonMixin.Event.OnClick, self);
		end);

		local systemScrollBox = self:GetSystemScrollBox();
		ScrollUtil.InitScrollBoxListWithScrollBar(systemScrollBox, self.SystemScrollBar, view);
	end

	do
		local padding = 0;
		local paddingBottom = 1;
		local paddingRight = 0;
		local spacing = 0;
		local view = CreateScrollBoxListLinearView(padding, paddingBottom, padding, paddingRight, spacing);
		local systemContentScrollBox = self:GetSystemContentScrollBox();

		local function ToggleAPI(_, api)
			local scrollTo = false;
			if (APII.openedAPIs[api]) then
				APII.openedAPIs[api] = nil;
				self:AddHistory(APII_HistoryReason.APIClose, api);
			else
				APII.openedAPIs[api] = true;
				self:AddHistory(APII_HistoryReason.APIOpen, api);
				scrollTo = true;
			end

			systemContentScrollBox:SetDataProvider(systemContentScrollBox:GetDataProvider(), ScrollBoxConstants.RetainScrollPosition);

			if (scrollTo) then
				systemContentScrollBox:ScrollToElementData(api, ScrollBoxConstants.AlignNearest);
			end
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

				local differentSystem = systemToOpen ~= APII.openedSystem;

				if(systemToOpen) then
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
					local align = differentSystem and ScrollBoxConstants.AlignCenter or ScrollBoxConstants.AlignNearest;
					systemContentScrollBox:ScrollToElementData(apiToShow, align);
				end
			end
		end

		view:SetElementInitializer("APII_SystemContentTemplate", function(frame, data)
			frame:RegisterCallback(APII_SystemContentMixin.Event.ExpandToggled, ToggleAPI, self);
			frame:RegisterCallback(APII_SystemContentMixin.Event.OnHyperlinkClick, OnHyperlinkClick, self);
			frame:Initialize(data, APII.openedAPIs[data]);
			frame:SetHyperlinkingEnabled(self:IsHyperlinkingActive());
		end);
		view:SetElementResetter(function(frame, data)
			frame:UnregisterCallback(APII_SystemContentMixin.Event.ExpandToggled, self);
			frame:UnregisterCallback(APII_SystemContentMixin.Event.OnHyperlinkClick, self);
		end);
		view:SetElementExtentCalculator(function (index, data)
			local dummy = systemContentScrollBox.ContentDummy;
			dummy:Initialize(data, APII.openedAPIs[data]);
			return dummy:GetHeight();
		end);

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
		end, self);
	end

	local systemContentSearch = self:GetSystemContentSearch();
	systemContentSearch:RegisterCallback(APII_SearchboxMixin.Event.OnTextChanged, function(_, text, userInput)
		if (not userInput) then return; end
			self:UpdateSystemContent(ScrollBoxConstants.DiscardScrollPosition);
			self:AddHistory(APII_HistoryReason.ContentSearch);
		end, self);

	systemContentSearch:RegisterCallback(APII_SearchboxMixin.Event.OnClearButtonClicked, function()
			self:UpdateSystemContent(ScrollBoxConstants.DiscardScrollPosition);
			self:AddHistory(APII_HistoryReason.ContentSearch);
		end, self);

	local backButton = self:GetHistoryBackButton();
	backButton:RegisterCallback(APII_HistoryButtonMixin.Event.OnClick, function(_, delta) self:StepHistory(delta); end);
	backButton:SetTooltip(function()
			GameTooltip_SetTitle(GameTooltip, HISTORY_BACKWARDS);
			GameTooltip_AddInstructionLine(GameTooltip, HISTORY_BACKWARDS_TT);
		end);

	local forwardButton = self:GetHistoryForwardButton();
	forwardButton:RegisterCallback(APII_HistoryButtonMixin.Event.OnClick, function(_, delta) self:StepHistory(delta); end);
	forwardButton:SetTooltip(function()
			GameTooltip_SetTitle(GameTooltip, HISTORY_FORWARDS);
			GameTooltip_AddInstructionLine(GameTooltip, HISTORY_FORWARDS_TT);
		end);

	local highlightButton = self:GetHighlightToggleButton();
	highlightButton:RegisterCallback(APII_CheckButtonMixin.Event.OnClick, function() self:UpdateHyperlinking(); end, self);
	highlightButton:SetTooltip(function(tooltip)
			GameTooltip_SetTitle(tooltip, TOGGLE_HYPERLINKS);
			GameTooltip_AddNormalLine(tooltip, TOGGLE_HYPERLINKS_TT);
			GameTooltip_AddInstructionLine(GameTooltip, TOGGLE_HYPERLINKS_TT_SHIFT);
		end);
	
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

			if (valueType == "table" and not canaccesstable(value)) then return false; end

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
						GameTooltip_AddNormalLine(tooltip, TT_SEARCH_FUNCTIONS);
					end);
			end

			do
				local button = rootDescription:CreateButton("Tables", SearchGlobal, GlobalSearchTypes.Tables);
				button:SetTooltip(function(tooltip, description)
						GameTooltip_SetTitle(tooltip, description.text);
						GameTooltip_AddNormalLine(tooltip, TT_SEARCH_TABLES);
					end);
			end

			do
				local button = rootDescription:CreateButton("Frames", SearchGlobal, GlobalSearchTypes.Frames);
				button:SetTooltip(function(tooltip, description)
						GameTooltip_SetTitle(tooltip, description.text);
						GameTooltip_AddNormalLine(tooltip, TT_SEARCH_FRAMES);
						GameTooltip_AddColoredLine(tooltip, TT_SEARCH_FRAMES_FORBIDDEN, RED_FONT_COLOR);
					end);
			end

			do
				local button = rootDescription:CreateButton("Strings", SearchGlobal, GlobalSearchTypes.Strings);
				button:SetTooltip(function(tooltip, description)
						GameTooltip_SetTitle(tooltip, description.text);
						GameTooltip_AddNormalLine(tooltip, TT_SEARCH_STRINGS);
						GameTooltip_AddInstructionLine(GameTooltip, TT_SEARCH_STRINGS_VALUE);
						GameTooltip_AddInstructionLine(GameTooltip, TT_SEARCH_STRINGS_BOTH);
					end);
			end

			do
				local button = rootDescription:CreateButton("Values", SearchGlobal, GlobalSearchTypes.Values);
				button:SetTooltip(function(tooltip, description)
						GameTooltip_SetTitle(tooltip, description.text);
						GameTooltip_AddNormalLine(tooltip, TT_SEARCH_VALUES);
					end);
			end
		end

		local dropdown = self:GetGlobalSearchDropdown();
		dropdown.Text:SetPoint("TOP", 0, 1);
		dropdown:SetupMenu(DropdownSetup);
	end


	-- This has to be last
	local maxWidth, maxHeight = GetPhysicalScreenSize();
	self.ResizeButton:Init(self, MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT, maxWidth, maxHeight);
	self.ResizeButton:SetOnResizeStoppedCallback(function() self:OnDragStop() end)
end

function APII_CoreMixin:PLAYER_REGEN_DISABLED()
	HideUIPanel(self);
end

function APII_CoreMixin:Reset()
	self:ClearAllPoints();
	self:SetPoint("CENTER", UIParent);
	self:SetSize(MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT);
end

function APII_CoreMixin:OnUpdate()
	-- Doing this in OnUpdate because the event doesn't trigger with an editbox focused or clicking outside the game
	if (self.shiftDown ~= IsShiftKeyDown()) then
		self.shiftDown = IsShiftKeyDown();
		self:UpdateHyperlinking();
	end
end

function APII_CoreMixin:IsHyperlinkingActive()
	return self.shiftDown or self:GetHighlightToggleButton():GetChecked();
end

function APII_CoreMixin:UpdateHyperlinking()
	local highlightButton = self:GetHighlightToggleButton();
	highlightButton:SetIconHighlighted(self.shiftDown);
	local enableHyperlink = self:IsHyperlinkingActive();
	local systemContentScrollBox = self:GetSystemContentScrollBox();
	for k, frame in systemContentScrollBox:EnumerateFrames() do
		frame:SetHyperlinkingEnabled(enableHyperlink);
	end
end

function APII_CoreMixin:OnShow()
	if (not self.initialized) then
		self.initialized = true;
		if (not APIDocumentation) then
			C_AddOns.LoadAddOn("Blizzard_APIDocumentationGenerated");
		end

		APII_FIELDS_COLOR = CreateColorFromRGBHexString(FieldsAPIMixin:GetLinkHexColor());

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
	self:UpdateSystemContent(ScrollBoxConstants.DiscardScrollPosition);

	self:AddHistory(APII_HistoryReason.SystemOpen);
end

function APII_CoreMixin:UpdateSystemContent(scrollPosition)
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

		if (searchString and #searchString > 0) then
			apiMatches = APII.openedSystem:FindAllAPIMatches(searchString);
		else
			apiMatches = APII.openedSystem:ListAllAPI();
		end

		dprint("- - - -")
		dprint(apiMatches, apiMatches and #apiMatches or "");
	else
		if (searchString and #searchString > 0) then
			apiMatches = APIDocumentation:FindAllAPIMatches(searchString);
		end
	end

	local total = 0;
	local passed = 0;

	local function AddSystemContentToDateprovider(info)
		total = total + 1;
		if (InfoPassesFilters(info)) then
			dataProvider:Insert(info);
			passed = passed + 1;
		end
	end

	if (apiMatches) then
		for k, info in ipairs(apiMatches.functions) do
			AddSystemContentToDateprovider(info);
		end

		for k, info in ipairs(apiMatches.events) do
			AddSystemContentToDateprovider(info);
		end

		for k, info in ipairs(apiMatches.tables) do
			AddSystemContentToDateprovider(info);
		end
	end
	dprint(passed, "/", total);

	local systemContentScrollBox = self:GetSystemContentScrollBox();

	scrollPosition = scrollPosition == nil and ScrollBoxConstants.RetainScrollPosition or scrollPosition;
	systemContentScrollBox:SetDataProvider(dataProvider, scrollPosition);
end

function APII_CoreMixin:RequestShow(searchText)
	if (not InCombatLockdown()) then
		ShowUIPanel(self);
		self:SetGeneralSearchText(searchText);
	else
		print(ERROR_COMBAT:format(_addonName));
	end
end
