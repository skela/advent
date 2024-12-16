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
    .sample => "puzzle17.data.sample",
    .real => "puzzle17.data",
};

pub fn puzzle() !void {
    // var points = std.ArrayList(Point).init(std.heap.page_allocator);
    // defer points.deinit();
    //
    // var splits = split(u8, file, "\n");
    // while (splits.next()) |line| {
    //     if (line.len == 0) {
    //         continue;
    //     }
    // }
}
