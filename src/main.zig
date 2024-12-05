const std = @import("std");
// pub const puzzle = @import("puzzle1.zig");
// pub const puzzle = @import("puzzle2.zig");
// pub const puzzle = @import("puzzle3.zig");
// pub const puzzle = @import("puzzle4.zig");
pub const puzzle = @import("puzzle5.zig");

pub fn main() !void {
    try puzzle.puzzle();
}
