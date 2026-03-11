const std = @import("std");
const Type = @import("../type/type.zig").Type;
const AstNode = @import("../ast.zig").AstNode;

pub const Symbol = @This();

kind: SymbolKind,
/// the concrete type of the symbol
ty: *Type,
/// the node corresponding to the symbol
node: *AstNode,

pub const SymbolKind = enum(u8) {
    constant,
    function,
    variable,
    type,
    parameter,
};