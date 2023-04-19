#!/usr/bin/env -S tarantool --script

for i=-1,#arg do
    print(string.format("arg[%d] => %s", i, arg[i]))
end
