const std = @import("std");
const Operator = @import("operator.zig").Operator;
const Type = @import("type/type.zig").Type;
const TypeTable = @import("type/table.zig").TypeTable;

pub const AstNode = union(enum) {
    /// the root of the file, contains all top level nodes
    root: []*AstNode,

    /// constant declaration
    @"const": ConstStmt,
    /// variable declaration
    let: LetStmt,
    /// return statement
    ret: RetStmt,
    /// function declaration
    @"fn": FnStmt,
    /// a function parameter
    param: Param,
    /// some type
    ty_expr: TypeExpr,
    /// any expression / a thing that can be evaluated
    expr: Expr,

    const Self = @This();

    pub const ConstStmt = struct {
        name: []const u8,
        type_expr: ?*AstNode,
        value: *AstNode,
    };

    pub const LetStmt = struct {
        name: []const u8,
        type_expr: ?*AstNode,
        value: *AstNode,
    };

    pub const Expr = union(enum) {
        literal: Literal,
        ident: Ident,
        call: FnCall,
        unary: UnOp,
        binary: BinOp,
        @"if": If,
        block: Block,

        pub const LiteralKind = enum {
            numeric,
            bool,
            char,
            string,
        };

        pub const Literal = struct {
            kind: LiteralKind,
            val: []const u8,
        };

        pub const Ident = struct {
            name: []const u8,
        };

        pub const FnCall = struct {
            name: []const u8,
            args: []*AstNode,
        };

        pub const UnOp = struct {
            op: Operator,
            operand: *AstNode,
        };

        pub const BinOp = struct {
            op: Operator,
            left: *AstNode,
            right: *AstNode,
        };

        pub const If = struct {
            clause: *AstNode,
            then: *AstNode,
            @"else": ?*AstNode,
        };

        pub const Block = struct {
            contents: []*AstNode,
        };
    };

    pub const RetStmt = struct {
        value: *AstNode,
    };

    pub const FnStmt = struct {
        name: []const u8,
        params: []*AstNode,
        ret: *AstNode,
        body: *AstNode,
    };

    pub const Param = struct {
        name: []const u8,
        type_expr: *AstNode,
    };

    pub const TypeExpr = struct {
        name: []const u8,
        nullable: bool = false,
    };

    fn writeIndent(writer: *std.io.Writer, i: usize) !void {
        for (0..i) |_| {
            try writer.print("  ", .{});
        }
    }

    fn formatIndented(self: AstNode, writer: *std.io.Writer, indent: usize) !void {
        switch (self) {
            .root => |nodes| {
                for (nodes) |node| {
                    try node.formatIndented(writer, indent);
                    try writer.writeByte('\n');
                }
            },
            .@"const" => |n| {
                try writeIndent(writer, indent);
                if (n.type_expr) |t| {
                    try writer.print("const {f} {s} = {f}", .{t, n.name, n.value});
                }  else {
                    try writer.print("const {s} = {f}", .{n.name, n.value});
                }
            },
            .let => |n| {
                try writeIndent(writer, indent);
                if (n.type_expr) |t| {
                    try writer.print("let {f} {s} = {f}", .{t, n.name, n.value});
                }  else {
                    try writer.print("let {s} = {f}", .{n.name, n.value});
                }
            },
            // .@"if" => |n| {
            //     try writeIndent(writer, indent);
            //     try writer.print("if ", .{});
            //     try n.clause.formatIndented(writer, indent);
            //     try writer.print(" then:\n", .{});
            //
            //     try n.then.formatIndented(writer, indent);
            //
            //     if (n.@"else") |else_block| {
            //         try writer.writeByte('\n');
            //         try writeIndent(writer, indent);
            //         try writer.print("else:\n", .{});
            //         try else_block.formatIndented(writer, indent);
            //     }
            // },
            // .ret => |n| {
            //     try writeIndent(writer, indent);
            //     try writer.print("ret {f}", .{n.value});
            // },
            // .@"fn" => |n| try writer.print("{s} :: fn({f}) -> {f} {{\n{f}\n}}", .{n.name, n.params, n.ret, n.body}),
            // .param => |n| try writer.print("{s}: {f}", .{n.name, n.type}),
            // .type => |n| {
            //     if (n.nullable) {
            //         try writer.print("?", .{});
            //     }
            //     try writer.print("{s}", .{n.name});
            // },
            // .block => |n| {
            //     for (n.statements, 0..) |stmt, i| {
            //         if (i != 0) {
            //             try writer.writeByte('\n');
            //         }
            //         try stmt.formatIndented(writer, indent + 1);
            //     }
            // },
            // .literal => |n| {
            //     try writeIndent(writer, indent);
            //     try writer.print("{s}", .{n.val.raw});
            // },
            // .ident => |n| {
            //     try writeIndent(writer, indent);
            //     try writer.print("{s}", .{n.name.raw});
            // },
            // .call => |n| {
            //     try writeIndent(writer, indent);
            //     try writer.print("{s}(", .{n.name.raw});
            //     for (n.args, 0..) |arg, i| {
            //         try writer.print("{f}", .{arg});
            //         if (i != n.args.len - 1) {
            //             try writer.print(", ", .{});
            //         }
            //     }
            //     try writer.print(")", .{});
            // },
            // .unary => |n| try writer.print("{s}({f})", .{@tagName(n.op.type), n.operand}),
            // .binary => |n| try writer.print("{s}({f}, {f})", .{@tagName(n.op.type), n.left, n.right}),
            else => try writer.print("TODO: impl format for {s}", .{@tagName(self)}),
        }
    }

    pub fn create(alloc: std.mem.Allocator, node: AstNode) !*AstNode {
        const ptr = try alloc.create(AstNode);
        ptr.* = node;
        return ptr;
    }

    pub fn format(self: AstNode, writer: *std.io.Writer) !void {
        try self.formatIndented(writer, 0);
    }
};