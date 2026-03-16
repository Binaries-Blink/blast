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

pub const Error = error {
    UnknownSymbol,
    UndefinedSymbol,
    UnknownType,
    UnsupportedType,
    TypeMismatch,
    ExpectedRootNode,
    DuplicateDefinition,
    InferenceNotSupported,
    InvalidUnaryOp,
    InvalidBinaryOp,
    InvalidUnaryOperand,
    InvalidBinaryOperand,
    NonNumericHint,
    ExpectedComptimeValue,
    OutOfMemory,
};

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
    /// if the result is something that can be
    /// fully known at compile time, and is thus
    /// valid for assignment to a constant
    constant: bool = false
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
pub fn analyze(self: *Self, node: *AstNode) Error!void {
    if (node.* != .root) return Error.ExpectedRootNode;

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
fn analyseTop(self: *Self, node: *AstNode) Error!void {
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
fn analyzeFull(self: *Self, node: *AstNode, ctx: Ctx) Error!void {
    switch (node.*) {
        .@"const" => |n| {
            const result = try self.analyzeAssignment(n.name, n.type_expr, n.value, ctx, .constant);
            if (!result.constant) return Error.ExpectedComptimeValue;
        },
        .let => |n| {
            _ = try self.analyzeAssignment(n.name, n.type_expr, n.value, ctx, .variable);
        },
        .@"fn" => |n| {
            var sym = self.global.get(n.name) orelse return Error.UnknownSymbol;
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
            std.debug.print("todo : {s}\n", .{@tagName(n)});
            return Error.UnknownSymbol;
        },
    }
}

fn analyzeAssignment(
    self: *Self,
    name: []const u8,
    ty_expr: ?*AstNode,
    value: *AstNode,
    ctx: Ctx,
    kind: Symbol.SymbolKind,
) Error!ExprRes {
    const hint = if (ty_expr) |te|
        try self.resolveType(try readTypeExpr(self.alloc, te.ty_expr))
    else null;

    const expr_ctx = Ctx {
        .scope = ctx.scope,
        .expected_ty = hint,
        .ret_ty = ctx.ret_ty,
    };

    const result = try self.analyzeExpr(&value.expr, expr_ctx);

    const ty = if (hint) |h| blk: {
        if (!canCoerce(result.ty, h)) return Error.TypeMismatch;
        break :blk h;
    } else result.ty;
    
    try ctx.scope.insert(name, Symbol {
        .kind = kind,
        .ty = ty,
        .node = value,
        .constant = kind == .constant,
    });

    return ExprRes {
        .ty = ty,
        .constant = result.constant,
    };
}

/// performs full analysis of an expression node
fn analyzeExpr(self: *Self, expr: *AstNode.Expr, ctx: Ctx) Error!ExprRes {
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

fn analyzeLiteral(self: *Self, lit: AstNode.Expr.Literal, ctx: Ctx) Error!ExprRes {
    const ty = switch (lit.kind) {
        .numeric => blk: {
            const integer = std.mem.indexOfScalar(u8, lit.val, '.') == null;
            const hint = ctx.expected_ty orelse {
                if (integer) break :blk self.table.get(.{
                    .primitive = .{
                        .int = .{ .signed = true, .bits = 32 }
                    }});
                break :blk self.table.get(.{ .primitive = .f32 });
            };

            if (integer and hint.isInteger()) break :blk hint;
            if (!integer and hint.isFloat()) break :blk hint;
            // this point should be unreachable, getting here
            // would mean the type hint isn't correct.
            return Error.NonNumericHint;
        },
        .char => self.table.get(.{ .primitive = .char }),
        .bool => self.table.get(.{ .primitive = .bool }),
        .string => return Error.UnknownSymbol,
    };

    return .{
        .ty = ty,
        .constant = true,
    };
}

fn analyzeIdent(self: *Self, ident: AstNode.Expr.Ident, ctx: Ctx) Error!ExprRes {
    _ = self;
   const sym = ctx.scope.lookup(ident.name)
       orelse return Error.UndefinedSymbol;
    return .{
        .ty = sym.ty,
        .constant = sym.constant
    };
}

fn analyzeUnary(self: *Self, op: AstNode.Expr.UnOp, ctx: Ctx) Error!ExprRes {
    const operand = try self.analyzeExpr(&op.operand.expr, ctx);
    const ty = switch (op.op) {
        .Sub => blk: {
            if (!operand.ty.isNumeric()) return Error.InvalidUnaryOperand;
            break :blk operand.ty;
        },
        else => return Error.InvalidUnaryOp,
    };

    return .{
        .ty = ty,
        .constant = operand.constant,
    };
}

fn analyzeBinary(self: *Self, op: AstNode.Expr.BinOp, ctx: Ctx) Error!ExprRes {
    const lhs = try self.analyzeExpr(&op.left.expr, ctx);
    const rhs = try self.analyzeExpr(&op.right.expr, .{
        .scope = ctx.scope,
        .ret_ty = ctx.ret_ty,
        .expected_ty = lhs.ty,
    });

    const ty = switch (op.op) {
        // arithmetic ops (both operands must be numbers)
        .Add, .Sub, .Mul, .Div, .Mod => blk: {
            if (!lhs.ty.isNumeric()) return Error.InvalidBinaryOperand;
            if (!rhs.ty.isNumeric()) return Error.InvalidBinaryOperand;
            const unified = unifyTypes(lhs.ty, rhs.ty)
                orelse return Error.TypeMismatch;
            break :blk unified;
        },
        // comparison ops operands must be the same, always returns a bool
        .Eq, .Neq, .Gt, .Ge, .Lt, .Le, => blk: {
            _ = unifyTypes(lhs.ty, rhs.ty)
                orelse return Error.TypeMismatch;
            break :blk self.table.get(.{ .primitive = .bool });
        },
        // logical ops, both operands must be bool, always returns a bool
        .And, .Or => blk: {
            const bool_ty = self.table.get(.{ .primitive = .bool });
            if (lhs.ty != bool_ty) return Error.InvalidBinaryOperand;
            if (rhs.ty != bool_ty) return Error.InvalidBinaryOperand;
            break :blk bool_ty;
        },
        // todo : other kinds of operators (bitwise, and other wacky shit)
        else => return Error.InvalidBinaryOp,
    };

    return .{
        .ty = ty,
        .constant = lhs.constant & rhs.constant,
    };
}

fn analyzeBlock(self: *Self, block: AstNode.Expr.Block, ctx: Ctx) Error!ExprRes {
    _ = self;
    _ = block;
    _ = ctx;
    return Error.UnknownSymbol;
}

fn analyzeCall(self: *Self, call: AstNode.Expr.FnCall, ctx: Ctx) Error!ExprRes {
    _ = self;
    _ = call;
    _ = ctx;
    return Error.UnknownSymbol;
}

fn analyzeIf(self: *Self, if_expr: AstNode.Expr.If, ctx: Ctx) Error!ExprRes {
    _ = self;
    _ = if_expr;
    _ = ctx;
    return Error.UnknownSymbol;
}

/// resolve a type pointer to its canonical pointer via the table
fn resolveType(self: *Self, ty: *Type) Error!*Type {
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
                return Error.UnknownType;
            },
            .Unknown => return Error.UnknownType,
        },
        else => return Error.UnsupportedType,
    }
}

