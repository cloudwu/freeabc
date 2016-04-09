local pime = {}

--[[
	commitString : string	-- 提交字符串
	compositionString : string	-- 正在输入的字符串
	compositionCursor : integer -- 输入字符串光标位置
	candidateList : { strings }	-- 备选列表
	showCandidates : boolean	-- 显示备选列表窗
	candidateCursor : integer	-- 备选列表窗光标

	addButton : {
		id : string		-- "windows-mode-icon" 为托盘按钮
		style : integer	-- C API style, 一般不用
		icon: string	-- full path to a *.ico file
		commandId: integer	-- an integer ID which will be passed to onCommand() when the button is clicked.
		text: string	-- text on the button (optional)
		tooltip: string		-- (optional)
		type: "button", "menu", "toggle" -- (optional, button is the default)
		enable: boolean		-- if the button is enabled (optional)
		toggled: boolean	-- is the button toggled, only valid if type is "toggle" (optional)
	}

	removeButton : { names }	-- id 列表
	changeButton : { buttons }	-- button 列表

	addPreservedKey : {
		guid : {
			keyCode : integer ,	-- VK_*
			modifiers : integer ,
				TF_MOD_ALT                       = 0x0001
				TF_MOD_CONTROL                   = 0x0002
				TF_MOD_SHIFT                     = 0x0004
				TF_MOD_RALT                      = 0x0008
				TF_MOD_RCONTROL                  = 0x0010
				TF_MOD_RSHIFT                    = 0x0020
				TF_MOD_LALT                      = 0x0040
				TF_MOD_LCONTROL                  = 0x0080
				TF_MOD_LSHIFT                    = 0x0100
				TF_MOD_ON_KEYUP                  = 0x0200
				TF_MOD_IGNORE_ALL_MODIFIER       = 0x0400
		}
	}

	setSelKeys : string "1234567890"	-- 显示在备选表上的字符
	customizeUI : {
		candFontName : string,
		candFontSize : integer,
		candPerRow : integer,
		candUseCursor : boolean,
	}
	showMessage : {
		message : string,
		duration : integer,	-- 秒
	}

	init : {
		id : string
		isConsole : boolean
		isMetroApp : boolean
		isUiLess : boolean
		isWindows8Above : boolean
	}

	onActivate
	onDeactivate

	onLangProfileActivated : {
		guid : string	-- should be {7C42702A-3DDD-4AFF-B936-F7BF00BF2E1D} freeabc
					-- multi mod support
	}
	onLangProfileDeactivated : { guid }

	type keymap {
		charCode : integer
		keyCode : integer
		repeatCount : integer
		scanCode : integer
		isExtended : boolean
		keyStates : integer[256]
	}

	filterKeyDown : keymap
		return : true means filter
	filterKeyUp : keymap
		return : true means filter
	onKeyDown : keymap
		return : true means processed
	onKeyUp : keymap
		return : true means processed
	onPreservedKey : guid
		return : true means processed
	onCommand : {
		id : integer (commandId when addButton)
		type : integer (left click or right click)
				COMMAND_LEFT_CLICK = 0,
				COMMAND_RIGHT_CLICK = 1,
				COMMAND_MENU =2,
		}
		return : true means processd
	onMenu : { id : integer }
		return : {
			id : integer
			text : string
			checked : boolean
			submenu : { ... }
		}
	onCompartmentChanged : { guid }
	onKeyboardStatusChanged : { opened : boolean }
	onCompositionTerminated : { forced : boolean }	-- called just before current composition is terminated for doing cleanup.

]]

local response = {} ; response.__index = response

function pime.dispatch(req, dispatcher)
	local resp = setmetatable({ success = nil, seqNum = req.seqNum }, response)
	local f = dispatcher[req.method]
	if not f then
		resp.success = false
		return resp
	end

	local ok, err = pcall(f, dispatcher, req, resp)
	if resp.success == nil then
		resp.success = ok
	end
	if not ok then
		print(err)
	elseif err ~= nil then
		resp["return"] = err
	end
	return resp
end

local function set(s)
	for k,v in ipairs(s) do
		s[k] = nil
		s[v] = true
	end
	return s
end

local valid_command = set {
	"init",
	"onActivate",
	"onDeactivate",
	"onLangProfileActivated",
	"onLangProfileDeactivated",
	"filterKeyDown",
	"filterKeyUp",
	"onKeyDown",
	"onKeyUp",
	"onPreservedKey",
	"onCommand",
	"onMenu",
	"onCompartmentChanged",
	"onKeyboardStatusChanged",
	"onCompositionTerminated",
}
function pime.check(dispatcher)
	for k,v in pairs(dispatcher) do
		if type(v) == "function" and type(k) == "string"
			and k:sub(1,1) ~= "_" then
			if not valid_command[k] then
				error( k .. " is invalid method")
			end
		end
	end
