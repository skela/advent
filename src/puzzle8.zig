const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.one;
const sample: bool = true;

pub fn puzzle() !void {
    const allocator = std.heap.page_allocator;
    const data = @embedFile(if (sample) "puzzle8.data.sample" else "puzzle8.data");
    const split = std.mem.split;
    var splits = split(u8, data, "\n");

    var eqs = std.ArrayList(i32).init(allocator);
    defer eqs.deinit();

    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
    }
}
