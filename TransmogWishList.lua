﻿local _addonName, _addon = ...;

local TWL = LibStub("AceAddon-3.0"):NewAddon("TransmogWishlist");
local WARDROBE_MODEL_SETUP = {
	["INVTYPE_HEAD"] 		= { useTransmogSkin = false, slots = { INVTYPE_CHEST = true,  INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = false } },
	["INVTYPE_SHOULDER"]	= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_CLOAK"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_CHEST"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_ROBE"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_TABARD"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	--["SHIRTSLOT"]		= { useTransmogSkin = true,  slots = { CHESTSLOT = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_WRIST"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_HAND"]		= { useTransmogSkin = false, slots = { INVTYPE_CHEST = true,  INVTYPE_HAND = false, INVTYPE_LEGS = true,  INVTYPE_FEET = true, INVTYPE_HEAD = true } },
	["INVTYPE_WAIST"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_LEGS"]		= { useTransmogSkin = true,  slots = { INVTYPE_CHEST = false, INVTYPE_HAND = false, INVTYPE_LEGS = false, INVTYPE_FEET = false, INVTYPE_HEAD = true } },
	["INVTYPE_FEET"]		= { useTransmogSkin = false, slots = { INVTYPE_CHEST = true, INVTYPE_HAND = true, INVTYPE_LEGS = true,  INVTYPE_FEET = false, INVTYPE_HEAD = true } },	
}
local WARDROBE_MODEL_SETUP_GEAR = {
	["INVTYPE_CHEST"] = 78420,
	["INVTYPE_ROBE"] = 78420,
	["INVTYPE_LEGS"] = 78425,
	["INVTYPE_FEET"] = 78427,
	["INVTYPE_HAND"] = 78426,
	["INVTYPE_HEAD"] = 78416,
}

local TWL_DEFAULTS = {
	global = {	
		wishList = {};
	}
}


function TWL:UpdateAllWishButtons()
	local models = WardrobeCollectionFrame.ItemsCollectionFrame.Models;
	
	for k, model in ipairs(models) do
		model.TWLWishButton:Update();
	end
end

TransmogWishListDataProviderMixin = {}

function TransmogWishListDataProviderMixin:OnLoad()
	self.wishList = {};
	self.waitingList = {}; -- For when data doesn't load right away
	self.lastAddition = nil;
end

function TransmogWishListDataProviderMixin:Sort()
	if #self.wishList < 2 then return; end
	table.sort(self.wishList, function (a, b) 
			if a.obtainable ~= b.obtainable then
				return a.obtainable and not b.obtainable;
			end
			if a.isArmor ~= b.isArmor then
				return a.isArmor and not b.isArmor;
			end
			if a.equipLocation ~= b.equipLocation then
				return a.equipLocation < b.equipLocation;
			end
			return a.visualID < b.visualID;
		end)
end

function TransmogWishListDataProviderMixin:RemoveByVisualID(appearanceID)
	for i = #self.wishList, 1, -1 do
		if (self.wishList[i].visualID == appearanceID) then
			table.remove(self.wishList, i);
			return;
		end
	end
end

function TransmogWishListDataProviderMixin:GetListItemByVisualID(visualID, sourceID)
	for k, item in ipairs(self.wishList) do
		if (item.visualID == visualID ) then
			return item;
		end
	end
end

function TransmogWishListDataProviderMixin:HasObtainableSource(visualID, sourceID)
	if (select(2, C_TransmogCollection.PlayerCanCollectSource(sourceID))) then
		return true;
	end

	local sources = C_TransmogCollection.GetAppearanceSources(visualID);
	if sources then
		for k, source in ipairs(sources) do
			if select(2, C_TransmogCollection.PlayerCanCollectSource(source.sourceID)) then
				return true;
			end
		end
	end
	
	return false;
end

function TransmogWishListDataProviderMixin:LoadSaveData(data)
	self.wishList = data;
	self.loadingSaveData = true;
	
	-- update obtainability for current character
	for k, itemInfo in ipairs(self.wishList) do
		itemInfo.obtainable = self:HasObtainableSource(itemInfo.visualID, itemInfo.sourceID);
	end
	self:Sort();
	self.loadingSaveData = false;
end

function TransmogWishListDataProviderMixin:AddVisualIDToList(visualID)
	if not type(visualID) == "number" then return; end
	
	local sources = C_TransmogCollection.GetAppearanceSources(visualID)

	--UIParentLoadAddOn("Blizzard_DebugTools");
	--DisplayTableInspectorWindow(sources)

	self:AddItemIDToList(sources[1].itemID, sources[1].itemModID);
end

function TransmogWishListDataProviderMixin:AddItemIDToList(itemID, modID)
	if not type(itemID) == "number" then return; end
	--print(itemID, modID, C_TransmogCollection.GetItemInfo(itemID, modID))
	local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemID, modID);
	if not appearanceID then
		print("Invalid item ID.");
		return;
	end
	
	local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
	
	if sourceInfo.isCollected then
		print("You already unlocked the appearance of this item.");
		return;
	end
	
	if not self:GetListItemByVisualID(appearanceID, sourceID) then
		local name, link, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemID, modID);
		if not link then
			self.waitingList[itemID] = {["itemID"] = itemID, ["modID"] = modID};
			--print("Waiting for item data");
			return;
		end
		local obtainable = select(2, C_TransmogCollection.PlayerCanCollectSource(sourceID));
		local isArmor = WARDROBE_MODEL_SETUP[itemEquipLoc] and true or false;
		local item = {["itemID"] = itemID, ["visualID"] = appearanceID, ["collected"] = false, ["sourceID"] = sourceID, ["isArmor"] = isArmor, ["equipLocation"] = itemEquipLoc, ["obtainable"] = self:HasObtainableSource(appearanceID, sourceID)};
		self.lastAddition = item;
		table.insert(self.wishList, item);
		print("Appearance of " .. name .. " ".. link .. " added to your wishlist (".. appearanceID ..").");
		self:Sort();
		
		TransmogWishListFrame:Update();
		-- Update in case we added something that was currently visible
		TWL:UpdateAllWishButtons();
	else
		print("The appearance of this item is already on your wishlist.")
	end
