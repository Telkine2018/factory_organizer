local tools = require("scripts.tools")
local commons = require("scripts.commons")
local defs = require("scripts._defs")
local debug = tools.debug

local prefix = commons.prefix

local frame_name = prefix .. "-frame"

---@type table<int, {[1]:integer, [2]:integer}>
local deltas = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local ignored_types = {
    ["character"] = true,
    ["unit"] = true,
    ["unit-spawner"] = true,
    ["spider-vehicle"] = true,
    ["item-request-proxy"] = true,
    ["rocket-silo-rocket"] = true,
    ["resource"] = true,
    ["construction-robot"] = true,
    ["logistic-robot"] = true,
    ["rocket"] = true,
    ["tile-ghost"] = true,
    ["item-entity"] = true,
    ["offshore-pump"] = true
    -- ["mining-drill"]       = true
}

local collision_unrestricted_types = {
    ["character"] = true,
    ["resource"] = true,
    ["construction-robot"] = true,
    ["logistic-robot"] = true
}

local forbidden_types = {
    ["locomotive"] = true,
    ["cargo-wagon"] = true,
    ["artillery-wagon"] = true,
    ["fluid-wagon"] = true,
    ["entity-ghost"] = true
}

---@type table<string, boolean>
local not_moveable_names = {
    ["request-depot"] = true,
    ["supply-depot-chest"] = true,
    ["buffer-depot"] = true,
    ["fluid-depot"] = true,
    ["fuel-depot"] = true,
    ["supply-depot"] = true,
}

local forbidden_names = {}

local rail_types = { ["straight-rail"] = true, ["curved-rail"] = true }

local belt_types = {
    ["linked-belt"] = true,
    ["transport-belt"] = true,
    ["underground-belt"] = true,
    ["splitter"] = true,
    ["loader"] = true,
    ["loader-1x1"] = true
}

local rotation_matrix = {
    { { 1, 0 }, { 0, 1 } }, { { 0, -1 }, { 1, 0 } }, { { -1, 0 }, { 0, -1 } }, { { 0, 1 }, { -1, 0 } }
}

---@type table<string, {interface:string, method:string }>
local collect_methods_by_name = {}

---@type table<string, ({interface:string , method:string }[])>
local collect_methods_by_type = {}

---@type table<string, {interface:string, method:string }>
local teleport_methods_by_name = {}

---@type table<string, ({interface:string, method:string }[]) >
local teleport_methods_by_type = {}

---@type table<string, {interface:string, method:string }>
local preteleport_methods_by_name = {}

---@param tile LuaTile
---@return string
local function get_key(tile)
    local pos = tile.position
    return pos.x .. "/" .. pos.y
end

--- @class Teleporter
local Teleporter = {}

---@param info Teleporter
function Teleporter.scan_tiles(info)
    local request_map = {}
    local start_tile = info.start_tile
    info.tile_map = {}
    local tile_map = info.tile_map

    local proto = info.proto
    local pos_key = get_key(start_tile)
    request_map[pos_key] = start_tile

    local surface = info.surface
    local xmin, ymin = start_tile.position.x, start_tile.position.y
    local xmax, ymax = xmin, ymin
    while (true) do
        local _, tile = next(request_map)
        if not tile then break end

        local key = get_key(tile)
        request_map[key] = nil
        tile_map[key] = tile
        for _, delta in pairs(deltas) do
            local pos = tile.position
            local x = pos.x
            local y = pos.y
            if x < xmin then xmin = x end
            if y < ymin then ymin = y end
            if x > xmax then xmax = x end
            if y > ymax then ymax = y end

            x = x + delta[1]
            y = y + delta[2]
            local found_tile = surface.get_tile(x, y)
            if found_tile then
                if found_tile.prototype.name == proto then
                    local found_key = get_key(found_tile)
                    if not tile_map[found_key] then
                        request_map[found_key] = found_tile
                    end
                end
            end
        end
    end

    info.area = {
        left_top = { x = xmin, y = ymin },
        right_bottom = { x = xmax + 1, y = ymax + 1 }
    }
end

---@param info Teleporter
function Teleporter.compute_boundery(info)
    ---@type Boundary
    local boundary = {}

    ---@param x integer
    ---@param y integer
    ---@param dx integer
    ---@param dy integer
    local function check(x, y, x1, y1, dx, dy)
        local key = x .. "/" .. y
        if not info.tile_map[key] then
            table.insert(boundary, {
                p1 = { x = x1, y = y1 },
                p2 = { x = x1 + dx, y = y1 + dy }
            })
        end
    end

    for _, tile in pairs(info.tile_map) do
        local pos = tile.position

        check(pos.x - 1, pos.y, pos.x, pos.y, 0, 1)
        check(pos.x + 1, pos.y, pos.x + 1, pos.y, 0, 1)

        check(pos.x, pos.y - 1, pos.x, pos.y, 1, 0)
        check(pos.x, pos.y + 1, pos.x, pos.y + 1, 1, 0)
    end
    info.boundary = boundary
end

