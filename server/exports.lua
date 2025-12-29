local RSGCore = nil
local Inventory = {}
local VBridge = exports["v-inventory"]:VBridge()

-- Initialize RSGCore if available
if GetResourceState('rsg-core') == 'started' then
    RSGCore = exports['rsg-core']:GetCoreObject()
end

-- Wait for VBridge to be ready
CreateThread(function()
    while not VBridge do Wait(100) end
    
end)

Inventory.LoadInventory = function(source, citizenid)
    return VBridge.GetInventory(source, "player", citizenid)
end

Inventory.SaveInventory = function(source, offline)
    if offline then
        -- Not fully supported in v-inventory bridge structure for offline save by source, 
        -- but we can try saving if we have an identifier.
        return 
    end
    exports["v-inventory"]:ForceSave(source)
end

Inventory.SetInventory = function(source, items)
    -- This is a complex operation in v-inventory. 
    -- Best effort: Clear and Add.
    VBridge.ClearInventory(source)
    if items then
        for _, item in pairs(items) do
            VBridge.AddItem(source, item.name, item.amount, item.info or item.metadata, "player", nil, item.slot)
        end
    end
end

Inventory.SetItemData = function(source, itemName, key, val)
    local item = exports[GetCurrentResourceName()]:getItemMatchingMetadata(source, itemName, nil)
    if item then
        local meta = item.metadata or {}
        meta[key] = val
        VBridge.SetItemMetadata(source, item.slot, meta)
        return true
    end
    return false
end

Inventory.GetItemWeight = function(itemName)
    local def = VBridge.GetItemDefinitions()[itemName]
    return def and def.weight
end

Inventory.UseItem = function(itemName, ...)
    -- v-inventory handles usage internally or via events. 
    -- This export usually triggers the callback in rsg-inventory.
    -- We'll try to use the VBridge UseItem if possible.
    -- VBridge.UseItem requires an item object, not just name.
    -- This might need to be adapted based on usage. 
    -- For now, stub or try to find item.
end

Inventory.GetSlotsByItem = function(items, itemName)
    local slots = {}
    if not items then return slots end
    for k, v in pairs(items) do
        if v.name == itemName then table.insert(slots, v.slot) end
    end
    return slots
end

Inventory.GetFirstSlotByItem = function(items, itemName)
    if not items then return nil end
    for k, v in pairs(items) do
        if v.name == itemName then return v.slot end
    end
    return nil
end

Inventory.GetItemBySlot = function(source, slot)
    local items = VBridge.GetInventory(source)
    for _, v in ipairs(items) do
        if v.slot == tonumber(slot) then return v end
    end
    return nil
end

Inventory.GetTotalWeight = function(items)
    local w = 0
    for _, v in ipairs(items) do
        w = w + (v.weight * v.amount)
    end
    return w
end

Inventory.GetItemByName = function(source, item)
    local items = VBridge.GetInventory(source)
    for _, v in ipairs(items) do
        if v.name == item then return v end
    end
    return nil
end

Inventory.GetItemsByName = function(source, item)
    local items = VBridge.GetInventory(source)
    local found = {}
    for _, v in ipairs(items) do
        if v.name == item then table.insert(found, v) end
    end
    return found
end

Inventory.GetSlots = function(identifier)
    -- Logic for v-inventory slots
    return 0, 80 -- Stub max slots
end

Inventory.GetItemCount = function(source, items)
    if type(items) == "table" then
        local count = 0
        for _, i in ipairs(items) do
             count = count + VBridge.GetItemCount(source, i)
        end
        return count
    else
        return VBridge.GetItemCount(source, items)
    end
end

Inventory.CanAddItem = function(source, item, amount)
    return exports["v-inventory"]:canCarryItem(source, item, amount)
end

Inventory.GetFreeWeight = function(source)
    -- v-inventory specific calculation
    return 10000 -- Stub
end

Inventory.ClearInventory = function(source, filterItems)
    -- filterItems support not implemented in bridge
    VBridge.ClearInventory(source)
end

