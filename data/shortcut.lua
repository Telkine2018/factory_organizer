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
    icon =
    {
      filename = png("icons/tool-x32"),
      priority = "extra-high-no-scale",
      size = 32,
      scale = 1,
      flags = { "gui-icon" }
    },
    small_icon =
    {
      filename = png("icons/tool-x24"),
      priority = "extra-high-no-scale",
      size = 24,
      scale = 1,
      flags = { "gui-icon" }
    },
  },
}


local controls = {
  {
    type = "custom-input",
    name = prefix .. "-start_teleport",
    key_sequence = "CONTROL + K",
    consuming = "none"
  },
  {
    type = "custom-input",
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
  selection_color = { r=0, g=0, b=1 },
  alt_selection_color = { r=1, g=0, b=0 },
  selection_mode = {"same-force", "any-entity" },
  alt_selection_mode = {"same-force","any-entity"},
  selection_cursor_box_type = "entity",
  alt_selection_cursor_box_type =  "entity",
  flags = {"hidden", "not-stackable", "only-in-cursor", "spawnable"},
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
  },
  {
    type = "custom-input",
    name = prefix .. "-rotate",
    key_sequence = "R"
  }

}
