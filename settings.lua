

local commons = require("scripts.commons")
local prefix = commons.prefix

data:extend(
    {
		{
			type = "bool-setting",
			name = prefix .. "-always_use_selection_tools",
			setting_type = "runtime-per-user",
			default_value = true
		}
})
