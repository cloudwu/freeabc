local pipe = require "pipe"
local json = require "cjson"

local server = {}

local fd
local debug

function server.connect()
	fd = pipe.connect "pime"
	print("client connected", fd)
end

function server.debug()
	debug = true
end

local function one_request(dispatcher)
	local data = pipe.read(fd)
	if debug then print("<===", data) end
	local req = json.decode(data)
	local resp = dispatcher(req)
	local reply = json.encode(resp)
	if debug then print("===>", reply) end
	pipe.write(fd, reply)
end

function server.run(dispatcher)
	print "Start"
	while true do
		if not fd then
			server.connect()
		end
		local ok, err = pcall(one_request,dispatcher)
		if not ok then
			print("ERR:", err)
			pipe.close(fd)
			fd = nil
		end
	end
end

return server