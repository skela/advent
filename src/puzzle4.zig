const std = @import("std");

fn count(ar: []const u8, target: []const u8) usize {
    var totalCount: usize = 0;

    var currentIndex: usize = 0;
    while (true) {
        const foundIndex = std.mem.indexOf(u8, ar[currentIndex..], target);
        if (foundIndex == null) break;

        totalCount += 1;
        currentIndex += foundIndex.? + target.len;
    }
    return totalCount;
}

fn crossCount(ar: std.ArrayList([]const u8)) usize {
    var totalCount: usize = 0;

    for (1..ar.items.len - 1) |y| {
        const h = ar.items[y];
        for (1..h.len - 1) |x| {
            const c = h[x];
            if (c != 'A') continue;
            const tl = ar.items[y - 1][x - 1];
            const bl = ar.items[y + 1][x - 1];
            const tr = ar.items[y - 1][x + 1];
            const br = ar.items[y + 1][x + 1];
            const yay1 = (tl == 'M' and br == 'S') or (tl == 'S' and br == 'M');
            const yay2 = (bl == 'M' and tr == 'S') or (bl == 'S' and tr == 'M');
            if (yay1 and yay2) {
                totalCount += 1;
            }
        }
    }
    return totalCount;
}

fn reversed(slice: []const u8) []u8 {
    var rev: [1024]u8 = undefined;
    const len = slice.len;

    for (0..len) |i| {
        rev[i] = slice[len - i - 1];
    }

    return rev[0..len];
}

fn transpose(data: std.ArrayList([]const u8)) !std.ArrayList([]const u8) {
    const allocator = std.heap.page_allocator;
    if (data.items.len == 0) return std.ArrayList([]const u8).init(allocator);
    const rowLength = data.items[0].len;

    var transposed = std.ArrayList(std.ArrayList(u8)).init(allocator);
    try transposed.ensureTotalCapacity(rowLength);
    for (0..rowLength) |_| {
        const column = std.ArrayList(u8).init(allocator);
        try transposed.append(column);
    }

    for (data.items) |row| {
        for (0..row.len) |colIndex| {
            try transposed.items[colIndex].append(row[colIndex]);
        }
    }

    var transposed2 = std.ArrayList([]const u8).init(allocator);

    for (transposed.items) |row| {
        try transposed2.append(row.items);
    }
    return transposed2;
}

fn diagonalTranspose(data: std.ArrayList([]const u8)) !std.ArrayList([]const u8) {
    const allocator = std.heap.page_allocator;

    if (data.items.len == 0) return std.ArrayList([]const u8).init(allocator);

    const rows = data.items.len;
    const cols = data.items[0].len;

    const maxDiagonals = rows + cols - 1;

    var diagonals = std.ArrayList(std.ArrayList(u8)).init(allocator);
    try diagonals.ensureTotalCapacity(maxDiagonals);
    for (0..maxDiagonals) |_| {
        const diagonal = std.ArrayList(u8).init(allocator);
        try diagonals.append(diagonal);
    }

    for (0..rows) |i| {
        for (0..cols) |j| {
            const diagIndex = i + j;
            try diagonals.items[diagIndex].append(data.items[i][j]);
        }
    }

    var result = std.ArrayList([]const u8).init(allocator);
    for (diagonals.items) |diagonal| {
        try result.append(diagonal.items);
    }

    return result;
}

fn otherDiagonalTranspose(data: std.ArrayList([]const u8)) !std.ArrayList([]const u8) {
    const allocator = std.heap.page_allocator;

    if (data.items.len == 0) return std.ArrayList([]const u8).init(allocator);

    const rows: usize = data.items.len;
    const cols: usize = data.items[0].len;

    const maxDiagonals = rows + cols - 1;

    var diagonals = std.ArrayList(std.ArrayList(u8)).init(allocator);
    try diagonals.ensureTotalCapacity(maxDiagonals);
    for (0..maxDiagonals) |_| {
        const diagonal = std.ArrayList(u8).init(allocator);
        try diagonals.append(diagonal);
    }

    for (0..rows) |i| {
        for (0..cols) |j| {
            const ii: isize = @intCast(i);
            const jj: isize = @intCast(j);
            const rrows: isize = @intCast(rows);
            const diagIndex = jj - ii + (rrows - 1);
            const index: usize = @intCast(diagIndex);
            try diagonals.items[index].append(data.items[i][j]);
        }
    }

    var result = std.ArrayList([]const u8).init(allocator);
    for (diagonals.items) |diagonal| {
        try result.append(diagonal.items);
    }

    return result;
}

pub fn puzzle() !void {
    const allocator = std.heap.page_allocator;
    const data = @embedFile("puzzle4.data");
    const split = std.mem.split;
    var splits = split(u8, data, "\n");

    var list = std.ArrayList([]const u8).init(allocator);

    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        try list.append(line);
    }

    var total: usize = 0;
    for (0..list.items.len) |i| {
        const x = list.items[i];
        total += count(x, "XMAS");
        total += count(reversed(x), "XMAS");
    }

    const vertical = try transpose(list);
    for (0..vertical.items.len) |i| {
        const x = vertical.items[i];
        total += count(x, "XMAS");
        total += count(reversed(x), "XMAS");
    }

    const diagonal1 = try diagonalTranspose(list);
    for (0..diagonal1.items.len) |i| {
        const x = diagonal1.items[i];
        total += count(x, "XMAS");
        total += count(reversed(x), "XMAS");
    }

    const diagonal2 = try otherDiagonalTranspose(list);
    for (0..diagonal2.items.len) |i| {
        const x = diagonal2.items[i];
        total += count(x, "XMAS");
        total += count(reversed(x), "XMAS");
    }

    const total2: usize = crossCount(list);

    std.debug.print("Total XMAS count is {d}\n", .{total});
    std.debug.print("Total X-MAS count is {d}\n", .{total2});

    defer list.deinit();
    defer vertical.deinit();
}
