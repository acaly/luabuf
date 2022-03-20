package.path = "./../src/?.lua;" .. package.path

luabuf = require("luabuf");
luaconv = require("luaconv")

-- create scheme

local scheme = luabuf.create_scheme()
local vector2 = luabuf.create_struct_type({
    { name = "X", type = scheme.types.float32 },
    { name = "Y", type = scheme.types.float32 },
})
local controller = luabuf.create_class_type(nil, {
    { name = "ParameterA", type = scheme.types.float64 },
})
local entity = luabuf.create_struct_type({
    { name = "Id", type = scheme.types.int64 },
    --{ name = "Controller", type = controller },
    { name = "Pos", type = vector2 },
    { name = "Vel", type = vector2 },
})
scheme.types["Vector2"] = vector2
scheme.types["Controller"] = controller
scheme.types["Entity"] = entity

-- compile scheme

local compiled_scheme = luabuf.calc_layout(scheme, "Entity")

print("root: " .. compiled_scheme.root.kind .. " #" .. compiled_scheme.root.index)

for i, t in ipairs(compiled_scheme.primitive_types) do
    print(string.format("%s #%d: %s (%s), size = %d", t.kind, i, t.name, t.primitive_id, t.size))
end
for i, t in ipairs(compiled_scheme.struct_types) do
    print(string.format("%s #%d: %s, size = %d, alignment = %d", t.kind, i, t.name, t.size, t.alignment))
end
for i, t in ipairs(compiled_scheme.class_types) do
    print(string.format("%s #%d: %s, data size = %d, data alignment = %d", t.kind, i, t.name, t.class_size, t.class_alignment))
end
print()

-- generate template

local output = luaconv.create_string_writer()
luaconv.compile(io.open("./../src/cpp/template.h"), "/*#", "*/", "=", "&", output)
local template_str = output.get_string()

print("template: ")
print("=================================")
do
    local print_template_str = template_str:gsub("\r\n", "\n"):gsub("\r", "\n")
    local i = 1
    local l = 1
    while i <= string.len(print_template_str) do
        local line_break = string.find(print_template_str, "\n", i, true)
        if not line_break then
            line_break = string.len(print_template_str) + 1
        end
        print(l, string.sub(print_template_str, i, line_break - 1))
        i = line_break + 1
        l = l + 1
    end
end
print("=================================")

local func_template = load(template_str)()

print("generated code: ")
print("=================================")
local result_str = func_template({ compiled_scheme = compiled_scheme })
print(result_str)
print("=================================")

local result_output = io.open("output.h", "w+")
result_output:write(result_str)
result_output:close()

print("result saved to output.h")
