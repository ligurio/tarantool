#!/usr/bin/env tarantool

-- get instance name from filename (qsync1.lua => qsync1)
local INSTANCE_ID = string.match(arg[0], "%d")

local SOCKET_DIR = require('fio').cwd()

local function instance_uri(instance_id)
    return SOCKET_DIR..'/qsync'..instance_id..'.sock'
end

-- start console first to create busy loop
-- otherwise instance will finish
require('console').listen(os.getenv('ADMIN'))

box.cfg({
    listen = instance_uri(INSTANCE_ID),
    replication = {
        instance_uri(1),
        instance_uri(2),
        instance_uri(3),
        instance_uri(4),
        instance_uri(5),
    },
    replication_synchro_timeout = 1000,
    replication_synchro_quorum = 5,
    read_only = false,
})

box.once("bootstrap", function()
    box.schema.user.grant("guest", 'replication')
end)
