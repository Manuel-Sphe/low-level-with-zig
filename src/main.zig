const std = @import("std");
const Io = std.Io;

// The library in src/root.zig: `dsa.ds` (data structures) and `dsa.algo` (algorithms)
const dsa = @import("dsa");
const LinkedList = dsa.ds.LinkedList;

pub fn main(init: std.process.Init) !void {
    // Prints to stderr, unbuffered, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();
    _ = LinkedList(i32).init(arena);
}