Inventory.HasItem = function(source, items, amount)
    if type(items) == "table" then
        for k, v in pairs(items) do
            local name = type(k) == "string" and k or v
            local amt = type(k) == "string" and v or amount or 1
            if VBridge.GetItemCount(source, name) < amt then return false end
        end
        return true
    else
        return VBridge.GetItemCount(source, items) >= (amount or 1)
    end
end

Inventory.CloseInventory = function(source, identifier)
    TriggerEvent('v-inventory:server:CloseInventory', {type="player", id=identifier})
end

Inventory.OpenInventoryById = function(source, targetId)
    local targetIdentifier = VBridge.GetIdentifier(targetId)
    if targetIdentifier then
        TriggerClientEvent('v-inventory:client:OpenInventory', source, { 
            type = "player", 
            id = targetIdentifier, 
            label = "Player " .. targetId,
            slots = 80
        })
    end
end

Inventory.ClearStash = function(identifier)
    -- VBridge implementation required for direct stash clear if simple ID
    -- Using internal query logic from user provided snippet? 
    -- Better to bridge it if possible.
end

Inventory.SaveStash = function(identifier)
end

Inventory.OpenInventory = function (source, identifier, data)
    -- Map to v-inventory open
    if type(identifier) == "string" then
         TriggerClientEvent('v-inventory:client:OpenInventory', source, { 
            type = "stash", 
            id = identifier, 
            label = identifier,
            slots = (data and data.slots) or 80,
            capacity = (data and data.maxweight) or 100000
        })
    end
end

Inventory.ForceDropItem = function(source, item, amount, info, reason)
    VBridge.CreateDrop(source, {name=item, label=item}, amount, info)
    return true
end

Inventory.AddItem = function(identifier, item, amount, slot, info, reason)
    -- Identifier here in RSG might be a player ID or stash ID.
    -- v-inventory AddItem takes (source/containerId, ...)
    local src = tonumber(identifier)
    if src then
        return VBridge.AddItem(src, item, amount, info, "player", nil, slot)
    else
        -- Assume stash
        return VBridge.AddItem(nil, item, amount, info, "stash", identifier, slot)
    end
end

Inventory.RemoveItem = function(identifier, item, amount, slot, reason, isMove)
    local src = tonumber(identifier)
    if src then
        return VBridge.RemoveItem(src, item, amount, "player", nil, slot)
    else
         return VBridge.RemoveItem(nil, item, amount, "stash", identifier, slot)
    end
end

Inventory.GetInventory = function(identifier)
     -- return generic table?
     local src = tonumber(identifier)
     if src then
        return VBridge.GetInventory(src)
     end
     return {}
end

Inventory.CreateInventory = function (identifier, data)
    -- v-inventory auto creates/configures stashes usually.
end

Inventory.DeleteInventory = function(identifier)
end



-- Shops Compatibility
local Shops = {}
local RegisteredShops = {}

Shops.SetupShopItems = function(items, shopData)
    local setupItems = {}
    if not items then return setupItems end
    for k, v in pairs(items) do
        local item = {
            name = v.name,
            amount = v.amount or 100,
            price = v.price or 0,
            slot = k,
            label = v.label or v.name,
            info = v.info or {},
            type = "item"
        }
        table.insert(setupItems, item)
    end
    return setupItems
end

Shops.CreateShop = function(shopData)
    if shopData.name then
        if RegisteredShops[shopData.name] then
            local old = RegisteredShops[shopData.name]
            old.items = Shops.SetupShopItems(shopData.items, shopData)
            old.slots = #shopData.items
            old.persistentStock = shopData.persistentStock ~= nil and shopData.persistentStock or old.persistentStock
        else
            RegisteredShops[shopData.name] = {
                name = shopData.name,
                label = shopData.label,
                coords = shopData.coords,
                slots = #shopData.items,
                items = Shops.SetupShopItems(shopData.items, shopData),
                persistentStock = shopData.persistentStock,
            }
        end
        
        -- Sync with v-inventory Config.Shops so server.lua BuyItem verification works
        if Config and Config.Shops then
            local found = false
            for i, s in ipairs(Config.Shops) do
                if s.name == shopData.name then
                    Config.Shops[i] = RegisteredShops[shopData.name]
                    found = true
                    break
                end
            end
            if not found then
                table.insert(Config.Shops, RegisteredShops[shopData.name])
            end
        end
    else
        for key, data in pairs(shopData) do
            if type(data) == 'table' then
                if data.name then
                     Shops.CreateShop(data) -- Recursive call for single shop structure
                else
                     -- Maybe simple list of shops?
                     data.name = key
                     Shops.CreateShop(data)
                end
            end
        end
    end
