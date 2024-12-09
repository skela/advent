const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.two;
const sample: bool = false;
const verbose: bool = false;

pub fn puzzle() !void {
    // var data = std.ArrayList(Data).init(std.heap.page_allocator);
    // defer data.deinit();

    const file = @embedFile(if (sample) "puzzle10.data.sample" else "puzzle10.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
    }
}
