const std = @import("std");

fn containsRule(s: []const u8) bool {
    for (s) |char| {
        if (char == '|') {
            return true;
        }
    }
    return false;
}

fn contains(updates: []i32, r: i32) bool {
    var contained = false;
    for (updates) |u| {
        if (u == r) {
            contained = true;
        }
    }
    return contained;
}

fn count(updates: []i32, r: i32) i32 {
    var c: i32 = 0;
    for (updates) |u| {
        if (u == r) {
            c += 1;
        }
    }
    return c;
}

fn isUpdateValid(update: []i32, rules: [][]i32) !bool {
    const allocator = std.heap.page_allocator;
    var index: usize = 0;
    for (update) |page| {
        var validRules = std.ArrayList([]i32).init(allocator);
        defer validRules.deinit();
        for (rules) |r| {
            if (page == r[0]) {
                try validRules.append(r);
            }
        }
        const prep = update[0..index];
        for (validRules.items) |r| {
            if (count(prep, r[1]) > 0) {
                return false;
            }
        }
        index += 1;
    }
    return true;
}

fn swap(array: []i32, a: usize, b: usize) void {
    const temp = array[a];
    array[a] = array[b];
    array[b] = temp;
}

const Context = struct {
    rules: [][]i32,
};

fn compare(ctx: *const Context, a: i32, b: i32) bool {
    for (ctx.rules) |rule| {
        if (rule[0] == a and rule[1] == b) {
            return true;
        }
        if (rule[0] == b and rule[1] == a) {
            return false;
        }
    }
    return a < b;
}

fn sortPages(pages: []i32, rules: [][]i32) []i32 {
    const ctx = Context{ .rules = rules };
    std.sort.heap(i32, pages, &ctx, compare);
    return pages;
}

fn bruteForceFindValidOrder(array: []i32, start: usize, rules: [][]i32) !?[]i32 {
    const len = array.len;

    if (start == len) {
        if (try isUpdateValid(array, rules)) {
            return array;
        }
        return null;
    }

    for (start..len) |i| {
        swap(array, start, i);

        std.debug.print(" Checking({d},{d}) {any}\n", .{ start, i, array });
        const validArray = try bruteForceFindValidOrder(array, start + 1, rules);
        if (validArray != null)
            return validArray;

        swap(array, start, i);
    }

    return null;
}

pub fn puzzle() !void {
    const allocator = std.heap.page_allocator;
    const data = @embedFile("puzzle5.data");
    const split = std.mem.split;
    var splits = split(u8, data, "\n");

    var rules = std.ArrayList([]i32).init(allocator);
    var updates = std.ArrayList([]i32).init(allocator);

    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        if (containsRule(line)) {
            var parts = split(u8, line, "|");

            var array = std.ArrayList(i32).init(allocator);

            while (parts.next()) |part| {
                const v = try std.fmt.parseInt(i32, part, 10);
                try array.append(v);
            }

            try rules.append(array.items);
        } else {
            var parts = split(u8, line, ",");

            var array = std.ArrayList(i32).init(allocator);

            while (parts.next()) |part| {
                const v = try std.fmt.parseInt(i32, part, 10);
                try array.append(v);
            }

            try updates.append(array.items);
        }
    }

    var validUpdates = std.ArrayList([]i32).init(allocator);
    var invalidUpdates = std.ArrayList([]i32).init(allocator);
    for (updates.items) |u| {
        if (try isUpdateValid(u, rules.items)) {
            try validUpdates.append(u);
        } else {
            std.debug.print("Correcting {any}\n", .{u});
            // const ar = try bruteForceFindValidOrder(u, 0, rules.items);
            // if (ar != null)
            //     try invalidUpdates.append(ar.?);

            const ar = sortPages(u, rules.items);
            try invalidUpdates.append(ar);
        }
    }

    var valids: i32 = 0;
    for (validUpdates.items) |u| {
        // std.debug.print("{any}\n", .{u});
        const middle = (u.len - 1) / 2;
        valids += u[middle];
    }

    var invalids: i32 = 0;
    for (invalidUpdates.items) |u| {
        std.debug.print("{any}\n", .{u});
        const middle = (u.len - 1) / 2;
        invalids += u[middle];
    }

    std.debug.print("Sum of valids: {d}\n", .{valids});
    std.debug.print("Sum of invalids: {d}\n", .{invalids});

    defer rules.deinit();
    defer updates.deinit();
    defer validUpdates.deinit();
    defer invalidUpdates.deinit();
}