end

Shops.OpenShop = function(source, name)
    if not name then return end
    if not RegisteredShops[name] then return end
    
    local shop = RegisteredShops[name]
    
    -- v-inventory usage
    TriggerClientEvent('v-inventory:client:OpenInventory', source, { 
        type = "shop", 
        id = shop.name, 
        label = shop.label, 
        slots = shop.slots, 
        items = shop.items 
    })
end

Shops.RestockShop = function(shopName, percentage)    
    local shopData = RegisteredShops[shopName]
    if not shopData then return false end

    percentage = percentage or 100
    local mult = percentage / 100
    
    for slot, item in pairs(shopData.items) do 
        if item.amount and item.defaultstock then 
            local restock = math.floor(item.defaultstock * mult)
            item.amount = math.min(item.defaultstock, item.amount + restock)
        end
    end
end

Shops.DoesShopExist = function(shopName)
    if type(shopName) ~= "string" then return false end
    return RegisteredShops and RegisteredShops[shopName] ~= nil
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source

    -- Voeg inventaris functies toe aan de speler
    local methods = {
        AddItem = function(item, amount, slot, info, reason)
            return Inventory.AddItem(src, item, amount, slot, info, reason)
        end,
        RemoveItem = function(item, amount, slot, reason)
            return Inventory.RemoveItem(src, item, amount, slot, reason)
        end,
        GetItemBySlot = function(slot)
            return Inventory.GetItemBySlot(src, slot)
        end,
        GetItemByName = function(item)
            return Inventory.GetItemByName(src, item)
        end,
        GetItemsByName = function(item)
            return Inventory.GetItemsByName(src, item)
        end,
        ClearInventory = function(filterItems)
            Inventory.ClearInventory(src, filterItems)
        end,
        SetInventory = function(items)
            Inventory.SetInventory(src, items)
        end
    }

    for methodName, methodFunc in pairs(methods) do
        RSGCore.Functions.AddPlayerMethod(src, methodName, methodFunc)
    end
end)


-- Exports Registration
local Exports = {
    LoadInventory = Inventory.LoadInventory,
    SaveInventory = Inventory.SaveInventory,
    SetInventory = Inventory.SetInventory,
    SetItemData = Inventory.SetItemData,
    GetItemWeight = Inventory.GetItemWeight,
    UseItem = Inventory.UseItem,
    GetSlotsByItem = Inventory.GetSlotsByItem,
    GetFirstSlotByItem = Inventory.GetFirstSlotByItem,
    GetItemBySlot = Inventory.GetItemBySlot,
    GetTotalWeight = Inventory.GetTotalWeight,
    GetItemByName = Inventory.GetItemByName,
    GetItemsByName = Inventory.GetItemsByName,
    GetSlots = Inventory.GetSlots,
    GetItemCount = Inventory.GetItemCount,
    CanAddItem = Inventory.CanAddItem,
    GetFreeWeight = Inventory.GetFreeWeight,
    ClearInventory = Inventory.ClearInventory,
    HasItem = Inventory.HasItem,
    CloseInventory = Inventory.CloseInventory,
    OpenInventoryById = Inventory.OpenInventoryById,
    ClearStash = Inventory.ClearStash,
    SaveStash = Inventory.SaveStash,
    OpenInventory = Inventory.OpenInventory,
    ForceDropItem = Inventory.ForceDropItem,
    AddItem = Inventory.AddItem,
    RemoveItem = Inventory.RemoveItem,
    GetInventory = Inventory.GetInventory,
    CreateInventory = Inventory.CreateInventory,
    DeleteInventory = Inventory.DeleteInventory,
    -- Shop Exports
    CreateShop = Shops.CreateShop,
    OpenShop = Shops.OpenShop,
    RestockShop = Shops.RestockShop,
    DoesShopExist = Shops.DoesShopExist
}

for k, v in pairs(Exports) do
    exports(k, v)
end
