const std = @import("std");
const Operator = @import("operator.zig").Operator;
const Type = @import("type/type.zig").Type;
const TypeTable = @import("type/table.zig").TypeTable;

pub const AstNode = struct {
    kind: NodeKind,
    /// metadata about the node, defaults to null
    /// but is guaranteed be non-null at the end of semantic analysis
    /// (unless a tragic error occurs)
    meta: ?Meta = null,

    pub const NodeKind = union(enum) {
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

        fn formatIndented(self: *const NodeKind, writer: *std.io.Writer, indent: usize) !void {
            switch (self.*) {
                .root => |nodes| {
                    for (nodes) |node| {
                        try node.kind.formatIndented(writer, indent);
                        try writer.writeByte('\n');
                    }
                },
                .@"const" => |n| {
                    try writeIndent(writer, indent);
                    if (n.type_expr) |t| {
                        try writer.print("const {f} {s} = {f}", .{ t, n.name, n.value });
                    } else {
                        try writer.print("const {s} = {f}", .{ n.name, n.value });
                    }
                },
                .let => |n| {
                    try writeIndent(writer, indent);
                    if (n.type_expr) |t| {
                        try writer.print("let {f} {s} = {f}", .{ t, n.name, n.value });
                    } else {
                        try writer.print("let {s} = {f}", .{ n.name, n.value });
                    }
                },
                .ret => |n| {
                    try writeIndent(writer, indent);
                    try writer.print("ret {f}", .{n.value});
                },
                .@"fn" => |n| {
                    try writeIndent(writer, indent);
                    try writer.print("{s} :: fn(", .{n.name});
                    for (n.params, 0..) |param, i| {
                        try writer.print("{f}", .{param});
                        if (i != n.params.len - 1) try writer.print(", ", .{});
                    }
                    try writer.print(") -> {f} = {f}", .{n.ret, n.body});
                },
                .param => |n| {
                    try writeIndent(writer, indent);
                    try writer.print("{s}: {f}", .{ n.name, n.type_expr });
                },
                .ty_expr => |n| {
                    if (n.nullable) try writer.print("?", .{});
                    try writer.print("{s}", .{n.name});
                },
                .expr => |e| {
                    try writeIndent(writer, indent);
                    switch (e) {
                        .literal => |l| try writer.print("{s} {s}", .{ @tagName(l.kind), l.val }),
                        .ident => |i| try writer.print("{s}", .{i.name}),
                        .call => |c| {
                            try writer.print("{s}(", .{c.name});
                            for (c.args, 0..) |arg, i| {
                                try writer.print("{f}", .{arg});
                                if (i != c.args.len - 1) {
                                    try writer.print(", ", .{});
                                }
                            }
                            try writer.print(")", .{});
                        },
                        .unary => |u| try writer.print("{s}({f})", .{ @tagName(u.op), u.operand }),
                        .binary => |b| try writer.print("{s}({f}, {f})", .{ @tagName(b.op), b.left, b.right }),
                        else => try writer.print("TODO : FORMAT {s} EXPR", .{@tagName(e)}),
                    }
                },
                // else => try writer.print("TODO: impl format for {s}", .{@tagName(self)}),
            }
        }
    };

    pub fn format(self: *const AstNode, writer: *std.io.Writer) !void {
        try writer.print("(", .{});
        try self.kind.formatIndented(writer, 0);
        if (self.meta) |m| {
            try writer.print(" | {f})", .{m});
        } else try writer.print(" | null)", .{});
    }

    pub fn create(alloc: std.mem.Allocator, node: NodeKind) !*AstNode {
        const ptr = try alloc.create(AstNode);
        ptr.* = .{
            .kind = node,
            .meta = null,
        };
        return ptr;
    }
};

pub const Meta = struct {
    /// the concrete type of the node
    ty: *Type,
    /// true when a node is known or can be evaluated at compile time
    constant: bool = false,

    pub fn format(self: Meta, writer: *std.io.Writer) !void {
        if (self.constant) {
            try writer.print("const {f}", .{self.ty.*});
        } else {
            try writer.print("{f}", .{self.ty.*});
        }
    }
};
