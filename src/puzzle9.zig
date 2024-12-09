const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.two;
const sample: bool = false;
const verbose: bool = false;

pub fn puzzle() !void {
    var data = std.ArrayList(Data).init(std.heap.page_allocator);
    defer data.deinit();

    const file = @embedFile(if (sample) "puzzle9.data.sample" else "puzzle9.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    const ascii_zero: i64 = @intCast('0');
    var id: i64 = 0;
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        var dtype: DataType = .block;
        for (line) |c| {
            const i: i64 = @intCast(c);
            const v: usize = @intCast(i - ascii_zero);
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

    if (verbose) {
        printData(data);
    }

    switch (task) {
        Task.one => {
            var filesystem = try createFilesystem(data);

            for (0..filesystem.items.len) |i| {
                for (0..filesystem.items.len) |jt| {
                    const j = filesystem.items.len - jt - 1;
                    if (j == i) {
                        break;
                    }
                    const left = filesystem.items[i];
                    const right = filesystem.items[j];
                    if (left.type == DataType.freespace and right.type == DataType.block) {
                        filesystem.items[i] = right;
                        filesystem.items[j] = left;
                        if (verbose) {
                            printFilesystem(filesystem);
                        }
                    }
                }
            }
            checksumFilesystem(filesystem);
        },
        Task.two => {
            const sortedList = try sortList(data, compareByIdDescending);
            for (sortedList.items) |possible_right| {
                for (0..data.items.len) |i| {
                    const left = data.items[i];
                    if (left.size < possible_right.size) {
                        continue;
                    }
                    if (left.type == DataType.block) {
                        continue;
                    }
                    const jo = findIndex(data, possible_right);
                    if (jo == null) {
                        continue;
                    }
                    const j = jo.?;
                    if (i >= j) {
                        break;
                    }
                    const right = data.items[j];
                    data.items[i] = right;
                    if (left.size > right.size) {
                        try data.insert(i + 1, Data{ .type = .freespace, .id = 0, .size = left.size - right.size });
                        data.items[j + 1] = Data{ .type = .freespace, .id = 0, .size = right.size };
                    } else {
                        data.items[j] = Data{ .type = .freespace, .id = 0, .size = right.size };
                    }
                    if (verbose) {
                        printData(data);
                    }
                    break;
                }
            }
            const filesystem = try createFilesystem(data);
            checksumFilesystem(filesystem);
        },
    }
}

const DataType = enum { block, freespace };

const Data = struct {
    id: i64,
    size: usize,
    type: DataType,

    fn resize(self: *Data, size: usize) void {
        self.size = size;
    }
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

fn checksumFilesystem(filesystem: std.ArrayList(FilesystemData)) void {
    var checksum: i64 = 0;
    var counter: i64 = 0;
    for (filesystem.items) |fs| {
        if (fs.type == DataType.freespace) {
            counter += 1;
            continue;
        }
        checksum += counter * fs.id;
        counter += 1;
    }

    print("Checksum is {d}", .{checksum});
}

fn findIndex(list: std.ArrayList(Data), item: Data) ?usize {
    var index: usize = 0;
    for (list.items) |entry| {
        if (entry.id == item.id and entry.type == item.type) return index;
        index += 1;
    }
    return null;
}

fn compareByIdDescending(a: Data, b: Data) i32 {
    if (a.id > b.id) return -1;
    if (a.id < b.id) return 1;
    return 0;
}

fn sortList(list: std.ArrayList(Data), comparator: fn (Data, Data) i32) !std.ArrayList(Data) {
    const allocator = std.heap.page_allocator;
    var newList = std.ArrayList(Data).init(allocator);

    for (list.items) |item| {
        if (item.type == DataType.block) {
            try newList.append(item);
        }
    }

    var n = newList.items.len;
    while (n > 1) : (n -= 1) {
        for (0..(n - 1)) |i| {
            if (comparator(newList.items[i], newList.items[i + 1]) > 0) {
                const temp = newList.items[i];
                newList.items[i] = newList.items[i + 1];
                newList.items[i + 1] = temp;
            }
        }
    }

    return newList;
}

fn createFilesystem(data: std.ArrayList(Data)) !std.ArrayList(FilesystemData) {
    var filesystem = std.ArrayList(FilesystemData).init(std.heap.page_allocator);
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
    return filesystem;
}
