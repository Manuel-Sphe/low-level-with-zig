const std = @import("std");
const Allocator = std.mem.Allocator;
const utils = @import("../utils.zig");

pub const IteratorError = error{
    /// `next` was called after the last value (`hasNext` is false)
    NoSuchElement,
    /// `peek`, `changeHere` or `delete` was called with no node at the position
    IllegalState,
};

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

        /// Walks the list and edits it in place. `position` is the node `next` will
        /// return; `previous` is the node before it (null at the head), which is what
        /// lets `addHere` and `delete` relink the list.
        ///
        ///     var it = list.iterator();
        ///     while (it.hasNext()) {
        ///         const value = try it.next();
        ///         ...
        ///     }
        ///
        /// Don't change the list through anything else while iterating.
        pub const Iterator = struct {
            list: *Self,
            position: ?*Node,
            previous: ?*Node = null,

            pub fn hasNext(it: *const Iterator) bool {
                return it.position != null;
            }

            /// Returns the value at `position` and moves one node forward.
            pub fn next(it: *Iterator) IteratorError!*const T {
                const node = it.position orelse return error.NoSuchElement;
                it.previous = node;
                it.position = node.next;
                // Point at the value inside the node: it lives as long as the node.
                return &node.value;
            }

            /// Returns the value `next` would return, without moving.
            pub fn peek(it: *const Iterator) IteratorError!*const T {
                const node = it.position orelse return error.IllegalState;
                return &node.value;
            }

            /// Inserts `value` before `position`, and moves `previous` onto the new
            /// node, so `next` still returns the same value it would have. At the end
            /// of the list this appends; on an empty list it adds the only node.
            pub fn addHere(it: *Iterator, value: T) Allocator.Error!void {
                const new_node = try Node.create(it.list.allocator, value, it.position);
                if (it.previous) |prev| {
                    prev.next = new_node;
                } else {
                    // Nothing before `position`: the new node becomes the head
                    it.list.head = new_node;
                }
                it.previous = new_node;
                it.list.len += 1;
            }

            /// Replaces the value at `position`.
            pub fn changeHere(it: *Iterator, value: T) IteratorError!void {
                const node = it.position orelse return error.IllegalState;
                node.value = value;
            }

            /// Removes and frees the node at `position`, and moves `position` to the
            /// node after it. `previous` stays where it is.
            pub fn delete(it: *Iterator) IteratorError!void {
                const node = it.position orelse return error.IllegalState;
                // Unlink first, so nothing points at the node once it's freed
                if (it.previous) |prev| {
                    prev.next = node.next;
                } else {
                    it.list.head = node.next;
                }
                it.position = node.next;
                // Unlike Java, nothing frees an unreachable node for us
                node.destroy(it.list.allocator);
                it.list.len -= 1;
            }
        };

        /// Starts an iterator at the head. See `Iterator`.
        pub fn iterator(self: *Self) Iterator {
            return .{ .list = self, .position = self.head };
        }

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            var current = self.head;
            while (current) |node| {
                // Save the next node first: `node` is freed on the next line
                const next = node.next;
                node.destroy(self.allocator);
                current = next;
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
            var tail = self.head orelse {
                self.head = new_node;
                return;
            };

            while (tail.next) |node| {
                tail = node;
            }

            tail.next = new_node;
        }

        pub fn contains(self: *const Self, value: T) bool {
            return self.find(value) != null;
        }

        /// Returns a read-only pointer to the first value equal to `target`, comparing by
        /// content (see `utils.eql`), or null. Use `findBy` when you need a different notion
        /// of equal, and `Iterator.changeHere` to change a value in place.
        pub fn find(self: *const Self, target: T) ?*const T {
            return self.findBy(target, utils.eqlFn(T));
        }

        /// Like `find`, but `isEqual(target, value)` decides what counts as equal,
        /// e.g. case-insensitive strings or matching only an `id` field.
        pub fn findBy(self: *const Self, target: T, comptime isEqual: fn (T, T) bool) ?*const T {
            var current = self.head;
            while (current) |node| : (current = node.next) {
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

test "LinkedList: find returns a read-only pointer to the value" {
    var list = LinkedList(i32).init(std.testing.allocator);
    defer list.deinit();

    try list.addBack(1);
    try list.addBack(2);

    const two: ?*const i32 = list.find(2);
    try std.testing.expectEqual(@as(i32, 2), two.?.*);
    try std.testing.expect(list.find(42) == null);
}

/// Collects the list's values front to back, so tests can check the order
fn expectValues(list: *LinkedList(i32), expected: []const i32) !void {
    var values: std.ArrayList(i32) = .empty;
    defer values.deinit(std.testing.allocator);

    var it = list.iterator();
    while (it.hasNext()) {
        try values.append(std.testing.allocator, (try it.next()).*);
    }
    try std.testing.expectEqualSlices(i32, expected, values.items);
    try std.testing.expectEqual(expected.len, list.len);
}

test "LinkedList.Iterator: next walks front to back, then errors" {
    var list = LinkedList(i32).init(std.testing.allocator);
    defer list.deinit();
    try list.addBack(1);
    try list.addBack(2);

    var it = list.iterator();
    try std.testing.expectEqual(@as(i32, 1), (try it.peek()).*);
    try std.testing.expectEqual(@as(i32, 1), (try it.next()).*);
    try std.testing.expectEqual(@as(i32, 2), (try it.next()).*);
    try std.testing.expect(!it.hasNext());
    try std.testing.expectError(error.NoSuchElement, it.next());
    try std.testing.expectError(error.IllegalState, it.peek());
}

test "LinkedList.Iterator: addHere inserts at the head, middle, end, and into an empty list" {
    var list = LinkedList(i32).init(std.testing.allocator);
    defer list.deinit();

    var it = list.iterator();
    try it.addHere(2); // empty list: only node
    try expectValues(&list, &.{2});

    it = list.iterator();
    try it.addHere(0); // at the head
    try expectValues(&list, &.{ 0, 2 });

    it = list.iterator();
    _ = try it.next(); // past 0
    try it.addHere(1); // between 0 and 2
    try std.testing.expectEqual(@as(i32, 2), (try it.next()).*); // next is unchanged
    try it.addHere(3); // past the end: appends
    try expectValues(&list, &.{ 0, 1, 2, 3 });
}

test "LinkedList.Iterator: changeHere replaces the value at the position" {
    var list = LinkedList(i32).init(std.testing.allocator);
    defer list.deinit();
    try list.addBack(1);
    try list.addBack(2);

    var it = list.iterator();
    _ = try it.next();
    try it.changeHere(20);
    try expectValues(&list, &.{ 1, 20 });

    _ = try it.next();
    try std.testing.expectError(error.IllegalState, it.changeHere(30)); // past the end
}

test "LinkedList.Iterator: delete removes and frees nodes at the head, middle and end" {
    // std.testing.allocator fails the test if any deleted node isn't freed
    var list = LinkedList(i32).init(std.testing.allocator);
    defer list.deinit();
    for ([_]i32{ 1, 2, 3, 4 }) |value| try list.addBack(value);

    var it = list.iterator();
    try it.delete(); // head
    try expectValues(&list, &.{ 2, 3, 4 });
    try std.testing.expectEqual(@as(i32, 2), (try it.peek()).*); // moved to the next node

    _ = try it.next(); // past 2
    try it.delete(); // middle (3)
    try expectValues(&list, &.{ 2, 4 });

    try it.delete(); // last (4)
    try expectValues(&list, &.{2});
    try std.testing.expectError(error.IllegalState, it.delete()); // nothing left here
}
