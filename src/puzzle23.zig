const std = @import("std");
const utils = @import("utils.zig");
const print = utils.print;
const alloc = std.heap.page_allocator;

const DataSource = enum { sample, real };
const source: DataSource = .sample;

const verbose: bool = switch (source) {
    .sample => true,
    .real => false,
};

const filename: []const u8 = switch (source) {
    .sample => "puzzle23.data.sample",
    .real => "puzzle23.data",
};

pub fn puzzle() !void {
    // var buyers = std.ArrayList(i64).init(alloc);
    // defer buyers.deinit();

    const file = @embedFile(filename);
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
    }
}
