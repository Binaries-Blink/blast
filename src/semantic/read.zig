const std = @import("std");
const AstNode = @import("../ast.zig").AstNode;
const Type = @import("../type/type.zig").Type;
const Error = @import("analyzer.zig").Analyzer.Error;

/// read the type of some node, returning some partial context which can be canonicalized later
pub fn readNodeType(alloc: std.mem.Allocator, node: *AstNode) Error!*Type {
    return switch (node.*.kind) {
        .@"const" => |n| try readConst(alloc, n),
        .@"fn" => |n| try readFn(alloc, n),
        else => try Type.create(alloc, .{.primitive = .void}),
    };
}

/// returns a named type to be resolved later
fn readName(alloc: std.mem.Allocator, name: []const u8) Error!*Type {
    return try Type.create(alloc, .{.unresolved = .{ .named = .{ .name = name }}});
}

pub fn readTypeExpr(alloc: std.mem.Allocator, node: AstNode.NodeKind.TypeExpr) Error!*Type {
    if (node.nullable) {
        // it will be the responsibility of the
        // parser to separate the actual name from whatever
        // syntax specifies nullable types
        return try Type.create(alloc, .{.optional = .{ .inner = try readName(alloc, node.name) }});
    }
    return try readName(alloc, node.name);
}

fn readConst(alloc: std.mem.Allocator, node: AstNode.NodeKind.ConstStmt) Error!*Type {
    if (node.type_expr) |ty| {
        return try readTypeExpr(alloc, ty.kind.ty_expr);
    }
    return try Type.create(alloc, .{ .unresolved = .Unknown });
}

fn readFn(alloc: std.mem.Allocator, node: AstNode.NodeKind.FnStmt) Error!*Type {
    const params = node.params;
    var param_types = try alloc.alloc(*Type, params.len);
    for (params, 0..) |param, i| {
        param_types[i] = try readTypeExpr(alloc, param.kind.param.type_expr.kind.ty_expr);
    }

    const ret_ty = try readTypeExpr(alloc, node.ret.kind.ty_expr);

    return Type.create(alloc, .{
        .function = .{
            .@"return" = ret_ty,
            .params = param_types,
        }
    });
}