end

function TransmogWishListDataProviderMixin:EnumerateWishList()
	return ipairs(self.wishList);
end

function TransmogWishListDataProviderMixin:GetWishList()
	return self.wishList;
end

function TransmogWishListDataProviderMixin:MarkAppearanceIDCollected(appearanceID)
	if self.wishList[appearanceID] then
		self.wishList[appearanceID] = 1;
	end
end

local _wishListDataProvider = CreateFromMixins(TransmogWishListDataProviderMixin);


TransmogWishListMixin = {};

function TransmogWishListMixin:OnLoad() 
	_wishListDataProvider:OnLoad();
	
	self.NUM_ROWS = 3;
	self.NUM_COLS = 6;
	self.PAGE_SIZE = self.NUM_ROWS * self.NUM_COLS;
	
	self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED");
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("GET_ITEM_INFO_RECEIVED");
	self:RegisterEvent("TRANSMOG_COLLECTION_ITEM_UPDATE");

	self:SetScript("OnEvent", function(self, event, ...) self:OnEvent(event, ...) end)
end

function TransmogWishListMixin:OnEvent(event, ...)
	if (event == "ADDON_LOADED") then
		local addon = ...;
		if (addon ==  "Blizzard_Collections") then
			self:StickToItemCollectionFrame();
			self:UnregisterEvent("ADDON_LOADED");
		end
		return;
	end

	if (event == "TRANSMOG_COLLECTION_UPDATED") then
		self:Update();
		local appearanceID, c = C_TransmogCollection.GetLatestAppearance();
		if not appearanceID then return end

		for k, item in _wishListDataProvider:EnumerateWishList() do
			if (item.visualID == appearanceID and not item.collected) then
				print("You unlocked an appearance from your wishlist!");
				_wishListDataProvider:RemoveByVisualID(appearanceID);
				item.collected = true;
				TransmogWishListFrame:Update();
				return;
			end
		end
		return;
	end
	
	if (event == "GET_ITEM_INFO_RECEIVED") then
		local itemID = ...;
		local waiting = _wishListDataProvider.waitingList[itemID];
		if (waiting) then
			_wishListDataProvider:AddItemIDToList(waiting.itemID, waiting.modID);
			_wishListDataProvider.waitingList[itemID] = nil;
		end
		return;
	end
	--print(event, ...)
	if (event == "TRANSMOG_COLLECTION_ITEM_UPDATE") then
		-- if no lastAddition it's because we loaded save data
		-- we just started the game and don't have data cached yet
		if (not _wishListDataProvider.lastAddition) then
			for k, item in _wishListDataProvider:EnumerateWishList() do
				local obtainable = item.obtainable;
				item.obtainable = _wishListDataProvider:HasObtainableSource(item.visualID, item.sourceID);
				if (obtainable ~= item.obtainable) then
					_wishListDataProvider:Sort();
					self:Update();
				end
			end
		else
			local item = _wishListDataProvider.lastAddition;
			local obtainable = item.obtainable;
			item.obtainable = _wishListDataProvider:HasObtainableSource(item.visualID, item.sourceID);
			if (obtainable ~= item.obtainable) then
				_wishListDataProvider:Sort();
				self:Update();
			end
		end
		return;
	end
	
