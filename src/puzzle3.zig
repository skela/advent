const std = @import("std");

fn mul(a: i32, b: i32) i32 {
    return a * b;
}

fn trimBefore(input: []const u8, target: u8) ![]const u8 {
    var index: usize = 0;
    for (input) |char| {
        if (char == target) {
            return input[0..index];
        }
        index += 1;
    }
    return input[0..0];
}

fn containsSpace(s: []const u8) bool {
    for (s) |char| {
        if (char == ' ') {
            return true;
        }
    }
    return false;
}

fn isValid(s: []const u8) bool {
    for (s) |char| {
        if (!isDigitOrComma(char)) {
            return false;
        }
    }
    return true;
}

fn isDigitOrComma(c: u8) bool {
    return (c >= '0' and c <= '9') or (c == ',');
}

fn indexOfSubstring(s: []const u8, substring: []const u8) ?usize {
    return std.mem.indexOf(u8, s, substring);
}

fn containsSubstring(s: []const u8, substring: []const u8) bool {
    return indexOfSubstring(s, substring) != null;
}

pub fn puzzle() !void {
    const data = @embedFile("puzzle3.data2");

    const split = std.mem.split;
    var splits = split(u8, data, "mul(");

    const target: u8 = ')';
    var sum: i32 = 0;
    var enabled: bool = true;
    const allocator = std.heap.page_allocator;
    while (splits.next()) |line| {
        const trimmed = try trimBefore(line, target);

        if (!isValid(trimmed)) {
            continue;
        }

        var comps = split(u8, trimmed, ",");

        var parts = std.ArrayList(i32).init(allocator);

        while (comps.next()) |c| {
            std.debug.print("trying {s}\n", .{c});
            const v = std.fmt.parseInt(i32, c, 10) catch |err| {
                std.debug.print("Skipping invalid value: {s} (error: {any})\n", .{ c, err });
                continue;
            };
            try parts.append(v);
        }

        if (parts.items.len != 2) {
            continue;
        }

        const v1 = parts.items[0];
        const v2 = parts.items[1];
        if (enabled) {
            sum += mul(v1, v2);
        }

        const dont = indexOfSubstring(line, "don't()");
        const do = indexOfSubstring(line, "do()");

        if (do != null) {
            if (dont == null) {
                enabled = true;
            } else {
                enabled = do.? > dont.?;
            }
        } else if (dont != null) {
            if (do == null) {
                enabled = false;
            } else {
                enabled = do.? > dont.?;
            }
        }

        defer parts.deinit();
    }

    std.debug.print("Result: {d}\n", .{sum});
}
