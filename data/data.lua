

local commons = require("scripts.commons")

local prefix = commons.prefix
local png = commons.png

local arrow_sprite = {
	type = "sprite",
	name = prefix .. "-arrow",
	filename = png("icons/arrow"),
	width = 32,
	height = 32
}

data:extend {arrow_sprite}