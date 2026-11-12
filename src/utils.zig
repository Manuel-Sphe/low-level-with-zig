//! Helpers shared across data structures and algorithms.
const std = @import("std");

/// Deep equality: compares what values contain, not where they live in memory.
/// Recurses into slices, arrays, structs, optionals and tagged unions, so a
/// `struct { name: []const u8 }` or a `[]const []const u8` compares by text.
pub fn eql(comptime T: type, a: T, b: T) bool {
    // annotated so ZLS knows the tags (.int, .float, ...) and can complete them
    const info: std.builtin.Type = @typeInfo(T);
    switch (info) {
        .pointer => |ptr| switch (ptr.size) {
            // slices (like []const u8 or [][]const u8): same length and every element equal
            .slice => {
                if (a.len != b.len) return false;
                for (a, b) |x, y| {
                    if (!eql(ptr.child, x, y)) return false;
                }
                return true;
            },
            // single and many-item pointers (*T, [*]T): compare addresses,
            // since we can't know how much memory they point at
            .one, .many, .c => return a == b,
        },
        .array => |arr| {
            for (a, b) |x, y| {
                if (!eql(arr.child, x, y)) return false;
            }
            return true;
        },
        .@"struct" => |s| {
            // packed structs are plain integers underneath, so `==` works
            if (s.layout == .@"packed") return a == b;
            inline for (s.field_names, s.field_types) |name, FieldType| {
                if (!eql(FieldType, @field(a, name), @field(b, name))) return false;
            }
            return true;
        },
        .optional => |opt| {
            const x = a orelse return b == null;
            const y = b orelse return false;
            return eql(opt.child, x, y);
        },
        .@"union" => |u| {
            if (u.layout == .@"packed") return a == b;
            const Tag = u.tag_type orelse @compileError("can't compare untagged union " ++ @typeName(T));
            if (@as(Tag, a) != @as(Tag, b)) return false;
            switch (a) {
                inline else => |payload, tag| return eql(@TypeOf(payload), payload, @field(b, @tagName(tag))),
            }
        },
        // ints, floats, bools, enums, error sets, vectors, void, ...
        else => return std.meta.eql(a, b),
    }
}

/// `eql` specialised to one type, so it can be passed where `fn (T, T) bool` is expected
pub fn eqlFn(comptime T: type) fn (T, T) bool {
    return struct {
        fn call(a: T, b: T) bool {
            return eql(T, a, b);
        }
    }.call;
}

test "eql: slices and nested slices compare by content" {
    var hi = "hi".*;
    try std.testing.expect(eql([]const u8, "hi", &hi));
    try std.testing.expect(!eql([]const u8, "hi", "ho"));
    try std.testing.expect(!eql([]const u8, "hi", "hii"));
    try std.testing.expect(eql([]const []const u8, &.{ "a", "b" }, &.{ "a", "b" }));
}

test "eql: structs, optionals and unions recurse" {
    const P = struct { name: []const u8, tags: [2]u8 };
    var ada = "ada".*;
    try std.testing.expect(eql(P, .{ .name = "ada", .tags = .{ 1, 2 } }, .{ .name = &ada, .tags = .{ 1, 2 } }));
    try std.testing.expect(!eql(P, .{ .name = "ada", .tags = .{ 1, 2 } }, .{ .name = "ada", .tags = .{ 1, 3 } }));

    try std.testing.expect(eql(?u8, null, null));
    try std.testing.expect(!eql(?u8, null, 0));

    const U = union(enum) { n: i32, s: []const u8 };
    try std.testing.expect(eql(U, .{ .s = "x" }, .{ .s = "x" }));
    try std.testing.expect(!eql(U, .{ .n = 0 }, .{ .s = "x" }));
}

test "eql: single pointers compare by address" {
    var a: i32 = 1;
    var b: i32 = 1;
    try std.testing.expect(eql(*i32, &a, &a));
    try std.testing.expect(!eql(*i32, &a, &b));
}
