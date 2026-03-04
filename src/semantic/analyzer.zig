const std = @import("std");
const AstNode = @import("../ast.zig").AstNode;
const TypeTable = @import("../type/table.zig").TypeTable;
const Type = @import("../type/type.zig").Type;
const Scope = @import("../scope/scope.zig").Scope;
const Symbol = @import("../scope/symbol.zig").Symbol;

/// responsible for performing semantic analysis on the AST
pub const Analyzer = @This();

alloc: std.mem.Allocator,
table: TypeTable,
global: *Scope,
/// a stack of scopes used for parent tracking during traversal
stack: std.ArrayList(*Scope),

const Self = @This();

pub fn init(alloc: std.mem.Allocator) !Self {
    const global = try alloc.create(Scope);
    global.* = Scope {
        .parent = null,
        .symbols = std.StringHashMap(Symbol).init(alloc),
    };

    return .{
        .alloc = alloc,
        .table = try TypeTable.init(alloc),
        .global = global,
        .stack = try std.ArrayList(*Scope).initCapacity(alloc, 1)
    };
}

/// run some semantic analysis over the given node.
///
/// expects the given node to be a root node
pub fn analyze(self: *Self, node: *AstNode) !void {
    if (node.* != .root) return error.ExpectedRootNode;

    for (node.root) |n| {
        try self.analyseTop(n);
    }

    for (node.root) |n| {
        try self.analyzeFull(n);
    }
}

/// analyse the top level nodes, building context
/// which will then be used for the full pass later on
fn analyseTop(self: *Self, node: *AstNode) !void {
    const ty = try Type.create(self.alloc,
        try readNodeType(self.alloc, node)
    );
    var name: []const u8 = undefined;
    const kind = switch (node.*) {
        .@"const" => |n| blk: {
            name = n.name;
            break :blk Symbol.SymbolKind.constant;
        },
        .@"fn" => |n| blk: {
            name = n.name;
            break :blk Symbol.SymbolKind.function;
        },
        else => return,
    };
    const sym = Symbol {
        .kind = kind,
        .ty = ty,
        .node = node,
    };
    try self.global.insert(name, sym);
}

/// completely analyze the given node, traversing any and all contained scopes
fn analyzeFull(self: *Self, node: *AstNode) !void {
    switch (node.*) {
        .@"const" => |n| {
            var sym = self.global.get(n.name) orelse return error.UnknownSymbol;

            if (sym.ty.isUnknown()) {
                const inferred = try self.inferType(n.value);
                sym.ty = inferred;
            }

            sym.ty = try self.resolveType(sym.ty);
        },
        .@"fn" => |n| {
            var sym = self.global.get(n.name) orelse return error.UnknownSymbol;
            sym.ty = try self.resolveType(sym.ty);

            self.analyzeFull(n.body);
        },
        else => |n| {
            std.debug.print("{s}", .{@tagName(n)});
            return error.TodoResolve;
        },
    }
}

/// read the type of some node, returning some partial context which can be canonicalized later
fn readNodeType(alloc: std.mem.Allocator, node: *AstNode) !*Type {
    return switch (node.*) {
        .@"const" => |n| try readConst(alloc, n),
        .@"fn" => |n| try readFn(alloc, n),
        else => try Type.create(alloc, .{.primitive = void}),
    };
}

/// returns a named type to be resolved later
fn readName(alloc: std.mem.Allocator, name: []const u8) !*Type {
    return try Type.create(alloc, .{.unresolved = .{ .named = .{ .name = name }}});
}

fn readTypeExpr(alloc: std.mem.Allocator, node: AstNode.TypeExpr) !*Type {
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

/// resolve a type pointer to its canonical pointer via the table
fn resolveType(self: *Self, ty: *Type) !*Type {
    switch (ty.*) {
        .primitive => return self.table.get(ty.*),
        .function => |f| {
            const ret = try self.resolveType(f.@"return");
            const params = try self.alloc.alloc(*Type, f.params.len);
            for (f.params, 0..) |param, i| {
                params[i] = try self.resolveType(param);
            }

            return self.table.get(.{
                .function = Type.Function {
                    .params = params,
                    .@"return" = ret,
                }
            });
        },
        .unresolved => |un| switch (un) {
            .named => |n| {
                if (self.table.primitiveFromName(n.name)) |p| {
                    return p;
                }
                return error.UnknownType;
            },
            .Unknown => return error.UnknownType,
        },
        else => return error.UnsupportedType,
    }
}

fn inferType(self: *Self, node: *AstNode) !*Type {
    switch (node.*) {
        .expr => |*e| return try self.inferExprType(e),
        else => return error.InferenceNotSupported,
    }
}

fn inferExprType(self: *Self, expr: *AstNode.Expr) !*Type {
    _ = self;
    return switch (expr.*) {
        .literal => error.todo,
        .ident => error.todo,
        .unary => error.todo,
        .binary => error.todo,
        .block => error.todo,
        .call => error.todo,
        .@"if" => error.todo,
        else => error.NotImplemented,
    };
}