const std = @import("std");
const Allocator = std.mem.Allocator;
const utils = @import("../utils.zig");

pub fn LinkedList(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Private: callers get `*T` from `find`, so they can't touch the links
        /// and break the list or `len`.
        const Node = struct {
            value: T,
            next: ?*Node,

            /// Allocates a node on the heap. Free it with `destroy`.
            fn create(allocator: Allocator, value: T, next: ?*Node) Allocator.Error!*Node {
                const node = try allocator.create(Node);
                node.* = .{ .value = value, .next = next };
                return node;
            }

            fn destroy(self: *Node, allocator: Allocator) void {
                allocator.destroy(self);
            }
        };

        head: ?*Node = null,
        allocator: Allocator,
        len: usize = 0,

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            // start at the head
            var curr = self.head;
            while (curr) |node| {
                const next_node = node.next;
                node.destroy(self.allocator);
                curr = next_node;
            }

            self.head = null;
            self.len = 0;
        }

        pub fn addFront(self: *Self, value: T) Allocator.Error!void {
            self.head = try Node.create(self.allocator, value, self.head);
            self.len += 1;
        }

        pub fn addBack(self: *Self, value: T) Allocator.Error!void {
            const new_node = try Node.create(self.allocator, value, null);

            self.len += 1;
            var curr = self.head orelse {
                self.head = new_node;
                return;
            };

            while (curr.next) |node| {
                curr = node;
            }

            curr.next = new_node;
        }

        pub fn contains(self: *const Self, value: T) bool {
            return self.find(value) != null;
        }

        /// Returns a pointer to the first value equal to `target`, comparing by content
        /// (see `utils.eql`), or null. Use `findBy` when you need a different notion of equal.
        /// The pointer can be used to read or change the value in place.
        pub fn find(self: *const Self, target: T) ?*T {
            return self.findBy(target, utils.eqlFn(T));
        }

        /// Like `find`, but `isEqual(target, value)` decides what counts as equal,
        /// e.g. case-insensitive strings or matching only an `id` field.
        pub fn findBy(self: *const Self, target: T, comptime isEqual: fn (T, T) bool) ?*T {
            var curr = self.head;
            while (curr) |node| : (curr = node.next) {
                if (isEqual(target, node.value)) {
                    return &node.value;
                }
            }

            return null;
        }
    };
}

// Generic code is only type-checked once it's used with a concrete type,
// so this test is also what lets `zig build check` catch errors in LinkedList.
test "LinkedList(i32)" {
    var list = LinkedList(i32).init(std.testing.allocator);
    defer list.deinit();

    try list.addFront(2);
    try list.addFront(1);
    try list.addBack(3);

    try std.testing.expect(list.contains(3));
    try std.testing.expect(!list.contains(42));
    try std.testing.expectEqual(@as(i32, 2), list.find(2).?.*);
}

test "LinkedList: struct with a string field compares by text" {
    const Person = struct { name: []const u8, age: u8 };
    var list = LinkedList(Person).init(std.testing.allocator);
    defer list.deinit();

    try list.addFront(.{ .name = "ada", .age = 36 });

    // same text, but stored in different memory than the literal above
    var name = "ada".*;
    try std.testing.expect(list.contains(.{ .name = &name, .age = 36 }));
    try std.testing.expect(!list.contains(.{ .name = "ada", .age = 37 }));
    try std.testing.expect(!list.contains(.{ .name = "bob", .age = 36 }));
}

test "LinkedList: list of strings" {
    var list = LinkedList([]const []const u8).init(std.testing.allocator);
    defer list.deinit();

    try list.addFront(&.{ "a", "b" });

    try std.testing.expect(list.contains(&.{ "a", "b" }));
    try std.testing.expect(!list.contains(&.{ "a", "c" }));
    try std.testing.expect(!list.contains(&.{"a"}));
}

test "LinkedList: optionals and tagged unions compare by payload" {
    const Shape = union(enum) { circle: f32, label: []const u8, empty };
    var list = LinkedList(?Shape).init(std.testing.allocator);
    defer list.deinit();

    var text = "hi".*;
    try list.addFront(.{ .label = &text });
    try list.addFront(.empty);
    try list.addFront(null);

    try std.testing.expect(list.contains(.{ .label = "hi" }));
    try std.testing.expect(list.contains(.empty));
    try std.testing.expect(list.contains(null));
    try std.testing.expect(!list.contains(.{ .circle = 1.0 }));
}

test "LinkedList: single pointers compare by address" {
    var a: i32 = 1;
    var b: i32 = 1;
    var list = LinkedList(*i32).init(std.testing.allocator);
    defer list.deinit();

    try list.addFront(&a);

    try std.testing.expect(list.contains(&a));
    try std.testing.expect(!list.contains(&b)); // same value, different variable
}

test "LinkedList: findBy with a custom comparison" {
    const User = struct { id: u32, name: []const u8 };
    var list = LinkedList(User).init(std.testing.allocator);
    defer list.deinit();

    try list.addFront(.{ .id = 7, .name = "ada" });

    const sameId = struct {
        fn f(a: User, b: User) bool {
            return a.id == b.id;
        }
    }.f;
    const found = list.findBy(.{ .id = 7, .name = "" }, sameId) orelse return error.NotFound;
    try std.testing.expectEqualStrings("ada", found.name);
}

test "LinkedList: len counts every add, including addBack on an empty list" {
    var list = LinkedList(i32).init(std.testing.allocator);
    defer list.deinit();

    try list.addBack(1);
    try list.addBack(2);
    try list.addFront(0);
    try std.testing.expectEqual(@as(usize, 3), list.len);

    list.deinit();
    try std.testing.expectEqual(@as(usize, 0), list.len);
}

test "LinkedList: find returns a pointer to the value, which can change it in place" {
    var list = LinkedList(i32).init(std.testing.allocator);
    defer list.deinit();

    try list.addBack(1);
    try list.addBack(2);

    const two: ?*i32 = list.find(2);
    two.?.* = 20;

    try std.testing.expect(list.contains(20));
    try std.testing.expect(!list.contains(2));
    try std.testing.expect(list.find(42) == null);
}
