local DMW = DMW
local LocalPlayer = DMW.Classes.LocalPlayer
local Spell = DMW.Classes.Spell
local Buff = DMW.Classes.Buff
local Debuff = DMW.Classes.Debuff

function LocalPlayer:GetSpells()
    if self.Class == "SHAMAN"  then
        self.Totems = {}
        DMW.Tables.Totems = {}
        DMW.Tables.Totems.Elements = {"Fire", "Earth", "Water", "Air"}
    end
    self.Spells = {}
    self.Buffs = {}
    self.Debuffs = {}
    local CastType, Duration
    for k, v in pairs(DMW.Enums.Spells) do
        if k == "GLOBAL" or k == self.Class then
            for SpellType, SpellTable in pairs(v) do
                if SpellType == "Abilities" then
                    for SpellName, SpellInfo in pairs(SpellTable) do
                        CastType = SpellInfo.CastType or "Normal"
                        self.Spells[SpellName] = Spell(SpellInfo.Ranks, CastType)
                        self.Spells[SpellName].Key = SpellName
                        if SpellInfo.Totem ~= nil then
                            for i = 1, #SpellInfo.Ranks do
                                DMW.Tables.Totems[SpellInfo.Ranks[i]] = {}
                                local totem = DMW.Tables.Totems[SpellInfo.Ranks[i]]
                                totem["SpellName"] = self.Spells[SpellName]["SpellName"]
                                totem["TotemSlot"] = SpellInfo.Totem[1]
                                totem["Element"] = DMW.Tables.Totems.Elements[totem["TotemSlot"]]
                                totem["Duration"] = SpellInfo.Totem[2]
                                totem["Key"] = SpellName
                            end
                        end
                    end
                elseif SpellType == "Buffs" then
                    for SpellName, SpellInfo in pairs(SpellTable) do
                        self.Buffs[SpellName] = Buff(SpellInfo.Ranks)
                    end
                elseif SpellType == "Debuffs" then
                    for SpellName, SpellInfo in pairs(SpellTable) do
                        Duration = SpellInfo.Duration or nil
                        self.Debuffs[SpellName] = Debuff(SpellInfo.Ranks, Duration)
                    end
                end
            end
        end
    end
end

function LocalPlayer:GetTalents()
    if self.Talents then
        table.wipe(self.Talents)
    else
        self.Talents = {}
    end
    local name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq
    for k, v in pairs(DMW.Enums.Spells[self.Class].Talents) do
        name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(v[1], v[2])
        if name then
            self.Talents[k] = {Rank = currentRank, MaxRank = maxRank, Active = false}
            if currentRank > 0 then
                self.Talents[k].Active = true
            end
        end
    end
end

function LocalPlayer:UpdateEquipment()
    table.wipe(self.Equipment)
    self.Items.Trinket1 = nil
    self.Items.Trinket2 = nil
    local ItemID
    for i = 1, 19 do
        ItemID = GetInventoryItemID("player", i)
        if ItemID then
            self.Equipment[i] = ItemID
            if i == 13 then
                self.Items.Trinket1 = DMW.Classes.Item(ItemID)
            elseif i == 14 then
                self.Items.Trinket2 = DMW.Classes.Item(ItemID)
            end
        end
    end
end

function LocalPlayer:GetItems()
    local Item = DMW.Classes.Item
    for Name, ItemID in pairs(DMW.Enums.Items) do
        self.Items[Name] = Item(ItemID)
    end
end

function LocalPlayer:GetBagItems()
    table.wipe(self.BagItems)
    local i = 0
    local NumSlot, ItemID
    local Item = DMW.Classes.BagItem
    for BagID = 0, 4, 1 do
        NumSlot = GetContainerNumSlots(BagID)
        for Slot = 1, NumSlot, 1 do
            ItemID = GetContainerItemID(BagID, Slot)
            if ItemID then
                i = i + 1
                self.BagItems[i] = Item(BagID,Slot)
            end
        end
    end
end

function LocalPlayer:UpdateProfessions()
    table.wipe(self.Professions)
    self.Professions.Fishing = -1
    self.Professions.Mining = -1
    self.Professions.Herbalism = -1
    self.Professions.Skinning = -1
    self.Professions.PickLock = -1
    for i = 1, GetNumSkillLines() do
        local Name, _, _, Rank = GetSkillLineInfo(i)
        if Name == "钓鱼" then
            self.Professions.Fishing = Rank
        elseif Name == "采矿" then
            self.Professions.Mining = Rank
        elseif Name == "草药学" then
            self.Professions.Herbalism = Rank
        elseif Name == "剥皮" then
            self.Professions.Skinning = Rank
        elseif Name == "开锁" then
            self.Professions.PickLock = Rank
        end
    end
end
