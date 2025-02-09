local commons = require("scripts.commons")

local prefix = commons.prefix
local png = commons.png


data:extend
{
  {
    type = "shortcut",
    name = prefix .. "-tools",
    order = "f[actory]-a[nalyzer]",
    action = "lua",
    icon = png("icons/tool-x32"),
    icon_size = 32,
    small_icon = png("icons/tool-x24"),
    small_icon_size = 24
  },
}


local controls = {
    {
      type = "custom-input",
      name = prefix .. "-start_teleport",
      key_sequence = "CONTROL + K",
      consuming = "none"
    },
    {    type = "custom-input",
    name = prefix .. "-escape",
    key_sequence = "ESCAPE",
    consuming = "none"
  }
}

data:extend(controls)

local selection_tool = {

  type = "selection-tool",
  name = prefix .. "-selection_tool",
  icon = png("icons/selection-tool"),
  icon_size = 32,

  select = {
    border_color = { r=0, g=0, b=1 },
    cursor_box_type = "entity",
    mode = {"same-force", "any-entity" }
  },
  alt_select = {
    border_color = { r=0, g=0, b=1 },
    cursor_box_type = "entity",
    mode = {"same-force", "any-entity" }
  },
  flags = {"not-stackable", "only-in-cursor", "spawnable"},
  subgroup = "other",
  stack_size = 1,
  stackable = false,
  show_in_library = false
}

data:extend {selection_tool}

data:extend {
  {
      type = "custom-input",
      name = prefix .. "-north",
      key_sequence = "CONTROL + UP"
  },
  {
      type = "custom-input",
      name = prefix .. "-west",
      key_sequence = "CONTROL + LEFT"
  },
  {
      type = "custom-input",
      name = prefix .. "-south",
      key_sequence = "CONTROL + DOWN"
  },
  {
      type = "custom-input",
      name = prefix .. "-east",
      key_sequence = "CONTROL + RIGHT"
  },
  {
    type = "custom-input",
    name = prefix .. "-enter",
    key_sequence = "CONTROL + ENTER"
  }

}
