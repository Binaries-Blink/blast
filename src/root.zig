pub const AstNode = @import("ast.zig").AstNode;
pub const Operator = @import("operator.zig").Operator;

pub const Analyzer = @import("semantic/analyzer.zig").Analyzer;

pub const TypeTable = @import("type/table.zig").TypeTable;
pub const Type = @import("type/type.zig").Type;

pub const Scope = @import("scope/scope.zig").Scope;
pub const Symbol = @import("scope/symbol.zig").Symbol;

pub const Parser = @import("IR/Parser.zig");

test "test" {
    const std = @import("std");

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer _ = arena.deinit();
    const alloc = arena.allocator();

    // read test code
    std.debug.print("reading test file\n", .{});
    const file = try std.fs.cwd().openFile("test.txt", .{});
    defer file.close();
    const size = (try file.stat()).size;
    const content = try file.readToEndAlloc(alloc, size);
    std.debug.print("read {d} bytes\n", .{size});

    // parse it
    std.debug.print("parsing text\n", .{});
    var parser = Parser.init(alloc, content);
    const root = try parser.Parse();

    // display ast
    std.debug.print("{f}\n", .{root.*});
    std.debug.print("parsing complete with {d} top level nodes\n", .{root.root.len});

    // semantic analysis

    // display type table

    // optimize

    // display optimized ast

}