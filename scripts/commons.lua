

local tools = require("scripts.tools")

local prefix = "factory_organizer"
local modpath = "__" .. prefix .. "__"

local commons = {

	prefix = prefix ,
    modpath = modpath,
	graphic_path = modpath .. '/graphics/%s.png',
}

---@param name string
---@return string
function commons.png(name) return (commons.graphic_path):format(name) end


return commons
