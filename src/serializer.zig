// // TODO (19 Nov 2024 sam): See if these notes are upto date.
// Some notes about deserialization
// Deserialization is currently type-neutral, so it treats all types as the same, which
// can cause an issue when some things are nested and others are not. Specifically when
// it comes to arraylists and hashmaps etc. There is an issue where we don't know exactly
// when they need to be initialised. So this is handled in the structs themselves. in its
// deserialization, a struct will init the things that it needs to, if it needs to. So
// things that are already initialised wont be affected, and things that need initializing
// will be taken care of.

const std = @import("std");
const c = @import("c.zig");
const build_options = @import("build_options");
const BUILDER_MODE = build_options.builder_mode;
const helpers = @import("helpers.zig");

// We have a hashmap that stores array_list as a value. So if we just check for arraylist
// string in type name, we will find it when looking at the hashmap, which results in the
// hashmap being treated as an arraylist. This prevents that false positive.
const ARRAY_LIST_INDEX_MAX = 10;
pub const JsonWriter = std.io.Writer(*JsonStream, JsonStreamError, JsonStream.write);
pub const JsonStreamError = error{JsonWriteError};
pub const JsonSerializer = std.json.WriteStream(JsonWriter, .{ .checked_to_fixed_depth = 256 });
pub const JsonStream = struct {
    const Self = @This();
    buffer: std.ArrayList(u8),

    pub fn new(allocator: std.mem.Allocator) Self {
        return Self{
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }

    pub fn writer(self: *Self) JsonWriter {
        return .{ .context = self };
    }

    pub fn write(self: *Self, bytes: []const u8) JsonStreamError!usize {
        self.buffer.appendSlice(bytes) catch unreachable;
        return bytes.len;
    }

    pub fn webSave(self: *Self, key_name: []const u8) !void {
        helpers.webSave(key_name, self.buffer.items);
    }

    pub fn saveDataToFile(self: *Self, filepath: []const u8, allocator: std.mem.Allocator) !void {
        // TODO (08 Dec 2021 sam): See whether we want to add a hash or base64 encoding
        try helpers.writeFileContents(filepath, self.buffer.items, allocator);
        if (true) {
            if (build_options.generator_print) helpers.debugPrint("saving to file {s}\n", .{filepath});
        }
    }

    pub fn serializer(self: *Self) JsonSerializer {
        return std.json.writeStream(self.writer(), .{});
    }

    pub fn serializerOptions(self: *Self, options: std.json.StringifyOptions) JsonSerializer {
        return std.json.writeStream(self.writer(), options);
    }
};

pub fn serialize(opt_struct_name: ?[]const u8, data: anytype, js: *JsonSerializer) !void {
    // helpers.debugPrint("serializing {s} of type {s}\n", .{ opt_struct_name orelse "val", @typeName(@TypeOf(data)) });
    // @compileLog("", @typeName(@TypeOf(data)));
    switch (@typeInfo(@TypeOf(data))) {
        .@"struct" => {
            if (opt_struct_name) |struct_name| try js.objectField(struct_name);
            if (comptime std.mem.indexOf(u8, @typeName(@TypeOf(data)), "array_list.ArrayListAligned") != null and
                std.mem.indexOf(u8, @typeName(@TypeOf(data)), "array_list.ArrayListAligned").? <= ARRAY_LIST_INDEX_MAX)
            {
                try js.beginArray();
                for (data.items) |val| {
                    try serialize(null, val, js);
                }
                try js.endArray();
            } else if (comptime std.mem.indexOf(u8, @typeName(@TypeOf(data)), "hash_map.HashMap") != null) {
                try js.beginArray();
                var items = data.keyIterator();
                while (items.next()) |key| {
                    try js.beginObject();
                    try serialize("key", key.*, js);
                    try serialize("value", data.get(key.*).?, js);
                    try js.endObject();
                }
                try js.endArray();
            } else {
                try js.beginObject();
                try serializeStruct(@TypeOf(data), data, js);
                try js.endObject();
            }
        },
        .pointer => |pointer| {
            if (opt_struct_name) |struct_name| try js.objectField(struct_name);
            if (@TypeOf(data[0]) == u8) {
                try js.write(data);
            } else {
                // only can store const slices
                helpers.debugAssert(pointer.size == .slice);
                helpers.debugAssert(pointer.is_const);
                try js.beginArray();
                for (data) |item| try serialize(null, item, js);
                try js.endArray();
            }
        },
        .optional => {
            if (data != null) {
                try serialize(opt_struct_name, data.?, js);
            } else {
                if (opt_struct_name) |struct_name| try js.objectField(struct_name);
                try js.write(null);
            }
        },
        .@"enum" => {
            if (opt_struct_name) |struct_name| try js.objectField(struct_name);
            const is_runtime = comptime std.mem.indexOf(u8, @typeName(@TypeOf(data)), "RuntimeEnum") != null;
            if (is_runtime) {
                try js.write(data.query(.name));
            } else {
                try js.write(@tagName(data));
            }
        },
        .float, .int, .bool => {
            if (opt_struct_name) |struct_name| try js.objectField(struct_name);
            try js.write(data);
        },
        .@"union" => {
            if (opt_struct_name) |struct_name| try js.objectField(struct_name);
            try js.beginObject();
            try serialize("case", @tagName(std.meta.activeTag(data)), js);
            switch (data) {
                inline else => |val| try serialize("value", val, js),
            }
            try js.endObject();
        },
        .void, .null => {
            if (opt_struct_name) |struct_name| try js.objectField(struct_name);
            try js.write("");
        },
        .array => {
            if (opt_struct_name) |struct_name| try js.objectField(struct_name);
            try js.beginArray();
            for (data[0..]) |elem| {
                try serialize(null, elem, js);
            }
            try js.endArray();
        },
        .vector => |vector_data| {
            if (opt_struct_name) |struct_name| try js.objectField(struct_name);
            try js.beginArray();
            for (0..vector_data.len) |i| {
                try serialize(null, data[i], js);
            }
            try js.endArray();
        },
        else => comptime {
            var buffer: [512]u8 = undefined;
            const text = std.fmt.bufPrint(buffer[0..], "Could not serialize {s}\n", .{@tagName(@typeInfo(@TypeOf(data)))}) catch unreachable;
            @compileError(text);
        },
    }
}

pub fn serializeStruct(comptime T: type, data: T, js: *JsonSerializer) !void {
    helpers.assert(@typeInfo(T) == .@"struct");
    const DEBUG_COMPILE_LOGS = false;
    const DEBUG_RUNTIME_LOGS = false;
    comptime {
        if (@hasDecl(T, "dont_serialize_fields") and @hasDecl(T, "serialize_fields")) {
            @compileError(@typeName(T) ++ " has both fields: dont_serialize_fields and serialize_fields. It should have at most 1 of these.");
        }
    }
    if (@hasDecl(T, "serialize")) {
        if (DEBUG_COMPILE_LOGS) @compileLog(@typeName(T), " has serialize()");
        if (DEBUG_RUNTIME_LOGS) helpers.debugPrint("{s} has a serialize()", .{@typeName(T)});
        try data.serialize(js);
    } else if (@hasDecl(T, "dont_serialize_fields")) {
        if (DEBUG_RUNTIME_LOGS) helpers.debugPrint("{s} - ignoring some fields", .{@typeName(T)});
        if (DEBUG_COMPILE_LOGS) @compileLog(@typeName(T), " has dont_serialize_fields");
        inline for (@typeInfo(T).@"struct".fields) |field| {
            if (comptime !helpers.stringIn(field.name[0..], @field(T, "dont_serialize_fields")[0..])) {
                try serialize(field.name, @field(data, field.name), js);
            }
        }
    } else if (@hasDecl(T, "serialize_fields")) {
        if (DEBUG_COMPILE_LOGS) @compileLog(@typeName(T), " has serialize_fields");
        if (DEBUG_RUNTIME_LOGS) helpers.debugPrint("{s} has a list of serialize_fields", .{@typeName(T)});
        inline for (@field(T, "serialize_fields")) |field| try serialize(field, @field(data, field), js);
    } else {
        if (DEBUG_COMPILE_LOGS) @compileLog(@typeName(T), "serialize all");
        if (DEBUG_RUNTIME_LOGS) helpers.debugPrint("{s} - serializing all fields", .{@typeName(T)});
        inline for (@typeInfo(T).@"struct".fields) |field| {
            try serialize(field.name, @field(data, field.name), js);
        }
    }
}

pub const DeserializationOptions = struct {
    error_on_not_found: bool = false,
    allocator: std.mem.Allocator,
    arena: std.mem.Allocator,
    // to load in const slices. meant for runtime enum etc
    const_allocator: ?std.mem.Allocator = null,
};

pub fn deserialize(opt_struct_name: ?[]const u8, data: anytype, js: std.json.Value, options: DeserializationOptions) void {
    //if (opt_struct_name) |str_name| helpers.debugPrint("deserializiing {s}\n", .{str_name});
    var not_found = false;
    const figured_type = @TypeOf(data.*);
    // var names = js.object.iterator();
    // while (names.next()) |name| helpers.debugPrint("found {s}\n", .{name.key_ptr.*});
    const value = get_field: {
        if (opt_struct_name) |struct_name| {
            if (js.object.get(struct_name)) |s| {
                break :get_field s;
            } else {
                helpers.debugPrint("{s} not found\n", .{struct_name});
                if (options.error_on_not_found) unreachable;
                not_found = true;
                break :get_field js;
            }
        } else {
            break :get_field js;
        }
    };
    if (not_found) {
        return;
    }
    if (comptime @typeInfo(figured_type) == .optional) {
        if (value == .null) {
            data.* = null;
            return;
        } else {
            const new_type = @typeInfo(figured_type).optional.child;
            data.* = undefined;
            deserializeType(&data.*.?, value, options, new_type);
            return;
        }
    }
    deserializeType(data, value, options, figured_type);
}

fn deserializeType(data: anytype, value: std.json.Value, options: DeserializationOptions, comptime T: type) void {
    const is_optional = @typeInfo(T) == .optional;
    helpers.assert(!is_optional);
    switch (@typeInfo(T)) {
        .@"struct" => {
            if (comptime std.mem.indexOf(u8, @typeName(@TypeOf(data)), "array_list.ArrayListAligned") != null and
                std.mem.indexOf(u8, @typeName(@TypeOf(data)), "array_list.ArrayListAligned").? <= ARRAY_LIST_INDEX_MAX)
            {
                // TODO (26 Feb 2024 sam): Should this call deserialize on data.items and allow array to take care of the rest?
                data.resize(value.array.items.len) catch unreachable;
                for (value.array.items, 0..) |item, i| {
                    deserialize(null, &data.items[i], item, options);
                }
            } else if (comptime std.mem.indexOf(u8, @typeName(@TypeOf(data)), "hash_map.HashMap") != null) {
                data.ensureTotalCapacity(@intCast(value.array.items.len)) catch unreachable;
                const kitype = @TypeOf(data.keyIterator().items);
                const keytype = @typeInfo(kitype).pointer.child;
                const vitype = @TypeOf(data.valueIterator().items);
                const valtype = @typeInfo(vitype).pointer.child;
                for (value.array.items) |item| {
                    var key: keytype = undefined;
                    var val: valtype = undefined;
                    deserialize("key", &key, item, options);
                    deserialize("value", &val, item, options);
                    data.put(key, val) catch unreachable;
                }
            } else {
                // TODO (28 Feb 2024 sam): Maybe we can move the ser/deser code here? Its anyways
                // common between almost all classes
                deserializeStruct(T, data, value, options);
            }
        },
        .pointer => |po| {
            if (po.child == u8) {
                data.* = value.string;
                if (options.const_allocator) |ca| {
                    const mem = ca.alloc(u8, value.string.len) catch unreachable;
                    @memcpy(mem, value.string);
                    data.*.ptr = mem.ptr;
                }
            } else {
                helpers.debugAssert(po.size == .slice);
                helpers.debugAssert(po.is_const);
                if (options.const_allocator == null) {
                    helpers.debugPrint("error: cannot deserialize {s}\nto load const slices, set options.const_allocator\n\n", .{@typeName(T)});
                    unreachable; // to load const slices, set options.const_allocator
                }
                const mem = options.const_allocator.?.alloc(po.child, value.array.items.len) catch unreachable;
                for (mem, value.array.items) |*slot, val| {
                    deserialize(null, slot, val, options);
                }
                data.ptr = mem.ptr;
                data.len = mem.len;
            }
        },
        .optional => {
            unreachable; // we should have taken care of optionals above
        },
        .@"enum" => {
            if (comptime is_optional) {
                data.*.? = std.meta.stringToEnum(@TypeOf(data.*.?), value.string).?;
                @compileError("should not reach here?");
                // keeping this here because I don't remember why it was written. since its a
                // comptime branch, will be optimised out.
            } else {
                const is_runtime = comptime std.mem.indexOf(u8, @typeName(@TypeOf(data.*)), "RuntimeEnum") != null;
                if (is_runtime) {
                    data.* = T.fromString(value.string);
                } else {
                    data.* = std.meta.stringToEnum(T, value.string).?;
                }
            }
        },
        .float => {
            data.* = @floatCast(value.float);
        },
        .bool => {
            data.* = value.bool;
        },
        .array => {
            for (value.array.items, 0..) |item, i| {
                deserialize(null, &data[i], item, options);
            }
        },
        .vector => |vector_data| {
            for (0..vector_data.len) |i| {
                deserializeType(&data[i], value.array.items[i], options, vector_data.child);
            }
        },
        .void => {
            data.* = {};
        },
        .@"union" => {
            const tag = @typeInfo(T).@"union".tag_type.?;
            const case_name = value.object.get("case").?.string;
            const case = std.meta.stringToEnum(tag, case_name).?;
            switch (case) {
                inline else => |branch| {
                    const tag_name = @tagName(branch);
                    data.* = @unionInit(T, tag_name, undefined);
                    deserialize(null, &@field(data.*, tag_name), value.object.get("value").?, options);
                },
            }
        },
        .int => {
            data.* = @intCast(value.integer);
        },
        else => {
            helpers.debugPrint("Could not deserialize {s}\n", .{@tagName(@typeInfo(T))});
        },
    }
}

pub fn deserializeStruct(comptime T: type, data: *T, value: std.json.Value, options: DeserializationOptions) void {
    helpers.assert(@typeInfo(T) == .@"struct");
    comptime {
        if (@hasDecl(T, "dont_serialize_fields") and @hasDecl(T, "serialize_fields")) {
            @compileError(@typeName(T) ++ " has both fields: dont_serialize_fields and serialize_fields. It should have at most 1 of these.");
        }
    }
    // initialize all the default values first, as long as field should be deserialized
    inline for (@typeInfo(T).@"struct".fields) |field| {
        if (field.default_value_ptr) |dv| {
            if (@hasDecl(T, "dont_serialize_fields")) {
                if (comptime helpers.stringIn(field.name[0..], @field(T, "dont_serialize_fields")[0..])) {
                    continue;
                }
            } else if (@hasDecl(T, "serialize_fields")) {
                if (comptime !helpers.stringIn(field.name[0..], @field(T, "serialize_fields")[0..])) {
                    continue;
                }
            }
            const def_v: *field.type = @alignCast(@ptrCast(@constCast(dv)));
            @field(data.*, field.name) = def_v.*;
        }
    }
    {
        // TODO (30 Jan 2025 sam): This will init all arraylists and hashmaps in nested structs. For example
        // sim.structures has an arraylist for cells, and similarly other things may have other lists that
        // need to be stored. There is no way to check if these structs have already been initted, so we have
        // to rememeber to clearAndFree them or else memory gets leaked.
        // To solve this, we need to use a struct that does not need memory initialisation like a StackSlice
        // or else use a wrapper around the arraylist and hashmap which has a flag storing if the thing has
        // been initted.
        @setEvalBranchQuota(100000);
        const init_fields = [_][]const u8{ "array_list.ArrayListAligned", "hash_map.HashMap" };
        inline for (@typeInfo(T).@"struct".fields) |field| {
            if (@hasDecl(T, "dont_serialize_fields")) {
                if (comptime helpers.stringIn(field.name[0..], @field(T, "dont_serialize_fields")[0..])) {
                    continue;
                }
            } else if (@hasDecl(T, "serialize_fields")) {
                if (comptime !helpers.stringIn(field.name[0..], @field(T, "serialize_fields")[0..])) {
                    continue;
                }
            }
            inline for (init_fields) |name| {
                if (comptime std.mem.indexOf(u8, @typeName(field.type), name) != null and
                    @typeName(field.type)[0] != '?' and
                    std.mem.indexOf(u8, @typeName(field.type), name).? <= ARRAY_LIST_INDEX_MAX)
                {
                    @field(data.*, field.name) = @TypeOf(@field(data.*, field.name)).init(options.allocator);
                }
            }
        }
    }
    if (@hasDecl(T, "deserialize")) {
        data.deserialize(value, options);
        return;
    } else if (@hasDecl(T, "dont_serialize_fields")) {
        inline for (@typeInfo(T).@"struct".fields) |field| {
            if (comptime !helpers.stringIn(field.name[0..], @field(T, "dont_serialize_fields")[0..])) {
                deserialize(field.name, &@field(data, field.name), value, options);
            }
        }
    } else if (@hasDecl(T, "serialize_fields")) {
        inline for (@field(T, "serialize_fields")) |field| deserialize(field, &@field(data, field), value, options);
    } else {
        inline for (@typeInfo(T).@"struct".fields) |field| deserialize(field.name, &@field(data, field.name), value, options);
    }
}
