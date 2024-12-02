const std = @import("std");

fn is_safe(ar: []i32) bool {
    const delta = ar[0] - ar[1];
    const decreasing = delta < 0;

    var safe = true;
    for (0..ar.len - 1) |i| {
        const delt = ar[i] - ar[i + 1];
        const decr = delt < 0;
        if (decr != decreasing) {
            safe = false;
        }
        if (@abs(delt) > 3) {
            safe = false;
        }
        if (delt == 0) {
            safe = false;
        }
    }

    return safe;
}

pub fn puzzle() !void {
    var allocator = std.heap.page_allocator;
    const data = @embedFile("puzzle2.data");
    const split = std.mem.split;
    var splits = split(u8, data, "\n");

    var list = std.ArrayList([]i32).init(allocator);
    defer list.deinit();

    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        var parts = split(u8, line, " ");

        var array = std.ArrayList(i32).init(allocator);

        while (parts.next()) |part| {
            const v = try std.fmt.parseInt(i32, part, 10);
            try array.append(v);
        }

        try list.append(array.items);
    }

    var numberOfOrigSafeReports: i32 = 0;
    var numberOfSafeReports: i32 = 0;
    for (list.items) |ar| {
        const orig_safe: bool = is_safe(ar);
        var safe: bool = orig_safe;
        if (!safe) {
            for (0..ar.len) |i| {
                var new_array = try allocator.alloc(i32, ar.len - 1);
                defer allocator.free(new_array);
                var new_index: usize = 0;
                var index: usize = 0;
                for (ar) |item| {
                    if (index != i) {
                        new_array[new_index] = item;
                        new_index += 1;
                    }
                    index += 1;
                }
                safe = is_safe(new_array);
                if (safe) {
                    break;
                }
            }
        }

        if (safe) {
            std.debug.print("{d}\n", .{ar});
            numberOfSafeReports += 1;
        }
        if (orig_safe) {
            numberOfOrigSafeReports += 1;
        }
    }

    std.debug.print("Number of safe reports: {d}\n", .{numberOfOrigSafeReports});
    std.debug.print("Number of safe reports (Adjusted): {d}\n", .{numberOfSafeReports});

    for (list.items) |ar| {
        defer allocator.free(ar);
    }
}
