#pragma once
#include <cstdint>

namespace LuaBuf
{/*#
    if false then
*/
    namespace CompilerTypes
    {
        struct FieldType
        {
            int IntFieldName;
        };
        struct FieldTypeAccessor
        {
            static int GetIntFieldName() { return {}; }
            static void SetIntFieldName(int value) {}
        };

        struct StructType
        {
            FieldType FieldName;
        };
        struct StructTypeAccessor
        {
            StructTypeAccessor(StructType* obj) {}

            using FieldNameGetter = FieldTypeAccessor;
            static FieldNameGetter GetFieldNameGetter() { return {}; }

            using FieldNameSetter = FieldTypeAccessor;
            static FieldNameSetter GetFieldNameSetter() { return {}; }
        };

        class ClassType
        {
        public:
            FieldType FieldName;
        };
        struct ClassTypeAccessor
        {
            ClassTypeAccessor(ClassType* obj) {}

            using FieldNameGetter = FieldTypeAccessor;
            static FieldNameGetter GetFieldNameGetter() { return {}; }

            using FieldNameSetter = FieldTypeAccessor;
            static FieldNameSetter GetFieldNameSetter() { return {}; }
        };
    }/*#
    end

    --[[ define standard name for primitive types ]]

    local primitive_type_names =
    {
        char8 = "char",
        char16 = "std::uint16_t",
        int8 = "std::int8_t",
        uint8 = "std::uint8_t",
        int16 = "std::int16_t",
        uint16 = "std::uint16_t",
        int32 = "std::int32_t",
        uint32 = "std::uint32_t",
        int64 = "std::int64_t",
        uint64 = "std::uint64_t",
        float32 = "float",
        float64 = "double",
    }

    --=====================================================================
    --[[ buffer getters that are used in deserialization ]]
    --=====================================================================

    local function get_single_buffer_field_getter_name(type)
        return "SingleBufferGetter_" .. type.name
    end

    local function generate_single_buffer_field_getter1(type, fields)
        local getter_name = get_single_buffer_field_getter_name(type)
    */
    struct /*#= getter_name &*/SingleBufferGetter_StructType/*#*/;/*#
    end

    local function generate_single_buffer_field_getter2(type, fields)
        local getter_name = get_single_buffer_field_getter_name(type)
    */
    struct /*#= getter_name &*/SingleBufferGetter_StructType/*#*/
    {
    private:
        const void* const _ptr;
    public:
        /*#= getter_name &*/SingleBufferGetter_StructType/*#*/(const void* ptr) : _ptr(ptr) {}

