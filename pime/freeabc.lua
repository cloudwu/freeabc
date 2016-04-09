local pime = require "pime"

local freeabc = {
	english = true,
	composition = nil,
	path = nil,
}

local FREEABC_GUID = "{7C42702A-3DDD-4AFF-B936-F7BF00BF2E1D}"
--local CTRL_SPACE_GUID = "{574053A5-6F3D-451B-A048-802AF4E101BC}"

function freeabc:init(req)
	print "init"
end

function freeabc:onLangProfileActivated(req)
	assert(req.guid == FREEABC_GUID)
end

function freeabc:_setpath(path)
	self.path = path
end

function freeabc:onActivate(req, resp)
	print("add", resp.add_button)
	self.english = not req.isKeyboardOpen
	if self.english then
		resp:add_button(self.path.."\\en.ico")
	else
		resp:add_button(self.path.."\\zh.ico")
	end
	if self.composition then
		resp:composition(self.composition)
	end

	resp:commit "Hello"
end

function freeabc:onDeactivate(req, resp)
	resp:remove_button()
end

function freeabc:onMenu()
	print("on menu")
--[[
	return {
		{
			text = "啦啦啦啦",
			id = 1,
			checked = true,s
		}
	}
	]]
end

function freeabc:onKeyboardStatusChanged(req, resp)
	if self.english ~= not req.opened then
		self.english = not req.opened
		if self.english then
			print("change en")
			resp:change_button "d:\\project\\freeabc\\en.ico"
		else
			print("change zh")
			resp:change_button "d:\\project\\freeabc\\zh.ico"
		end
	end
	return true
end

function freeabc:onCommand(req, resp)
	if req.id == 0 then
		print("On command 0")
		resp:keyboard(self.english)
	else
		print("click menu", req.id)
	end
	return true
end

local function is_key_down(req, code)
	-- lua is base 1, so use [code + 1]
	return (req.keyStates[code+1] & (1 << 7)) ~= 0
end

local support = "abcdefghijklmnopqrstuvwxyz0123456789"
do
	local tmp = {}
	for i=1,#support do
		tmp[support:byte(i)] = true
	end
	support = tmp
end
function freeabc:filterKeyDown(req, resp)
	local c = req.charCode
	if support[c] and not is_key_down(req, pime.VK_MENU)
		and not is_key_down(req, pime.VK_CONTROL) then
		return true
	end
	if self.composition ==  nil then
		return false
	end
	if c == 8 or c == 27 or c == 32 then
		return true
	end
	resp:commit(self.composition)
	self.composition = nil
	if c == 13 then
		resp:keyboard(false)
	end
	return false
end

function freeabc:onKeyDown(req, resp)
	local c = req.charCode
	if c <= 32 then
		if c == 13 then	-- CR
--			resp:keyboard(false)
--			self.composition = nil
		elseif c == 27 then	-- ESC
			resp:composition ""
			self.composition = nil
		elseif c == 8 then -- BACKSPACE
			self.composition = self.composition:sub(1,-2)
			resp:composition(self.composition)
			if self.composition == "" then
				self.composition = nil
			end
		elseif c == 32 then -- SPACE
		-- end composition
			resp:commit(self.composition)
			self.composition = nil
		end
		return true
	end
	self.composition = (self.composition or "") .. string.char(req.charCode):rep(req.repeatCount+1)
	resp:composition(self.composition)
	return true
end


return freeabc