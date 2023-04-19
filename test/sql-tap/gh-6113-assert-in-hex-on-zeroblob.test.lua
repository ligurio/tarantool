#!/usr/bin/env -S tarantool --script
local test = require("sqltester")
test:plan(1)

test:do_execsql_test(
    "gh-6113",
    [[
        SELECT hex(zeroblob(0)), hex(zeroblob(10));
    ]], {
        '', '00000000000000000000'
    })

test:finish_test()
