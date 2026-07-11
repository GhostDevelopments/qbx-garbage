fx_version "cerulean"
game "gta5"

author "SwisserAI"
description "Garbage Job - Generated with SwisserAI - https://ai.swisser.dev"
version "1.0.0"

shared_scripts {
    "@ox_lib/init.lua",
    "config.lua"
}

client_scripts {
    "client.lua"
}

server_scripts {
    "server.lua"
}

dependencies {
    "qbx_core",
    "ox_lib",
    "ox_target",
    "ox_inventory"
}