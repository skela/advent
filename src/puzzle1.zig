const std = @import("std");
pub const print = @import("utils.zig").print;

const sample: bool = false;

pub fn puzzle() !void {
    const allocator = std.heap.page_allocator;
    const data = @embedFile(if (sample) "puzzle1.data.sample" else "puzzle1.data");
    const split = std.mem.split;
    var splits = split(u8, data, "\n");

    var vars1 = std.ArrayList(i64).init(allocator);
    defer vars1.deinit();
    var vars2 = std.ArrayList(i64).init(allocator);
    defer vars2.deinit();

    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        var comps = split(u8, line, "   ");

        const c1 = comps.first();
        const v1 = try std.fmt.parseInt(i64, c1, 10);
        try vars1.append(v1);
        const c2 = comps.next();
        if (c2) |c2r| {
            const v2 = try std.fmt.parseInt(i64, c2r, 10);
            try vars2.append(v2);
        }
    }
    const l1 = vars1.items;
    const l2 = vars2.items;

    std.mem.sort(i64, l1, {}, comptime std.sort.asc(i64));
    std.mem.sort(i64, l2, {}, comptime std.sort.asc(i64));

    var sum: i64 = 0;
    var siml: i64 = 0;
    for (0..l1.len) |i| {
        const diff: i64 = @intCast(@abs(l2[i] - l1[i]));
        sum += diff;
        const target = l1[i];
        var counter: i64 = 0;
        for (0..l2.len) |j| {
            if (target == l2[j]) {
                counter += 1;
            }
        }
        siml += target * counter;
    }

    print("Sum is {d}", .{sum});
    print("Siml is {d}", .{siml});
}