/// check if the type of `from` can be coerced into the type of `to`
fn canCoerce(from: *Type, to: *Type) bool {
    if (from == to) return true;
    return switch (from.*) {
        .primitive => |p| switch(p) {
            .int_literal => to.isInteger(),
            .float_literal => to.isFloat(),
            else => false,
        },
        else => false,
    };
}

/// given two canonical types, determine which type they should coerce into,
/// returns null on a type mismatch
fn unifyTypes(a: *Type, b: *Type) ?*Type {
    if (a == b) return a;
    if (a.isNumericLiteral() and b.isConcreteNumeric()) return b;
    if (a.isConcreteNumeric() and b.isNumericLiteral()) return a;
    return null;
}

fn inferType(self: *Self, node: *AstNode) Error!*Type {
    switch (node.*) {
        .expr => |*e| return try self.inferExprType(e),
        else => return Error.InferenceNotSupported,
    }
}

fn inferExprType(self: *Self, expr: *AstNode.Expr) Error!*Type {
    _ = self;
    return switch (expr.*) {
        .literal => Error.UnKnownSymbol,
        .ident => Error.UnKnownSymbol,
        .unary => Error.UnKnownSymbol,
        .binary => Error.UnKnownSymbol,
        .block => Error.UnKnownSymbol,
        .call => Error.UnKnownSymbol,
        .@"if" => Error.UnKnownSymbol,
    };
}