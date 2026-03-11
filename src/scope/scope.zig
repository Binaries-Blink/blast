const std = @import("std");
const Symbol = @import("symbol.zig").Symbol;
const Type = @import("../type/type.zig").Type;

pub const Scope = @This();

parent: ?*Scope,
symbols: std.StringHashMap(Symbol),

pub fn init(alloc: std.mem.Allocator, parent: ?*Scope) Scope {
    return .{
        .parent = parent,
        .symbols = .init(alloc),
    };
}

/// insert some symbol into the map with the given name, will return an error on duplicate definitions
// todo : perhaps we can do some name mangling later to allow duplicate definitions for variables
pub fn insert(self: *Scope, name: []const u8, symbol: Symbol) !void {
    const dup = try self.symbols.fetchPut(name, symbol);
    if (dup) |_| {
        return error.DuplicateDefinition;
    }
}

pub fn create(alloc: std.mem.Allocator, scope: Scope) !*Scope {
    const ptr = try alloc.create(Scope);
    ptr.* = scope;
    return ptr;
}

/// return a pointer to some symbol if it is defined
pub fn get(self: *Scope, name: []const u8) ?*Symbol {
    return self.symbols.getPtr(name);
}