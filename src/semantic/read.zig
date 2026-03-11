const std = @import("std");
const AstNode = @import("../ast.zig").AstNode;
const Type = @import("../type/type.zig").Type;

/// read the type of some node, returning some partial context which can be canonicalized later
pub fn readNodeType(alloc: std.mem.Allocator, node: *AstNode) !*Type {
    return switch (node.*) {
        .@"const" => |n| try readConst(alloc, n),
        .@"fn" => |n| try readFn(alloc, n),
        else => try Type.create(alloc, .{.primitive = .void}),
    };
}

/// returns a named type to be resolved later
fn readName(alloc: std.mem.Allocator, name: []const u8) !*Type {
    return try Type.create(alloc, .{.unresolved = .{ .named = .{ .name = name }}});
}

pub fn readTypeExpr(alloc: std.mem.Allocator, node: AstNode.TypeExpr) !*Type {
    if (node.nullable) {
        // it will be the responsibility of the
        // parser to separate the actual name from whatever
        // syntax specifies nullable types
        return try Type.create(alloc, .{.optional = .{ .inner = try readName(alloc, node.name) }});
    }
    return try readName(alloc, node.name);
}

fn readConst(alloc: std.mem.Allocator, node: AstNode.ConstStmt) !*Type {
    if (node.type_expr) |ty| {
        return try readTypeExpr(alloc, ty.ty_expr);
    }
    return try Type.create(alloc, .{ .unresolved = .Unknown });
}

fn readFn(alloc: std.mem.Allocator, node: AstNode.FnStmt) !*Type {
    const params = node.params;
    var param_types = try alloc.alloc(*Type, params.len);
    for (params, 0..) |param, i| {
        param_types[i] = try readTypeExpr(alloc, param.param.type_expr.ty_expr);
    }

    const ret_ty = try readTypeExpr(alloc, node.ret.ty_expr);

    return Type.create(alloc, .{
        .function = .{
            .@"return" = ret_ty,
            .params = param_types,
        }
    });
}