local yaml = require('yaml')
local t = require('luatest')
local cbuilder = require('luatest.cbuilder')
local treegen = require('luatest.treegen')
local justrun = require('luatest.justrun')
local cluster = require('test.config-luatest.cluster')
local it = require('test.interactive_tarantool')

local g = t.group()

g.before_all(cluster.init)
g.after_each(cluster.drop)
g.after_all(cluster.clean)

g.after_each(function(g)
    if g.it ~= nil then
        g.it:close()
    end
end)

-- Verify that an instance can't start in the isolated mode if
-- there is no local snapshot.
g.test_startup_no_snap = function()
    local config = cbuilder:new()
        :set_replicaset_option('replication.failover', 'manual')
        :set_replicaset_option('leader', 'i-001')
        :add_instance('i-001', {})
        :add_instance('i-002', {})
        :add_instance('i-003', {isolated = true})
        :config()

    -- Write config to a temporary directory.
    local dir = treegen.prepare_directory({}, {})
    local config_file = treegen.write_file(dir, 'config.yaml',
        yaml.encode(config))

    -- Run tarantool instance that is expected to exit
    -- immediately.
    local env = {}
    local args = {'--name', 'i-003', '--config', config_file}
    local opts = {nojson = true, stderr = true}
    local res = justrun.tarantool(dir, env, args, opts)

    -- Verify the exit code and the error reported to stderr.
    local exp_err = 'Startup failure.\n' ..
        'The isolated mode is enabled and the instance "i-003" has no local ' ..
        'snapshot. An attempt to bootstrap the instance would lead to the ' ..
        'split-brain situation.'
    t.assert_covers(res, {
        exit_code = 1,
        stderr = ('LuajitError: %s\nfatal error, exiting the event loop')
            :format(exp_err),
    })
end

-- The opposite to the previous test case: verify that an instance
-- can start in the isolated mode if there is a local snapshot.
g.test_startup_with_snap = function(g)
    local config = cbuilder:new()
        :set_replicaset_option('replication.failover', 'manual')
        :set_replicaset_option('leader', 'i-001')
        :add_instance('i-001', {})
        :add_instance('i-002', {})
        :add_instance('i-003', {})
        :config()

    local cluster = cluster.new(g, config)
    cluster:start()

    -- Stop i-003. It leaves a local snapshot.
    cluster['i-003']:stop()

    -- Mark i-003 as isolated in the configuration, write it to
    -- the file.
    local config_2 = cbuilder:new(config)
        :set_instance_option('i-003', 'isolated', true)
        :config()
    cluster:sync(config_2)

    -- Start the instance again from the local snapshot in the
    -- isolated mode.
    cluster['i-003']:start()

    -- Use the console connection, because an instance in the
    -- isolated mode doesn't accept iproto requests.
    g.it = it.connect(cluster['i-003'])

    -- Verify that the instance is started in the isolated mode.
    g.it:roundtrip("require('config'):get('isolated')", true)

    -- Verify that the instance loaded the database.
    g.it:roundtrip("box.space._schema:get({'replicaset_name'})[2]",
        'replicaset-001')
end