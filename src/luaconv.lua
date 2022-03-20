local luaconv = {}
luaconv.options = {}
luaconv.options.buffer_size = 1000
luaconv.options.prolog = [[return function(data) local buffer = ""]]
luaconv.options.write_format = "buffer = buffer .. (%s) "
luaconv.options.epilog = "return buffer end"

-- TODO
-- for cpp syntax, `/*#= data.class_name &*/ _CLASS_NAME_ /*#&*/` is not handled correctly

function luaconv.create_string_reader(string)
    local reader = {}
    local pos = 1
    local string_len = string.len(string)
    function reader:read(pattern)
        if pos > string_len then
            return nil
        end
        if type(pattern) == "number" and pattern >= 0 then
            local read_len = math.min(pattern, string_len - pos + 1)
            local ret = string.sub(string, pos, read_len)
            pos = pos + read_len
            return ret
        elseif pattern == "*all" then
            local ret = string.sub(string, pos)
            pos = string_len + 1
            return ret
        else
            error("unsupported pattern")
        end
    end
    return reader
end

function luaconv.create_string_writer()
    local result = ""
    local ret = {}
    function ret:write(str)
        result = result .. str
    end
    function ret:get_string()
        return result
    end
    return ret
end

-- TODO
-- check whether we should change string.len(str) to str:len()

local function create_output_builder(stream, value_mode_char, suspension_char, write_format)
    local builder = {}
    local buffer = ""
    local suspension_remaining = false

    -- nil: content, false: lua statement block, true: lua value block
    local value_lua_mode = nil

    function builder:write_raw(str)
        stream:write(str)
    end
    function builder:flush_content()
        if string.len(buffer) > 0 then
            self:write_raw(string.format(write_format, string.format("%q", buffer)))
        end
        buffer = ""
    end
    function builder:append_content(str)
        if value_lua_mode then
            self:write_raw(string.format(write_format, buffer))
            buffer = ""
        end
        value_lua_mode = nil
        if suspension_remaining then
            return
        end
        buffer = buffer .. str
    end
    function builder:append_code(str)
        if value_lua_mode == nil then
            self:flush_content()
        end
        if string.len(str) == 0 then
            -- an empty Lua block, or an empty segment after a buffer-split
            -- the only thing to do is to clear suspension_remaining if it's the first case (empty Lua block)
            if value_lua_mode == nil then
                suspension_remaining = false
            end
            return
        end

        -- update suspension flag
        if suspension_remaining then
            self:write_raw(suspension_char)
            suspension_remaining = false
        end
        if string.sub(str, -1) == suspension_char then
            suspension_remaining = true
            str = string.sub(str, 1, -2)
        end

        -- first segment in this block
        -- check value_mode_char and set value_lua_mode
        if value_lua_mode == nil then
            if string.sub(str, 1, 1) == value_mode_char then
                value_lua_mode = true
                str = string.sub(str, 2)
            else
                value_lua_mode = false
            end
        end

        if value_lua_mode then
            -- value block
            buffer = buffer .. str
        else
            -- statement block
            self:write_raw(str)
        end
    end
    function builder:finish(is_in_lua)
        -- must finish with a content block
        -- note that content block finalizes the Lua value block
        if is_in_lua then
            error("unexpected EOS in Lua block")
        end
        self:flush_content()
    end
    return builder
end

function luaconv.compile(input_stream, left_mark, right_mark, value_mode_char, suspension_char, output_stream)
    -- TODO
    -- check arguments (valid strings)
    if string.len(suspension_char) ~= 1 then
        error("suspension char must be 1 char")
    end

    local is_in_lua = false
    local buffer_size = luaconv.options.buffer_size
    local output_builder = create_output_builder(output_stream, value_mode_char, suspension_char, luaconv.options.write_format)
    local buffer = ""

    -- we use buffer_keep_end_len == 0 to indicate EOS, so ensure it's not zero here
    local buffer_keep_end_len = math.max(2, string.len(left_mark), string.len(right_mark)) - 1
    local min_process_len = buffer_size + buffer_keep_end_len

    local function fill_buffer()
        while string.len(buffer) < min_process_len do
            local read = input_stream:read(buffer_size);
            if not read then
                buffer_keep_end_len = 0
                return
            end
            buffer = buffer .. read
        end
    end

    output_builder:append_code(luaconv.options.prolog)

    while buffer_keep_end_len ~= 0 do
        fill_buffer()
        local buffer_len = string.len(buffer)
        local buffer_offset = 1
        while buffer_offset <= buffer_len - buffer_keep_end_len do
            local current_block_last = buffer_len - buffer_keep_end_len
            local next_block_first = current_block_last + 1

            local find_first, find_last = string.find(buffer, is_in_lua and right_mark or left_mark, buffer_offset, true)
            if find_first then
                if find_first > current_block_last then
                    -- ignore matches after the current_block_last
                    -- this will cause problem in determining how much to keep
                    -- it may happen when length of left_mark and right_mark are different
                    find_first = nil
                else
                    current_block_last = find_first - 1
                    next_block_first = find_last + 1
                end
            end

            if is_in_lua then
                output_builder:append_code(string.sub(buffer, buffer_offset, current_block_last))
            else
                output_builder:append_content(string.sub(buffer, buffer_offset, current_block_last))
            end
            if find_first then
                is_in_lua = not is_in_lua
            end

            buffer_offset = next_block_first
        end -- buffer scan loop

        buffer = string.sub(buffer, math.max(buffer_offset, buffer_len - buffer_keep_end_len + 1))
    end -- stream read loop
    
    output_builder:append_code(luaconv.options.epilog)
    output_builder:finish(is_in_lua)
end

return luaconv