end

function response:commit(str)
	self.commitString = tostring(str)
end

function response:composition(str , cursor)
	self.compositionString = tostring(str)
	if cursor then
		self.compositionCursor = math.floor(tonumber(cursor))
	end
end

function response:candidate(list , cursor)
	assert(type(list) == "table")
	self.candidateList = list
	if cursor then
		self.candidateCursor = math.floor(tonumber(cursor))
	end
end

function response:show(show)
	self.showCandidates = show ~= false
end

function response:keyboard(open)
	self.openKeyboard = open
end

function response:add_button(icon)
	self.addButton = {{
		id = "windows-mode-icon",	-- windows 8+ only support this
		type = "button",
		icon = icon,
	}}
end

function response:remove_button()
	self.removeButton = { "windows-mode-icon" }
end

function response:change_button(icon)
	self.changeButton = {{
		id = "windows-mode-icon",	-- windows 8+ only support this
		icon = icon,
	}}
end

function response:add_preserved_key(guid, keycode, modifier)
	local add = self.addPreservedKey
	if not add then
		add = {}
		self.addPreservedKey = add
	end
	add[guid] = {
		keyCode = keycode,
		modifiers = modifier,
	}
end

function response:set_select(str)
	self.SelKeys = tostring(str)
end

function response:customize(font, size, number, cursor)
	self.customizeUI = {
		candFontName = font,
		candFontSize = size,
		candPerRow = number,
		candUseCursor = cursor,
	}
end

function response:message(text, d)
	self.showMessage = {
		message = text,
		duration = d,
	}
end

pime.TF_MOD_ALT                       = 0x0001
pime.TF_MOD_CONTROL                   = 0x0002
pime.TF_MOD_SHIFT                     = 0x0004
pime.TF_MOD_RALT                      = 0x0008
pime.TF_MOD_RCONTROL                  = 0x0010
pime.TF_MOD_RSHIFT                    = 0x0020
pime.TF_MOD_LALT                      = 0x0040
pime.TF_MOD_LCONTROL                  = 0x0080
pime.TF_MOD_LSHIFT                    = 0x0100
pime.TF_MOD_ON_KEYUP                  = 0x0200
pime.TF_MOD_IGNORE_ALL_MODIFIER       = 0x0400

pime.VK_LBUTTON =0x01
pime.VK_RBUTTON =0x02
pime.VK_CANCEL =0x03
pime.VK_MBUTTON =0x04
pime.VK_XBUTTON1 =0x05
pime.VK_XBUTTON2 =0x06
pime.VK_BACK =0x08
pime.VK_TAB =0x09
pime.VK_CLEAR =0x0C
pime.VK_RETURN =0x0D
pime.VK_SHIFT =0x10
pime.VK_CONTROL =0x11
pime.VK_MENU =0x12
pime.VK_PAUSE =0x13
pime.VK_CAPITAL =0x14
pime.VK_KANA =0x15
pime.VK_HANGEUL =0x15
pime.VK_HANGUL =0x15
pime.VK_JUNJA =0x17
pime.VK_FINAL =0x18
pime.VK_HANJA =0x19
pime.VK_KANJI =0x19
pime.VK_ESCAPE =0x1B
pime.VK_CONVERT =0x1C
pime.VK_NONCONVERT =0x1D
pime.VK_ACCEPT =0x1E
pime.VK_MODECHANGE =0x1F
pime.VK_SPACE =0x20
pime.VK_PRIOR =0x21
pime.VK_NEXT =0x22
pime.VK_END =0x23
pime.VK_HOME =0x24
pime.VK_LEFT =0x25
pime.VK_UP =0x26
pime.VK_RIGHT =0x27
pime.VK_DOWN =0x28
pime.VK_SELECT =0x29
pime.VK_PRINT =0x2A
pime.VK_EXECUTE =0x2B
pime.VK_SNAPSHOT =0x2C
pime.VK_INSERT =0x2D
pime.VK_DELETE =0x2E
pime.VK_HELP =0x2F