end

function TransmogWishListMixin:OnShow() 
	WardrobeCollectionFrameSearchBox:Hide();
	WardrobeCollectionFrame.FilterButton:Hide();
end

function TransmogWishListMixin:OnHide() 
	WardrobeCollectionFrameSearchBox:Show();
	WardrobeCollectionFrame.FilterButton:Show();	
end

function TransmogWishListMixin:OnEnter() 
	for k, model in pairs(self.Models) do
		model.RemoveButton:Hide();
	end
end

function TransmogWishListMixin:StickToItemCollectionFrame()
	-- Stuff we have to after Blizzard_Collections is loaded as it doesn't do so until you open it the first time
	local collectionFrame = WardrobeCollectionFrame.ItemsCollectionFrame;
	
	self:SetParent(collectionFrame);
	--WardrobeCollectionFrame.ItemsCollectionFrame:Hide()
	self:SetFrameLevel(15);
	self:SetAllPoints();
	
	TransmogWishListButton:SetParent(collectionFrame);
	TransmogWishListButton:SetPoint("BOTTOMRIGHT", collectionFrame, "BOTTOMRIGHT", -75, 42);
	
	for k, model in ipairs(collectionFrame.Models) do
		model.TWLWishButton = CreateFrame("FRAME", nil, model, "TWLWishButtonTemplate");
		model:HookScript("OnEnter", function(self)
				self.TWLWishButton:Show();
				self.TWLWishButton:Update(true);
			end)
		model:HookScript("OnLeave", function(self)
				TWL:UpdateAllWishButtons()
			end)
		--SetPortraitToTexture(model.TWLWishButton.texture, "Interface/ICONS/Spell_Holy_PrayerOfMendingtga");
		-- model.TWLWishButton:ClearAllPoints();
		-- model.TWLWishButton:SetPoint("TOPRIGHT");
		-- model.TWLWishButton:Show();
		-- print(model.TWLWishButton);
	end
	
	hooksecurefunc("WardrobeCollectionFrame_SetTab", function(...) 
			local tabID = ...;
			if (tabID == 1) then
				self:Hide();
			end
		end) 
	
	hooksecurefunc(collectionFrame, "UpdateItems", function(...)
			TWL:UpdateAllWishButtons();
		end);
	
end

function TransmogWishListMixin:OnMouseWheel(delta)
	self.PagingFrame:OnMouseWheel(delta);
end

function TransmogWishListMixin:OnPageChanged(userAction)
	PlaySound(SOUNDKIT.UI_TRANSMOG_PAGE_TURN);
	if ( userAction ) then
		self:Update();
	end
end

