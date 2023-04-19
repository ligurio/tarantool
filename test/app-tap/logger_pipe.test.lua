#!/usr/bin/env -S tarantool --script

os.setenv('TEST_VAR', '48')
box.cfg { log = '|echo $TEST_VAR; cat > /dev/null' }
os.exit(0)
