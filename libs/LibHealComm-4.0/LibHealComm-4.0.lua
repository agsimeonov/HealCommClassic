if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then return end

local major = "LibHealComm-4.0"
local minor = 82
assert(LibStub, format("%s requires LibStub.", major))

local HealComm = LibStub:NewLibrary(major, minor)
if( not HealComm ) then return end

local COMM_PREFIX = "LHC40"
C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)

local bit = bit
local ceil = ceil
local error = error
local floor = floor
local format = format
local gsub = gsub
local max = max
local min = min
local pairs = pairs
local rawset = rawset
local select = select
local setmetatable = setmetatable
local strlen = strlen
local strmatch = strmatch
local strsplit = strsplit
local strsub = strsub
local tinsert = tinsert
local tonumber = tonumber
local tremove = tremove
local type = type
local unpack = unpack
local wipe = wipe

local Ambiguate = Ambiguate
local CastingInfo = CastingInfo
local ChannelInfo = ChannelInfo
local CreateFrame = CreateFrame
local GetInventoryItemLink = GetInventoryItemLink
local GetInventorySlotInfo = GetInventorySlotInfo
local GetNumGroupMembers = GetNumGroupMembers
local GetNumTalents = GetNumTalents
local GetNumTalentTabs = GetNumTalentTabs
local GetRaidRosterInfo = GetRaidRosterInfo
local GetSpellBonusHealing = GetSpellBonusHealing
local GetSpellCritChance = GetSpellCritChance
local GetSpellInfo = GetSpellInfo
local GetTalentInfo = GetTalentInfo
local GetTime = GetTime
local GetZonePVPInfo = GetZonePVPInfo
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local IsEquippedItem = IsEquippedItem
local IsInGroup = IsInGroup
local IsInInstance = IsInInstance
local IsInRaid = IsInRaid
local IsLoggedIn = IsLoggedIn
local IsSpellInRange = IsSpellInRange
local SpellIsTargeting = SpellIsTargeting
local UnitAura = UnitAura
local UnitCanAssist = UnitCanAssist
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsCharmed = UnitIsCharmed
local UnitIsVisible = UnitIsVisible
local UnitIsUnit = UnitIsUnit
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitPlayerControlled = UnitPlayerControlled
local CheckInteractDistance = CheckInteractDistance

local COMBATLOG_OBJECT_AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE

local spellRankTableData = {
	[1] = { 774, 8936, 5185, 740, 635, 19750, 139, 2060, 596, 2061, 2054, 2050, 1064, 331, 8004, 136, 755, 689, 746 },
	[2] = { 1058, 8938, 5186, 8918, 639, 19939, 6074, 10963, 996, 9472, 2055, 2052, 10622, 332, 8008, 3111, 3698, 699, 1159 },
	[3] = { 1430, 8939, 5187, 9862, 647, 19940, 6075, 10964, 10960, 9473, 6063, 2053, 10623, 547, 8010, 3661, 3699, 709, 3267 },
	[4] = { 2090, 8940, 5188, 9863, 1026, 19941, 6076, 10965, 10961, 9474, 6064, 913, 10466, 3662, 3700, 7651, 3268 },
	[5] = { 2091, 8941, 5189, 1042, 19942, 6077, 22009, 25314, 25316, 10915, 939, 10467, 13542, 11693, 11699, 7926 },
	[6] = { 3627, 9750, 6778, 3472, 19943, 6078, 10916, 959, 10468, 13543, 11694, 11700, 7927, 23569, 24412 },
	[7] = { 8910, 9856, 8903, 10328, 10927, 10917, 8005, 13544, 11695, 10838 },
	[8] = { 9839, 9857, 9758, 10329, 10928, 10395, 10839, 23568, 24413 },
	[9] = { 9840, 9858, 9888, 25292, 10929, 10396, 18608 },
	[10] = { 9841, 9889, 25315, 25357, 18610, 23567, 24414 },
	[11] = { 25299, 25297, 30020 },
}

local SpellIDToRank = {}
for rankIndex, spellIDTable in pairs(spellRankTableData) do
	for _, spellID in pairs(spellIDTable) do
		SpellIDToRank[spellID] = rankIndex
	end
end

-- API CONSTANTS
local ALL_DATA = 0x0f
local DIRECT_HEALS = 0x01
local CHANNEL_HEALS = 0x02
local HOT_HEALS = 0x04
local ABSORB_SHIELDS = 0x08
local BOMB_HEALS = 0x10
local ALL_HEALS = bit.bor(DIRECT_HEALS, CHANNEL_HEALS, HOT_HEALS, BOMB_HEALS)
local CASTED_HEALS = bit.bor(DIRECT_HEALS, CHANNEL_HEALS)
local OVERTIME_HEALS = bit.bor(HOT_HEALS, CHANNEL_HEALS)

HealComm.ALL_HEALS, HealComm.CHANNEL_HEALS, HealComm.DIRECT_HEALS, HealComm.HOT_HEALS, HealComm.CASTED_HEALS, HealComm.ABSORB_SHIELDS, HealComm.ALL_DATA, HealComm.BOMB_HEALS = ALL_HEALS, CHANNEL_HEALS, DIRECT_HEALS, HOT_HEALS, CASTED_HEALS, ABSORB_SHIELDS, ALL_DATA, BOMB_HEALS

local playerGUID, playerName, playerLevel
local playerHealModifier = 1

HealComm.callbacks = HealComm.callbacks or LibStub:GetLibrary("CallbackHandler-1.0"):New(HealComm)
HealComm.activeHots = HealComm.activeHots or {}
HealComm.activePets = HealComm.activePets or {}
HealComm.equippedSetCache = HealComm.equippedSetCache or {}
HealComm.guidToGroup = HealComm.guidToGroup or {}
HealComm.guidToUnit = HealComm.guidToUnit or {}
HealComm.hotData = HealComm.hotData or {}
HealComm.itemSetsData = HealComm.itemSetsData or {}
HealComm.pendingHeals = HealComm.pendingHeals or {}
HealComm.pendingHots = HealComm.pendingHots or {}
HealComm.spellData = HealComm.spellData or {}
HealComm.talentData = HealComm.talentData or {}
HealComm.tempPlayerList = HealComm.tempPlayerList or {}

if( not HealComm.unitToPet ) then
	HealComm.unitToPet = {["player"] = "pet"}
	for i = 1, MAX_PARTY_MEMBERS do HealComm.unitToPet["party" .. i] = "partypet" .. i end
	for i = 1, MAX_RAID_MEMBERS do HealComm.unitToPet["raid" .. i] = "raidpet" .. i end
end

local spellData, hotData, tempPlayerList, pendingHeals, pendingHots = HealComm.spellData, HealComm.hotData, HealComm.tempPlayerList, HealComm.pendingHeals, HealComm.pendingHots
local equippedSetCache, itemSetsData, talentData = HealComm.equippedSetCache, HealComm.itemSetsData, HealComm.talentData
local activeHots, activePets = HealComm.activeHots, HealComm.activePets

-- Figure out what they are now since a few things change based off of this
local playerClass = select(2, UnitClass("player"))

if( not HealComm.compressGUID  ) then
	HealComm.compressGUID = setmetatable({}, {
		__index = function(tbl, guid)
			local str
			if strsub(guid,1,6) ~= "Player" then
				for unit,pguid in pairs(activePets) do
					if pguid == guid then
						str = "p-" .. strmatch(UnitGUID(unit), "^%w*-([-%w]*)$")
					end
				end
				if not str then
					--assert(str, "Could not encode: "..guid)
					return nil
				end
			else
				str = strmatch(guid, "^%w*-([-%w]*)$")
			end
			rawset(tbl, guid, str)
			return str
	end})

	HealComm.decompressGUID = setmetatable({}, {
		__index = function(tbl, str)
			if( not str ) then return nil end
			local guid
			if strsub(str,1,2) == "p-" then
				guid = activePets[HealComm.guidToUnit["Player-"..strsub(str,3)]]
			else
				guid = "Player-"..str
			end

			rawset(tbl, str, guid)
			return guid
	end})
end

local compressGUID, decompressGUID = HealComm.compressGUID, HealComm.decompressGUID

-- Handles caching of tables for variable tick spells, like Wild Growth
if( not HealComm.tableCache ) then
	HealComm.tableCache = setmetatable({}, {__mode = "k"})
	function HealComm:RetrieveTable()
		return tremove(HealComm.tableCache, 1) or {}
	end

	function HealComm:DeleteTable(tbl)
		wipe(tbl)
		tinsert(HealComm.tableCache, tbl)
	end
end

-- Validation for passed arguments
if( not HealComm.tooltip ) then
	local tooltip = CreateFrame("GameTooltip")
	tooltip:SetOwner(UIParent, "ANCHOR_NONE")
	tooltip.TextLeft1 = tooltip:CreateFontString()
	tooltip.TextRight1 = tooltip:CreateFontString()
	tooltip:AddFontStrings(tooltip.TextLeft1, tooltip.TextRight1)

	HealComm.tooltip = tooltip
end

-- Record management, because this is getting more complicted to deal with
local function updateRecord(pending, guid, amount, stack, endTime, ticksLeft)
	if( pending[guid] ) then
		local id = pending[guid]

		pending[id] = guid
		pending[id + 1] = amount
		pending[id + 2] = stack
		pending[id + 3] = endTime or 0
		pending[id + 4] = ticksLeft or 0
	else
		pending[guid] = #(pending) + 1
		tinsert(pending, guid)
		tinsert(pending, amount)
		tinsert(pending, stack)
		tinsert(pending, endTime or 0)
		tinsert(pending, ticksLeft or 0)

		if( pending.bitType == HOT_HEALS ) then
			activeHots[guid] = (activeHots[guid] or 0) + 1
			HealComm.hotMonitor:Show()
		end
	end
end

local function getRecord(pending, guid)
	local id = pending[guid]
	if( not id ) then return nil end

	-- amount, stack, endTime, ticksLeft
	return pending[id + 1], pending[id + 2], pending[id + 3], pending[id + 4]
end

local function removeRecord(pending, guid)
	local id = pending[guid]
	if( not id ) then return nil end

	-- ticksLeft, endTime, stack, amount, guid
	tremove(pending, id + 4)
	tremove(pending, id + 3)
	tremove(pending, id + 2)
	local amount = tremove(pending, id + 1)
	tremove(pending, id)
	pending[guid] = nil

	-- Release the table
	if( type(amount) == "table" ) then HealComm:DeleteTable(amount) end

	if( pending.bitType == HOT_HEALS and activeHots[guid] ) then
		activeHots[guid] = activeHots[guid] - 1
		activeHots[guid] = activeHots[guid] > 0 and activeHots[guid] or nil
	end

	-- Shift any records after this ones index down 5 to account for the removal
	for i=1, #(pending), 5 do
		local guid = pending[i]
		if( pending[guid] > id ) then
			pending[guid] = pending[guid] - 5
		end
	end
end

local function removeRecordList(pending, inc, comp, ...)
	for i=1, select("#", ...), inc do
		local guid = select(i, ...)
		guid = comp and decompressGUID[guid] or guid

		local id = pending[guid]
		-- ticksLeft, endTime, stack, amount, guid
		tremove(pending, id + 4)
		tremove(pending, id + 3)
		tremove(pending, id + 2)
		local amount = tremove(pending, id + 1)
		tremove(pending, id)
		pending[guid] = nil

		-- Release the table
		if( type(amount) == "table" ) then HealComm:DeleteTable(amount) end
	end

	-- Redo all the id maps
	for i=1, #(pending), 5 do
		pending[pending[i]] = i
	end
end

