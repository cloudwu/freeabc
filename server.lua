local pime = require "pime"
local server = require "pime.server"
local freeabc = require "pime.freeabc"

--server.debug()

freeabc:_setpath "d:\\project\\freeabc"
pime.check(freeabc)
server.run(function (req)
	return pime.dispatch(req, freeabc)
end)
