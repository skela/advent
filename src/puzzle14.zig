const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.one;
const sample: bool = true;
const verbose: bool = false;

pub fn puzzle() !void {
    // var games = std.ArrayList(Game).init(std.heap.page_allocator);
    // defer games.deinit();

    const file = @embedFile(if (sample) "puzzle14.data.sample" else "puzzle14.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");

    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
    }
}
