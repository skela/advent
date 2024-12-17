const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const DataSource = enum { sample, real };
const task: Task = .one;
const source: DataSource = .sample;

const verbose: bool = switch (source) {
    .sample => true,
    .real => false,
};

const filename: []const u8 = switch (source) {
    .sample => "puzzle18.data.sample",
    .real => "puzzle18.data",
};

pub fn puzzle() !void {
    var values = std.ArrayList(u64).init(std.heap.page_allocator);
    defer values.deinit();

    const file = @embedFile(filename);
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
    }
}
