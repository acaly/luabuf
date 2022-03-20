local luabuf = {}
luabuf.options = {}
luabuf.options.magic_seed = 0x12345678 -- TODO
luabuf.options.buffer_offset_size = 4

function luabuf.create_primitive_type(size, id, table)
    -- TODO
    -- check size (power of 2)
    -- check id (alphabet first char, not empty)
    table = table or {}
    table.kind = "primitive"
    table.primitive_id = id
    table.primitive_size = size
    return table
end

function luabuf.create_struct_type(fields, table)
    -- TODO
    -- check fields (array-like, valid entries with name and type)
    -- don't check field type for now (check when calculating layout)
    table = table or {}
    table.kind = "struct"
    table.struct_fields = fields
    return table
end

function luabuf.create_enum_type(value_type, values, table)
    -- TODO
    -- check value_type valid primitive type
    -- check values array-like, valid entries with name and value (number)
    -- don't check value type for now (check when calculating layout)
    table = table or {}
    table.kind = "enum"
    table.enum_values = values
    table.enum_value_type = value_type
    return table
end

function luabuf.create_class_type(base_type, fields, table)
    -- TODO
    -- check base_type nil or another virtual type (only check table for now, see below)
    -- check fields (see struct fields)
    -- don't check field type for now (check when calculating layout)
    table = table or {}
    table.kind = "class"
    table.class_base = base_type
    table.class_fields = fields
    return table
end

-- TODO
-- make_ref_type(target)
-- make_map_type(k, v)

function luabuf.make_array_type(element_type)
    return { kind = "array", array_element_type = element_type }
end

function luabuf.create_scheme()
    local scheme = {}
    scheme.types =
    {
        char8 = luabuf.create_primitive_type(1, "char8"),
        char16 = luabuf.create_primitive_type(2, "char16"),

        int8 = luabuf.create_primitive_type(1, "int8"),
        uint8 = luabuf.create_primitive_type(1, "uint8"),
        int16 = luabuf.create_primitive_type(2, "int16"),
        uint16 = luabuf.create_primitive_type(2, "uint16"),
        int32 = luabuf.create_primitive_type(4, "int32"),
        uint32 = luabuf.create_primitive_type(4, "uint32"),
        int64 = luabuf.create_primitive_type(8, "int64"),
        uint64 = luabuf.create_primitive_type(8, "uint64"),

        float32 = luabuf.create_primitive_type(4, "float32"),
        float64 = luabuf.create_primitive_type(8, "float64"),
    }

    scheme.types.string8 = luabuf.make_array_type(scheme.types.char8)
    scheme.types.string16 = luabuf.make_array_type(scheme.types.char16)

    return scheme
end

function luabuf.calc_layout(scheme, root_name)
    -- TODO
    -- check data when processing

    local ret =
    {
        primitive_types = {},
        --enum_types = {}, --TODO set_element_indices
        struct_types = {},
        class_types = {},
        --array_types = {}, --TODO set_element_indices
        --map_types = {}, --TODO set_element_indices
    }

    local buffer_offset_size = luabuf.options.buffer_offset_size
    local type_namerevmap = {}
    local loading_tasks = {}
    local known_type_info = {}
    for k, v in pairs(scheme.types) do
        type_namerevmap[v] = k
    end

    local function find_type_name(type, referee)
        local ret = type_namerevmap[type]
        if not ret then
            if string.len(referee) > 0 and string.sub(referee, -1) ~= " " then
                referee = referee .. " "
            end
            error("the type of " .. referee .. "(" .. type.kind .. ") is not in the scheme")
        end
        return ret
    end

    local function apply_alignment(offset, alignment, referee_name)
        if alignment & (alignment - 1) ~= 0 then
            error("invalid alignment in " .. referee_name)
        end
        return (offset + alignment - 1) & ~(alignment - 1)
    end

    local process_type = nil

    local function calc_fields(fields, type_name, type_referee)
        local ret_fields = {}
        local struct_size, struct_alignement = 0, 1
        for _, field in ipairs(fields) do
            local referee_name = type_name .. "." .. field.name .. ", referenced by " .. type_referee
            local field_type_name = find_type_name(field.type, referee_name)
            local loaded_type = known_type_info[field_type_name]
            if not loaded_type then
                loaded_type = process_type(field.type, referee_name, false, true)
            end
            local size, alignment = loaded_type.size, loaded_type.alignment
            if not size or not alignment then
                error("cyclic dependency in scheme, when processing " .. referee_name)
            end

            struct_size = apply_alignment(struct_size, alignment, referee_name)
            table.insert(ret_fields, { name = field.name, offset = struct_size, type = loaded_type })
            struct_size = struct_size + size
            struct_alignement = math.max(struct_alignement, alignment)
        end

        -- TODO
        -- consider reorder struct fields (use a shared function with class types)

        return ret_fields, struct_size, struct_alignement
    end

    process_type = function(type, referee, set_root, preload)
        if type.kind == "primitive" then
            if preload then
                local type_name = find_type_name(type, referee)
                local primitive_info = {
                    name = type.primitive_id,
                    kind = "primitive",
                    size = type.primitive_size,
                    alignment = type.primitive_size,
                    primitive_id = type.primitive_id,
                }
                known_type_info[type_name] = primitive_info
                table.insert(ret.primitive_types, primitive_info)

                if set_root then
                    ret.root = primitive_info
                end
                return primitive_info
            else
                return
            end
        elseif type.kind == "struct" then
            if preload then
                local type_name = find_type_name(type, referee)
                local struct_info = {
                    name = type_name,
                    kind = "struct",
                }
                known_type_info[type_name] = struct_info
                
                local f, s, a = calc_fields(type.struct_fields, type_name, referee)
                struct_info.fields = f
                struct_info.size = s
                struct_info.alignment = a

                table.insert(ret.struct_types, struct_info)

                if set_root then
                    ret.root = struct_info
                end
                return struct_info
            else
                return
            end
        elseif type.kind == "class" then
            if preload then
                local type_name = find_type_name(type, referee)
                local class_info = {
                    name = type_name,
                    kind = "class",
                    size = buffer_offset_size,
                    alignment = buffer_offset_size,
                }
                known_type_info[type_name] = class_info
                table.insert(ret.class_types, class_info)

                -- queue load
                table.insert(loading_tasks, { type, referee, set_root })

                if set_root then
                    ret.root = class_info
                end
                return class_info
            else
                local type_name = find_type_name(type, referee)
                local class_info = known_type_info[type_name]

                local f, s, a = calc_fields(type.class_fields, type_name, referee)
                class_info.fields = f
                class_info.class_size = s
                class_info.class_alignment = a

                -- TODO
                -- load derived classes
            end
        else
            -- TODO
            -- for class types, preload only adds the task, actual loading is when preload == false
            -- note that for array/map/ref types, we should not use type_namerevmap
            error("unsupported type " .. referee)
        end
    end

    -- preload root type
    process_type(scheme.types[root_name], "root", true, true)
    -- finish loading all types
    while #loading_tasks > 0 do
        process_type(table.unpack(table.remove(loading_tasks)))
    end

    -- TODO
    -- sort types

    -- TODO
    -- calculate magic based on types
    local magic = 0
    ret.magic = magic & 0xFFFFFFFF

    -- calculate index for each type to help template generation
    local function set_element_indices(array)
        for i, v in ipairs(array) do
            v.index = i
        end
    end
    set_element_indices(ret.primitive_types)
    set_element_indices(ret.struct_types)
    set_element_indices(ret.class_types)

    return ret
end

return luabuf
