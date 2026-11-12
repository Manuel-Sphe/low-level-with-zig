//! Data structures and algorithms. Import it as `@import("dsa")`.
const std = @import("std");

pub const ds = @import("ds/root.zig");
pub const algo = @import("algo/root.zig");
pub const utils = @import("utils.zig");

test {
    // Pull every file's tests into `zig build test` (and the on-save `check`)
    std.testing.refAllDecls(@This());
}