---@param info Teleporter
function Teleporter.display_boundary(info)
    local surface = info.surface
    for _, line in pairs(info.boundary) do
        line.id = rendering.draw_line {
            color = { 0, 1, 0 },
            width = 2,
            from = line.p1,
            to = line.p2,
            surface = surface
        }
    end
end

---@param info Teleporter
---@param dx number
---@param dy number
function Teleporter.move_boundary(info, dx, dy)
    if not info.boundary then return end
    dx = math.floor(dx)
    dy = math.floor(dy)
    for _, line in pairs(info.boundary) do
        rendering.set_from(line.id, { line.p1.x + dx, line.p1.y + dy })
        rendering.set_to(line.id, { line.p2.x + dx, line.p2.y + dy })
    end
end

---@param info Teleporter
function Teleporter.clear_boundary(info)
    if not info or not info.boundary then return end

    for _, line in pairs(info.boundary) do rendering.destroy(line.id) end
end

---@param info Teleporter
---@return boolean
function Teleporter.collect_entities(info)
    local surface = info.surface
    local area = info.area
    local entities = surface.find_entities_filtered { area = area }

    return Teleporter.add_entities(info, entities)
end

---@param entity LuaEntity
---@return boolean
function Teleporter.is_forbidden(entity)
    return forbidden_types[entity.type] or forbidden_names[entity.name]
end

local is_forbidden = Teleporter.is_forbidden

---@param entity LuaEntity
---@return boolean
function Teleporter.is_allowed(entity)
    if not ignored_types[entity.type] and entity.unit_number and
        not not_moveable_names[entity.name] then
        return true
    end
    return false
end

local is_allowed = Teleporter.is_allowed

---@param info Teleporter
---@param entities LuaEntity[]
---@return boolean
function Teleporter.add_entities(info, entities)
    local entities_table = info.entities or {}
    local rails = info.rails or {}
    local entity_map = info.entity_map or {}
    local belts = info.belts or {}
    local rotatable = true

    local others = {}

    ---@param collect_method {interface:string, method:string}
    ---@param entity LuaEntity
    local function call_external(collect_method, entity)
        local collected = remote.call(collect_method.interface,
            collect_method.method, entity)
        if collected then
            for _, e in pairs(collected) do
                table.insert(others, e)
            end
        end
    end

    for _, entity in pairs(entities) do
        local collect_method = collect_methods_by_name[entity.name]
        if collect_method then
            call_external(collect_method, entity)
        end
        local collect_methods = collect_methods_by_type[entity.type]
        if collect_methods then
            for _, collect_method in pairs(collect_methods) do
                call_external(collect_method, entity)
            end
        end
    end

    for _, e in pairs(others) do table.insert(entities, e) end

    for _, entity in pairs(entities) do
        if is_forbidden(entity) then return false end
        if is_allowed(entity) then
            if not entity_map[entity.unit_number] then
                local position = entity.position
                local x = math.floor(position.x)
                local y = math.floor(position.y)
                local key = x .. "/" .. y
                local type = entity.type
                if not info.tile_map or info.tile_map[key] then
                    if rail_types[type] then
                        table.insert(rails, entity)
                        rotatable = false
                    elseif belt_types[type] then
                        table.insert(belts, entity)
                    else
                        if not entity.rotatable then
                            rotatable = false
                        end
                    end
                    table.insert(entities_table, entity)
                    entity_map[entity.unit_number] = entity
                end
            end
        end
    end

    info.entities = entities_table
    info.rails = rails
    info.belts = belts
    info.entity_map = entity_map
    info.rotatable = rotatable
    info.center = Teleporter.compute_center(info)
    if not rotatable then
        info.rotation = 0
        info.matrix = nil
    else
        info.matrix = rotation_matrix[info.rotation + 1]
    end
    return true
end

---@param info Teleporter
---@param entities LuaEntity[]
---@return boolean
function Teleporter.remove_entities(info, entities)
    local entity_map = info.entity_map or {}

    for _, entity in pairs(entities) do
        if entity.unit_number and entity_map[entity.unit_number] then
            entity_map[entity.unit_number] = nil
        end
    end
    local entities = {}
    for _, entity in pairs(entity_map) do table.insert(entities, entity) end

    info.entities = nil
    info.rails = nil
    info.belts = nil
    info.entity_map = nil

    return Teleporter.add_entities(info, entities)
end

---@param info Teleporter
---@param point MapPosition
---@return MapPosition
function Teleporter.rotate_point(info, point)
    local center, matrix = info.center, info.matrix
    local dx = point.x - center.x
    local dy = point.y - center.y

    local dxp = matrix[1][1] * dx + matrix[1][2] * dy
    local dyp = matrix[2][1] * dx + matrix[2][2] * dy

    local x = center.x + dxp
    local y = center.y + dyp
    return { x = x, y = y }
end

---@param info Teleporter
---@param selection_box BoundingBox
function Teleporter.rotate_box(info, selection_box)
    local left_top = selection_box.left_top
    local right_bottom = selection_box.right_bottom

    left_top = Teleporter.rotate_point(info, left_top)
    right_bottom = Teleporter.rotate_point(info, right_bottom)

    local left_top1 = {
        math.min(left_top.x, right_bottom.x),
        math.min(left_top.y, right_bottom.y)
    }
    local right_bottom1 = {
        math.max(left_top.x, right_bottom.x),
        math.max(left_top.y, right_bottom.y)
    }

    return { left_top = left_top1, right_bottom = right_bottom1 }