    public:/*#
        for _, field in ipairs(fields) do
            if field.type.kind == "primitive" then
                local cpp_type_name = primitive_type_names[field.type.name]
    */
        inline /*#= cpp_type_name &*/int/*#*/ /*#= "Get" .. field.name &*/GetFieldName/*#*/() const;/*#
            elseif field.type.kind == "struct" then
    */
        using /*#= field.name .. "Getter" &*/FieldNameGetter/*#*/ = /*#= get_single_buffer_field_getter_name(field.type) &*/CompilerTypes::FieldTypeAccessor/*#*/;
        inline /*#= get_single_buffer_field_getter_name(field.type) &*/CompilerTypes::FieldTypeAccessor/*#*/ /*#= "Get" .. field.name .. "Getter" &*/GetFieldNameGetter/*#*/() const;/*#
            elseif field.type.kind == "class" then
    *//*#
            else
                error("unknown field type")
            end
        end
    */
    };
    /*#
    end

    local function generate_single_buffer_field_getter3(type, fields)
        local getter_name = get_single_buffer_field_getter_name(type)
        for _, field in ipairs(fields) do
            if field.type.kind == "primitive" then
                local cpp_type_name = primitive_type_names[field.type.name]
    */
    /*#= cpp_type_name &*/int/*#*/ /*#= getter_name &*/SingleBufferGetter_StructType/*#*/::/*#= "Get" .. field.name &*/GetFieldName/*#*/() const
    {
        return *(/*#= cpp_type_name &*/int/*#*/*)(/*#= field.offset &*/0/*#*/ + (char*)_ptr);
    }
    /*#
            elseif field.type.kind == "struct" then
    */
    /*#= get_single_buffer_field_getter_name(field.type) &*/CompilerTypes::FieldTypeAccessor/*#*/ /*#= getter_name &*/SingleBufferGetter_StructType/*#*/::/*#= "Get" .. field.name .. "Getter" &*/GetFieldNameGetter/*#*/() const
    {
        return { /*#= field.offset &*/0/*#*/ + (char*)_ptr };
    }
    /*#
            elseif field.type.kind == "class" then
    *//*#
            else
                error("unknown field type")
            end
        end
    end

    do
        local getter_tasks = {}
        for _, type in ipairs(data.compiled_scheme.struct_types) do
            table.insert(getter_tasks, { type, type.fields })
        end
        for _, type in ipairs(data.compiled_scheme.class_types) do
            table.insert(getter_tasks, { type, type.fields })
        end

        for _, task in ipairs(getter_tasks) do
            generate_single_buffer_field_getter1(table.unpack(task))
        end
        for _, task in ipairs(getter_tasks) do
            generate_single_buffer_field_getter2(table.unpack(task))
        end
        for _, task in ipairs(getter_tasks) do
            generate_single_buffer_field_getter3(table.unpack(task))
        end
    end

    --=====================================================================
    --[[ copy helper for each type ]]
    --=====================================================================

    local function get_copy_helper_name(type)
        return "CopyHelper_" .. type.name
    end

    local function generate_copy_helper1(type, fields)
        local helper_name = get_copy_helper_name(type)
    */
    struct /*#= helper_name &*/CopyHelper_StructType/*#*/
    {
        template <typename TGetter, typename TSetter, typename TSetterAllocator>
        inline static void Copy(TGetter getter, TSetter setter, TSetterAllocator allocator);
    };
    /*#
    end

    local function generate_copy_helper2(type, fields)
        local helper_name = get_copy_helper_name(type)
    */
    template <typename TGetter, typename TSetter, typename TSetterAllocator>
    static void /*#= helper_name &*/CopyHelper_StructType/*#*/::Copy(TGetter getter, TSetter setter, TSetterAllocator allocator)
    {/*#
        for _, field in ipairs(fields) do
            if field.type.kind == "primitive" then
                local getterMethod = "Get" .. field.name
                local setterMethod = "Set" .. field.name
    */
        {
            setter./*#= setterMethod &*/SetFieldName/*#*/(getter./*#= getterMethod &*/GetFieldName/*#*/());
        }/*#
            elseif field.type.kind == "struct" then
                local getterMethod = "Get" .. field.name .. "Getter"
                local setterMethod = "Get" .. field.name .. "Setter"
    */
        {
            using FieldGetter = typename TGetter::/*#= field.name .. "Getter" &*/FieldNameGetter/*#*/;
            using FieldSetter = typename TSetter::/*#= field.name .. "Setter" &*/FieldNameSetter/*#*/;
            using FieldCopy = /*#= get_copy_helper_name(field.type) &*/CopyHelper_FieldType/*#*/;
            FieldCopy::Copy<FieldGetter, FieldSetter, TSetterAllocator>(getter./*#= getterMethod &*/GetFieldNameGetter/*#*/(), setter./*#= setterMethod &*/GetFieldNameSetter/*#*/(), allocator);
        }/*#
            else
                error("unsupported field type")
            end
        end
    */
    }
    /*#
    end

    do
        local copy_tasks = {}
        for _, type in ipairs(data.compiled_scheme.struct_types) do
            table.insert(copy_tasks, { type, type.fields })
        end
        for _, type in ipairs(data.compiled_scheme.class_types) do
            table.insert(copy_tasks, { type, type.fields })
        end

        for _, task in ipairs(copy_tasks) do
            generate_copy_helper1(table.unpack(task))
        end
        for _, task in ipairs(copy_tasks) do
            generate_copy_helper2(table.unpack(task))
        end
    end


    --=====================================================================
    
    --[[ global helpers ]]
    -- currently only allow one cpp type per serialized type
    local function get_cpp_type_name(type)
        return primitive_type_names[type.name] or type.name
    end

    --[[ define base classes used by serializer ]]

    if false then

    */
    template <typename T>
    struct DefaultSerializationHelper
    {
    };
    template <typename T>
    struct SerializationHelper : DefaultSerializationHelper<T>
    {
    };
    template <typename T>
    struct FieldSerializer
    {
    };/*#

    end
    
    --[[ specialization of FieldSerializer ]]

    local function generate_field_serializer(type, fields)
    */
    template <>
    struct FieldSerializer</*#= get_cpp_type_name(type) &*/CompilerTypes::StructType/*#*/>
    {/*#
        for _, field in ipairs(fields) do
        */
        template <typename TSerializationState, typename TSerializationPointer, typename TGetter>
        static void /*#= "Serialize" .. field.name &*/SerializeFieldName/*#*/(TSerializationState state, TSerializationPointer pointer, TGetter getter)
        {/*#
            if field.type.kind == "primitive" then
        */
            {
                using FieldType = /*#= get_cpp_type_name(field.type) &*/CompilerTypes::FieldType/*#*/;
                auto fieldPointer = state.OffsetPointer(pointer, /*#= field.offset &*/0/*#*/);
                state.SerializeValue<FieldType>(fieldPointer, getter./*#= "Get" .. field.name &*/GetFieldName/*#*/());
            }/*#
            elseif field.type.kind == "struct" then
            */
            {
                using FieldType = /*#= get_cpp_type_name(field.type) &*/CompilerTypes::FieldType/*#*/;
                using FieldGetter = TGetter::/*#= field.name .. "Getter" &*/FieldNameGetter/*#*/;
                auto fieldPointer = state.OffsetPointer(pointer, /*#= field.offset &*/0/*#*/);
                state.SerializeStruct<FieldType, FieldGetter>(fieldPointer, getter./*#= "Get" .. field.name .. "Getter" &*/GetFieldNameGetter/*#*/());
            }/*#
            elseif field.type.kind == "class" then
            */
            {
                throw 1;
            }/*#
            elseif field.type.kind == "array" then
                error("array fields are not supported")
            else
                error("unknown field types")
            end
         */
        }/*#
        end
        */
        template <typename TSerializationState, typename TSerializationPointer, typename TGetter>
        static void Serialize(TSerializationState state, TSerializationPointer pointer, TGetter getter)
        {/*#
            for _, field in ipairs(fields) do
        */
            /*#= "Serialize" .. field.name &*/SerializeFieldName/*#*/(state, pointer, getter);/*#
            end
        */
        }
        /*#
        for _, field in ipairs(fields) do
        */
        template <typename TDeserializationState, typename TDeserializationPointer, typename TSetter>
        static void /*#= "Deserialize" .. field.name &*/DeserializeFieldName/*#*/(TDeserializationState state, TDeserializationPointer pointer, TSetter setter)
        {/*#
            if field.type.kind == "primitive" then
        */
            {
                using FieldType = /*#= get_cpp_type_name(field.type) &*/CompilerTypes::FieldType/*#*/;
                auto fieldPointer = state.OffsetPointer(pointer, /*#= field.offset &*/0/*#*/);
                setter./*#= "Set" .. field.name &*/SetFieldName/*#*/(state.DeserializeValue<FieldType>(fieldPointer));
            }/*#
            elseif field.type.kind == "struct" then
            */
            {
                using FieldType = /*#= get_cpp_type_name(field.type) &*/CompilerTypes::FieldType/*#*/;
                using FieldSetter = TSetter::/*#= field.name .. "Setter" &*/FieldNameSetter/*#*/;
                auto fieldPointer = state.OffsetPointer(pointer, /*#= field.offset &*/0/*#*/);
                state.DerializeStruct<FieldType, FieldSetter>(fieldPointer, setter./*#= "Get" .. field.name .. "Setter" &*/GetFieldNameSetter/*#*/());
            }/*#
            elseif field.type.kind == "class" then
            */
            {
                throw 1;
            }/*#
            elseif field.type.kind == "array" then
                error("array fields are not supported")
            else
                error("unknown field types")
            end
        */
        }/*#
        end
        */
        template <typename TDeserializationState, typename TDeserializationPointer, typename TSetter>
        static void Deserialize(TDeserializationState state, TDeserializationPointer pointer, TSetter setter)
        {/*#
            for _, field in ipairs(fields) do
        */
            /*#= "Deserialize" .. field.name &*/DeserializeFieldName/*#*/(state, pointer, setter);/*#
            end
        */
        }
    };/*#
    end

    for _, type in ipairs(data.compiled_scheme.struct_types) do
        --generate_field_serializer(type, type.fields)
    end
    for _, type in ipairs(data.compiled_scheme.class_types) do
        --generate_field_serializer(type, type.fields)
    end

    --[[ helpers to define functions for basic building blocks for the file ]]

    */
}
