local tools = require("scripts.tools")



---@alias BoundaryPoint {x:integer, y:integer}

---@class Boundary
---@field p1 BoundaryPoint
---@field p2 BoundaryPoint
---@field id LuaRenderObject

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
---@field entity_ids LuaRenderObject[]
---@field arrow_id LuaRenderObject
---@field entities LuaEntity[]
---@field entity_map table<integer, LuaEntity>
---@field rails LuaEntity[]
---@field belts LuaEntity[]
---@field rotatable boolean
---@field rotation integer @ 0:none, 1:90 deg, 2: 180 deg, 3: 270 deg
---@field matrix int[][]
---@field center MapPosition

---@class BeltInfo
---@field position MapPosition
---@field name string
---@field direction defines.direction
---@field force LuaForce
---@field type string
---@field ext EntityExtension

---@alias EntityExtension BeltInfoExt | LoaderInfoExt | BeltUndergroundInfo | LinkedBeltInfoExt
---@alias EntityReference int | LuaEntity

---@class BeltBase
---@field apply any
---@field lines  {[integer]:BeltLineContent[]}
---@field unit_number integer

---@class BeltLineContent
---@field name string
---@field count integer
---@field quality string
---@field spoil_percent number
---@field health number
---@field position number

---@class BeltInfoExt : BeltBase
---@field type string
---@field circuit_connection_definitions CircuitConnectionDefinition[]

---@class LoaderInfoExt : BeltBase
---@field filters ItemFilter[]
---@field loader_type string
---@field position MapPosition
---@field name string
---@field has_cb boolean
---@field circuit_set_filters boolean
---@field circuit_read_transfers boolean
---@field circuit_enable_disable boolean
---@field circuit_condition CircuitConditionDefinition
---@field connect_to_logistic_network boolean
---@field logistic_condition  CircuitConditionDefinition
---@field loader_filter_mode string
---@field loader_belt_stack_size_override integer

---@class LinkedBeltInfoExt : BeltBase
---@field linked_belt_type string
---@field linked_belt_neighbour EntityReference

---@class BeltUndergroundInfo : BeltBase
---@field type string

---@class CircuitConnectionDefinition
---@field  src_connector_id defines.wire_connector_id
---@field  target_entity  EntityReference
---@field  target_connector_id  defines.wire_connector_id