end

---@param info Teleporter
---@return MapPosition
function Teleporter.compute_center(info)
    local xmin, ymin, xmax, ymax

    for _, entity in pairs(info.entities) do
        local bb = entity.bounding_box
        if not xmin then
            xmin, ymin = bb.left_top.x, bb.left_top.y
            xmax, ymax = bb.right_bottom.x, bb.right_bottom.y
        else
            xmin = math.min(xmin, bb.left_top.x)
            ymin = math.min(ymin, bb.left_top.y)
            xmax = math.max(xmax, bb.right_bottom.x)
            ymax = math.max(ymax, bb.right_bottom.y)
        end
    end
    if not xmin then return { x = 0, y = 0 } end

    local x, y = (xmin + xmax) / 2, (ymin + ymax) / 2
    x = math.floor(2 * x + 0.5) / 2
    y = math.floor(2 * y + 0.5) / 2
    local dx = math.floor(xmax - xmin + 0.5) % 2
    local dy = math.floor(ymax - ymin + 0.5) % 2
    if #info.rails > 0 then
        x = 2 * math.floor(x / 2)
        y = 2 * math.floor(y / 2)
    end
    return { x = x, y = y }
end

---@param info Teleporter
function Teleporter.display_entities(info)
    local entity_ids = {}
    local surface = info.surface
    for _, entity in pairs(info.entities) do
        local selection_box = entity.selection_box
        if selection_box then
            if info.rotation ~= 0 then
                selection_box = Teleporter.rotate_box(info, selection_box)
            end
            local id = rendering.draw_rectangle {
                surface = surface,
                left_top = selection_box.left_top,
                right_bottom = selection_box.right_bottom,
                color = { 0, 1, 1, 0.02 },
                width = 2,
                draw_on_ground = true,
                filled = true
            }
            table.insert(entity_ids, id)
        end
    end
    info.entity_ids = entity_ids
    if info.rotatable and not info.arrow_id then
        info.arrow_id = rendering.draw_sprite {
            surface = surface,
            orientation = 0.25 * info.rotation,
            sprite = prefix .. "-arrow",
            render_layer = "cursor",
            target = info.center
        }
    end
end

---@param info Teleporter
function Teleporter.move_entities(info, dx, dy)
    local rdx = dx - info.previous_dx
    local rdy = dy - info.previous_dy
    for _, id in pairs(info.entity_ids) do
        local left_top = rendering.get_left_top(id).position
        rendering.set_left_top(id, { left_top.x + rdx, left_top.y + rdy })
        local right_bottom = rendering.get_right_bottom(id).position
        rendering.set_right_bottom(id,
            { right_bottom.x + rdx, right_bottom.y + rdy })
    end
    if info.arrow_id then
        local pos = rendering.get_target(info.arrow_id).position --[[@as MapPosition]]
        rendering.set_target(info.arrow_id, { x = pos.x + rdx, y = pos.y + rdy })
    end
    info.previous_dx = dx
    info.previous_dy = dy
end

---@param info Teleporter
function Teleporter.clear_display_entities(info)
    if info.entity_ids then
        for _, id in pairs(info.entity_ids) do rendering.destroy(id) end
        info.entity_ids = nil
    end
    if info.arrow_id then
        rendering.destroy(info.arrow_id)
        info.arrow_id = nil
    end
end

---@param info Teleporter
---@param player LuaPlayer
function Teleporter.update_position(info, player)
    local position = player.position
    local dx = math.floor(position.x - info.start_pos.x)
    local dy = math.floor(position.y - info.start_pos.y)

    dx = dx + info.move_x
    dy = dy + info.move_y

    if #info.rails > 0 then
        dx = 2 * math.floor(dx / 2)
        dy = 2 * math.floor(dy / 2)
    end
    Teleporter.move_boundary(info, dx, dy)
    Teleporter.move_entities(info, dx, dy)
end

---@param e EventData.on_player_changed_position
tools.on_event(defines.events.on_player_changed_position, function(e)
    local player = game.players[e.player_index]

    local info = tools.get_vars(player).info --[[@as Teleporter]]
    if not info then return end

    Teleporter.update_position(info, player)
end)

