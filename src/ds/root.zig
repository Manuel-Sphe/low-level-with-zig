//! Data structures. Add each new file here so it gets exported and tested.
const std = @import("std");

const linked_list = @import("linked_list.zig");
pub const LinkedList = linked_list.LinkedList;

test {
    std.testing.refAllDecls(linked_list);
}
