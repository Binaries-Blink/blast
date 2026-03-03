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
comptime_int_ptr: *Type,
comptime_float_ptr: *Type,

f32_ptr: *Type,
f64_ptr: *Type,
f128_ptr: *Type,

int_ptrs: std.AutoHashMap(Type.Primitive.Int, *Type),
fn_ptrs: std.HashMap(Type.Function, *Type, FnHashContext, 80),

pub fn init(alloc: std.mem.Allocator) !TypeTable {
    return .{
        .alloc = alloc,
        .void_ptr = try Type.create(alloc, .{ .primitive = .void }),
        .bool_ptr = try Type.create(alloc, .{ .primitive = .bool }),
        .comptime_int_ptr = try Type.create(alloc, .{ .primitive = .comptime_int }),
        .comptime_float_ptr = try Type.create(alloc, .{ .primitive = .comptime_float }),
        .f32_ptr = try Type.create(alloc, .{ .primitive = .f32 }),
        .f64_ptr = try Type.create(alloc, .{ .primitive = .f64 }),
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
        .comptime_int => return self.comptime_int_ptr,
        .comptime_float => return self.comptime_float_ptr,
        .f32 => return self.f32_ptr,
        .f64 => return self.f64_ptr,
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

// pub fn format(self: TypeTable, writer: *std.Io.Writer) std.Io.Writer.Error!void {
//     try writer.print("~~ Primitives:\n", .{});
//     try writer.print("  {*} -> {f}\n", .{self.void_ptr, self.void_ptr.*});
//     try writer.print("  {*} -> {f}\n", .{self.bool_ptr, self.bool_ptr.*});
//     try writer.print("  {*} -> {f}\n", .{self.comptime_int_ptr, self.comptime_int_ptr.*});
//     try writer.print("  {*} -> {f}\n", .{self.comptime_float_ptr, self.comptime_float_ptr.*});
//     try writer.print("  {*} -> {f}\n", .{self.f32_ptr, self.f32_ptr.*});
//     try writer.print("  {*} -> {f}\n", .{self.f64_ptr, self.f64_ptr.*});
//     try writer.print("  {*} -> {f}\n", .{self.f128_ptr, self.f128_ptr.*});
//
//     // int types
//     try writer.print("~~ Ints:\n", .{});
//     var int_iter = self.int_ptrs.iterator();
//     while (int_iter.next()) |e| {
//         try writer.print("  {*} -> {f}\n", .{e.value_ptr.*, e.value_ptr.*.*});
//     }
//
//     // function types
//     try writer.print("~~ Functions:\n", .{});
//     var fn_iter = self.fn_ptrs.iterator();
//     while (fn_iter.next()) |e| {
//         try writer.print("  {*} -> {f}\n", .{e.value_ptr.*, e.value_ptr.*.*});
//     }
// }