pime.VK_LWIN =0x5B
pime.VK_RWIN =0x5C
pime.VK_APPS =0x5D
pime.VK_SLEEP =0x5F
pime.VK_NUMPAD0 =0x60
pime.VK_NUMPAD1 =0x61
pime.VK_NUMPAD2 =0x62
pime.VK_NUMPAD3 =0x63
pime.VK_NUMPAD4 =0x64
pime.VK_NUMPAD5 =0x65
pime.VK_NUMPAD6 =0x66
pime.VK_NUMPAD7 =0x67
pime.VK_NUMPAD8 =0x68
pime.VK_NUMPAD9 =0x69
pime.VK_MULTIPLY =0x6A
pime.VK_ADD =0x6B
pime.VK_SEPARATOR =0x6C
pime.VK_SUBTRACT =0x6D
pime.VK_DECIMAL =0x6E
pime.VK_DIVIDE =0x6F
pime.VK_F1 =0x70
pime.VK_F2 =0x71
pime.VK_F3 =0x72
pime.VK_F4 =0x73
pime.VK_F5 =0x74
pime.VK_F6 =0x75
pime.VK_F7 =0x76
pime.VK_F8 =0x77
pime.VK_F9 =0x78
pime.VK_F10 =0x79
pime.VK_F11 =0x7A
pime.VK_F12 =0x7B
pime.VK_F13 =0x7C
pime.VK_F14 =0x7D
pime.VK_F15 =0x7E
pime.VK_F16 =0x7F
pime.VK_F17 =0x80
pime.VK_F18 =0x81
pime.VK_F19 =0x82
pime.VK_F20 =0x83
pime.VK_F21 =0x84
pime.VK_F22 =0x85
pime.VK_F23 =0x86
pime.VK_F24 =0x87
pime.VK_NUMLOCK =0x90
pime.VK_SCROLL =0x91
pime.VK_OEM_NEC_EQUAL =0x92
pime.VK_OEM_FJ_JISHO =0x92
pime.VK_OEM_FJ_MASSHOU =0x93
pime.VK_OEM_FJ_TOUROKU =0x94
pime.VK_OEM_FJ_LOYA =0x95
pime.VK_OEM_FJ_ROYA =0x96
pime.VK_LSHIFT =0xA0
pime.VK_RSHIFT =0xA1
pime.VK_LCONTROL =0xA2
pime.VK_RCONTROL =0xA3
pime.VK_LMENU =0xA4
pime.VK_RMENU =0xA5
pime.VK_BROWSER_BACK =0xA6
pime.VK_BROWSER_FORWARD =0xA7
pime.VK_BROWSER_REFRESH =0xA8
pime.VK_BROWSER_STOP =0xA9
pime.VK_BROWSER_SEARCH =0xAA
pime.VK_BROWSER_FAVORITES =0xAB
pime.VK_BROWSER_HOME =0xAC
pime.VK_VOLUME_MUTE =0xAD
pime.VK_VOLUME_DOWN =0xAE
pime.VK_VOLUME_UP =0xAF
pime.VK_MEDIA_NEXT_TRACK =0xB0
pime.VK_MEDIA_PREV_TRACK =0xB1
pime.VK_MEDIA_STOP =0xB2
pime.VK_MEDIA_PLAY_PAUSE =0xB3
pime.VK_LAUNCH_MAIL =0xB4
pime.VK_LAUNCH_MEDIA_SELECT =0xB5
pime.VK_LAUNCH_APP1 =0xB6
pime.VK_LAUNCH_APP2 =0xB7
pime.VK_OEM_1 =0xBA
pime.VK_OEM_PLUS =0xBB
pime.VK_OEM_COMMA =0xBC
pime.VK_OEM_MINUS =0xBD
pime.VK_OEM_PERIOD =0xBE
pime.VK_OEM_2 =0xBF
pime.VK_OEM_3 =0xC0
pime.VK_OEM_4 =0xDB
pime.VK_OEM_5 =0xDC
pime.VK_OEM_6 =0xDD
pime.VK_OEM_7 =0xDE
pime.VK_OEM_8 =0xDF
pime.VK_OEM_AX =0xE1
pime.VK_OEM_102 =0xE2
pime.VK_ICO_HELP =0xE3
pime.VK_ICO_00 =0xE4
pime.VK_PROCESSKEY =0xE5
pime.VK_ICO_CLEAR =0xE6
pime.VK_PACKET =0xE7
pime.VK_OEM_RESET =0xE9
pime.VK_OEM_JUMP =0xEA
pime.VK_OEM_PA1 =0xEB
pime.VK_OEM_PA2 =0xEC
pime.VK_OEM_PA3 =0xED
pime.VK_OEM_WSCTRL =0xEE
pime.VK_OEM_CUSEL =0xEF
pime.VK_OEM_ATTN =0xF0
pime.VK_OEM_FINISH =0xF1
pime.VK_OEM_COPY =0xF2
pime.VK_OEM_AUTO =0xF3
pime.VK_OEM_ENLW =0xF4
pime.VK_OEM_BACKTAB =0xF5
pime.VK_ATTN =0xF6
pime.VK_CRSEL =0xF7
pime.VK_EXSEL =0xF8
pime.VK_EREOF =0xF9
pime.VK_PLAY =0xFA
pime.VK_ZOOM =0xFB
pime.VK_NONAME =0xFC
pime.VK_PA1 =0xFD
pime.VK_OEM_CLEAR =0xFE

return pime