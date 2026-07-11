local currentVehicle = nil
local currentBlip = nil
local jobStarted = false
local hasBag = false
local bagObj = nil
local stopCount = 0
local totalStops = #Config.TrashZones

-- Helper for safe model loading without throwing script errors
local function SafeRequestModel(model)
    local hash = type(model) == "number" and model or joaat(model)
    
    if not IsModelInCdimage(hash) then return false end
    
    RequestModel(hash)
    local timer = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() > timer then
            print("^1[Garbage Job] Timeout loading model: " .. tostring(model) .. "^7")
            return false
        end
    end
    
    return true
end

-- Initialize Boss NPC and Target
CreateThread(function()
    local bossModels = {"s_m_y_garbage_01", "s_m_y_construct_01", "a_m_m_prolhost_01"}
    local selectedModel = nil
    
    for _, m in ipairs(bossModels) do
        if SafeRequestModel(m) then
            selectedModel = m
            break
        end
    end
    
    if not selectedModel then
        print("^1[Garbage Job] Could not load any boss models!^7")
        return
    end
    
    local modelHash = joaat(selectedModel)
    local boss = CreatePed(4, modelHash, Config.Locations.Start.x, Config.Locations.Start.y, Config.Locations.Start.z, Config.Locations.Start.w, false, false)
    SetEntityInvincible(boss, true)
    FreezeEntityPosition(boss, true)
    SetBlockingOfNonTemporaryEvents(boss, true)
    SetModelAsNoLongerNeeded(modelHash)

    -- Add Blip for Start
    local blip = AddBlipForCoord(Config.Locations.Start.x, Config.Locations.Start.y, Config.Locations.Start.z)
    SetBlipSprite(blip, 493)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 5)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Garbage Depot")
    EndTextCommandSetBlipName(blip)

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
    -- Check for job requirement if Config.JobName is set
    if Config.JobName then
        local QBX = exports.qbx_core:GetPlayerData()
        if QBX.job.name ~= Config.JobName then
            return lib.notify({title = "Error", description = "You do not have the required job!", type = "error"})
        end
    end

    local modelName = Config.Model or "trash"
    
    if not SafeRequestModel(modelName) then
        modelName = "trash" -- Final fallback to standard GTA trash truck
        if not SafeRequestModel(modelName) then
            return lib.notify({title = "Error", description = "Could not load garbage truck model!", type = "error"})
        end
    end

    local serverSuccess = lib.callback.await("garbage:server:startJob", false)
    if not serverSuccess then return end

    local modelHash = joaat(modelName)
    currentVehicle = CreateVehicle(modelHash, Config.Locations.VehicleSpawn.x, Config.Locations.VehicleSpawn.y, Config.Locations.VehicleSpawn.z, Config.Locations.VehicleSpawn.w, true, false)
    local plate = GetVehicleNumberPlateText(currentVehicle)
    
    -- Vehicle Keys
    TriggerEvent("vehiclekeys:client:SetOwner", plate)

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
        SetBlipColour(currentBlip, 2)
        SetBlipRoute(currentBlip, true)
        return
    end

    local coords = Config.TrashZones[stopCount]
    currentBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(currentBlip, 1)
    SetBlipColour(currentBlip, 5)
    SetBlipRoute(currentBlip, true)
    
    SpawnTrashBags(coords)
end

function SpawnTrashBags(coords)
    local bagModel = "prop_cs_rub_binbag_01"
    if not SafeRequestModel(bagModel) then return end
    
    local bagHash = joaat(bagModel)
    for i = 1, Config.BagsPerStop do
        local offset = vector3(math.random(-2, 2), math.random(-2, 2), 0)
        local bag = CreateObject(bagHash, coords.x + offset.x, coords.y + offset.y, coords.z - 1.0, true, true, false)
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
