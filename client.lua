local currentVehicle = nil
local currentBlip = nil
local jobStarted = false
local hasBag = false
local bagObj = nil
local stopCount = 0
local totalStops = #Config.TrashZones

-- Initialize Boss NPC and Target
CreateThread(function()
    local model = `s_m_y_garbage_01`
    lib.requestModel(model)
    local boss = CreatePed(4, model, Config.Locations.Start.x, Config.Locations.Start.y, Config.Locations.Start.z - 1.0, Config.Locations.Start.w, false, true)
    SetEntityInteraction(boss, false)
    FreezeEntityPosition(boss, true)
    SetBlockingOfNonTemporaryEvents(boss, true)

    exports.ox_target:addLocalEntity(boss, {
        {
            name = "garbage_start",
            label = "Start Garbage Route",
            icon = "fas fa-trash",
            onSelect = function()
                StartGarbageJob()
            end,
            canInteract = function() return not jobStarted end
        },
        {
            name = "garbage_finish",
            label = "Finish Work",
            icon = "fas fa-hand-holding-dollar",
            onSelect = function()
                FinishGarbageJob()
            end,
            canInteract = function() return jobStarted end
        }
    })
end)

function StartGarbageJob()
    local success = lib.callback.await("garbage:server:startJob", false)
    if not success then return end

    lib.requestModel(Config.Model)
    currentVehicle = CreateVehicle(Config.Model, Config.Locations.VehicleSpawn.x, Config.Locations.VehicleSpawn.y, Config.Locations.VehicleSpawn.z, Config.Locations.VehicleSpawn.w, true, false)
    local plate = GetVehicleNumberPlateText(currentVehicle)
    
    -- Vehicle Keys (Export depends on your script, usually qbx_vehiclekeys or similar)
    if exports.qbx_vehiclekeys then
        exports.qbx_vehiclekeys:GiveKeys(plate)
    else
        -- Fallback for generic key scripts
        TriggerEvent("vehiclekeys:client:SetOwner", plate)
    end

    jobStarted = true
    stopCount = 1
    SetNextStop()
    lib.notify({title = "Garbage Job", description = "Collect trash bags at the marked locations", type = "inform"})
end

function SetNextStop()
    if currentBlip then RemoveBlip(currentBlip) end
    
    if stopCount > totalStops then
        lib.notify({title = "Route Complete", description = "Return the truck to the depot", type = "success"})
        currentBlip = AddBlipForCoord(Config.Locations.Return.x, Config.Locations.Return.y, Config.Locations.Return.z)
        SetBlipSprite(currentBlip, 351)
        SetBlipColor(currentBlip, 2)
        SetBlipRoute(currentBlip, true)
        return
    end

    local coords = Config.TrashZones[stopCount]
    currentBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(currentBlip, 1)
    SetBlipColor(currentBlip, 5)
    SetBlipRoute(currentBlip, true)
    
    SpawnTrashBags(coords)
end

function SpawnTrashBags(coords)
    local bagModel = `prop_cs_rub_binbag_01`
    lib.requestModel(bagModel)
    
    for i = 1, Config.BagsPerStop do
        local offset = vector3(math.random(-2, 2), math.random(-2, 2), 0)
        local bag = CreateObject(bagModel, coords.x + offset.x, coords.y + offset.y, coords.z - 1.0, true, true, false)
        PlaceObjectOnGroundProperly(bag)
        
        exports.ox_target:addLocalEntity(bag, {
            {
                label = "Pick up bag",
                icon = "fas fa-hand-rock",
                onSelect = function(data)
                    PickUpBag(data.entity)
                end,
                canInteract = function() return not hasBag end
            }
        })
    end
end

function PickUpBag(entity)
    hasBag = true
    bagObj = entity
    
    lib.playAnim(cache.ped, "anim@heists@narcotics@trash", "walk", 1.0, 1.0, -1, 49, 0, false, false, false)
    AttachEntityToEntity(bagObj, cache.ped, GetPedBoneIndex(cache.ped, 57005), 0.12, 0.0, -0.05, 220.0, 120.0, 0.0, true, true, false, true, 1, true)
    
    -- Add target to truck back
    exports.ox_target:addLocalEntity(currentVehicle, {
        {
            label = "Throw bag in truck",
            icon = "fas fa-truck-loading",
            onSelect = function()
                ThrowBagInTruck()
            end,
            canInteract = function() return hasBag end
        }
    })
end

function ThrowBagInTruck()
    if not hasBag or not bagObj then return end
    
    lib.playAnim(cache.ped, "anim@heists@narcotics@trash", "throw_b", 1.0, 1.0, -1, 0, 0, false, false, false)
    Wait(800)
    DetachEntity(bagObj, false, false)
    DeleteEntity(bagObj)
    
    hasBag = false
    bagObj = nil
    StopAnimTask(cache.ped, "anim@heists@narcotics@trash", "walk", 1.0)

    -- Check if stop is done
    local remaining = #GetGamePool("CObject") -- Simplistic check for bags nearby
    local bagsNearby = false
    local pool = GetGamePool("CObject")
    for _, obj in ipairs(pool) do
        if GetEntityModel(obj) == `prop_cs_rub_binbag_01` then
            local dist = #(GetEntityCoords(obj) - Config.TrashZones[stopCount])
            if dist < 10.0 then bagsNearby = true break end
        end
    end

    if not bagsNearby then
        stopCount = stopCount + 1
        SetNextStop()
    end
end

function FinishGarbageJob()
    local coords = GetEntityCoords(currentVehicle)
    local dist = #(coords - Config.Locations.Return)
    
    if dist > 15.0 then
        return lib.notify({title = "Error", description = "The truck must be at the depot!", type = "error"})
    end

    local amount = lib.callback.await("garbage:server:finishJob", false)
    if amount then
        if DoesEntityExist(currentVehicle) then DeleteEntity(currentVehicle) end
        if currentBlip then RemoveBlip(currentBlip) end
        jobStarted = false
        lib.notify({title = "Job Finished", description = "You received $" .. amount, type = "success"})
    end
end