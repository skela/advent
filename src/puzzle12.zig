const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.one;
const sample: bool = false;
const verbose: bool = false;

pub fn puzzle() !void {
    var stones = std.ArrayList(Stone).init(std.heap.page_allocator);
    defer stones.deinit();

    const file = @embedFile(if (sample) "puzzle12.data.sample" else "puzzle12.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");

    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        var parts = split(u8, line, " ");

        while (parts.next()) |part| {
            // const v = try std.fmt.parseInt(u64, part, 10);
            // try stones.append(try stoneForValue(v));
        }
    }
}
const Stone = struct {
    value: u64,
    number_of_digts: usize,
};
