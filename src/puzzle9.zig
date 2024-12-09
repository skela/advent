const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.two;
const sample: bool = true;

pub fn puzzle() !void {
    const allocator = std.heap.page_allocator;
    const file = @embedFile(if (sample) "puzzle9.data.sample" else "puzzle9.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");

    var data = std.ArrayList(Data).init(allocator);
    defer data.deinit();
    const zero: i64 = @intCast('0');
    var id: i64 = 0;
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        var dtype: DataType = .block;
        for (line) |c| {
            const i: i64 = @intCast(c); // Convert to i64 and subtract ASCII '0'
            const v: usize = @intCast(i - zero);
            try data.append(Data{ .id = id, .size = v, .type = dtype });
            switch (dtype) {
                DataType.block => {
                    id += 1;
                    dtype = DataType.freespace;
                },
                DataType.freespace => dtype = DataType.block,
            }
        }
    }

    printData(data);

    var filesystem = std.ArrayList(FilesystemData).init(allocator);
    defer filesystem.deinit();

    for (data.items) |d| {
        switch (d.type) {
            DataType.block => {
                for (0..d.size) |_| {
                    try filesystem.append(FilesystemData{ .id = d.id, .type = d.type });
                }
            },
            DataType.freespace => {
                for (0..d.size) |_| {
                    try filesystem.append(FilesystemData{ .id = d.id, .type = d.type });
                }
            },
        }
    }

    for (0..filesystem.items.len) |i| {
        for (0..filesystem.items.len) |jt| {
            const j = filesystem.items.len - jt - 1;
            // print("i: {d} , j: {d}", .{ i, j });
            if (j == i) {
                break;
            }
            const left = filesystem.items[i];
            const right = filesystem.items[j];
            if (left.type == DataType.freespace and right.type == DataType.block) {
                filesystem.items[i] = right;
                filesystem.items[j] = left;
                // printFilesystem(filesystem);
            }
        }
    }

    var checksum: i64 = 0;
    var counter: i64 = 0;
    for (filesystem.items) |fs| {
        if (fs.type == DataType.freespace) continue;
        checksum += counter * fs.id;
        counter += 1;
    }

    print("Checksum is {d}", .{checksum});
}

const DataType = enum { block, freespace };

const Data = struct {
    id: i64,
    size: usize,
    type: DataType,
};

const FilesystemData = struct {
    id: i64,
    type: DataType,
};

fn printData(data: std.ArrayList(Data)) void {
    for (data.items) |d| {
        switch (d.type) {
            DataType.block => {
                for (0..d.size) |_| {
                    std.debug.print("{d}", .{d.id});
                }
            },
            DataType.freespace => {
                for (0..d.size) |_| {
                    std.debug.print(".", .{});
                }
            },
        }
    }
    std.debug.print("\n", .{});
}

fn printFilesystem(data: std.ArrayList(FilesystemData)) void {
    for (data.items) |d| {
        switch (d.type) {
            DataType.block => {
                std.debug.print("{d}", .{d.id});
            },
            DataType.freespace => {
                std.debug.print(".", .{});
            },
        }
    }
    std.debug.print("\n", .{});
}
