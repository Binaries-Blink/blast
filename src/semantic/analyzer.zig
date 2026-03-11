const std = @import("std");
const AstNode = @import("../ast.zig").AstNode;
const TypeTable = @import("../type/table.zig").TypeTable;
const Type = @import("../type/type.zig").Type;
const Scope = @import("../scope/scope.zig").Scope;
const Symbol = @import("../scope/symbol.zig").Symbol;
const readNodeType = @import("read.zig").readNodeType;
const readTypeExpr = @import("read.zig").readTypeExpr;

/// responsible for performing semantic analysis on the AST
pub const Analyzer = @This();

alloc: std.mem.Allocator,
table: TypeTable,
global: *Scope,

const Self = @This();

/// context to be used during the second pass of semantic analysis
const Ctx = struct {
    /// the current scope
    scope: *Scope,
    /// expected return type of some enclosing function,
    /// defaults to null for the top level.
    ret_ty: ?*Type = null,
    /// hint for what type is expected to be produced, null if unknown
    expected_ty: ?*Type = null,
};

/// context produced when evaluating an expression
const ExprRes = struct {
    /// the type of this expression
    ty: *Type,
    /// false if an expression does not return
    ///
    /// basically the same as `fn() -> !` in rust
    returns: bool = true,
    /// true if the expression returns an lvalue
    ///
    /// will be useful for things like indexing
    ///
    /// `arr[i] = 0`
    lvalue: bool = false,
};

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

    const ctx = Ctx { .scope = self.global };

    for (node.root) |n| {
        try self.analyzeFull(n, ctx);
    }
}

/// analyse the top level nodes, building context
/// which will then be used for the full pass later on
fn analyseTop(self: *Self, node: *AstNode) !void {
    const ty = try readNodeType(self.alloc, node);
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
fn analyzeFull(self: *Self, node: *AstNode, ctx: Ctx) !void {
    switch (node.*) {
        .@"const" => |n| {
            var sym = self.global.get(n.name) orelse return error.UnknownSymbol;

            // todo : properly resolve the type of the expression instead of just inferring
            //  instead we will make a type hint, which has a value if a type expr is
            //  given, else is null.
            if (sym.ty.isUnknown()) {
                const inferred = try self.inferType(n.value);
                sym.ty = inferred;
            }

            sym.ty = try self.resolveType(sym.ty);
        },
        .@"fn" => |n| {
            var sym = self.global.get(n.name) orelse return error.UnknownSymbol;
            sym.ty = try self.resolveType(sym.ty);

            // right now we pass in the scope defined by the context,
            // im hoping this should allow functions inside of blocks
            var scope = try Scope.create(self.alloc, ctx.scope.*);
            for (n.params) |param| {
                const ty = try self.resolveType(
                    try readTypeExpr(self.alloc, param.param.type_expr.ty_expr)
                );
                try scope.insert(param.param.name, Symbol {
                    .kind = .parameter,
                    .ty = ty,
                    .node = param,
                });
            }

            const ret_ty = sym.ty.function.@"return";

            const body_ctx = Ctx {
                .scope = scope,
                .ret_ty = ret_ty,
                .expected_ty = ret_ty,
            };

            const result = try self.analyzeExpr(&n.body.expr, body_ctx);
            _ = result;

            // todo : if result type can coerce into return type, were good,
            //  else panic and freak out and lose your mind and crash and burn
        },
        else => |n| {
            std.debug.print("{s}", .{@tagName(n)});
            return error.TodoResolve;
        },
    }
}

/// performs full analysis of an expression node
fn analyzeExpr(self: *Self, expr: *AstNode.Expr, ctx: Ctx) !ExprRes {
    // todo : when analyzing an expr,
    //  build new context in the function that calls the analysis
    return switch(expr.*) {
        .literal => |lit| self.analyzeLiteral(lit, ctx),
        .ident   => |id|  self.analyzeIdent(id, ctx),
        .unary   => |un|  self.analyzeUnary(un, ctx),
        .binary  => |bi|  self.analyzeBinary(bi, ctx),
        .block   => |blk| self.analyzeBlock(blk, ctx),
        .call    => |ca|  self.analyzeCall(ca, ctx),
        .@"if"   => |i|   self.analyzeIf(i, ctx),
    };
}

fn analyzeLiteral(self: *Self, expr: AstNode.Expr.Literal, ctx: Ctx) !ExprRes {
    _ = self;
    _ = expr;
    _ = ctx;
    return error.todo;
}

fn analyzeIdent(self: *Self, expr: AstNode.Expr.Ident, ctx: Ctx) !ExprRes {
    _ = self;
    _ = expr;
    _ = ctx;
    return error.todo;
}

fn analyzeUnary(self: *Self, expr: AstNode.Expr.UnOp, ctx: Ctx) !ExprRes {
    _ = self;
    _ = expr;
    _ = ctx;
    return error.todo;
}

fn analyzeBinary(self: *Self, expr: AstNode.Expr.BinOp, ctx: Ctx) !ExprRes {
    _ = self;
    _ = expr;
    _ = ctx;
    return error.todo;
}

fn analyzeBlock(self: *Self, expr: AstNode.Expr.Block, ctx: Ctx) !ExprRes {
    _ = self;
    _ = expr;
    _ = ctx;
    return error.todo;
}

fn analyzeCall(self: *Self, expr: AstNode.Expr.FnCall, ctx: Ctx) !ExprRes {
    _ = self;
    _ = expr;
    _ = ctx;
    return error.todo;
}

fn analyzeIf(self: *Self, expr: AstNode.Expr.If, ctx: Ctx) !ExprRes {
    _ = self;
    _ = expr;
    _ = ctx;
    return error.todo;
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

/// check if the type of `from` can be coerced into the type of `to`
fn canCoerce(self: *Self, from: *Type, to: *Type) bool {
    _ = self;
    if (from == to) return true;
    return false;
}

/// given two canonical types, determine which type they should coerce into,
/// returns null on a type mismatch
fn unifyTypes(self: *Self, a: *Type, b: *Type) ?*Type {
    _ = self;
    if (a == b) return a;
    return null;
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
    };
}