---@param e EventData.on_lua_shortcut
local function start_teleport(e)
    local player = game.players[e.player_index]
    local vars = tools.get_vars(player)
    if vars.info then
        Teleporter.end_teleport(e.player_index)
        return
    end

    local start_pos = player.position
    local tile_position = {
        x = math.floor(start_pos.x + 0.5) + 0.5,
        y = math.floor(start_pos.y - 0.5) + 0.5
    }
    local start_tile = player.surface.get_tile(tile_position.x, tile_position.y)

    if settings.get_player_settings(player)[prefix ..
        "-always_use_selection_tools"].value or not start_tile or
        not start_tile.prototype.mineable_properties or
        not start_tile.prototype.mineable_properties.minable then
        if not player.cursor_stack.valid_for_read or player.cursor_stack.name ~=
            prefix .. "-selection_tool" then
            player.cursor_stack.clear()
            player.cursor_stack.set_stack(prefix .. "-selection_tool")
        else
            player.cursor_stack.clear()
        end
        return
    end

    ---@type Teleporter
    local info = {
        start_tile = start_tile,
        start_pos = start_pos,
        previous_dx = 0,
        previous_dy = 0,
        surface = start_tile.surface,
        proto = start_tile.prototype.name,
        move_x = 0,
        move_y = 0,
        rotation = 0,
        rotatable = true
    }

    vars.info = info
    Teleporter.scan_tiles(info)
    Teleporter.compute_boundery(info)
    Teleporter.display_boundary(info)
    if not Teleporter.collect_entities(info) then
        Teleporter.end_teleport(e.player_index)
        player.print({ prefix .. "-message.cannot_move_train" })
        return
    end
    Teleporter.display_entities(info)
    Teleporter.create_frame(player)
end

