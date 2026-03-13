const std = @import("std");
const Type = @import("type.zig").Type;

/// a registry of pointers to all unique types
pub const TypeTable = @This();

const FnHashContext = struct {
    pub fn hash(self: FnHashContext, key: Type.Function) u64 {
        _ = self;
        var h = std.hash.Wyhash.init(0);
        h.update(std.mem.asBytes(key.@"return"));
        for (key.params) |param| h.update(std.mem.asBytes(param));
        return h.final();
    }

    pub fn eql(self: FnHashContext, a: Type.Function, b: Type.Function) bool {
        _ = self;
        if (a.@"return" != b.@"return") return false;
        if (a.params.len != b.params.len) return false;
        for (a.params, b.params) |ap, bp| if (ap != bp) return false;
        return true;
    }
};

alloc: std.mem.Allocator,

void_ptr: *Type,
bool_ptr: *Type,
int_literal_ptr: *Type,
float_literal_ptr: *Type,
char_ptr: *Type,

f32_ptr: *Type,
f64_ptr: *Type,
f80_ptr: *Type,
f128_ptr: *Type,

int_ptrs: std.AutoHashMap(Type.Primitive.Int, *Type),
fn_ptrs: std.HashMap(Type.Function, *Type, FnHashContext, 80),

pub fn init(alloc: std.mem.Allocator) !TypeTable {
    return .{
        .alloc = alloc,
        .void_ptr = try Type.create(alloc, .{ .primitive = .void }),
        .bool_ptr = try Type.create(alloc, .{ .primitive = .bool }),
        .int_literal_ptr = try Type.create(alloc, .{ .primitive = .int_literal }),
        .float_literal_ptr = try Type.create(alloc, .{ .primitive = .float_literal }),
        .char_ptr = try Type.create(alloc, .{ .primitive = .char }),
        .f32_ptr = try Type.create(alloc, .{ .primitive = .f32 }),
        .f64_ptr = try Type.create(alloc, .{ .primitive = .f64 }),
        .f80_ptr = try Type.create(alloc, .{ .primitive = .f80 }),
        .f128_ptr = try Type.create(alloc, .{ .primitive = .f128 }),
        .int_ptrs = std.AutoHashMap(Type.Primitive.Int, *Type).init(alloc),
        .fn_ptrs = std.HashMap(Type.Function, *Type, FnHashContext, 80).init(alloc),
    };
}

pub fn get(self: *TypeTable, key: Type) *Type {
    switch (key) {
        .primitive => |p| return self.getPrimitive(p),
        .function => |f| return self.getFn(f) catch unreachable,
        else => @panic("not yet implemented"),
    }
}

fn getInt(self: *TypeTable, key: Type.Primitive.Int) !*Type {
    if (self.int_ptrs.get(key)) |int| return int;
    const ty = try self.alloc.create(Type);
    ty.* = .{.primitive = .{ .int = key }};
    try self.int_ptrs.put(key, ty);
    return ty;
}

fn getPrimitive(self: *TypeTable, key: Type.Primitive) *Type {
    switch (key) {
        .void => return self.void_ptr,
        .bool => return self.bool_ptr,
        .int_literal => return self.int_literal_ptr,
        .float_literal => return self.float_literal_ptr,
        .char => return self.char_ptr,
        .f32 => return self.f32_ptr,
        .f64 => return self.f64_ptr,
        .f80 => return self.f80_ptr,
        .f128 => return self.f128_ptr,
        // todo : unreachable might be a bit dangerous here,
        //  but all integer primitives are defined if they are
        //  used once so we should be good lol
        .int => |i| return self.getInt(i) catch unreachable,
    }
}

fn getFn(self: *TypeTable, key: Type.Function) !*Type {
    if (self.fn_ptrs.get(key)) |func| return func;
    const ty = try self.alloc.create(Type);
    ty.* = .{ .function = key };
    try self.fn_ptrs.put(key, ty);
    return ty;
}

pub fn primitiveFromName(self: *TypeTable, name: []const u8) ?*Type {
    if (std.mem.eql(u8, name, "void")) return self.void_ptr;
    if (std.mem.eql(u8, name, "bool")) return self.bool_ptr;
    if (std.mem.eql(u8, name, "char")) return self.char_ptr;
    if (std.mem.eql(u8, name, "f32")) return self.f32_ptr;
    if (std.mem.eql(u8, name, "f64")) return self.f64_ptr;
    if (std.mem.eql(u8, name, "f80")) return self.f80_ptr;
    if (std.mem.eql(u8, name, "f128")) return self.f128_ptr;

    const key = Type.Primitive.Int.fromName(name) orelse return null;
    return self.get(key);
}

pub fn format(self: TypeTable, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.print("~~ Primitives:\n", .{});
    try writer.print("  {*} -> {f}\n", .{self.void_ptr, self.void_ptr.*});
    try writer.print("  {*} -> {f}\n", .{self.bool_ptr, self.bool_ptr.*});
    try writer.print("  {*} -> {f}\n", .{self.int_literal_ptr, self.int_literal_ptr.*});
    try writer.print("  {*} -> {f}\n", .{self.float_literal_ptr, self.float_literal_ptr.*});
    try writer.print("  {*} -> {f}\n", .{self.char_ptr, self.char_ptr.*});
    try writer.print("  {*} -> {f}\n", .{self.f32_ptr, self.f32_ptr.*});
    try writer.print("  {*} -> {f}\n", .{self.f64_ptr, self.f64_ptr.*});
    try writer.print("  {*} -> {f}\n", .{self.f80_ptr, self.f80_ptr.*});
    try writer.print("  {*} -> {f}\n", .{self.f128_ptr, self.f128_ptr.*});

    // int types
    try writer.print("~~ Ints:\n", .{});
    var int_iter = self.int_ptrs.iterator();
    while (int_iter.next()) |e| {
        try writer.print("  {*} -> {f}\n", .{e.value_ptr.*, e.value_ptr.*.*});
    }

    // function types
    try writer.print("~~ Functions:\n", .{});
    var fn_iter = self.fn_ptrs.iterator();
    while (fn_iter.next()) |e| {
        try writer.print("  {*} -> {f}\n", .{e.value_ptr.*, e.value_ptr.*.*});
    }
}