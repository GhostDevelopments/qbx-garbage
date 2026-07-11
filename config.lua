Config = {}

Config.JobName = nil -- Set to nil if you want it to be a public job
Config.Model = "trash"
Config.Payout = { min = 500, max = 1200 }

Config.Locations = {
    Start = vector4(-322.25, -1545.89, 31.02, 268.45), -- Where to talk to the boss
    VehicleSpawn = vector4(-318.57, -1524.08, 27.65, 272.58),
    Return = vector3(-328.84, -1523.35, 27.53)
}

Config.TrashZones = {
    vector3(-302.21, -1551.98, 30.73),
    vector3(-270.81, -1516.35, 30.59),
    vector3(-226.79, -1487.65, 30.59),
    vector3(-181.76, -1447.16, 30.59),
    vector3(-146.42, -1428.14, 30.59),
    vector3(-87.89, -1451.27, 30.48),
    vector3(-104.97, -1502.5, 30.59),
    vector3(-125.13, -1546.51, 33.72),
}

Config.BagsPerStop = 3