-- Removes every mention to the given GUID
local function removeAllRecords(guid)
	local changed

	for _, tbl in pairs({pendingHeals, pendingHots}) do
		for _, spells in pairs(tbl) do
			for _, pending in pairs(spells) do
				if( pending.bitType and pending[guid] ) then
					local id = pending[guid]

					-- ticksLeft, endTime, stack, amount, guid
					tremove(pending, id + 4)
					tremove(pending, id + 3)
					tremove(pending, id + 2)
					local amount = tremove(pending, id + 1)
					tremove(pending, id)
					pending[guid] = nil

					-- Release the table
					if( type(amount) == "table" ) then HealComm:DeleteTable(amount) end

					-- Shift everything back
					if( #(pending) > 0 ) then
						for i=1, #(pending), 5 do
							local guid = pending[i]
							if( pending[guid] > id ) then
								pending[guid] = pending[guid] - 5
							end
						end
					else
						wipe(pending)
					end

					changed = true
				end
			end
		end
	end

	activeHots[guid] = nil

	if( changed ) then
		HealComm.callbacks:Fire("HealComm_GUIDDisappeared", guid)
	end
end

-- These are not public APIs and are purely for the wrapper to use
HealComm.removeRecordList = removeRecordList
HealComm.removeRecord = removeRecord
HealComm.getRecord = getRecord
HealComm.updateRecord = updateRecord

-- Removes all pending heals, if it's a group that is causing the clear then we won't remove the players heals on themselves
local function clearPendingHeals()
	for _, tbl in pairs({pendingHeals, pendingHots}) do
		for casterGUID, spells in pairs(tbl) do
			for _, pending in pairs(spells) do
				if( pending.bitType ) then
					wipe(tempPlayerList)
					for i=#(pending), 1, -5 do tinsert(tempPlayerList, pending[i - 4]) end

					if( #(tempPlayerList) > 0 ) then
						local spellID, bitType = pending.spellID, pending.bitType
						wipe(pending)

						HealComm.callbacks:Fire("HealComm_HealStopped", casterGUID, spellID, bitType, true, unpack(tempPlayerList))
					end
				end
			end
		end
	end
end

-- APIs
-- Returns the players current heaing modifier
function HealComm:GetPlayerHealingMod()
	return playerHealModifier or 1
end

-- Returns the current healing modifier for the GUID
function HealComm:GetHealModifier(guid)
	return HealComm.currentModifiers[guid] or 1
end

-- Returns whether or not the GUID has casted a heal
function HealComm:GUIDHasHealed(guid)
	return (pendingHeals[guid] or pendingHots[guid]) and true or nil
end

-- Returns the guid to unit table
function HealComm:GetGUIDUnitMapTable()
	if( not HealComm.protectedMap ) then
		HealComm.protectedMap = setmetatable({}, {
			__index = function(tbl, key) return HealComm.guidToUnit[key] end,
			__newindex = function() error("This is a read only table and cannot be modified.", 2) end,
			__metatable = false
		})
	end

	return HealComm.protectedMap
end

-- Gets the next heal landing on someone using the passed filters
function HealComm:GetNextHealAmount(guid, bitFlag, time, ignoreGUID)
	local healTime, healAmount, healFrom
	local currentTime = GetTime()

	for _, tbl in pairs({pendingHeals, pendingHots}) do
		for casterGUID, spells in pairs(tbl) do
			if( not ignoreGUID or ignoreGUID ~= casterGUID ) then
				for _, pending in pairs(spells) do
					if( pending.bitType and bit.band(pending.bitType, bitFlag) > 0 ) then
						for i=1, #(pending), 5 do
							local amount = pending[i + 1]
							local stack = pending[i + 2]
							local endTime = pending[i + 3]
							endTime = endTime > 0 and endTime or pending.endTime

							-- Direct heals are easy, if they match the filter then return them
							if( ( pending.bitType == DIRECT_HEALS or pending.bitType == BOMB_HEALS ) and ( not time or endTime <= time ) ) then
								if( not healTime or endTime < healTime ) then
									healTime = endTime
									healAmount = amount * stack
									healFrom = casterGUID
								end

							-- Channeled heals and hots, have to figure out how many times it'll tick within the given time band
							elseif( ( pending.bitType == CHANNEL_HEALS or pending.bitType == HOT_HEALS ) ) then
								local secondsLeft = time and time - currentTime or endTime - currentTime
								local nextTick = currentTime + (secondsLeft % pending.tickInterval)
								if( not healTime or nextTick < healTime ) then
									healTime = nextTick
									healAmount = amount * stack
									healFrom = casterGUID
								end
							end
						end
					end
				end
			end
		end
	end

	return healTime, healFrom, healAmount
end

-- Get the healing amount that matches the passed filters
local function filterData(spells, filterGUID, bitFlag, time, ignoreGUID)
	local healAmount = 0
	local currentTime = GetTime()

	if spells then
		for _, pending in pairs(spells) do
			if( pending.bitType and bit.band(pending.bitType, bitFlag) > 0 ) then
				for i = 1, #(pending), 5 do
					local guid = pending[i]
					if( guid == filterGUID or ignoreGUID ) then
						local amount = pending[i + 1]
						local stack = pending[i + 2]
						local endTime = pending[i + 3]
						endTime = endTime > 0 and endTime or pending.endTime

						if( ( pending.bitType == DIRECT_HEALS or pending.bitType == BOMB_HEALS ) and ( not time or endTime <= time ) ) then
							healAmount = healAmount + amount * stack
						elseif( ( pending.bitType == CHANNEL_HEALS or pending.bitType == HOT_HEALS ) and endTime > currentTime ) then
							local ticksLeft = pending[i + 4]
							if( not time or time >= endTime ) then
								healAmount = healAmount + (amount * stack) * ticksLeft
							else
								local secondsLeft = endTime - currentTime
								local bandSeconds = time - currentTime
								local ticks = floor(min(bandSeconds, secondsLeft) / pending.tickInterval)
								local nextTickIn = secondsLeft % pending.tickInterval
								local fractionalBand = bandSeconds % pending.tickInterval
								if( nextTickIn > 0 and nextTickIn < fractionalBand ) then
									ticks = ticks + 1
								end

								healAmount = healAmount + (amount * stack) * min(ticks, ticksLeft)
							end
						end
					end
				end
			end
		end
	end

	return healAmount
end

-- Gets healing amount using the passed filters
function HealComm:GetHealAmount(guid, bitFlag, time, casterGUID)
	local amount = 0
	if( casterGUID and (pendingHeals[casterGUID] or pendingHots[casterGUID]) ) then
		amount = filterData(pendingHeals[casterGUID], guid, bitFlag, time) + filterData(pendingHots[casterGUID], guid, bitFlag, time)
	elseif( not casterGUID ) then
		for _, tbl in pairs({pendingHeals, pendingHots}) do
			for _, spells in pairs(tbl) do
				amount = amount + filterData(spells, guid, bitFlag, time)
			end
		end
	end

	return amount > 0 and amount or nil
end

-- Gets healing amounts for everyone except the player using the passed filters
function HealComm:GetOthersHealAmount(guid, bitFlag, time)
	local amount = 0
	for _, tbl in pairs({pendingHeals, pendingHots}) do
		for casterGUID, spells in pairs(tbl) do
			if( casterGUID ~= playerGUID ) then
				amount = amount + filterData(spells, guid, bitFlag, time)
			end
		end
	end

	return amount > 0 and amount or nil
end

function HealComm:GetCasterHealAmount(guid, bitFlag, time)
	local amount = pendingHeals[guid] and filterData(pendingHeals[guid], nil, bitFlag, time, true) or 0
	amount = amount + (pendingHots[guid] and filterData(pendingHots[guid], nil, bitFlag, time, true) or 0)
	return amount > 0 and amount or nil
end

-- Healing class data
-- Thanks to Gagorian (DrDamage) for letting me steal his formulas and such
local playerCurrentRelic
local guidToUnit, guidToGroup = HealComm.guidToUnit, HealComm.guidToGroup

-- UnitBuff priortizes our buffs over everyone elses when there is a name conflict, so yay for that
do
	local function SpellIdPredicate(spellIdToFind, _, _, _, _, _, _, _, _, _, _, _, spellId)
		return spellIdToFind == spellId;
	end

	function AuraUtil.FindAuraBySpellId(spellId, unit, filter)
		return AuraUtil.FindAura(SpellIdPredicate, unit, filter, spellId);
	end
end

 -- UnitBuff priortizes our buffs over everyone elses when there is a name conflict, so yay for that
local function unitHasAura(unit, name)
	if type(name) == "number" then
		return AuraUtil.FindAuraBySpellId(name, unit)
	else
		return AuraUtil.FindAuraByName(name, unit)
	end
end

-- Note because I always forget on the order:
-- Talents that effective the coeffiency of spell power to healing are first and are tacked directly onto the coeffiency (Empowered Rejuvenation)
-- Penalty modifiers (downranking/spell level too low) are applied directly to the spell power
-- Spell power modifiers are then applied to the spell power
-- Heal modifiers are applied after all of that
-- Crit modifiers are applied after
-- Any other modifiers such as Mortal Strike or Avenging Wrath are applied after everything else

local function calculateGeneralAmount(level, amount, spellPower, spModifier, healModifier)
	local penalty = level > 20 and 1 or (1 - ((20 - level) * 0.0375))

	spellPower = spellPower * penalty

	return healModifier * (amount + (spellPower * spModifier))
end

local function DirectCoefficient(castTime)
	return castTime / 3.5
end

local function HotCoefficient(duration)
	return duration / 15
end

local function avg(a, b)
	return (a + b) / 2
end

--[[
	What the different callbacks do:

	AuraHandler: Specific aura tracking needed for this class, who has Beacon up on them and such

	ResetChargeData: Due to spell "queuing" you can't always rely on aura data for buffs that last one or two casts, for example Divine Favor (+100% crit, one spell)
	if you cast Holy Light and queue Flash of Light the library would still see they have Divine Favor and give them crits on both spells. The reset means that the flag that indicates
	they have the aura can be killed and if they interrupt the cast then it will call this and let you reset the flags.

	What happens in terms of what the client thinks and what actually is, is something like this:

	UNIT_SPELLCAST_START, Holy Light -> Divine Favor up
	UNIT_SPELLCAST_SUCCEEDED, Holy Light -> Divine Favor up (But it was really used)
	UNIT_SPELLCAST_START, Flash of Light -> Divine Favor up (It's not actually up but auras didn't update)
	UNIT_AURA -> Divine Favor up (Split second where it still thinks it's up)
	UNIT_AURA -> Divine Favor faded (Client catches up and realizes it's down)

	CalculateHealing: Calculates the healing value, does all the formula calculations talent modifiers and such

	CalculateHotHealing: Used specifically for calculating the heals of hots

	GetHealTargets: Who the heal is going to hit, used for setting extra targets for Beacon of Light + Paladin heal or Prayer of Healing.
	The returns should either be:

	"compressedGUID1,compressedGUID2,compressedGUID3,compressedGUID4", healthAmount
	Or if you need to set specific healing values for one GUID it should be
	"compressedGUID1,healthAmount1,compressedGUID2,healAmount2,compressedGUID3,healAmount3", -1

	The latter is for cases like Glyph of Healing Wave where you need a heal for 1,000 on A and a heal for 200 on the player for B without sending 2 events.
	The -1 tells the library to look in the GUId list for the heal amounts

	**NOTE** Any GUID returned from GetHealTargets must be compressed through a call to compressGUID[guid]
]]

local CalculateHealing, GetHealTargets, AuraHandler, CalculateHotHealing, ResetChargeData, LoadClassData

local function getBaseHealAmount(spellData, spellName, spellRank)
	spellData = spellData[spellName]
	local average = spellData.averages[spellRank]
	if type(average) == "number" then
		return average
	end
	local requiresLevel = spellData.levels[spellRank]
	return average[min(playerLevel - requiresLevel + 1, #average)]
end

if( playerClass == "DRUID" ) then
	LoadClassData = function()
		local GiftofNature = GetSpellInfo(17104)
		local HealingTouch = GetSpellInfo(5185)
		local ImprovedRejuv = GetSpellInfo(17111)
		local Innervate = GetSpellInfo(29166)
		local Regrowth = GetSpellInfo(8936)
		local Rejuvenation = GetSpellInfo(774)
		local Tranquility = GetSpellInfo(740)

		hotData[Regrowth] = { interval = 3, ticks = 7, coeff = 0.5, levels = { 12, 18, 24, 30, 36, 42, 48, 54, 60 }, averages = { 98, 175, 259, 343, 427, 546, 686, 861, 1064 }}
		hotData[Rejuvenation] = { interval = 3, levels = { 4, 10, 16, 22, 28, 34, 40, 46, 52, 58, 60 }, averages = { 32, 56, 116, 180, 244, 304, 388, 488, 608, 756, 888 }}

		spellData[HealingTouch] = { levels = {1, 8, 14, 20, 26, 32, 38, 44, 50, 56, 60}, averages = {
			{avg(37, 51), avg(37, 52), avg(38, 53), avg(39, 54), avg(40, 55)},
			{avg(88, 112), avg(89, 114), avg(90, 115), avg(91, 116), avg(93, 118), avg(94, 119)},
			{avg(195, 243), avg(196, 245), avg(198, 247), avg(200, 249), avg(202, 251), avg(204, 253)},
			{avg(363, 445), avg(365, 448), avg(368, 451), avg(371, 454), avg(373, 456), avg(376, 459)},
			{avg(572, 694), avg(575, 698), avg(579, 701), avg(582, 705), avg(586, 708), avg(589, 712)},
			{avg(742, 894), avg(746, 898), avg(750, 902), avg(754, 906), avg(758, 910), avg(762, 914)},
			{avg(936, 1120), avg(940, 1125), avg(945, 1129), avg(949, 1134), avg(954, 1138), avg(958, 1143)},
			{avg(1199, 1427), avg(1204, 1433), avg(1209, 1438), avg(1214, 1443), avg(1219, 1448), avg(1225, 1453)},
			{avg(1516, 1796), avg(1521, 1802), avg(1527, 1808), avg(1533, 1814), avg(1539, 1820), avg(1545, 1826)},
			{avg(1890, 2230), avg(1896, 2237), avg(1903, 2244), avg(1909, 2250), avg(1916, 2257)},
			{avg(2267, 2677)} }}
		spellData[Regrowth] = {coeff = 0.5 * (2 / 3.5) , levels = hotData[Regrowth].levels, averages = {
			{avg(84, 98), avg(85, 100), avg(87, 102), avg(89, 104), avg(91, 106), avg(93, 107)},
			{avg(164, 188), avg(166, 191), avg(169, 193), avg(171, 196), avg(174, 198), avg(176, 201)},
			{avg(240, 274), avg(243, 278), avg(246, 281), avg(249, 284), avg(252, 287), avg(255, 290)},
			{avg(318, 360), avg(321, 364), avg(325, 368), avg(328, 371), avg(332, 375), avg(336, 378)},
			{avg(405, 457), avg(409, 462), avg(413, 466), avg(417, 470), avg(421, 474), avg(425, 478)},
			{avg(511, 575), avg(515, 580), avg(520, 585), avg(525, 590), avg(529, 594), avg(534, 599)},
			{avg(646, 724), avg(651, 730), avg(656, 735), avg(661, 740), avg(667, 746), avg(672, 751)},
			{avg(809, 905), avg(815, 911), avg(821, 917), avg(827, 923), avg(833, 929), avg(839, 935)},
			{avg(1003, 1119)} }}
		spellData[Tranquility] = {coeff = 1/3, ticks = 5, interval = 2, levels = {30, 40, 50, 60}, averages = {
			{94 * 5, 95 * 5, 96 * 5, 96 * 5, 97 * 5, 97 * 5, 98 * 5},
			{138 * 5, 139 * 5, 140 * 5, 141 * 5, 141 * 5, 142 * 5, 143 * 5},
			{205 * 5, 206 * 5, 207 * 5, 208 * 5, 209 * 5, 210 * 5, 211 * 5},
			{294 * 5} }}

		talentData[GiftofNature] = {mod = 0.02, current = 0}
		talentData[ImprovedRejuv] = {mod = 0.05, current = 0}

		itemSetsData["Stormrage"] = {16903, 16898, 16904, 16897, 16900, 16899, 16901, 16902}

		GetHealTargets = function(bitType, guid, healAmount, spellID)
			-- Tranquility pulses on everyone within 30 yards, if they are in range of Innervate they'll get Tranquility
			local spellName = GetSpellInfo(spellID)
			if( spellName == Tranquility ) then
				local targets = compressGUID[playerGUID]
				local playerGroup = guidToGroup[playerGUID]

				for groupGUID, id in pairs(guidToGroup) do
					if( id == playerGroup and playerGUID ~= groupGUID and not IsSpellInRange(Innervate, guidToUnit[groupGUID]) == 1 ) then
						targets = targets .. "," .. compressGUID[groupGUID]
					end
				end

				return targets, healAmount
			end

			return compressGUID[guid], healAmount
		end

		-- Calculate hot heals
		CalculateHotHealing = function(guid, spellID)
			local spellName, spellRank = GetSpellInfo(spellID), SpellIDToRank[spellID]
			local healAmount = getBaseHealAmount(hotData, spellName, spellRank)
			local spellPower = GetSpellBonusHealing()
			local healModifier, spModifier = playerHealModifier, 1
			local totalTicks

			healAmount = healAmount * (1 + talentData[GiftofNature].current)

			-- Rejuvenation
			if( spellName == Rejuvenation ) then
				healAmount = healAmount * (1 + talentData[ImprovedRejuv].current)

				if( playerCurrentRelic == 22398 ) then
					spellPower = spellPower + 50
				end

				local duration = 12
				local ticks = duration / hotData[spellName].interval

				if( equippedSetCache["Stormrage"] >= 8 ) then
					healAmount = healAmount + (healAmount / ticks) -- Add Tick Amount Gained by Set.
					duration = 15
					ticks = ticks + 1
				end

				totalTicks = ticks

				spellPower = spellPower * (duration / 15)
				spellPower = spellPower / ticks
				healAmount = healAmount / ticks
			elseif( spellName == Regrowth ) then
				spellPower = spellPower * hotData[spellName].coeff
				spellPower = spellPower / hotData[spellName].ticks
				healAmount = healAmount / hotData[spellName].ticks

				totalTicks = 7
			end

			healAmount = calculateGeneralAmount(hotData[spellName].levels[spellRank], healAmount, spellPower, spModifier, healModifier)

			return HOT_HEALS, ceil(healAmount), totalTicks, hotData[spellName].interval
		end

		-- Calcualte direct and channeled heals
		CalculateHealing = function(guid, spellID)
			local spellName, spellRank = GetSpellInfo(spellID), SpellIDToRank[spellID]
			local healAmount = getBaseHealAmount(spellData, spellName, spellRank)
			local spellPower = GetSpellBonusHealing()
			local healModifier, spModifier = playerHealModifier, 1

			-- Gift of Nature
			healAmount = healAmount * (1 + talentData[GiftofNature].current)

			-- Regrowth
			if( spellName == Regrowth ) then
				spellPower = spellPower * spellData[spellName].coeff
			-- Healing Touch
			elseif( spellName == HealingTouch ) then
				local castTime = spellRank >= 5 and 3.5 or (spellRank == 4 and 3 or (spellRank == 3 and 2.5 or (spellRank == 2 and 2 or 1.5)))
				spellPower = spellPower * (castTime / 3.5)
			-- Tranquility
			elseif( spellName == Tranquility ) then
				spellPower = spellPower * spellData[spellName].coeff
				spellPower = spellPower / spellData[spellName].ticks
				healAmount = healAmount / spellData[spellName].ticks
			end

			healAmount = calculateGeneralAmount(spellData[spellName].levels[spellRank], healAmount, spellPower, spModifier, healModifier)

			-- 100% chance to crit with Nature, this mostly just covers fights like Loatheb where you will basically have 100% crit
			if( GetSpellCritChance(4) >= 100 ) then
				healAmount = healAmount * 1.50
			end

			if( spellData[spellName].ticks ) then
				return CHANNEL_HEALS, ceil(healAmount), spellData[spellName].ticks, spellData[spellName].interval
			end

			return DIRECT_HEALS, ceil(healAmount)
		end
	end
end

if( playerClass == "PALADIN" ) then
	LoadClassData = function()
		local DivineFavor = GetSpellInfo(20216)
		local FlashofLight = GetSpellInfo(19750)
		local HealingLight = GetSpellInfo(20237)
		local HolyLight = GetSpellInfo(635)

		spellData[HolyLight] = { coeff = 2.5 / 3.5, levels = {1, 6, 14, 22, 30, 38, 46, 54, 60}, averages = {
			{avg(39, 47), avg(39, 48), avg(40, 49), avg(41, 50), avg(42, 51)},
			{avg(76, 90), avg(77, 92), avg(78, 93), avg(79, 94), avg(80, 95), avg(81, 96)},
			{avg(159, 187), avg(160, 189), avg(162, 191), avg(164, 193), avg(165, 194), avg(167, 196)},
			{avg(310, 356), avg(312, 359), avg(314, 361), avg(317, 364), avg(319, 366), avg(322, 368)},
			{avg(491, 553), avg(494, 557), avg(497, 560), avg(500, 563), avg(503, 566), avg(506, 569)},
			{avg(698, 780), avg(701, 784), avg(705, 788), avg(709, 792), avg(713, 796), avg(717, 799)},
			{avg(945, 1053), avg(949, 1058), avg(954, 1063), avg(958, 1067), avg(963, 1072), avg(968, 1076)},
			{avg(1246, 1388), avg(1251, 1394), avg(1256, 1399), avg(1261, 1404), avg(1266, 1409), avg(1272, 1414)},
			{avg(1590, 1770)} }}
		spellData[FlashofLight] = { coeff = 1.5 / 3.5, levels = {20, 26, 34, 42, 50, 58}, averages = {
			{avg(62, 72), avg(63, 73), avg(64, 74), avg(65, 75), avg(66, 76), avg(67, 77)},
			{avg(96, 110), avg(97, 112), avg(98, 113), avg(99, 114), avg(101, 116), avg(102, 117)},
			{avg(145, 163), avg(146, 165), avg(148, 167), avg(149, 168), avg(151, 170), avg(153, 171)},
			{avg(197, 221), avg(198, 223), avg(200, 225), avg(202, 227), avg(204, 229), avg(206, 231)},
			{avg(267, 299), avg(269, 302), avg(271, 304), avg(273, 306), avg(275, 308), avg(278, 310)},
			{avg(343, 383), avg(345, 386), avg(348, 389)} }}

		talentData[HealingLight] = { mod = 0.04, current = 0 }

		local flashLibrams = {[23006] = 83, [23201] = 53}

		local blessings = {
			[19977] = {
				[HolyLight] = 210,
				[FlashofLight] = 60,
			},
			[19978] = {
				[HolyLight] = 300,
				[FlashofLight] = 85,
			},
			[19979] = {
				[HolyLight] = 400,
				[FlashofLight] = 115,
			},
			[25890] = {
				[HolyLight] = 400,
				[FlashofLight] = 115,
			},
		}

		local hasDivineFavor

		AuraHandler = function(unit, guid)
			if( unit == "player" ) then
				hasDivineFavor = unitHasAura("player", DivineFavor)
			end
		end

		ResetChargeData = function(guid)
			hasDivineFavor = unitHasAura("player", DivineFavor)
		end

		GetHealTargets = function(bitType, guid, healAmount, spellID)
			return compressGUID[guid], healAmount
		end

		CalculateHealing = function(guid, spellID, unit)
			local spellName, spellRank = GetSpellInfo(spellID), SpellIDToRank[spellID]
			local healAmount = getBaseHealAmount(spellData, spellName, spellRank)
			local spellPower = GetSpellBonusHealing()
			local healModifier, spModifier = playerHealModifier, 1

			healAmount = healAmount * (1 + talentData[HealingLight].current)

			if(playerCurrentRelic and spellName == FlashofLight and flashLibrams[playerCurrentRelic] ) then
				spellPower = spellPower + flashLibrams[playerCurrentRelic]
			end

			spellPower = spellPower * spellData[spellName].coeff
			healAmount = calculateGeneralAmount(spellData[spellName].levels[spellRank], healAmount, spellPower, spModifier, healModifier)

			for auraID, values in pairs(blessings) do
				if unitHasAura(unit, auraID) then
					healAmount = calculateGeneralAmount(spellData[spellName].levels[spellRank], healAmount, values[spellName], 1, 1)
					break
				end
			end

			if( hasDivineFavor or GetSpellCritChance(2) >= 100 ) then
				hasDivineFavor = nil
				healAmount = healAmount * 1.50
			end

			return DIRECT_HEALS, ceil(healAmount)
		end
	end
end

if( playerClass == "PRIEST" ) then
	LoadClassData = function()
		local Renew = GetSpellInfo(139)
		local GreaterHeal = GetSpellInfo(2060)
		local PrayerofHealing = GetSpellInfo(596)
		local FlashHeal = GetSpellInfo(2061)
		local Heal = GetSpellInfo(2054)
		local LesserHeal = GetSpellInfo(2050)
		local SpiritualHealing = GetSpellInfo(14898)
		local ImprovedRenew = GetSpellInfo(14908)
		local GreaterHealHot = GetSpellInfo(22009)
		local CureDisease = GetSpellInfo(528)

		hotData[Renew] = {coeff = 1, interval = 3, ticks = 5, levels = {8, 14, 20, 26, 32, 38, 44, 50, 56, 60}, averages = {
			45, 100, 175, 245, 315, 400, 510, 650, 810, 970 }}
		hotData[GreaterHealHot] = hotData[Renew]

		spellData[FlashHeal] = {coeff = 1.5 / 3.5, levels = {20, 26, 32, 38, 44, 50, 56}, averages = {
			{avg(193, 237), avg(194, 239), avg(196, 241), avg(198, 243),  avg(200, 245), avg(202, 247)},
			{avg(258, 314), avg(260, 317), avg(262, 319), avg(264, 321), avg(266, 323), avg(269, 325)},
			{avg(327, 393), avg(329, 396), avg(332, 398), avg(334, 401), avg(337, 403), avg(339, 406)},
			{avg(400, 478), avg(402, 481), avg(405, 484), avg(408, 487), avg(411, 490), avg(414, 492)},
			{avg(518, 616), avg(521, 620), avg(524, 623), avg(527, 626), avg(531, 630), avg(534, 633)},
			{avg(644, 764), avg(647, 768), avg(651, 772), avg(655, 776), avg(658, 779), avg(662, 783)},
			{avg(812, 958), avg(816, 963), avg(820, 967), avg(824, 971), avg(828, 975)} }}
		spellData[GreaterHeal] = {coeff = 3 / 3.5, levels = {40, 46, 52, 58, 60}, averages = {
			{avg(899, 1013), avg(904, 1019), avg(909, 1024), avg(914, 1029), avg(919, 1034), avg(924, 1039)},
			{avg(1149, 1289), avg(1154, 1295), avg(1160, 1301), avg(1166, 1307), avg(1172, 1313), avg(1178, 1318)},
			{avg(1437, 1609), avg(1443, 1616), avg(1450, 1623), avg(1456, 1629), avg(1463, 1636), avg(1470, 1642)},
			{avg(1798, 2006), avg(1805, 2014), avg(1813, 2021)},
			{avg(1966, 2194)} }}
		spellData[Heal] = {coeff = 3 / 3.5, levels = {16, 22, 28, 34}, averages = {
			{avg(295, 341), avg(297, 344), avg(299, 346), avg(302, 349), avg(304, 351), avg(307, 353)},
			{avg(429, 491), avg(432, 495), avg(435, 498), avg(438, 501), avg(441, 504), avg(445, 507)},
			{avg(566, 642), avg(570, 646), avg(574, 650), avg(578, 654), avg(582, 658), avg(586, 662)},
			{avg(712, 804), avg(716, 809), avg(721, 813), avg(725, 818), avg(730, 822), avg(734, 827)} }}
		spellData[LesserHeal] = {levels = {1, 4, 10}, averages = {
			{avg(46, 56), avg(46, 57), avg(47, 58)},
			{avg(71, 85), avg(72, 87), avg(73, 88), avg(74, 89), avg(75, 90), avg(76, 91)},
			{avg(135, 157), avg(136, 159), avg(138, 161), avg(139, 162), avg(141, 164), avg(143, 165)} }}
		spellData[PrayerofHealing] = {coeff = 3/3.5/3, levels = {30, 40, 50, 60, 60}, averages = {
			{avg(301, 321), avg(302, 323), avg(303, 324), avg(304, 325), avg(306, 327), avg(307, 328), avg(308, 329), avg(310, 331), avg(311, 332), avg(312, 333)},
			{avg(444, 472), avg(445, 474), avg(447, 476), avg(448, 477), avg(450, 479), avg(452, 480), avg(453, 482), avg(455, 484), avg(456, 485), avg(458, 487)},
			{avg(657, 695), avg(659, 697), avg(661, 699), avg(663, 701), avg(665, 703), avg(667, 705), avg(669, 707), avg(671, 709), avg(673, 711), avg(675, 713)},
			{avg(939, 991)},
			{avg(1041, 1099)} }}

		talentData[ImprovedRenew] = {mod = 0.05, current = 0}
		talentData[SpiritualHealing] = {mod = 0.02, current = 0}

		itemSetsData["Oracle"] = {21351, 21349, 21350, 21348, 21352}

		-- Check for beacon when figuring out who to heal
		GetHealTargets = function(bitType, guid, healAmount, spellID)
			local spellName = GetSpellInfo(spellID)
			if( spellName == PrayerofHealing ) then
				guid = UnitGUID("player")
				local targets = compressGUID[guid]
				local group = guidToGroup[guid]

				for groupGUID, id in pairs(guidToGroup) do
					local unit = guidToUnit[groupGUID]
					if( id == group and guid ~= groupGUID and (IsSpellInRange(CureDisease, unit) == 1 or CheckInteractDistance(unit, 4)) ) then
						targets = targets .. "," .. compressGUID[groupGUID]
					end
				end

				return targets, healAmount
			end

			return compressGUID[guid], healAmount
		end

		CalculateHotHealing = function(guid, spellID)
			local spellName, spellRank = GetSpellInfo(spellID), SpellIDToRank[spellID]
			local healAmount = getBaseHealAmount(hotData, spellName, spellRank)
			local spellPower = GetSpellBonusHealing()
			local healModifier, spModifier = playerHealModifier, 1
			local totalTicks

			healAmount = healAmount * (1 + talentData[SpiritualHealing].current)

			if( spellName == Renew or spellName == GreaterHealHot ) then
				healAmount = healAmount * (1 + talentData[ImprovedRenew].current)

				--if( equippedSetCache["Oracle"] >= 5 ) then ticks = ticks + 1 duration = 18 end

				totalTicks = 5

				spellPower = spellPower * hotData[spellName].coeff
				spellPower = spellPower / hotData[spellName].ticks
				healAmount = healAmount / hotData[spellName].ticks
			end

			healAmount = calculateGeneralAmount(hotData[spellName].levels[spellRank], healAmount, spellPower, spModifier, healModifier)
			return HOT_HEALS, ceil(healAmount), totalTicks, hotData[spellName].interval
		end

		-- If only every other class was as easy as Paladins
		CalculateHealing = function(guid, spellID)
			local spellName, spellRank = GetSpellInfo(spellID), SpellIDToRank[spellID]
			local healAmount = getBaseHealAmount(spellData, spellName, spellRank)
			local spellPower = GetSpellBonusHealing()
			local healModifier, spModifier = playerHealModifier, 1

			healAmount = healAmount * (1 + talentData[SpiritualHealing].current)

			-- Greater Heal
			if( spellName == GreaterHeal ) then
				spellPower = spellPower * spellData[spellName].coeff
			-- Flash Heal
			elseif( spellName == FlashHeal ) then
				spellPower = spellPower * spellData[spellName].coeff
			-- Binding Heal
			elseif( spellName == PrayerofHealing ) then
				spellPower = spellPower * spellData[spellName].coeff
			-- Heal
			elseif( spellName == Heal ) then
				spellPower = spellPower * spellData[spellName].coeff
			-- Lesser Heal
			elseif( spellName == LesserHeal ) then
				local castTime = spellRank >= 3 and 2.5 or spellRank == 2 and 2 or 1.5
				spellPower = spellPower * (castTime / 3.5)
			end

			healAmount = calculateGeneralAmount(spellData[spellName].levels[spellRank], healAmount, spellPower, spModifier, healModifier)

			-- Player has over a 100% chance to crit with Holy spells
			if( GetSpellCritChance(2) >= 100 ) then
				healAmount = healAmount * 1.50
			end

			return DIRECT_HEALS, ceil(healAmount)
		end
	end
end

if( playerClass == "SHAMAN" ) then
	LoadClassData = function()
		local ChainHeal = GetSpellInfo(1064)
		local HealingWave = GetSpellInfo(331)
		local LesserHealingWave = GetSpellInfo(8004)
		local ImpChainHeal = GetSpellInfo(30872)
		local HealingWay = GetSpellInfo(29206)
		local Purification = GetSpellInfo(16178)

		spellData[ChainHeal] = {coeff = 2.5 / 3.5, levels = {40, 46, 54}, averages = {
			{avg(320, 368), avg(322, 371), avg(325, 373), avg(327, 376), avg(330, 378), avg(332, 381)},
			{avg(405, 465), avg(407, 468), avg(410, 471), avg(413, 474), avg(416, 477), avg(419, 479)},
			{avg(551, 629), avg(554, 633), avg(557, 636), avg(560, 639), avg(564, 643), avg(567, 646)} }}
		spellData[HealingWave] = {levels = {1, 6, 12, 18, 24, 32, 40, 48, 56, 60}, averages = {
			{avg(34, 44), avg(34, 45), avg(35, 46), avg(36, 47)},
			{avg(64, 78), avg(65, 79), avg(66, 80), avg(67, 81), avg(68, 82), avg(69, 83)},
			{avg(129, 155), avg(130, 157), avg(132, 158), avg(133, 160), avg(135, 161), avg(136, 163)},
			{avg(268, 316), avg(270, 319), avg(272, 321), avg(274, 323), avg(277, 326), avg(279, 328)},
			{avg(376, 440), avg(378, 443), avg(381, 446), avg(384, 449), avg(386, 451), avg(389, 454)},
			{avg(536, 622), avg(539, 626), avg(542, 629), avg(545, 632), avg(549, 636), avg(552, 639)},
			{avg(740, 854), avg(743, 858), avg(747, 862), avg(751, 866), avg(755, 870), avg(759, 874)},
			{avg(1017, 1167), avg(1021, 1172), avg(1026, 1177), avg(1031, 1182), avg(1035, 1186), avg(1040, 1191)},
			{avg(1367, 1561), avg(1372, 1567), avg(1378, 1572), avg(1383, 1578), avg(1389, 1583)},
			{avg(1620, 1850)} }}
		spellData[LesserHealingWave] = {coeff = 1.5 / 3.5, levels = {20, 28, 36, 44, 52, 60}, averages = {
			{avg(162, 186), avg(163, 188), avg(165, 190), avg(167, 192), avg(168, 193), avg(170, 195)},
			{avg(247, 281), avg(249, 284), avg(251, 286), avg(253, 288), avg(255, 290), avg(257, 29)},
			{avg(337, 381), avg(339, 384), avg(342, 386), avg(344, 389), avg(347, 391), avg(349, 394)},
			{avg(458, 514), avg(461, 517), avg(464, 520), avg(467, 523), avg(470, 526), avg(473, 529)},
			{avg(631, 705), avg(634, 709), avg(638, 713), avg(641, 716), avg(645, 720), avg(649, 723)},
			{avg(832, 928)} }}

		talentData[HealingWay] = {mod = 0, current = 0}
		talentData[ImpChainHeal] = {mod = 0.10, current = 0}
		talentData[Purification] = {mod = 0.02, current = 0}

		local lhwTotems = {[22396] = 80, [23200] = 53}

		-- Lets a specific override on how many people this will hit
		GetHealTargets = function(bitType, guid, healAmount)
			return compressGUID[guid], healAmount
		end

		-- If only every other class was as easy as Paladins
		CalculateHealing = function(guid, spellID, unit)
			local spellName, spellRank = GetSpellInfo(spellID), SpellIDToRank[spellID]
			local healAmount = getBaseHealAmount(spellData, spellName, spellRank)
			local spellPower = GetSpellBonusHealing()
			local healModifier, spModifier = playerHealModifier, 1

			healAmount = healAmount * (1 + talentData[Purification].current)

			-- Chain Heal
			if( spellName == ChainHeal ) then
				healAmount = healAmount * (1 + talentData[ImpChainHeal].current)
				spellPower = spellPower * spellData[spellName].coeff
			-- Heaing Wave
			elseif( spellName == HealingWave ) then
				local hwStacks = select(3, unitHasAura(unit, 29203))
				if( hwStacks ) then
					healAmount = healAmount * ((hwStacks * 0.06) + 1)
				end
				--healModifier = healModifier * (talentData[HealingWay].spent == 3 and 1.25 or talentData[HealingWay].spent == 2 and 1.16 or talentData[HealingWay].spent == 1 and 1.08 or 1)

				local castTime = spellRank > 3 and 3 or spellRank == 3 and 2.5 or spellRank == 2 and 2 or 1.5
				spellPower = spellPower * (castTime / 3.5)

			-- Lesser Healing Wave
			elseif( spellName == LesserHealingWave ) then
				spellPower = spellPower + (playerCurrentRelic and lhwTotems[playerCurrentRelic] or 0)
				spellPower = spellPower * spellData[spellName].coeff
			end

			healAmount = calculateGeneralAmount(spellData[spellName].levels[spellRank], healAmount, spellPower, spModifier, healModifier)

			-- Player has over a 100% chance to crit with Nature spells
			if( GetSpellCritChance(4) >= 100 ) then
				healAmount = healAmount * 1.50
			end

			-- Apply the final modifier of any MS or self heal increasing effects
			return DIRECT_HEALS, ceil(healAmount)
		end
	end
end

if( playerClass == "HUNTER" ) then
	LoadClassData = function()
		local MendPet = GetSpellInfo(136)

		spellData[MendPet] = { interval = 1, levels = { 12, 20, 28, 36, 44, 52, 60 }, ticks = 5, averages = {100, 190, 340, 515, 710, 945, 1225 } }

		itemSetsData["Giantstalker"] = {16851, 16849, 16850, 16845, 16848, 16852, 16846, 16847}

		GetHealTargets = function(bitType, guid, healAmount, spellID)
			return compressGUID[UnitGUID("pet")], healAmount
		end

		CalculateHealing = function(guid, spellID)
			local spellName, spellRank = GetSpellInfo(spellID), SpellIDToRank[spellID]
			local amount = getBaseHealAmount(spellData, spellName, spellRank)

			if( equippedSetCache["Giantstalker"] >= 3 ) then amount = amount * 1.1 end

			return CHANNEL_HEALS, ceil(amount / spellData[spellName].ticks), spellData[spellName].ticks, spellData[spellName].interval
		end
	end
end

if( playerClass == "WARLOCK" ) then
	LoadClassData = function()
		local HealthFunnel = GetSpellInfo(755)
		--local DrainLife = GetSpellInfo(689)
		local ImpHealthFunnel = GetSpellInfo(18703)

		spellData[HealthFunnel] = { interval = 1, levels = { 12, 20, 28, 36, 44, 52, 60 }, ticks = 10, averages = { 120, 240, 430, 640, 890, 1190, 1530 } }
		--spellData[DrainLife] = { interval = 1, levels = { 14, 22, 30, 38, 46, 54 }, ticks = 5, averages = { 10 * 5, 17 * 5, 29 * 5, 41 * 5, 55 * 5, 71 * 5 } }

		talentData[ImpHealthFunnel] = { mod = 0.1, current = 0 }

		GetHealTargets = function(bitType, guid, healAmount, spellID)
			return compressGUID[UnitGUID("pet")], healAmount
		end

		CalculateHealing = function(guid, spellID)
			local spellName, spellRank = GetSpellInfo(spellID), SpellIDToRank[spellID]
			local amount = getBaseHealAmount(spellData, spellName, spellRank)

			amount = amount * (1 + talentData[ImpHealthFunnel].current)

			return CHANNEL_HEALS, ceil(amount / spellData[spellName].ticks), spellData[spellName].ticks, spellData[spellName].interval
		end
	end
end

-- Healing modifiers
if( not HealComm.aurasUpdated ) then
	HealComm.aurasUpdated = true
	HealComm.healingModifiers = nil
end

HealComm.currentModifiers = HealComm.currentModifiers or {}

-- The only spell in the game with a name conflict is Ray of Pain from the Nagrand Void Walkers
HealComm.healingModifiers = HealComm.healingModifiers or {
	[28776] = 0.10, -- Necrotic Poison
	[19716] = 0.25, -- Gehennas' Curse
	[13218] = 0.50, -- Wound Poison1
	[13222] = 0.50, -- Wound Poison2
	[13223] = 0.50, -- Wound Poison3
	[13224] = 0.50, -- Wound Poison4
	[21551] = 0.50, -- Mortal Strike
	[23169] = 0.50, -- Brood Affliction: Green
	[22859] = 0.50, -- Mortal Cleave
	[17820] = 0.25, -- Veil of Shadow
	[22687] = 0.25, -- Veil of Shadow
	[23224] = 0.25, -- Veil of Shadow
	[24674] = 0.25, -- Veil of Shadow
	[28440] = 0.25, -- Veil of Shadow
	[13583] = 0.50, -- Curse of the Deadwood
	[23230] = 0.50, -- Blood Fury
}

HealComm.healingStackMods = HealComm.healingStackMods or {
	-- Mortal Wound
	[25646] = function(stacks) return 1 - stacks * 0.10 end,
	[28467] = function(stacks) return 1 - stacks * 0.10 end,
}

local healingStackMods = HealComm.healingStackMods
local healingModifiers, currentModifiers = HealComm.healingModifiers, HealComm.currentModifiers

local distribution
local CTL = _G.ChatThrottleLib
local function sendMessage(msg)
	if( distribution and strlen(msg) <= 240 ) then
		if CTL then
		CTL:SendAddonMessage("BULK", COMM_PREFIX, msg, distribution or 'GUILD')
	end
end
end

-- Keep track of where all the data should be going
local instanceType
local function updateDistributionChannel()
	if( instanceType == "pvp" ) then
		distribution = "BATTLEGROUND"
	elseif( IsInRaid() ) then
		distribution = "RAID"
	elseif( IsInGroup() ) then
		distribution = "PARTY"
	else
		distribution = nil
	end
end

-- Figure out where we should be sending messages and wipe some caches
function HealComm:PLAYER_ENTERING_WORLD()
	HealComm.eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
	HealComm:ZONE_CHANGED_NEW_AREA()
end

function HealComm:ZONE_CHANGED_NEW_AREA()
	local pvpType = GetZonePVPInfo()
	local instance = select(2, IsInInstance())

	HealComm.zoneHealModifier = 1
	if( pvpType == "combat" or instance == "arena" or instance == "pvp" ) then
		HealComm.zoneHealModifier = 0.90
	end

	if( instance ~= instanceType ) then
		instanceType = instance

		updateDistributionChannel()
		clearPendingHeals()
		wipe(activeHots)
	end

	instanceType = instance
end

local alreadyAdded = {}
function HealComm:UNIT_AURA(unit)
	local guid = UnitGUID(unit)
	if( not guidToUnit[guid] ) then return end
	local increase, decrease, playerIncrease, playerDecrease = 1, 1, 1, 1

	-- Scan buffs
	local id = 1
	while( true ) do
		local name, _, _, stack, _, _, _, _, _, _, spellID = UnitAura(unit, id, "HELPFUL")
		if( not name ) then break end
		-- Prevent buffs like Tree of Life that have the same name for the shapeshift/healing increase from being calculated twice
		if( not alreadyAdded[name] ) then
			alreadyAdded[name] = true

			if( healingModifiers[spellID] ) then
				increase = increase * healingModifiers[spellID]
			elseif( healingStackMods[spellID] ) then
				increase = increase * healingStackMods[spellID](stack)
			end
		end

		id = id + 1
	end

	-- Scan debuffs
	id = 1
	while( true ) do
		local name, _, _, stack, _, _, _, _, _, _, spellID = UnitAura(unit, id, "HARMFUL")
		if( not name ) then break end

		if( healingModifiers[spellID] ) then
			decrease = min(decrease, healingModifiers[spellID])
		elseif( healingStackMods[spellID] ) then
			decrease = min(decrease, healingStackMods[spellID](stack))
		end

		id = id + 1
	end

	-- Check if modifier changed
	local modifier = increase * decrease
	if( modifier ~= currentModifiers[guid] ) then
		if( currentModifiers[guid] or modifier ~= 1 ) then
			currentModifiers[guid] = modifier
			self.callbacks:Fire("HealComm_ModifierChanged", guid, modifier)
		else
			currentModifiers[guid] = modifier
		end
	end

	wipe(alreadyAdded)

	if( unit == "player" ) then
		playerHealModifier = playerIncrease * playerDecrease
	end

	-- Class has a specific monitor it needs for auras
	if( AuraHandler ) then
		AuraHandler(unit, guid)
	end
end

function HealComm:PLAYER_LEVEL_UP(level)
	playerLevel = tonumber(level) or UnitLevel("player")
end

-- Cache player talent data for spells we need
function HealComm:PLAYER_TALENT_UPDATE()
	for tabIndex=1, GetNumTalentTabs() do
		for i=1, GetNumTalents(tabIndex) do
			local name, _, _, _, spent = GetTalentInfo(tabIndex, i)
			if( name and talentData[name] ) then
				talentData[name].current = talentData[name].mod * spent
				talentData[name].spent = spent
			end
		end
	end
end

-- Save the currently equipped range weapon
local RANGED_SLOT = GetInventorySlotInfo("RangedSlot")
function HealComm:PLAYER_EQUIPMENT_CHANGED()
	-- Caches set bonus info, as you can't reequip set bonus gear in combat no sense in checking it
	if( not InCombatLockdown() ) then
		for name, items in pairs(itemSetsData) do
			equippedSetCache[name] = 0
			for _, itemID in pairs(items) do
				if( IsEquippedItem(itemID) ) then
					equippedSetCache[name] = equippedSetCache[name] + 1
				end
			end
		end
	end

	-- Check relic
	local relic = GetInventoryItemLink("player", RANGED_SLOT)
	playerCurrentRelic = relic and tonumber(strmatch(relic, "item:(%d+):")) or nil
end

-- COMM CODE
local function loadHealAmount(...)
	local tbl = HealComm:RetrieveTable()
	for i=1, select("#", ...) do
		tbl[i] = tonumber((select(i, ...)))
	end

	return tbl
end

-- Direct heal started
local function loadHealList(pending, amount, stack, endTime, ticksLeft, ...)
	wipe(tempPlayerList)

	-- For the sake of consistency, even a heal doesn't have multiple end times like a hot, it'll be treated as such in the DB
	if( amount ~= -1 and amount ~= "-1" ) then
		amount = not pending.hasVariableTicks and amount or loadHealAmount(strsplit("@", amount))

		for i=1, select("#", ...) do
			local guid = select(i, ...)
			local decompGUID = guid and decompressGUID[guid]
			if( decompGUID ) then
				updateRecord(pending, decompGUID, amount, stack, endTime, ticksLeft)
				tinsert(tempPlayerList, decompGUID)
			end
		end
	else
		for i = 1, select("#", ...), 2 do
			local guid = select(i, ...)
			local decompGUID = guid and decompressGUID[guid]
			amount = tonumber((select(i + 1, ...)))
			if( decompGUID and amount ) then
				updateRecord(pending, decompGUID, amount, stack, endTime, ticksLeft)
				tinsert(tempPlayerList, decompGUID)
			end
		end
	end
end

local function parseDirectHeal(casterGUID, spellID, amount, castTime, ...)
	local spellName = GetSpellInfo(spellID)
	local unit = guidToUnit[casterGUID]

	if( not unit or not spellName or not amount or select("#", ...) == 0 ) then return end

	local endTime
	if unit == "player" then
		endTime = select(5, CastingInfo())
		if not endTime then return end
		endTime = endTime / 1000
	else
		endTime = GetTime() + (castTime or 1.5)
	end

	pendingHeals[casterGUID] = pendingHeals[casterGUID] or {}
	pendingHeals[casterGUID][spellName] = pendingHeals[casterGUID][spellName] or {}

	local pending = pendingHeals[casterGUID][spellName]
	wipe(pending)
	pending.endTime = endTime
	pending.spellID = spellID
	pending.bitType = DIRECT_HEALS

	loadHealList(pending, amount, 1, pending.endTime, nil, ...)

	HealComm.callbacks:Fire("HealComm_HealStarted", casterGUID, spellID, pending.bitType, pending.endTime, unpack(tempPlayerList))
end

HealComm.parseDirectHeal = parseDirectHeal

-- Channeled heal started
local function parseChannelHeal(casterGUID, spellID, amount, totalTicks, ...)
	local spellName = GetSpellInfo(spellID)
	local unit = guidToUnit[casterGUID]
	if( not unit or not spellName or not totalTicks or not amount or select("#", ...) == 0 ) then return end

	local tickInterval = spellName == GetSpellInfo(740) and 2 or 1

	local startTime, endTime
	if unit == "player" then
		startTime, endTime = select(4, ChannelInfo())
		if not startTime then return end
		startTime = startTime / 1000
		endTime = endTime / 1000
	else
		startTime = GetTime()
		endTime = startTime + totalTicks * tickInterval
	end

	pendingHots[casterGUID] = pendingHots[casterGUID] or {}
	pendingHots[casterGUID][spellName] = pendingHots[casterGUID][spellName] or {}

	local inc = amount == -1 and 2 or 1
	local pending = pendingHots[casterGUID][spellName]
	wipe(pending)
	pending.startTime = startTime
	pending.endTime = endTime
	pending.duration = max(pending.duration or 0, pending.endTime - pending.startTime)
	pending.totalTicks = totalTicks
	pending.tickInterval = (pending.endTime - pending.startTime) / totalTicks
	pending.spellID = spellID
	pending.isMultiTarget = (select("#", ...) / inc) > 1
	pending.bitType = CHANNEL_HEALS

	loadHealList(pending, amount, 1, pending.endTime, ceil(pending.duration / pending.tickInterval), ...)

	HealComm.callbacks:Fire("HealComm_HealStarted", casterGUID, spellID, pending.bitType, pending.endTime, unpack(tempPlayerList))
end

-- Hot heal started
-- When the person is within visible range of us, the aura is available by the time the message reaches the target
-- as such, we can rely that at least one person is going to have the aura data on them (and that it won't be different, at least for this cast)
local function findAura(casterGUID, spellID, ...)
	for i = 1, select("#", ...) do
		local guid = decompressGUID[select(i, ...)]
		local unit = guid and guidToUnit[guid]
		if( unit and UnitIsVisible(unit) ) then
			local id = 1
			while true do
				local name, _, stack, _, duration, endTime, caster, _, _, spell = UnitAura(unit, id, 'HELPFUL')
				if( not spell ) then break end

				if( spell == spellID and caster and UnitGUID(caster) == casterGUID ) then
					return (stack and stack > 0 and stack or 1), duration or 0, endTime or 0
				end

				id = id + 1
			end
		end
	end
end

local function parseHotHeal(casterGUID, wasUpdated, spellID, tickAmount, totalTicks, tickInterval, ...)
	local spellName = GetSpellInfo(spellID)
	-- If the user is on 3.3, then anything without a total ticks attached to it is rejected
	if( not tickAmount or not spellName or select("#", ...) == 0 ) then return end

	-- Retrieve the hot information
	local inc = 2
	local stack, duration, endTime = findAura(casterGUID, spellID, ...)

	if not ( tickAmount == -1 or tickAmount == "-1" ) then
		inc = 1
		duration = totalTicks * tickInterval
		endTime = GetTime() + duration
	end

	if( not stack or stack == 0 or duration == 0 or endTime == 0 ) then return end

	pendingHots[casterGUID] = pendingHots[casterGUID] or {}
	pendingHots[casterGUID][spellName] = pendingHots[casterGUID][spellName] or {}

	local pending = pendingHots[casterGUID][spellName]
	pending.duration = duration
	pending.endTime = endTime
	pending.stack = stack
	pending.totalTicks = totalTicks or duration / tickInterval
	pending.tickInterval = totalTicks and duration / totalTicks or tickInterval
	pending.spellID = spellID
	pending.hasVariableTicks = type(tickAmount) == "string"
	pending.isMutliTarget = (select("#", ...) / inc) > 1
	pending.bitType = HOT_HEALS

	-- As you can't rely on a hot being the absolutely only one up, have to apply the total amount now :<
	local ticksLeft = ceil((endTime - GetTime()) / pending.tickInterval)
	loadHealList(pending, tickAmount, stack, endTime, ticksLeft, ...)

	if( not wasUpdated ) then
		HealComm.callbacks:Fire("HealComm_HealStarted", casterGUID, spellID, pending.bitType, endTime, unpack(tempPlayerList))
	else
		HealComm.callbacks:Fire("HealComm_HealUpdated", casterGUID, spellID, pending.bitType, endTime, unpack(tempPlayerList))
	end
end

-- Heal finished
local function parseHealEnd(casterGUID, pending, checkField, spellID, interrupted, ...)
	local spellName = GetSpellInfo(spellID)
	if( not spellName or not casterGUID ) then return end

	if( not pending ) then
		if pendingHeals[casterGUID] then
			pending = pendingHeals[casterGUID][spellName]
		end
		if (not pending) and pendingHots[casterGUID] then
			pending = pendingHots[casterGUID][spellName]
		end
	end
	if( not pending or not pending.bitType ) then return end

	wipe(tempPlayerList)

	if( select("#", ...) == 0 ) then
		for i=#(pending), 1, -5 do
			tinsert(tempPlayerList, pending[i - 4])
			removeRecord(pending, pending[i - 4])
		end
	else
		for i=1, select("#", ...) do
			local guid = decompressGUID[select(i, ...)]

			tinsert(tempPlayerList, guid)
			removeRecord(pending, guid)
		end
	end

	-- Double check and make sure we actually removed at least one person
	if( #(tempPlayerList) == 0 ) then return end

	local bitType = pending.bitType
	-- Clear data if we're done
	if( #(pending) == 0 ) then wipe(pending) end

	HealComm.callbacks:Fire("HealComm_HealStopped", casterGUID, spellID, bitType, interrupted, unpack(tempPlayerList))
end

HealComm.parseHealEnd = parseHealEnd

-- Heal delayed
local function parseHealDelayed(casterGUID, startTime, endTime, spellName)
	if not casterGUID then return end
	local pending = (pendingHeals[casterGUID][spellName] or pendingHots[casterGUID][spellName])
	-- It's possible to get duplicate interrupted due to raid1 = party1, player = raid# etc etc, just block it here
	if( pending.endTime == endTime and pending.startTime == startTime ) then return end

	-- Casted heal
	if( pending.bitType == DIRECT_HEALS ) then
		pending.startTime = startTime
		pending.endTime = endTime
	-- Channel heal
	elseif( pending.bitType == CHANNEL_HEALS ) then
		pending.startTime = startTime
		pending.endTime = endTime
		pending.tickInterval = (pending.endTime - pending.startTime)
	else
		return
	end

	wipe(tempPlayerList)
	for i=1, #(pending), 5 do
		tinsert(tempPlayerList, pending[i])
	end

	HealComm.callbacks:Fire("HealComm_HealDelayed", casterGUID, pending.spellID, pending.bitType, pending.endTime, unpack(tempPlayerList))
end

-- After checking around 150-200 messages in battlegrounds, server seems to always be passed (if they are from another server)
-- Channels use tick total because the tick interval varies by haste
-- Hots use tick interval because the total duration varies but the tick interval stays the same
function HealComm:CHAT_MSG_ADDON(prefix, message, channel, sender)
	if( prefix ~= COMM_PREFIX or channel ~= distribution ) then return end

	local commType, extraArg, spellID, arg1, arg2, arg3, arg4 = strsplit(":", message)
	local casterGUID = UnitGUID(Ambiguate(sender, "none"))
	spellID = tonumber(spellID)

	if( not commType or not spellID or not casterGUID or casterGUID == playerGUID) then return end

	-- New direct heal - D:<extra>:<spellID>:<amount>:target1,target2...
	if( commType == "D" and arg1 and arg2 ) then
		parseDirectHeal(casterGUID, spellID, tonumber(arg1), extraArg, strsplit(",", arg2))
	-- New channel heal - C:<extra>:<spellID>:<amount>:<totalTicks>:target1,target2...
	elseif( commType == "C" and arg1 and arg3 ) then
		parseChannelHeal(casterGUID, spellID, tonumber(arg1), tonumber(arg2), strsplit(",", arg3))
	-- New hot - H:<totalTicks>:<spellID>:<amount>:<isMulti>:<tickInterval>:target1,target2...
	elseif( commType == "H" and arg1 and arg4 ) then
		parseHotHeal(casterGUID, false, spellID, tonumber(arg1), tonumber(extraArg), tonumber(arg3), strsplit(",", arg4))
	-- New updated heal somehow before ending - U:<totalTicks>:<spellID>:<amount>:<tickInterval>:target1,target2...
	elseif( commType == "U" and arg1 and arg3 ) then
		parseHotHeal(casterGUID, true, spellID, tonumber(arg1), tonumber(extraArg), tonumber(arg2), strsplit(",", arg3))
	-- Heal stopped - S:<extra>:<spellID>:<ended early: 0/1>:target1,target2...
	elseif( commType == "S" or commType == "HS" ) then
		local interrupted = arg1 == "1" and true or false
		local checkType = commType == "HS" and "id" or "name"

		if( arg2 and arg2 ~= "" ) then
			parseHealEnd(casterGUID, nil, checkType, spellID, interrupted, strsplit(",", arg2))
		else
			parseHealEnd(casterGUID, nil, checkType, spellID, interrupted)
		end
	end
end

-- Bucketing reduces the number of events triggered for heals such as Tranquility that hit multiple targets
-- instead of firing 5 events * ticks it will fire 1 (maybe 2 depending on lag) events
HealComm.bucketHeals = HealComm.bucketHeals or {}
local bucketHeals = HealComm.bucketHeals
local BUCKET_FILLED = 0.30

HealComm.bucketFrame = HealComm.bucketFrame or CreateFrame("Frame")
HealComm.bucketFrame:Hide()

HealComm.bucketFrame:SetScript("OnUpdate", function(self, elapsed)
	local totalLeft = 0
	for casterGUID, spells in pairs(bucketHeals) do
		for _, data in pairs(spells) do
			if( data.timeout ) then
				data.timeout = data.timeout - elapsed
				if( data.timeout <= 0 ) then
					-- This shouldn't happen, on the offhand chance it does then don't bother sending an event
					if( #(data) == 0 or not data.spellID or not data.spellName ) then
						wipe(data)
					-- We're doing a bucket for a tick heal like Tranquility or Wild Growth
					elseif( data.type == "tick" ) then
						local pending = pendingHots[casterGUID] and pendingHots[casterGUID][data.spellName]
						if( pending and pending.bitType ) then
							local endTime = select(3, getRecord(pending, data[1]))
							HealComm.callbacks:Fire("HealComm_HealUpdated", casterGUID, pending.spellID, pending.bitType, endTime, unpack(data))
						end

						wipe(data)
					-- We're doing a bucket for a cast thats a multi-target heal like Wild Growth or Prayer of Healing
					elseif( data.type == "heal" ) then
						local bitType, amount, totalTicks, tickInterval, _ = CalculateHotHealing(data[1], data.spellID)
						if( bitType ) then
							local targets, amt = GetHealTargets(bitType, data[1], max(amount, 0), data.spellID, data)
							parseHotHeal(playerGUID, false, data.spellID, amt, totalTicks, tickInterval, strsplit(",", targets))
							sendMessage(format("H:%d:%d:%d::%d:%s", totalTicks, data.spellID, amt, tickInterval, targets))
						end

						wipe(data)
					end
				else
					totalLeft = totalLeft + 1
				end
			end
		end
	end

	if( totalLeft <= 0 ) then
		self:Hide()
	end
end)

-- Monitor aura changes as well as new hots being cast
local eventRegistered = {
	SPELL_HEAL = true,
	SPELL_PERIODIC_HEAL = true,
	SPELL_AURA_REMOVED = true,
	SPELL_AURA_APPLIED = true,
	SPELL_AURA_REFRESH = true,
	SPELL_AURA_APPLIED_DOSE = true,
	SPELL_AURA_REMOVED_DOSE = true,
}

function HealComm:COMBAT_LOG_EVENT_UNFILTERED(...)
	local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = ...

	if( not eventRegistered[eventType] ) then return end

	local _, spellName = select(12, ...)
	local destUnit = guidToUnit[destGUID]
	local spellID = destUnit and select(10, unitHasAura(destUnit, spellName)) or select(7, GetSpellInfo(spellName))

	-- Heal or hot ticked that the library is tracking
	-- It's more efficient/accurate to have the library keep track of this locally, spamming the comm channel would not be a very good thing especially when a single player can have 4 - 8 hots/channels going on them.
	if( eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL" ) then
		local pending = sourceGUID and pendingHots[sourceGUID] and pendingHots[sourceGUID][spellName]
		if( pending and pending[destGUID] and pending.bitType and bit.band(pending.bitType, OVERTIME_HEALS) > 0 ) then
			local amount, stack, _, ticksLeft = getRecord(pending, destGUID)
			ticksLeft = ticksLeft - 1
			local endTime = GetTime() + pending.tickInterval * ticksLeft

			updateRecord(pending, destGUID, amount, stack, endTime, ticksLeft)

			if( pending.isMultiTarget ) then
				bucketHeals[sourceGUID] = bucketHeals[sourceGUID] or {}
				bucketHeals[sourceGUID][spellID] = bucketHeals[sourceGUID][spellID] or {}

				local spellBucket = bucketHeals[sourceGUID][spellID]
				if( not spellBucket[destGUID] ) then
					spellBucket.timeout = BUCKET_FILLED
					spellBucket.type = "tick"
					spellBucket.spellName = spellName
					spellBucket.spellID = spellID
					spellBucket[destGUID] = true
					tinsert(spellBucket, destGUID)

					self.bucketFrame:Show()
				end
			else
				HealComm.callbacks:Fire("HealComm_HealUpdated", sourceGUID, spellID, pending.bitType, endTime, destGUID)
			end
		end

	-- New hot was applied
	elseif( ( eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH" or eventType == "SPELL_AURA_APPLIED_DOSE" ) and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) == COMBATLOG_OBJECT_AFFILIATION_MINE ) then
		if( hotData[spellName] ) then
			-- Single target so we can just send it off now thankfully
			local bitType, amount, totalTicks, tickInterval = CalculateHotHealing(destGUID, spellID)
			if( bitType ) then
				local targets, amt = GetHealTargets(type, destGUID, max(amount, 0), spellID)
				if targets then
					parseHotHeal(sourceGUID, false, spellID, amt, totalTicks, tickInterval, strsplit(",", targets))
					sendMessage(format("H:%d:%d:%d::%d:%s", totalTicks, spellID, amount, tickInterval, targets))
				end
			end
		elseif spellData[spellName] and spellData[spellName]._isChanneled then
			local bitType, amount, totalTicks, tickInterval = CalculateHealing(destGUID, spellID, destUnit)
			if bitType == CHANNEL_HEALS then
				local targets, amt = compressGUID[destGUID], max(amount, 0)
				if targets then
					local endTime = select(5, ChannelInfo())
					if endTime then
						endTime = endTime / 1000
					else
						endTime = GetTime() + totalTicks * tickInterval
					end
					local ticksLeft = min(floor((endTime - GetTime() + 0.001) / tickInterval), totalTicks)
					if ticksLeft > 0 then
						parseChannelHeal(sourceGUID, spellID, amt, ticksLeft, strsplit(",", targets))
						sendMessage(format("C::%d:%d:%s:%s", spellID, amt, ticksLeft, targets))
					end
				end
			end
		end
	-- Single stack of a hot was removed, this only applies when going from 2 -> 1, when it goes from 1 -> 0 it fires SPELL_AURA_REMOVED
	elseif( eventType == "SPELL_AURA_REMOVED_DOSE" and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) == COMBATLOG_OBJECT_AFFILIATION_MINE ) then
		local pending = sourceGUID and pendingHeals[sourceGUID] and pendingHeals[sourceGUID][spellID]
		if( pending and pending.bitType ) then
			local amount = getRecord(pending, destGUID)
			if( amount ) then
				parseHotHeal(sourceGUID, true, spellID, amount, pending.totalTicks, pending.tickInterval, compressGUID[destGUID])
				sendMessage(format("U:%s:%d:%d:%d:%s", spellID, amount, pending.totalTicks, pending.tickInterval, compressGUID[destGUID]))
			end
		end
	-- Aura faded
	elseif( eventType == "SPELL_AURA_REMOVED" and bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) == COMBATLOG_OBJECT_AFFILIATION_MINE ) then
		if compressGUID[destGUID] then
		-- Hot faded that we cast
			if hotData[spellName] then
			parseHealEnd(sourceGUID, nil, "id", spellID, false, compressGUID[destGUID])
			sendMessage(format("HS::%d::%s", spellID, compressGUID[destGUID]))
			elseif spellData[spellName] and spellData[spellName]._isChanneled then
				parseHealEnd(sourceGUID, nil, "id", spellID, false, compressGUID[destGUID])
				sendMessage(format("S::%d:0:%s", spellID, compressGUID[destGUID]))
			end
		end
	end
end

-- Spell cast magic
-- When auto self cast is on, the UNIT_SPELLCAST_SENT event will always come first followed by the funciton calls
-- Otherwise either SENT comes first then function calls, or some function calls then SENT then more function calls
local castTarget, mouseoverGUID, mouseoverName, hadTargetingCursor, lastSentID, lastTargetGUID, lastTargetName
local lastFriendlyGUID, lastFriendlyName, lastGUID, lastName, lastIsFriend
local castGUIDs, guidPriorities = {}, {}

-- Deals with the fact that functions are called differently
-- Why a table when you can only cast one spell at a time you ask? When you factor in lag and mash clicking it's possible to:
-- cast A, interrupt it, cast B and have A fire SUCEEDED before B does, the tables keeps it from bugging out
local function setCastData(priority, name, guid)
	if( not guid or not lastSentID ) then return end
	if( guidPriorities[lastSentID] and guidPriorities[lastSentID] >= priority ) then return end

	-- This is meant as a way of locking a cast in because which function has accurate data can be called into question at times, one of them always does though
	-- this means that as soon as it finds a name match it locks the GUID in until another SENT is fired. Technically it's possible to get a bad GUID but it first requires
	-- the functions to return different data and it requires the messed up call to be for another name conflict.
	if( castTarget and castTarget == name ) then priority = 99 end

	castGUIDs[lastSentID] = guid
	guidPriorities[lastSentID] = priority
end

-- When the game tries to figure out the UnitID from the name it will prioritize players over non-players
-- if there are conflicts in names it will pull the one with the least amount of current health
function HealComm:UNIT_SPELLCAST_SENT(unit, targetName, castGUID, spellID)
	local spellName = GetSpellInfo(spellID)
	if(unit ~= "player") then return end

	if hotData[spellName] or spellData[spellName] then
		targetName = targetName or UnitName("player")

		castTarget = gsub(targetName, "(.-)%-(.*)$", "%1")
		lastSentID = spellID

		-- Self cast is off which means it's possible to have a spell waiting for a target.
		-- It's possible that it's the mouseover unit, but if a Target, TargetLast or AssistUnit call comes right after it means it's casting on that instead instead.
		if( hadTargetingCursor ) then
			hadTargetingCursor = nil
			self.resetFrame:Show()

			guidPriorities[lastSentID] = nil
			setCastData(5, mouseoverName, mouseoverGUID)
		else
			-- If the player is ungrouped and healing, you can't take advantage of the name -> "unit" map, look in the UnitIDs that would most likely contain the information that's needed.
			local guid = UnitGUID(targetName)
			if( not guid ) then
				guid = UnitName("target") == castTarget and UnitGUID("target") or UnitName("focus") == castTarget and UnitGUID("focus") or UnitName("mouseover") == castTarget and UnitGUID("mouseover") or UnitName("targettarget") == castTarget and UnitGUID("target") or UnitName("focustarget") == castTarget and UnitGUID("focustarget")
			end

			guidPriorities[lastSentID] = nil
			setCastData(0, nil, guid)
		end
	end
end

function HealComm:UNIT_SPELLCAST_START(unit, cast, spellID)
	if( unit ~= "player") then return end

	local spellName = GetSpellInfo(spellID)

	if (not spellData[spellName] or UnitIsCharmed("player") or not UnitPlayerControlled("player") ) then return end

	local castGUID = castGUIDs[spellID]
	local castUnit = guidToUnit[castGUID]
	if( not castGUID or not castUnit ) then
		return
	end

	-- Figure out who we are healing and for how much
	local bitType, amount, ticks, tickInterval = CalculateHealing(castGUID, spellID, castUnit)
	local targets, amt = GetHealTargets(bitType, castGUID, max(amount, 0), spellID)

	if not targets then return end -- only here until I compress/decompress npcs

	if( bitType == DIRECT_HEALS ) then
		local startTime, endTime = select(4, CastingInfo())
		parseDirectHeal(playerGUID, spellID, amt, (endTime - startTime) / 1000, strsplit(",", targets))
		sendMessage(format("D:%d:%d:%d:%s", (endTime - startTime) / 1000, spellID or 0, amt or "", targets))
	elseif( bitType == CHANNEL_HEALS ) then
		spellData[spellName]._isChanneled = true
	end
end

HealComm.UNIT_SPELLCAST_CHANNEL_START = HealComm.UNIT_SPELLCAST_START

function HealComm:UNIT_SPELLCAST_SUCCEEDED(unit, cast, spellID)
	if( unit ~= "player") then return end
	local spellName = GetSpellInfo(spellID)

	if spellData[spellName] and not spellData[spellName]._isChanneled then
		parseHealEnd(playerGUID, nil, "name", spellID, false)
		sendMessage(format("S::%d:0", spellID or 0))
	end
end

function HealComm:UNIT_SPELLCAST_STOP(unit, castGUID, spellID)
	local spellName = GetSpellInfo(spellID)
	if( unit ~= "player" or not spellData[spellName] or spellData[spellName]._isChanneled ) then return end

	parseHealEnd(playerGUID, nil, "name", spellID, true)
	sendMessage(format("S::%d:1", spellID or 0))
end

-- Cast didn't go through, recheck any charge data if necessary
function HealComm:UNIT_SPELLCAST_INTERRUPTED(unit, castGUID, spellID)
	local spellName = GetSpellInfo(spellID)
	if( unit ~= "player" or not spellData[spellName] ) then return end

	local guid = castGUIDs[spellID]
	if( guid ) then
		ResetChargeData(guid, spellID)
	end
end

-- It's faster to do heal delays locally rather than through syncing, as it only has to go from WoW -> Player instead of Caster -> WoW -> Player
function HealComm:UNIT_SPELLCAST_DELAYED(unit, castGUID, spellID)
	local spellName = GetSpellInfo(spellID)
	local casterGUID = UnitGUID(unit)
	if( unit == "focus" or unit == "target" or not pendingHeals[casterGUID] or not pendingHeals[casterGUID][spellName] ) then return end

	-- Direct heal delayed
	if( pendingHeals[casterGUID][spellName].bitType == DIRECT_HEALS ) then
		local startTime, endTime = select(4, ChannelInfo())
		if( startTime and endTime ) then
			parseHealDelayed(casterGUID, startTime / 1000, endTime / 1000, spellName)
		end
	-- Channel heal delayed
	elseif( pendingHeals[casterGUID][spellName].bitType == CHANNEL_HEALS ) then
		local startTime, endTime = select(4, ChannelInfo(unit))
		if( startTime and endTime ) then
			parseHealDelayed(casterGUID, startTime / 1000, endTime / 1000, spellName)
		end
	end
end

HealComm.UNIT_SPELLCAST_CHANNEL_UPDATE = HealComm.UNIT_SPELLCAST_DELAYED

-- Need to keep track of mouseover as it can change in the split second after/before casts
function HealComm:UPDATE_MOUSEOVER_UNIT()
	mouseoverGUID = UnitCanAssist("player", "mouseover") and UnitGUID("mouseover")
	mouseoverName = UnitCanAssist("player", "mouseover") and UnitName("mouseover")
end

-- Keep track of our last target/friendly target for the sake of /targetlast and /targetlastfriend
function HealComm:PLAYER_TARGET_CHANGED()
	if( lastGUID and lastName ) then
		if( lastIsFriend ) then
			lastFriendlyGUID, lastFriendlyName = lastGUID, lastName
		end

		lastTargetGUID, lastTargetName = lastGUID, lastName
	end

	-- Despite the fact that it's called target last friend, UnitIsFriend won't actually work
	lastGUID = UnitGUID("target")
	lastName = UnitName("target")
	lastIsFriend = UnitCanAssist("player", "target")
end

-- Unit was targeted through a function
function HealComm:Target(unit)
	if( self.resetFrame:IsShown() and UnitCanAssist("player", unit) ) then
		setCastData(6, UnitName(unit), UnitGUID(unit))
	end

	self.resetFrame:Hide()
	hadTargetingCursor = nil
end

-- This is only needed when auto self cast is off, in which case this is called right after UNIT_SPELLCAST_SENT
-- because the player got a waiting-for-cast icon up and they pressed a key binding to target someone
HealComm.TargetUnit = HealComm.Target

-- Works the same as the above except it's called when you have a cursor icon and you click on a secure frame with a target attribute set
HealComm.SpellTargetUnit = HealComm.Target

-- Used in /assist macros
function HealComm:AssistUnit(unit)
	if( self.resetFrame:IsShown() and UnitCanAssist("player", unit .. "target") ) then
		setCastData(6, UnitName(unit .. "target"), UnitGUID(unit .. "target"))
	end

	self.resetFrame:Hide()
	hadTargetingCursor = nil
end

-- Target last was used, the only reason this is called with reset frame being shown is we're casting on a valid unit
-- don't have to worry about the GUID no longer being invalid etc
function HealComm:TargetLast(guid, name)
	if( name and guid and self.resetFrame:IsShown() ) then
		setCastData(6, name, guid)
	end

	self.resetFrame:Hide()
	hadTargetingCursor = nil
end

function HealComm:TargetLastFriend()
	self:TargetLast(lastFriendlyGUID, lastFriendlyName)
end

function HealComm:TargetLastTarget()
	self:TargetLast(lastTargetGUID, lastTargetName)
end

-- Spell was cast somehow
function HealComm:CastSpell(arg, unit)
	-- If the spell is waiting for a target and it's a spell action button then we know that the GUID has to be mouseover or a key binding cast.
	if( unit and UnitCanAssist("player", unit)  ) then
		setCastData(4, UnitName(unit), UnitGUID(unit))
	-- No unit, or it's a unit we can't assist
	elseif( not SpellIsTargeting() ) then
		if( UnitCanAssist("player", "target") ) then
			setCastData(4, UnitName("target"), UnitGUID("target"))
		else
			setCastData(4, playerName, playerGUID)
		end

		hadTargetingCursor = nil
	else
		hadTargetingCursor = true
	end
end

HealComm.CastSpellByName = HealComm.CastSpell
HealComm.CastSpellByID = HealComm.CastSpell
HealComm.UseAction = HealComm.CastSpell

-- Make sure we don't have invalid units in this
local function sanityCheckMapping()
	for guid, unit in pairs(guidToUnit) do
		-- Unit no longer exists, remove all healing for them
		if( not UnitExists(unit) ) then
			-- Check for (and remove) any active heals
			for _, tbl in pairs({ pendingHeals, pendingHots }) do
				if tbl[guid] then
					for _, pending in pairs(tbl[guid]) do
						if( pending.bitType ) then
							parseHealEnd(guid, pending, nil, pending.spellID, true)
						end
					end
				end
			end

			pendingHeals[guid] = nil
			pendingHots[guid] = nil

			-- Remove any heals that are on them
			removeAllRecords(guid)

			guidToUnit[guid] = nil
			guidToGroup[guid] = nil
		end
	end
end

-- 5s poll that tries to solve the problem of X running out of range while a HoT is ticking
-- this is not really perfect far from it in fact. If I can find a better solution I will switch to that.
if( not HealComm.hotMonitor ) then
	HealComm.hotMonitor = CreateFrame("Frame")
	HealComm.hotMonitor:Hide()
	HealComm.hotMonitor.timeElapsed = 0
	HealComm.hotMonitor:SetScript("OnUpdate", function(self, elapsed)
		self.timeElapsed = self.timeElapsed + elapsed
		if( self.timeElapsed < 5 ) then return end
		self.timeElapsed = self.timeElapsed - 5

		-- For the time being, it will only remove them if they don't exist and it found a valid unit
		-- units that leave the raid are automatically removed
		local found
		for guid in pairs(activeHots) do
			if( guidToUnit[guid] and not UnitIsVisible(guidToUnit[guid]) ) then
				removeAllRecords(guid)
			else
				found = true
			end
		end

		if( not found ) then
			self:Hide()
		end
	end)
end

-- After the player leaves a group, tables are wiped out or released for GC
local function clearGUIDData()
	clearPendingHeals()

	wipe(compressGUID)
	wipe(decompressGUID)
	wipe(activePets)

	playerGUID = playerGUID or UnitGUID("player")
	HealComm.guidToUnit = {[playerGUID] = "player"}
	guidToUnit = HealComm.guidToUnit

	HealComm.guidToGroup = {}
	guidToGroup = HealComm.guidToGroup

	HealComm.activeHots = {}
	activeHots = HealComm.activeHots

	HealComm.pendingHeals = {}
	pendingHeals = HealComm.pendingHeals

	HealComm.pendingHots = {}
	pendingHots = HealComm.pendingHots

	HealComm.bucketHeals = {}
	bucketHeals = HealComm.bucketHeals
end

-- Keeps track of pet GUIDs, as pets are considered vehicles this will also map vehicle GUIDs to unit
function HealComm:UNIT_PET(unit)
	local pet = self.unitToPet[unit]
	local guid = pet and UnitGUID(pet)

	-- We have an active pet guid from this user and it's different, kill it
	local activeGUID = activePets[unit]
	if( activeGUID and activeGUID ~= guid ) then
		removeAllRecords(activeGUID)

		guidToUnit[activeGUID] = nil
		guidToGroup[activeGUID] = nil
		activePets[unit] = nil
	end

	-- Add the new record
	if( guid ) then
		guidToUnit[guid] = pet
		guidToGroup[guid] = guidToGroup[UnitGUID(unit)]
		activePets[unit] = guid
	end
end

-- Keep track of raid GUIDs
function HealComm:GROUP_ROSTER_UPDATE()
	updateDistributionChannel()

	-- Left raid, clear any cache we had
	if( GetNumGroupMembers() == 0 ) then
		clearGUIDData()
		return
	end

	local isInRaid = IsInRaid()
	local unitType = isInRaid and "raid%d" or "party%d"
	if not isInRaid then
		guidToUnit[playerGUID or UnitGUID("player")] = "player"
		guidToGroup[playerGUID or UnitGUID("player")] = 1 -- Player doesn't belong to 'party%d' unit.
	end
	-- Add new members
	for i = 1, GetNumGroupMembers() do
		local unit = format(unitType, i)
		if( UnitExists(unit) ) then
			local guid = UnitGUID(unit)
			local lastGroup = guidToGroup[guid]
			guidToUnit[guid] = unit
			guidToGroup[guid] = select(3, GetRaidRosterInfo(i))

			-- If the pets owners group changed then the pets group should be updated too
			if guidToGroup[guid] ~= lastGroup then
				self:UNIT_PET(unit)
			end
		end
	end

	sanityCheckMapping()
end

-- PLAYER_ALIVE = got talent data
function HealComm:PLAYER_ALIVE()
	self:PLAYER_TALENT_UPDATE()
	self.eventFrame:UnregisterEvent("PLAYER_ALIVE")
end

-- Initialize the library
function HealComm:OnInitialize()
	-- If another instance already loaded then the tables should be wiped to prevent old data from persisting
	-- in case of a spell being removed later on, only can happen if a newer LoD version is loaded
	wipe(spellData)
	wipe(hotData)
	wipe(itemSetsData)
	wipe(talentData)

	-- Load all of the classes formulas and such
	if LoadClassData then
	LoadClassData()
	end

	do
		local FirstAid = GetSpellInfo(746)

		spellData[FirstAid] = { ticks = {6, 6, 7, 7, 8, 8, 8, 8, 8, 8, 8, 10}, interval = 1, averages = {
			66, 114, 161, 301, 400, 640, 800, 1104, 1360, 2000} }

		local _GetHealTargets = GetHealTargets

		GetHealTargets = function(bitType, guid, healAmount, spellID, data)
			local spellName = GetSpellInfo(spellID)

			if spellName == FirstAid then
				return compressGUID[guid], healAmount
			end

			if _GetHealTargets then
				return _GetHealTargets(bitType, guid, healAmount, spellID, data)
			end
		end

		local _CalculateHealing = CalculateHealing

		CalculateHealing = function(guid, spellID, unit)
			local spellName, spellRank = GetSpellInfo(spellID), SpellIDToRank[spellID]

			if spellName == FirstAid then
				local healAmount =  spellData[spellName].averages[spellRank]
				local ticks = spellData[spellName].ticks[spellRank]

				return CHANNEL_HEALS, ceil(healAmount / ticks), ticks, spellData[spellName].interval
			end

			if _CalculateHealing then
			return _CalculateHealing(guid, spellID, unit)
		end
	end
	end

	self:PLAYER_EQUIPMENT_CHANGED()

	-- When first logging in talent data isn't available until at least PLAYER_ALIVE, so if we don't have data
	-- will wait for that event otherwise will just cache it right now
	if( GetNumTalentTabs() == 0 ) then
		self.eventFrame:RegisterEvent("PLAYER_ALIVE")
	else
		self:PLAYER_TALENT_UPDATE()
	end

	if( ResetChargeData ) then
		HealComm.eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	end

	-- Finally, register it all
	self.eventFrame:RegisterEvent("CHAT_MSG_ADDON")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
	self.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self.eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	self.eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	self.eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
	self.eventFrame:RegisterEvent("UNIT_AURA")

	if( self.initialized ) then return end
	self.initialized = true

	self.resetFrame = CreateFrame("Frame")
	self.resetFrame:Hide()
	self.resetFrame:SetScript("OnUpdate", function(self) self:Hide() end)

	-- You can't unhook secure hooks after they are done, so will hook once and the HealComm table will update with the latest functions
	-- automagically. If a new function is ever used it'll need a specific variable to indicate those set of hooks.
	-- By default most of these are mapped to a more generic function, but I call separate ones so I don't have to rehook
	-- if it turns out I need to know something specific
	hooksecurefunc("TargetUnit", function(...) HealComm:TargetUnit(...) end)
	hooksecurefunc("SpellTargetUnit", function(...) HealComm:SpellTargetUnit(...) end)
	hooksecurefunc("AssistUnit", function(...) HealComm:AssistUnit(...) end)
	hooksecurefunc("UseAction", function(...) HealComm:UseAction(...) end)
	hooksecurefunc("TargetLastFriend", function(...) HealComm:TargetLastFriend(...) end)
	hooksecurefunc("TargetLastTarget", function(...) HealComm:TargetLastTarget(...) end)
	hooksecurefunc("CastSpellByName", function(...) HealComm:CastSpellByName(...) end)
	hooksecurefunc("CastSpellByID", function(...) HealComm:CastSpellByID(...) end)
end

-- General event handler
local function OnEvent(self, event, ...)
	if event == 'COMBAT_LOG_EVENT_UNFILTERED' then
		HealComm[event](HealComm, CombatLogGetCurrentEventInfo())
	else
		HealComm[event](HealComm, ...)
	end
end

-- Event handler
HealComm.eventFrame = HealComm.frame or HealComm.eventFrame or CreateFrame("Frame")
HealComm.eventFrame:UnregisterAllEvents()
HealComm.eventFrame:RegisterEvent("UNIT_PET")
HealComm.eventFrame:SetScript("OnEvent", OnEvent)
HealComm.frame = nil

-- At PLAYER_LEAVING_WORLD (Actually more like MIRROR_TIMER_STOP but anyway) UnitGUID("player") returns nil, delay registering
-- events and set a playerGUID/playerName combo for all players on PLAYER_LOGIN not just the healers.
function HealComm:PLAYER_LOGIN()
	playerGUID = UnitGUID("player")
	playerName = UnitName("player")
	playerLevel = UnitLevel("player")

	-- Oddly enough player GUID is not available on file load, so keep the map of player GUID to themselves too
	guidToUnit[playerGUID] = "player"

		self:OnInitialize()

	self.eventFrame:UnregisterEvent("PLAYER_LOGIN")
	self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

	self:ZONE_CHANGED_NEW_AREA()
	self:GROUP_ROSTER_UPDATE()
end

if( not IsLoggedIn() ) then
	HealComm.eventFrame:RegisterEvent("PLAYER_LOGIN")
else
	HealComm:PLAYER_LOGIN()
end
