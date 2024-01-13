
local tools = require("scripts.tools")



---@alias BoundaryPoint {x:integer, y:integer}

---@class Boundary
---@field p1 BoundaryPoint
---@field p2 BoundaryPoint

---@class Teleporter
---@field tile_map table<string, LuaTile>
---@field start_tile LuaTile
---@field surface LuaSurface
---@field proto string
---@field boundary Boundary
---@field start_pos MapPosition
---@field area BoundingBox
---@field previous_dx integer
---@field previous_dy integer
---@field move_x integer
---@field move_y integer
---@field entity_ids integer[]
---@field arrow_id integer
---@field entities LuaEntity[]
---@field entity_map table<integer, LuaEntity>
---@field rails LuaEntity[]
---@field belts LuaEntity[]
---@field rotatable boolean
---@field rotation integer @ 0:none, 1:90 deg, 2: 180 deg, 3: 270 deg
---@field matrix int[][]
---@field center MapPosition




