env = require('test_run')
test_run = env.new()
engine = test_run:get_cfg('engine')
fiber = require('fiber')

orig_synchro_quorum = box.cfg.replication_synchro_quorum
orig_synchro_timeout = box.cfg.replication_synchro_timeout

box.schema.user.grant('guest', 'replication')

-- Setup an cluster with two instances.
test_run:cmd('create server replica with rpl_master=default,\
                                         script="replication/replica.lua"')
test_run:cmd('start server replica with wait=True, wait_load=True')

-- Write data to a leader and enable/disable sync mode in a loop.
-- Testcase setup.
_ = box.schema.space.create('sync', {is_sync=true, engine=engine})
_ = box.space.sync:create_index('pk')

-- Testcase body.
for i = 1,100 do                                                               \
    box.cfg{replication_synchro_quorum=3, replication_synchro_timeout=1000}    \
    fiber.create(function() box.space.sync:insert{i} end)                      \
    mode = not box.space.sync.is_sync                                          \
    fiber.create(function() box.space.sync:alter{is_sync=mode} end)            \
    box.cfg{replication_synchro_quorum=2, replication_synchro_timeout=0.1}     \
end
box.space.sync:count() -- 100

-- Testcase cleanup.
test_run:switch('default')
box.space.sync:drop()

-- Teardown.
test_run:cmd('switch default')
test_run:cmd('stop server replica')
test_run:cmd('delete server replica')
test_run:cleanup_cluster()
box.schema.user.revoke('guest', 'replication')
box.cfg{                                                                       \
    replication_synchro_quorum = orig_synchro_quorum,                          \
    replication_synchro_timeout = orig_synchro_timeout,                        \
}
