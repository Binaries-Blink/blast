pub const AstNode = @import("ast.zig").AstNode;
pub const Operator = @import("operator.zig").Operator;

pub const Analyzer = @import("semantic/analyzer.zig").Analyzer;

pub const TypeTable = @import("type/table.zig").TypeTable;
pub const Type = @import("type/type.zig").Type;

pub const Scope = @import("scope/scope.zig").Scope;
pub const Symbol = @import("scope/symbol.zig").Symbol;

test "semantic" {
    const std = @import("std");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = arena.deinit();
    const alloc = arena.allocator();

    var root: [2] *AstNode = (try alloc.alloc(*AstNode, 2))[0..2].*;
    root[0] = try AstNode.create(alloc, .{
        .@"fn" = .{
            .name = "double",
            .params = @constCast(&[_]*AstNode {try AstNode.create(alloc,
                .{
                    .param = .{
                        .name = "n",
                    .type_expr = try AstNode.create(alloc, .{
                        .ty_expr = .{ .name = "u32" }
                    }),
                }})}),
            .ret = try AstNode.create(alloc, .{
                .ty_expr = .{ .name = "u32" }
            }),
            .body = try AstNode.create(alloc, .{ .expr =
                .{.binary = .{
                    .op = .Add,
                    .left = try AstNode.create(alloc, .{ .expr = .{ .ident = .{ .name = "n" }}}),
                    .right = try AstNode.create(alloc, .{ .expr = .{ .ident = .{ .name = "n" }}}),
                }}
            })
        }
    });
    root[1] = try AstNode.create(alloc, .{ .let = .{
        .name = "x" ,
        .type_expr = null,
        .value = try AstNode.create(alloc, .{ .expr = .{
            .call = .{
                .name = "double",
                .args = @constCast(&[1]*AstNode {try AstNode.create(alloc, .{ .expr = .{
                    .literal = .{
                        .kind = .numeric,
                        .val = "5",
                    }
                }})}),
            },
        }})
    }});

    const testAst = try AstNode.create(alloc, .{ .root = @constCast(&root)});
    var analyzer = try Analyzer.init(alloc);
    try analyzer.analyze(testAst);

    std.debug.print("{f}\n\n", .{testAst});

    std.debug.print("{f}\n", .{analyzer.table});

    var global = analyzer.global.*.symbols.iterator();
    while (global.next()) |entry| {
        std.debug.print("{s} : {f}\n", .{entry.key_ptr.*, entry.value_ptr.*.ty});
    }
}