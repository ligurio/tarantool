#!/usr/bin/env tarantool

local ffi = require('ffi')
local msgpack = require('msgpack')
local net_box = require('net.box')
local tap = require('tap')
local yaml = require('yaml')
local urilib = require('uri')
local test = tap.test('cfg')

box.cfg({
    listen = os.getenv('LISTEN') or 'localhost:3301',
})

box.schema.user.grant('guest', 'read,write,execute', 'universe')
local space = box.schema.space.create('test', {if_not_exists=true})
space:create_index('pk', {if_not_exists=true, type='TREE', parts = {{field = 1, type = 'unsigned'}}})

local IPROTO_STATUS_KEY         = 0x00
local IPROTO_OK                 = 0x00
local IPROTO_REQUEST_TYPE       = 0x00
local IPROTO_SYNC               = 0x01
local IPROTO_INSERT             = 0x02
local IPROTO_SPACE_ID		= 0x10
local IPROTO_TUPLE		= 0x21

local uri = urilib.parse(box.cfg.listen)
local sock = net_box.establish_connection(uri.host, uri.service)

local next_request_id = 16
local header = msgpack.encode({
    [IPROTO_REQUEST_TYPE] = IPROTO_INSERT,
    [IPROTO_SYNC] = next_request_id,
})

function encode_body_wo_tuple(hex_tuple, space_id)
    local body = '\x82' .. msgpack.encode(IPROTO_SPACE_ID)
    body = body .. msgpack.encode(space_id)
    body = body .. msgpack.encode(IPROTO_TUPLE)
    body = body .. (hex_tuple):fromhex()
    return body
end

function insert_tuple_with_iproto(hex_tuple, space_id)
    local body = encode_body_wo_tuple(hex_tuple, space_id)
    local size = msgpack.encode(header:len() + body:len())

    -- send request.
    local size = msgpack.encode(header:len() + body:len())
    assert(sock:write(size .. header .. body) ~= nil, 'Failed to send request')

    -- receive response.
    size = sock:read(5)
    assert(size ~= nil, 'Failed to receive response')
    size = msgpack.decode(size)
    local response = sock:read(size)
    local header, header_len = msgpack.decode(response)
    body = msgpack.decode(response:sub(header_len))
    space:truncate()

    -- print error if something goes wrong.
    if header[IPROTO_STATUS_KEY] ~= IPROTO_OK then
        for k,v in pairs(body) do
            print(k, v)
        end
    end

    return header[IPROTO_STATUS_KEY]
end

local id = box.space.test.id

local samples = {
    {
        tuple = '9201d47f00',
        comment = 'Tuple with MP_EXT, fixext 1, type 127',
    },
    {
        tuple = '9201d57f0000',
        comment = 'Tuple with MP_EXT, fixext 2, type 127',
    },
    {
        tuple = '9201d67f01010101',
        comment = 'Tuple with MP_EXT, fixext 4, type 127',
    },
    {
        tuple = '9201d77f0101010101010101',
        comment = 'Tuple with MP_EXT, fixext 8, type 127',
    },
    {
        tuple = '9201d87f01010101010101010101010101010101',
        comment = 'Tuple with MP_EXT, fixext 16, type 127',
    },
    {
        tuple = '9201c7017f01',
        comment = 'Tuple with MP_EXT, ext 8, type 127',
    },
    {
        tuple = '9201c800017f01',
        comment = 'Tuple with MP_EXT, ext 16, type 127',
    },
    {
        tuple = '9201c9000000017f01',
        comment = 'Tuple with MP_EXT, ext 32, type 127',
    },
    {
        tuple = '9201d501001c',
        comment = 'Tuple with MP_EXT, decimal',
    },
    {
        tuple = '9201d6010201234d',
        comment = 'Tuple with MP_EXT, decimal',
    },
    {
        tuple = '9201d802f6423bdfb49e4913b3610740c9702e4b',
        comment = 'Tuple with MP_EXT, uuid',
    },
 }

test:plan(#samples)

for _, sample in pairs(samples) do
    test:is(insert_tuple_with_iproto(sample.tuple, id), IPROTO_OK, sample.comment)
end

sock:close()
space:drop()
box.schema.user.revoke('guest', 'read,write,execute', 'universe')
os.exit(test:check() == true and 0 or 1)