function TransmogWishListMixin:Update()
	local wishList = _wishListDataProvider.wishList;
	self.PagingFrame:SetMaxPages(ceil(#wishList / self.PAGE_SIZE));
	local indexOffset = (self.PagingFrame:GetCurrentPage() - 1) * self.PAGE_SIZE;
	for i=1, self.PAGE_SIZE do
		local model = self.Models[i];
		local index = indexOffset + i;
		local itemInfo = wishList[index];
		if itemInfo then
			model:Show();
			model.itemInfo = itemInfo;
			model:SetKeepModelOnHide(true);
			model:ShowWishlistItem();
		else
			model:Hide();
		end
	end
	
	if true then return end
	for k, v in ipairs(self.Models) do
		local cameraID = C_TransmogCollection.GetAppearanceCameraID(item.visualID);
		v:SetUnit("player");
		Model_ApplyUICamera(v, cameraID);
		v:TryOn(item.sourceID)
		v:Show();
	end
end


TransMogWishListModelMixin = {};

function TransMogWishListModelMixin:OnLoad()
	self:SetAutoDress(false);
	for slot, id in pairs(WARDROBE_MODEL_SETUP_GEAR) do
		self:TryOn(id);
	end
end

function TransMogWishListModelMixin:OnModelLoaded()
	if (self.itemInfo) then
		self:ShowWishlistItem(true);
	end
end

function TransMogWishListModelMixin:OnEnter()
	local sources = C_TransmogCollection.GetAppearanceSources(self.itemInfo.visualID);
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	local itemName, _, titleQuality = GetItemInfo(self.itemInfo.itemID);
	GameTooltip:SetText(itemName, GetItemQualityColor(titleQuality or 1));
	if sources then 
		GameTooltip:AddLine("Available sources");
		for k, source in ipairs(sources) do
			GameTooltip:AddLine(source.name, GetItemQualityColor(source.quality or 1))
			if source.sourceType == TRANSMOG_SOURCE_BOSS_DROP then
				local drops = C_TransmogCollection.GetAppearanceSourceDrops(source.sourceID);
				for k, drop in pairs(drops) do
					GameTooltip:AddDoubleLine(drop.instance, drop.encounter, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75);
				end
			else
				GameTooltip:AddLine( _G["TRANSMOG_SOURCE_" .. source.sourceType], 0.75, 0.75, 0.75)
			end
		end
	elseif self.itemInfo.obtainable then
		GameTooltip:AddLine("No source data available.");
	end
	
	if not self.itemInfo.obtainable then
		GameTooltip:AddLine("Cannot be obtained on this character.", 1, 0.25, 0.25)
	end
	GameTooltip:Show();
	
	self.RemoveButton:Show();
end

function TransMogWishListModelMixin:OnLeave()
	self.RemoveButton:Hide();
	GameTooltip:Hide();
end

function TransMogWishListModelMixin:RemoveButtonOnClick()
	_wishListDataProvider:RemoveByVisualID(self.itemInfo.visualID);
	self:GetParent():Update();
end

function TransMogWishListModelMixin:ShowWishlistItem(skipModel)
	local cameraID;
	local itemInfo = self.itemInfo;
	self:Undress();
	
	if itemInfo.isArmor then
		cameraID = C_TransmogCollection.GetAppearanceCameraIDBySource(itemInfo.sourceID);
		if not skipModel then
			self:SetUnit("player", false);
		end
		self:SetUseTransmogSkin(WARDROBE_MODEL_SETUP[itemInfo.equipLocation].useTransmogSkin);
		for slot, equip in pairs(WARDROBE_MODEL_SETUP[itemInfo.equipLocation].slots) do
			if ( equip ) then
				self:TryOn(WARDROBE_MODEL_SETUP_GEAR[slot]);
			end
		end
		self:TryOn(itemInfo.sourceID)
	else
		cameraID = C_TransmogCollection.GetAppearanceCameraIDBySource(itemInfo.sourceID);
		if not skipModel then
			self:SetItemAppearance(itemInfo.visualID)
		end
	end
	
		Model_ApplyUICamera(self, cameraID);
		self.cameraID = cameraID;
	if (itemInfo.collected) then
		self.NewString:Show();
		self.NewString:SetText("You did it!")
	end
	if itemInfo.obtainable then
		self.Border:SetAtlas("transmog-wardrobe-border-collected");
	else
		self.Border:SetAtlas("transmog-wardrobe-border-unusable");
	end
end

		
TransmogWishListPagingMixin = { };

function TransmogWishListPagingMixin:OnLoad()
	self.currentPage = 1;
	self.maxPages = 1;
	self:Update();
end

function TransmogWishListPagingMixin:SetMaxPages(maxPages)
	maxPages = math.max(maxPages, 1);
	if ( self.maxPages == maxPages ) then
		return;
	end
	self.maxPages= maxPages;
	if ( self.maxPages < self.currentPage ) then
		self.currentPage = self.maxPages;
	end
	self:Update();
end

function TransmogWishListPagingMixin:GetMaxPages()
	return self.maxPages;
end

function TransmogWishListPagingMixin:SetCurrentPage(page, userAction)
	page = Clamp(page, 1, self.maxPages);
	if ( self.currentPage ~= page ) then
		self.currentPage = page;
		self:Update();
		if ( self:GetParent().OnPageChanged ) then
			self:GetParent():OnPageChanged(userAction);
		end
	end
end

function TransmogWishListPagingMixin:GetCurrentPage()
	return self.currentPage;
end

function TransmogWishListPagingMixin:NextPage()
	self:SetCurrentPage(self.currentPage + 1, true);
end

function TransmogWishListPagingMixin:PreviousPage()
	self:SetCurrentPage(self.currentPage - 1, true);
end

function TransmogWishListPagingMixin:OnMouseWheel(delta)
	if ( delta > 0 ) then
		self:PreviousPage();
	else
		self:NextPage();
	end
end

function TransmogWishListPagingMixin:Update()
	self.PageText:SetFormattedText(COLLECTION_PAGE_NUMBER, self.currentPage, self.maxPages);
	if ( self.currentPage <= 1 ) then
		self.PrevPageButton:Disable();
	else
		self.PrevPageButton:Enable();
	end
	if ( self.currentPage >= self.maxPages ) then
		self.NextPageButton:Disable();
	else
		self.NextPageButton:Enable();
	end
end
		
		
TWLWishButtonMixin = {}

function TWLWishButtonMixin:Update(enteredParent)
	
	local visualInfo = self:GetParent().visualInfo;
	
	-- no isHideVisual == enchant
	if (not visualInfo or visualInfo.isCollected or visualInfo.isHideVisual == nil) then 
		self:Hide();
		return; 
	end

	self.visualInfo = visualInfo;
	self.isWished = _wishListDataProvider:GetListItemByVisualID(visualInfo.visualID) and true;
	if (not enteredParent) then
		if (not self.isWished) then
			self:Hide();
		else
			self:Show();
		end
	end
	
	self.texture:SetAlpha(self.isWished and 0.75 or 0.4);
end
		
function TWLWishButtonMixin:OnEnter()
	self:Show();
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText("Wish list");
	GameTooltip:Show();
	self.texture:SetAlpha(1.0);
end

function TWLWishButtonMixin:OnLeave()
	self:Hide();
	GameTooltip:Hide();
	--self.texture:SetAlpha(self.isWished and 0.75 or 0.4);
	self:Update()
	self.texture:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0);
end

function TWLWishButtonMixin:OnMouseDown()
	self.texture:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -1);
