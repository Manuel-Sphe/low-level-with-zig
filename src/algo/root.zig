//! Algorithms. Add each new file here so it gets exported and tested, e.g.
//!
//!     pub const sort = @import("sort.zig");
//!     pub const search = @import("search.zig");
const std = @import("std");

test {
    std.testing.refAllDecls(@This());
}
