local activeJobs = {}

lib.callback.register("garbage:server:startJob", function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    -- Check for job requirement if Config.JobName is set
    if Config.JobName and player.PlayerData.job.name ~= Config.JobName then
        return false
    end
    
    if activeJobs[source] then return false end
    
    activeJobs[source] = {
        hasVehicle = true,
        stopsCompleted = 0
    }
    return true
end)

lib.callback.register("garbage:server:finishJob", function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    
    if not activeJobs[source] then return false end
    
    local amount = math.random(Config.Payout.min, Config.Payout.max)
    exports.qbx_core:AddMoney(source, "cash", amount, "garbage-payout")
    
    activeJobs[source] = nil
    return amount
end)

RegisterNetEvent("garbage:server:syncBag", function(netId)
    local bag = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(bag) then
        SetEntityDistanceCullingRadius(bag, 30000.0)
    end
end)
