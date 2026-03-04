const std = @import("std");
const Symbol = @import("symbol.zig").Symbol;
const Type = @import("../type/type.zig").Type;

pub const Scope = @This();

parent: ?*Scope,
symbols: std.StringHashMap(Symbol),

/// insert some symbol into the map with the given name, will return an error on duplicate definitions
// todo : perhaps we can do some name mangling later to allow duplicate definitions for variables
pub fn insert(self: *Scope, name: []const u8, symbol: Symbol) !void {
    const dup = try self.symbols.fetchPut(name, symbol);
    if (dup) |_| {
        return error.DuplicateDefinition;
    }
}

/// return a pointer to some symbol if it is defined
pub fn get(self: *Scope, name: []const u8) ?*Symbol {
    return self.symbols.getPtr(name);
}