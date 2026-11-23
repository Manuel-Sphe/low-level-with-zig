const std = @import("std");
const Allocator = std.mem.Allocator;
const LinkedList = @import("linked_list.zig").LinkedList;

/// Last in, first out. A `LinkedList` used only at its front, so `push` and
/// `pop` are both O(1). The list owns the nodes and frees them.
pub fn Stack(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Private, so callers can't reach into the middle of the stack
        list: LinkedList(T),

        pub fn init(allocator: Allocator) Self {
            return .{ .list = .init(allocator) };
        }

        /// Frees every value still on the stack.
        pub fn deinit(self: *Self) void {
            self.list.deinit();
        }

        pub fn push(self: *Self, value: T) Allocator.Error!void {
            try self.list.addFront(value);
        }

        /// Removes and returns the top value, or null if the stack is empty.
        pub fn pop(self: *Self) ?T {
            return self.list.popFront();
        }

        /// The top value without removing it, or null if the stack is empty.
        /// The pointer is valid until the value is popped.
        pub fn peek(self: *const Self) ?*const T {
            return self.list.peekFront();
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.list.len == 0;
        }

        pub fn len(self: *const Self) usize {
            return self.list.len;
        }
    };
}

test "Stack: pop returns values in reverse push order" {
    var stack = Stack(i32).init(std.testing.allocator);
    defer stack.deinit();

    try stack.push(1);
    try stack.push(2);
    try stack.push(3);

    try std.testing.expectEqual(@as(?i32, 3), stack.pop());
    try std.testing.expectEqual(@as(?i32, 2), stack.pop());
    try std.testing.expectEqual(@as(?i32, 1), stack.pop());
    try std.testing.expectEqual(@as(?i32, null), stack.pop());
}

test "Stack: peek looks at the top without removing it" {
    var stack = Stack(i32).init(std.testing.allocator);
    defer stack.deinit();

    try std.testing.expect(stack.peek() == null);

    try stack.push(1);
    try stack.push(2);
    try std.testing.expectEqual(@as(i32, 2), stack.peek().?.*);
    try std.testing.expectEqual(@as(usize, 2), stack.len()); // still there
}

test "Stack: len and isEmpty track pushes and pops" {
    var stack = Stack(i32).init(std.testing.allocator);
    defer stack.deinit();

    try std.testing.expect(stack.isEmpty());
    try stack.push(1);
    try stack.push(2);
    try std.testing.expect(!stack.isEmpty());
    try std.testing.expectEqual(@as(usize, 2), stack.len());

    _ = stack.pop();
    try std.testing.expectEqual(@as(usize, 1), stack.len());
    _ = stack.pop();
    try std.testing.expect(stack.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), stack.len());
}

test "Stack: while (pop()) drains the stack" {
    var stack = Stack(i32).init(std.testing.allocator);
    defer stack.deinit();
    for ([_]i32{ 1, 2, 3 }) |value| try stack.push(value);

    var sum: i32 = 0;
    while (stack.pop()) |value| sum += value;
    try std.testing.expectEqual(@as(i32, 6), sum);
    try std.testing.expect(stack.isEmpty());
}

test "Stack: deinit frees values still on the stack" {
    // std.testing.allocator fails the test if deinit misses a node
    var stack = Stack([]const u8).init(std.testing.allocator);
    try stack.push("a");
    try stack.push("b");
    stack.deinit();
    try std.testing.expect(stack.isEmpty());
}
