const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.one;
const sample: bool = true;
const verbose: bool = true;

pub fn puzzle() !void {
    // var robots = std.ArrayList(Robot).init(std.heap.page_allocator);
    // defer robots.deinit();

    const file = @embedFile(if (sample) "puzzle15.data.sample" else "puzzle15.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
    }
}