function Teleporter.create_frame(player)
    if player.gui.left[frame_name] then return end
    local frame = player.gui.left.add {
        type = "frame",
        name = frame_name,
        caption = { prefix .. ".frame-title" }
    }
    local inner_frame = frame.add {
        type = "frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    }
    local bflow = inner_frame.add { type = "flow", direction = "horizontal" }
    bflow.add {
        type = "button",
        name = prefix .. "-bteleport",
        caption = { prefix .. ".bteleport" }
    }
    bflow.add {
        type = "button",
        name = prefix .. "-bcancel",
        caption = { prefix .. ".bcancel" }
    }
end

tools.on_event(defines.events.on_lua_shortcut, function(e)
    if (e.prototype_name ~= prefix .. "-tools") then return end
    start_teleport(e)
end)

---@param player_index integer
function Teleporter.end_teleport(player_index)
    local player = game.players[player_index]
    local vars = tools.get_vars(player)
    local info = vars.info --[[@as Teleporter]]

    if not info then return end

    Teleporter.clear_boundary(info)
    Teleporter.clear_display_entities(info)
    vars.info = nil
    local frame = player.gui.left[frame_name]
    if frame then frame.destroy() end
end

function Teleporter.get_compare_func(dx, dy)
    local compare
    if dx > 0 then
        if dy > 0 then
            compare = function(e1, e2)
                return e1.position.x > e2.position.x or
                    (e1.position.x == e2.position.x and e1.position.y >
                        e2.position.y)
            end
        else
            compare = function(e1, e2)
                return e1.position.x > e2.position.x or
                    (e1.position.x == e2.position.x and e1.position.y <
                        e2.position.y)
            end
        end
    elseif dx < 0 then
        if dy > 0 then
            compare = function(e1, e2)
                return e1.position.x < e2.position.x or
                    (e1.position.x == e2.position.x and e1.position.y >
                        e2.position.y)
            end
        else
            compare = function(e1, e2)
                return e1.position.x < e2.position.x or
                    (e1.position.x == e2.position.x and e1.position.y <
                        e2.position.y)
            end
        end
    else
        if dy > 0 then
            compare = function(e1, e2)
                return e1.position.y > e2.position.y
            end
        else
            compare = function(e1, e2)
                return e1.position.y < e2.position.y
            end
        end
    end
    return compare
end

local tranport_belt_fields = {
    "enable_disable", "read_contents", "read_contents_mode",
    "circuit_condition", "logistic_condition", "connect_to_logistic_network"
}

---@param info Teleporter
local function transport_belt_apply(info, ext)
    local belt = info.entity_map[ext.unit_number]

    local cb = belt.get_or_create_control_behavior()
    for _, name in ipairs(tranport_belt_fields) do cb[name] = ext[name] end
    if ext.circuit_connection_definitions then
        for _, c in pairs(ext.circuit_connection_definitions) do
            local target_entity = c.target_entity
            if type(target_entity) == "number" then
                target_entity = info.entity_map[tonumber(target_entity)]
            end
            c.target_entity = target_entity
            belt.connect_neighbour(c)
        end
    end
end

local splitter_fields = {
    "splitter_filter", "splitter_input_priority", "splitter_output_priority"
}

---@param info Teleporter
local function splitter_apply(info, ext)
    local belt = info.entity_map[ext.unit_number]

    for _, name in ipairs(splitter_fields) do belt[name] = ext[name] end
end

---@param info Teleporter
local function loader_apply(info, ext)
    local belt = info.entity_map[ext.unit_number]

    belt.loader_type = ext.loader_type
    if ext.loader_type == "output" then
        belt.direction = tools.get_opposite_direction(belt.direction)
    end

    for i = 1, belt.filter_slot_count do belt.set_filter(i, ext.filters[i]) end
end

---@param info Teleporter
local function linke_belt_apply(info, ext)
    local belt = info.entity_map[ext.unit_number]

    if belt.linked_belt_neighbour then return end
    belt.linked_belt_type = ext.linked_belt_type
    local linked_belt_neighbour = ext.linked_belt_neighbour
    if type(linked_belt_neighbour) == "number" then
        linked_belt_neighbour = info.entity_map[linked_belt_neighbour]
    end
    if not linked_belt_neighbour then return end
    if linked_belt_neighbour.linked_belt_type == belt.linked_belt_type then
        if linked_belt_neighbour.linked_belt_type == 'input' then
            linked_belt_neighbour.linked_belt_type = 'output'
        else
            linked_belt_neighbour.linked_belt_type = 'intput'
        end
    end
    belt.connect_linked_belts(linked_belt_neighbour)
end

---@param info Teleporter
function Teleporter.destroy_belts(info, dx, dy)
    local belt_infos = {}
    local rotation_offset = 2 * info.rotation
    for _, belt in pairs(info.belts) do
        if belt.valid then
            local type = belt.type
            local position = belt.position
            if rotation_offset ~= 0 then
                position = Teleporter.rotate_point(info, position)
            end
            local belt_info = {
                position = { position.x + dx, position.y + dy },
                name = belt.name,
                direction = (belt.direction + rotation_offset) % 8,
                force = belt.force
            }
            table.insert(belt_infos, belt_info)
            local ext = {}
            belt_info.ext = ext
            ext.unit_number = belt.unit_number
            ext.type = type
            if type == "transport-belt" then
                local cb = belt.get_control_behavior() --[[@as LuaTransportBeltControlBehavior]]
                if cb then
                    ext.apply = transport_belt_apply
                    for _, name in ipairs(tranport_belt_fields) do
                        ext[name] = cb[name]
                    end
                    if belt.circuit_connection_definitions then
                        ext.circuit_connection_definitions = {}
                        for _, c in pairs(belt.circuit_connection_definitions) do
                            ---@type any
                            local target_entity = c.target_entity
                            if info.entity_map[target_entity.unit_number] then
                                target_entity = target_entity.unit_number
                            end
                            table.insert(ext.circuit_connection_definitions, {
                                wire = c.wire,
                                target_entity = target_entity,
                                source_circuit_id = c.source_circuit_id,
                                target_circuit_id = c.target_circuit_id
                            })
                        end
                    end
                end
            elseif type == "splitter" then
                for _, name in ipairs(splitter_fields) do
                    ext[name] = belt[name]
                end
                ext.apply = splitter_apply
            elseif type == "loader" or type == "loader-1x1" then
                ext.filters = {}
                for slot = 1, belt.filter_slot_count do
                    table.insert(ext.filters, belt.get_filter(slot))
                end
                ext.loader_type = belt.loader_type
                ext.position = belt.position
                ext.name = belt.name
                ext.apply = loader_apply
            elseif type == "underground-belt" then
                belt_info.type = belt.belt_to_ground_type
            elseif type == "linked-belt" then
                ext.linked_belt_type = belt.linked_belt_type
                if ext.linked_belt_type == 'output' then
                    belt_info.direction =
                        tools.get_opposite_direction(belt_info.direction)
                end

                ---@type any
                local linked_belt_neighbour = belt.linked_belt_neighbour
                if linked_belt_neighbour and linked_belt_neighbour.valid then
                    if info.entity_map[linked_belt_neighbour.unit_number] then
                        linked_belt_neighbour =
                            linked_belt_neighbour.unit_number
                    end
                    ext.linked_belt_neighbour = linked_belt_neighbour
                end
                ext.apply = linke_belt_apply
            end
            local lines
            for line_index = 1, belt.get_max_transport_line_index() do
                local transport_line = belt.get_transport_line(line_index)
                if transport_line then
                    local contents = transport_line.get_contents()
                    if contents and table_size(contents) > 0 then
                        if not lines then
                            lines = {}
                            ext.lines = lines
                        end
                        lines[line_index] = contents
                    end
                end
            end
        end
    end

    for _, belt in pairs(info.belts) do belt.destroy() end

    return belt_infos
end

---@param info Teleporter
---@param dx integer
---@param dy integer
function Teleporter.teleport(info, dx, dy)
    if not info.entities then return end

    local compare = Teleporter.get_compare_func(dx, dy)

    local rotation_offset = 2 * info.rotation
    local rail_infos = {}
    for _, rail in pairs(info.rails) do
        local position = rail.position
        if info.rotation ~= 0 then
            position = Teleporter.rotate_point(info, position)
        end
        local railInfo = {
            position = { position.x + dx, position.y + dy },
            name = rail.name,
            direction = (rail.direction + rotation_offset) % 8,
            force = rail.force
        }
        table.insert(rail_infos, railInfo)
        rail.destroy()
    end

    local belt_infos = Teleporter.destroy_belts(info, dx, dy)

    ---@type LuaEntity[]
    local entities = {}

    for _, entity in pairs(info.entities) do
        if entity.valid and not rail_types[entity.type] then
            table.insert(entities, entity)
        end
    end
    table.sort(entities, compare)

    if next(preteleport_methods_by_name) then
        for _, entity in pairs(entities) do
            local call = preteleport_methods_by_name[entity.name]
            if call then
                remote.call(call.interface, call.method, entity)
            end
        end
    end

    for _, entity in pairs(entities) do
        local position = entity.position
        if rotation_offset ~= 0 then
            position = Teleporter.rotate_point(info, position)
        end
        local x = position.x + dx
        local y = position.y + dy

        local proto = entity.prototype
        local old_direction = entity.direction
        local direction = (old_direction + rotation_offset) % 8

        if not proto.flags["placeable-off-grid"] then
            if direction == 2 or direction == 6 then
                if proto.tile_height % 2 == 0 then
                    x = math.floor(x)
                else
                    x = math.floor(x) + 0.5
                end
                if proto.tile_width % 2 == 0 then
                    y = math.floor(y)
                else
                    y = math.floor(y) + 0.5
                end
            else
                if proto.tile_width % 2 == 0 then
                    x = math.floor(x)
                else
                    x = math.floor(x) + 0.5
                end
                if proto.tile_height % 2 == 0 then
                    y = math.floor(y)
                else
                    y = math.floor(y) + 0.5
                end
            end
        end

        if rotation_offset ~= 0 then entity.direction = direction end
        entity.teleport({ x, y }, nil, true)

        local call = teleport_methods_by_name[entity.name]
        if call then
            remote.call(call.interface, call.method, {
                entity = entity,
                old_pos = position,
                old_direction = old_direction
            })
        end

        local calls = teleport_methods_by_type[entity.type]
        if calls then
            for _, call in pairs(calls) do
                remote.call(call.interface, call.method, {
                    entity = entity,
                    old_pos = position,
                    old_direction = old_direction
                })
            end
        end
    end

    for _, rail_info in pairs(rail_infos) do
        info.surface.create_entity(rail_info)
    end

    for _, belt_info in pairs(belt_infos) do
        local ext = belt_info.ext
        belt_info.ext = nil
        local entity = info.surface.create_entity(belt_info)
        info.entity_map[ext.unit_number] = entity
        belt_info.ext = ext
    end

    for _, belt_info in pairs(belt_infos) do
        local ext = belt_info.ext
        if ext.apply then ext.apply(info, ext) end
    end

    ---@type LuaEntity
    for _, entity in pairs(entities) do
        if entity.valid then entity.update_connections() end
    end

    -- items back
    for _, belt_info in pairs(belt_infos) do
        local ext = belt_info.ext
        if ext.lines then
            local belt = info.entity_map[ext.unit_number]
            for line_index, contents in pairs(ext.lines) do
                local transport_line = belt.get_transport_line(line_index)
                local pos = 0
                for item, count in pairs(contents) do
                    local stack = { name = item, count = 1 }
                    for i = 1, count do
                        if not transport_line.insert_at(pos, stack) then
                            --tools.set_tracing(true)
                            --debug("Failed")
                        end
                        pos = pos + 0.25
                    end
                end
            end
        end
    end
end

function Teleporter.check_connection(info)
    local surface = info.surface
    for _, entity in pairs(info.entities) do
        if entity.valid then
            -- local neighbours = copper_wire_types[entity.type] and entity.neighbours or entity.circuit_connected_entities
            local connections = entity.circuit_connection_definitions
            if connections then
                for _, connection in pairs(connections) do
                    if connection.target_entity.surface == surface and
                        not entity.can_wires_reach(connection.target_entity) then
                        entity.disconnect_neighbour(connection)
                    end
                end
            end
            if entity.type == "electric-pole" then
                local neighbours = entity.neighbours and
                    entity.neighbours.copper
                if neighbours then
                    for wire_type, n in pairs(neighbours) do
                        if wire_type == 'copper' and n.surface == surface and
                            not entity.can_wires_reach(n) then
                            entity.disconnect_neighbour(n)
                        end
                    end
                end
            end
        end
    end
end

---@param info Teleporter
---@param dx integer
---@param dy integer
function Teleporter.move_tiles(info, dx, dy)
    if not info.tile_map then return end
    local surface = info.surface
    local proto = info.proto
    local tiles_to_set = {}

    local tiles = {}
    for _, tile in pairs(info.tile_map) do
        if tile.valid then table.insert(tiles, tile) end
    end

    local compare = Teleporter.get_compare_func(dx, dy)
    table.sort(tiles, compare)

    for _, tile in pairs(tiles) do
        local pos = tile.position
        local x = pos.x + dx
        local y = pos.y + dy
        local previous_tile = surface.get_tile(x, y)
        if previous_tile then
            local previous_name = previous_tile.prototype.name
            if previous_tile.prototype.mineable_properties.minable then end
        end
        table.insert(tiles_to_set, { position = { x, y }, name = proto })
        table.insert(tiles_to_set,
            { position = { pos.x, pos.y }, name = tile.hidden_tile })
    end

    if #tiles_to_set > 0 then surface.set_tiles(tiles_to_set) end
end

---@param info Teleporter
---@param dx integer
---@param dy integer
function Teleporter.check_collision(info, dx, dy)
    local surface = info.surface
    local failed = false
    for _, entity in pairs(info.entities) do
        if entity.valid then
            local position = entity.position
            if info.rotation ~= 0 then
                position = Teleporter.rotate_point(info, position)
            end
            position = { position.x + dx, position.y + dy }
            if entity.name == "entity-ghost" then
                return true
            elseif not surface.can_place_entity {
                    name = entity.name,
                    force = entity.force,
                    position = position,
                    direction = (entity.direction + 2 * info.rotation) % 8
                } then
                local bb = entity.bounding_box
                bb = {
                    { bb.left_top.x + dx,     bb.left_top.y + dy },
                    { bb.right_bottom.x + dx, bb.right_bottom.y + dy }
                }
                local collidings = surface.find_entities_filtered { area = bb }
                for _, colliding in pairs(collidings) do
                    if not collision_unrestricted_types[colliding.type] then
                        if colliding.unit_number and
                            not info.entity_map[colliding.unit_number] then
                            failed = true
                            rendering.draw_circle {
                                surface = surface,
                                color = { 1, 0, 0 },
                                target = colliding.position,
                                radius = 0.2,
                                time_to_live = 120,
                                filled = true
                            }
                        end
                    end
                end
            end
        end
    end
    return failed
end

---@param e EventData.CustomInputEvent
local function on_teleport(e)
    local player = game.players[e.player_index]
    local vars = tools.get_vars(player)
    local info = vars.info --[[@as Teleporter]]
    if not info then return end

    local position = player.position
    local dx = math.floor(position.x - info.start_pos.x) + info.move_x
    local dy = math.floor(position.y - info.start_pos.y) + info.move_y
    if dx == 0 and dy == 0 then return end
    if #info.rails > 0 then
        dx = 2 * math.floor(dx / 2)
        dy = 2 * math.floor(dy / 2)
    end

    if Teleporter.check_collision(info, dx, dy) then
        player.print({ prefix .. "-message.collision" }, { 1, 0, 0 })
        return
    end

    Teleporter.teleport(info, dx, dy)
    -- bplayer.teleport({ info.start_pos.x + dx - info.move_x, info.start_pos.y + dy - info.move_y })
    Teleporter.move_tiles(info, dx, dy)
    Teleporter.check_connection(info)
    Teleporter.end_teleport(e.player_index)
end

---@param e EventData.CustomInputEvent
local function on_end_teleport(e) Teleporter.end_teleport(e.player_index) end

script.on_event(prefix .. "-start_teleport", start_teleport)
script.on_event(prefix .. "-escape", on_end_teleport)
tools.on_gui_click(prefix .. "-bteleport", on_teleport)
tools.on_gui_click(prefix .. "-bcancel", on_end_teleport)
tools.on_event(defines.events.on_player_changed_surface, on_end_teleport)

--------------------------------

---@param event EventData.on_player_selected_area
local function on_player_selected_area(event)
    local player = game.players[event.player_index]

    if event.item ~= prefix .. "-selection_tool" then return end

    local vars = tools.get_vars(player)
    --- @type Teleporter
    local info = vars.info
    local entities = event.entities
    local start_pos = player.position

    if not info then
        ---@type Teleporter
        info = {
            start_pos = start_pos,
            previous_dx = 0,
            previous_dy = 0,
            surface = player.surface,
            move_x = 0,
            move_y = 0,
            rotation = 0
        }

        vars.info = info
    else
        Teleporter.clear_display_entities(info)
        info.previous_dx = 0
        info.previous_dy = 0
        info.start_pos = start_pos
    end

    if not Teleporter.add_entities(info, entities) or table_size(info.entities) ==
        0 then
        Teleporter.end_teleport(event.player_index)
        player.print({ prefix .. "-message.cannot_move_train" })
        return
    end
    Teleporter.display_entities(info)
    Teleporter.create_frame(player)
end

---@param event EventData.on_player_selected_area
local function on_player_alt_selected_area(event)
    local player = game.players[event.player_index]

    if event.item ~= prefix .. "-selection_tool" then return end

    local vars = tools.get_vars(player)
    --- @type Teleporter
    local info = vars.info
    if not info then return end

    local entities = event.entities
    Teleporter.clear_display_entities(info)
    Teleporter.remove_entities(info, entities)
    Teleporter.display_entities(info)
end

tools.on_event(defines.events.on_player_selected_area, on_player_selected_area)
tools.on_event(defines.events.on_player_alt_selected_area,
    on_player_alt_selected_area)

---@param info Teleporter
---@return integer
local function get_delta(info) return #info.rails > 0 and 2 or 1 end

---@param player LuaPlayer
---@return Teleporter?
function Teleporter.create_from_selected(player)
    local selected = player.selected
    if not selected then return nil end
    if is_forbidden(selected) then return nil end
    if not is_allowed(selected) then return nil end

    local vars = tools.get_vars(player)
    local entities = { selected }
    local start_pos = player.position

    ---@type Teleporter
    local info = {
        start_pos = start_pos,
        previous_dx = 0,
        previous_dy = 0,
        surface = player.surface,
        move_x = 0,
        move_y = 0,
        rotation = 0
    }

    vars.info = info
    if not Teleporter.add_entities(info, entities) or table_size(info.entities) ==
        0 then
        Teleporter.end_teleport(player.index)
        player.print({ prefix .. "-message.cannot_move_train" })
        return nil
    end
    Teleporter.display_entities(info)
    Teleporter.create_frame(player)
    return info
end

--- @param e EventData.on_lua_shortcut
script.on_event(prefix .. "-north", function(e)
    local player = game.players[e.player_index]

    --- @type Teleporter?
    local info
    info = tools.get_vars(player).info
    if not info then
        info = Teleporter.create_from_selected(player)
        if not info then return end
    end

    info.move_y = info.move_y - get_delta(info)
    Teleporter.update_position(info, player)
end)

--- @param e EventData.on_lua_shortcut
script.on_event(prefix .. "-south", function(e)
    local player = game.players[e.player_index]

    --- @type Teleporter?
    local info
    info = tools.get_vars(player).info
    if not info then
        info = Teleporter.create_from_selected(player)
        if not info then return end
    end

    info.move_y = info.move_y + get_delta(info)
    Teleporter.update_position(info, player)
end)

--- @param e EventData.on_lua_shortcut
script.on_event(prefix .. "-west", function(e)
    local player = game.players[e.player_index]

    --- @type Teleporter?
    local info
    info = tools.get_vars(player).info
    if not info then
        info = Teleporter.create_from_selected(player)
        if not info then return end
    end

    info.move_x = info.move_x - get_delta(info)
    Teleporter.update_position(info, player)
end)

--- @param e EventData.on_lua_shortcut
script.on_event(prefix .. "-east", function(e)
    local player = game.players[e.player_index]

    --- @type Teleporter?
    local info
    info = tools.get_vars(player).info
    if not info then
        info = Teleporter.create_from_selected(player)
        if not info then return end
    end

    info.move_x = info.move_x + get_delta(info)
    Teleporter.update_position(info, player)
end)

script.on_event(prefix .. "-enter", --- @param e EventData.CustomInputEvent
    function(e)
        local player = game.players[e.player_index]

        --- @type Teleporter?
        local info
        info = tools.get_vars(player).info
        if not info then
            info = Teleporter.create_from_selected(player)
            if not info then return end
        end

        on_teleport(e)
    end)

--- @param e EventData.on_lua_shortcut
script.on_event(prefix .. "-rotate", function(e)
    local player = game.players[e.player_index]

    --- @type Teleporter
    local info
    info = tools.get_vars(player).info
    if not info then return end
    if not info.rotatable then
        player.print({ "factory_organizer-message.cannot_rotate" })
        return
    end

    info.rotation = (info.rotation + 1) % 4
    info.matrix = rotation_matrix[info.rotation + 1]

    Teleporter.clear_display_entities(info)
    Teleporter.display_entities(info)
    local dx = info.previous_dx
    local dy = info.previous_dy
    info.previous_dx = 0
    info.previous_dy = 0
    Teleporter.move_entities(info, dx, dy)
end)

---@param names string[]
function Teleporter.add_forbidden(names)
    for _, name in pairs(names) do forbidden_names[name] = true end
end

---@param names string[]
function Teleporter.add_not_moveable(names)
    for _, name in pairs(names) do not_moveable_names[name] = true end
end

---@param name string
---@param interface string
---@param method string
function Teleporter.add_collect_method(name, interface, method)
    collect_methods_by_name[name] = { interface = interface, method = method }
end

---@param name string
---@param interface string
---@param method string
function Teleporter.add_teleport_method(name, interface, method)
    teleport_methods_by_name[name] = { interface = interface, method = method }
end

---@param name string
---@param interface string
---@param method string
function Teleporter.add_preteleport_method(name, interface, method)
    preteleport_methods_by_name[name] = { interface = interface, method = method }
end

---@param call_table table<string, {interface:string, method:string}[]>
---@param name string
---@param interface string
---@param method string
local function table_insert_call(call_table, name, interface, method)
    local calls = call_table[name]
    if not calls then
        calls = {}
        call_table[name] = calls
    else
        for _, call in pairs(calls) do
            if call.interface == interface and call.method == method then
                return
            end
        end
    end
    table.insert(calls, { interface = interface, method = method })
end

---@param name string
---@param interface string
---@param method string
function Teleporter.add_collect_method_by_type(name, interface, method)
    table_insert_call(collect_methods_by_type, name, interface, method)
end

---@param name string
---@param interface string
---@param method string
function Teleporter.add_teleport_method_by_type(name, interface, method)
    table_insert_call(teleport_methods_by_type, name, interface, method)
end

remote.add_interface("factory_organizer", {
    add_forbidden = Teleporter.add_forbidden,
    add_not_moveable = Teleporter.add_not_moveable,
    add_collect_method = Teleporter.add_collect_method,
    add_collect_method_by_type = Teleporter.add_collect_method_by_type,
    add_teleport_method = Teleporter.add_teleport_method,
    add_teleport_method_by_type = Teleporter.add_teleport_method_by_type,
    add_preteleport_method = Teleporter.add_preteleport_method,
})
