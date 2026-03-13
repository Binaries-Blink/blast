const std = @import("std");

pub const Type = union(enum) {
    primitive: Primitive,
    @"struct": Struct,
    function: Function,
    optional: Optional,
    unresolved: Unresolved,

    pub const Primitive = union(enum) {
        void,
        bool,
        /// integer literals, can be coerced into any integer type,
        /// assuming the target can store the value
        int_literal,
        /// floating point literals, can be coerced into any float type,
        /// assuming the target can store the value
        float_literal,
        char,
        int: Int,
        f32,
        f64,
        f80,
        f128,

        pub const Int = struct {
            signed: bool,
            bits: u16,

            pub fn fromName(name: []const u8) ?Type {
                if (name.len < 2) return null;

                const signed = switch (name[0]) {
                    'i' => true,
                    'u' => false,
                    else => return null,
                };

                const bits = std.fmt.parseInt(u16, name[1..], 10) catch return null;

                if (bits == 0) return null;

                return Type {
                    .primitive = .{
                        .int = Int {
                            .signed = signed,
                            .bits = bits,
                        }
                    }
                };
            }
        };
    };

    pub const Struct = struct {
        // todo : structs are not supported yet
    };

    pub const Function = struct {
        params: []*Type,
        @"return": *Type,
    };

    pub const Optional = struct {
        inner: *Type,
    };

    pub const Unresolved = union(enum) {
        named: Named,
        Unknown,

        pub const Named = struct {
            name: []const u8,
        };

        pub fn format(self: Unresolved, writer: *std.io.Writer) !void {
            switch (self) {
                .named => |u| try writer.print("Named({s})", .{u.name}),
                .Unknown => try writer.print("Unknown", .{}),
            }
        }
    };

    pub fn create(alloc: std.mem.Allocator, ty: Type) !*Type {
        const ptr = try alloc.create(Type);
        ptr.* = ty;
        return ptr;
    }

    pub fn format(self: Type, writer: *std.io.Writer) !void {
        switch (self) {
            .@"struct" => try writer.print("TODO : FORMAT STRUCT", .{}),
            .function => |t| {
                try writer.print("(", .{});
                for (t.params, 0..) |param, i| {
                    try writer.print("{f}", .{param});
                    if (i != t.params.len - 1) {
                        try writer.print(", ", .{});
                    }
                }
                try writer.print(") -> {f}", .{t.@"return"});
            },
            .primitive => |t| {
                if (t == .int) {
                    switch (t.int.signed) {
                        true => try writer.print("i{d}", .{t.int.bits}),
                        false => try writer.print("u{d}", .{t.int.bits}),
                    }
                    return;
                }
                try writer.print("{s}", .{ @tagName(t) });
            },
            .optional => |t| try writer.print("Optional({f})", .{t.inner}),
            .unresolved => |t| try writer.print("{f}", .{t}),
        }
    }

    pub fn isUnknown(ty: Type) bool {
        return switch (ty) {
            .unresolved => |u| switch(u) {
                .Unknown => true,
                else => false,
            },
            else => false,
        };
    }

    pub fn isInteger(ty: Type) bool {
        if (ty != .primitive) return false;
        return ty.primitive == .int or ty.primitive == .int_literal;
    }

    pub fn isFloat(ty: Type) bool {
        if (ty != .primitive) return false;
        const prim = ty.primitive;
        return prim == .float_literal
            or prim == .f32
            or prim == .f64
            or prim == .f80
            or prim == .f128;
    }

    pub fn isNumericLiteral(ty: Type) bool {
        if (ty != .primitive) return false;
        if (ty.primitive == .int_literal) return true;
        if (ty.primitive == .float_literal) return true;
        return false;
    }

    pub fn isConcreteNumeric(ty: Type) bool {
        if (ty != .primitive) return false;
        const prim = ty.primitive;
        return prim == .int
            or prim == .f32
            or prim == .f64
            or prim == .f80
            or prim == .f128;
    }

    pub fn isNumeric(ty: Type) bool {
        return ty.isInteger() or ty.isNumeric();
    }
};