end

function TWLWishButtonMixin:OnMouseUp()
	self.texture:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0);
	--self.isWished = not self.isWished;
	
	
	
	if self.isWished  then
		_wishListDataProvider:RemoveByVisualID(self.visualInfo.visualID);
		TransmogWishListFrame:Update();
	else
		if self.visualInfo.isHideVisual ~= nil then
			_wishListDataProvider:AddVisualIDToList(self.visualInfo.visualID);
		end
	end
	
	self:Update(true);
end


TWLModPickerMixin = {};

function TWLModPickerMixin:AddButtonOnClick()
	_wishListDataProvider:AddItemIDToList(self.itemID, self.selected.modID);
	self:Close();
end

function TWLModPickerMixin:Close()
	self.itemID = nil;
	self.isArmor = nil;
	self.itemEquipLoc = nil; 
	self.mods = nil;
	self.selected = nil; 
	self.PreviewModel:SetKeepModelOnHide(false);
	TransmogWishListFrame.modpickerOverlay:Hide();
end

function TWLModPickerMixin:Setup(itemID, mods)
	local name, link, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemID, modID);
	self.itemID = itemID;
	self.isArmor = WARDROBE_MODEL_SETUP[itemEquipLoc] and true or false;
	self.itemEquipLoc = itemEquipLoc; 
	self.mods = mods;
	self.selected = self.mods[1]; 
	self:Show();
	TransmogWishListFrame.modpickerOverlay:Show();
	local infoItemIDFormat = "ItemID |cFFFFD100%d|r has |cFFFFD100%d|r appearance mods.|nPlease select which one you'd like to add to your list.";
	self.Info:SetText(infoItemIDFormat:format(itemID, #mods));
	
	self.PreviewModel:SetKeepModelOnHide(true);
	for k, button in ipairs(self.ModList.ModButtons) do
		button:Hide();
	end
	
	self:Update();
end

function TWLModPickerMixin:Update()
	for i = 1, #self.mods do
		local button = self.ModList.ModButtons[i];
		button:Setup(self.mods[i]);
	end
	
	local selectedItemIDFormat = "Selected: |cFFFFD100%d|r ";
	self.SelectedText:SetText(selectedItemIDFormat:format(self.selected.modID));
	
	self:ShowModel(self.selected)
end

function TWLModPickerMixin:ShowModel(modInfo)
	local cameraID;
	local model = self.PreviewModel;
	if (model.modID == modInfo.modID) then return; end;
	
	model.modID = modInfo.modID;
	model:Undress();
	
	if self.isArmor then
		cameraID = C_TransmogCollection.GetAppearanceCameraIDBySource(modInfo.sourceID);
		model:SetUnit("player", false);
		model:SetUseTransmogSkin(WARDROBE_MODEL_SETUP[self.itemEquipLoc].useTransmogSkin);
		for slot, equip in pairs(WARDROBE_MODEL_SETUP[self.itemEquipLoc].slots) do
			if ( equip ) then
				model:TryOn(WARDROBE_MODEL_SETUP_GEAR[slot]);
			end
		end
		model:TryOn(modInfo.sourceID)
	else
		cameraID = C_TransmogCollection.GetAppearanceCameraIDBySource(modInfo.sourceID);
		if not skipModel then
			model:SetItemAppearance(modInfo.visualID)
		end
	end

	Model_ApplyUICamera(model, cameraID);
end


TWLModButtonMixin = {};

function TWLModButtonMixin:OnClick()
	TransmogWishListModPicker.selected = self.modInfo;
	TransmogWishListModPicker:Update();
end

function TWLModButtonMixin:OnEnter()
	TransmogWishListModPicker:ShowModel(self.modInfo);
end

function TWLModButtonMixin:OnLeave()
	TransmogWishListModPicker:ShowModel(TransmogWishListModPicker.selected);
end

function TWLModButtonMixin:Setup(modInfo)
	self:SetText(modInfo.modID);
	self.modInfo = modInfo;
	self:Show();
end
		
function TWL:OnEnable()
	self.db = LibStub("AceDB-3.0"):New("TWLDB", TWL_DEFAULTS, true);
	self.settings = self.db.global;
	_wishListDataProvider:LoadSaveData(self.settings.wishList) 
end

local function slashcmd(msg, editbox)
	-- if msg:find("wowhead") then

		-- local itemID = msg:match("=(%d+)/");
		-- local modID = msg:match("(%d):");
		-- print("url", itemID, modID)
		-- _wishListDataProvider:AddItemIDToList(tonumber(itemID), tonumber(modID));
	-- else
	if msg:find("(%d+)") then
		local itemID, modID = string.match(msg, "(%d+) (%d+)");
		itemID = itemID or msg;
		
		local mods = {modID}
		if not modID then
				
			for i=0, 10 do
				local appearanceID, sourceID = C_TransmogCollection.GetItemInfo(itemID, i);
				if appearanceID then
					tinsert(mods, {["modID"] = i, ["visualID"] = appearanceID, ["sourceID"] = sourceID});
				end
			end
			
		end

		-- If there is only 1 itemModID, just use that one!
		if #mods == 1 then
			_wishListDataProvider:AddItemIDToList(tonumber(itemID), tonumber(mods[1]));
		elseif (#mods > 1) then
			--print("Show window for ".. #mods .. " mods");
			TransmogWishListModPicker:Setup(itemID, mods);
		end
	
	--/run local msg = "81654 4"; print(msg:match("(%d+) (%d+)"))
	-- elseif msg then
		-- local ids = {147064, 103219, 146994, 147031, 140887, 136210, 126760, 124389, 125637, 126057, 140537, 140542, 140554, 138358, 138360, 139162, 95338, 140560, 95474, 147205, 71287}
		-- for k, id in ipairs(ids) do
			-- _wishListDataProvider:AddItemIDToList(id);
		-- end
	-- else
		-- for k, v in pairs(WishList) do
			-- print(k);
		-- end
	end
end
SLASH_TWLSLASH1 = '/twl';
SlashCmdList["TWLSLASH"] = slashcmd
