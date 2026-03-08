const std = @import("std");
const AstNode = @import("../ast.zig").AstNode;

pub const Parser = @This();

alloc: std.mem.Allocator,
src: []const u8,
pos: usize = 0,

const Self = @This();

const Error = error {
    UnexpectedToken,
    UnexpectedEnd,
    ExpectedKword,
};

/// a map of parsers based on keyword
const parserMap = std.StaticStringMap(*const fn(*Self) Error!*AstNode).initComptime(.{
    .{"fn", parseFn},
    .{"let", parseLet},
    .{"const", parseConst},
});

pub fn init(alloc: std.mem.Allocator, src: []const u8) Self {
    return .{
        .alloc =  alloc,
        .src = src,
    };
}

inline fn eof(self: *Self) bool {
    return self.pos >= self.src.len;
}

inline fn peek(self: *Self) ?u8 {
    if (self.eof()) return null;
    return self.src[self.pos];
}

inline fn peekNoEnd(self: *Self) Error!u8 {
    return self.peek() orelse Error.ExpectedKword;
}

inline fn advance(self: *Self) u8 {
    const c = self.src[self.pos];
    self.pos += 1;
    return c;
}

fn skipWhitespace(self: *Self) void {
    while (!self.eof() and std.ascii.isWhitespace(self.src[self.pos])) {
        self.pos += 1;
    }
}

fn readKword(self: *Self) !*const fn(*Self) Parser.Error!*AstNode {
    self.skipWhitespace();
    const start = self.pos;
    var end = start;
    while (!self.eof()) {
        if (!std.ascii.isAlphanumeric(self.advance())) break;
        end += 1;
    }
    
    const kword = self.src[start..end];
    
    return parserMap.get(kword) orelse return Error.ExpectedKword;
}

/// parse out an ident, return the raw string, or any errors
fn parseIdent(self: *Self) Error![]const u8 {
    self.skipWhitespace();
    const peeked = try self.peekNoEnd();
    if (peeked != '$') {
        return Error.UnexpectedToken;
    }
    const start = self.pos;
    var end = start;

    while (!self.eof()) {
        if (!std.ascii.isAlphanumeric(self.advance())) break;
        end += 1;
    }

    return self.src[start..end];
}

fn parseExpr(self: *Parser) Error!*AstNode {
    self.skipWhitespace();
}

fn parseFn(self: *Self) Error!*AstNode {
    self.skipWhitespace();
    // const name = self.parseIdent();
    return Error.UnexpectedToken;
}

fn parseLet(self: *Self) Error!*AstNode {
    self.skipWhitespace();
    return Error.UnexpectedToken;
}

fn parseConst(self: *Self) Error!*AstNode {
    self.skipWhitespace();
    return Error.UnexpectedToken;
}

pub fn Parse(self: *Self) !*AstNode {
    var root = try std.ArrayList(*AstNode).initCapacity(self.alloc, 0);
    while (true) {
        // get a parser for the next node
        const parser = self.readKword() catch break;
        try root.append(self.alloc, try parser(self));
    }

    return AstNode.create(self.alloc, .{
        .root = try root.toOwnedSlice(self.alloc)
    });
}