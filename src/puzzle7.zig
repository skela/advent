const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.two;
const sample: bool = false;

const Equation = struct {
    variables: []i64,
    count: usize,
    result: i64,
};

pub fn puzzle() !void {
    const allocator = std.heap.page_allocator;
    const data = @embedFile(if (sample) "puzzle7.data.sample" else "puzzle7.data");
    const split = std.mem.split;
    var splits = split(u8, data, "\n");

    var eqs = std.ArrayList(Equation).init(allocator);
    defer eqs.deinit();

    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        var comps = split(u8, line, ":");

        const c1 = comps.first();
        const c2 = comps.next();

        const result = try std.fmt.parseInt(i64, c1, 10);

        if (c2) |c2r| {
            var parts = split(u8, c2r, " ");

            var vars = std.ArrayList(i64).init(allocator);
            while (parts.next()) |p| {
                if (p.len == 0) {
                    continue;
                }
                const v = try std.fmt.parseInt(i64, p, 10);
                try vars.append(v);
            }

            const eq = Equation{ .variables = vars.items, .count = vars.items.len, .result = result };
            try eqs.append(eq);
        }
    }

    var sum: i64 = 0;
    for (eqs.items) |eq| {
        const num = solve(eq.variables, 1, eq.variables[0], eq.result);
        // print("Eq result: {d} - Len {d} - {any} - {d}", .{ eq.result, eq.count, eq.variables, num });
        if (num > 0) {
            sum += eq.result;
        }
    }

    print("Result is {d}", .{sum});
}

fn solve(arr: []const i64, idx: usize, currentResult: i64, target: i64) i64 {
    if (idx == arr.len) {
        if (currentResult == target) {
            return 1;
        } else {
            return 0;
        }
    }

    const nextValue = arr[idx];

    switch (task) {
        Task.one => return solve(arr, idx + 1, currentResult + nextValue, target) + solve(arr, idx + 1, currentResult * nextValue, target),
        Task.two => return solve(arr, idx + 1, currentResult + nextValue, target) + solve(arr, idx + 1, currentResult * nextValue, target) + solve(arr, idx + 1, concat(currentResult, nextValue), target),
    }
}

fn concat(a: i64, b: i64) i64 {
    var temp = b;
    var digits: i64 = 0;
    while (temp != 0) {
        digits += 1;
        temp = @divTrunc(temp, 10);
    }

    const multiplier: i64 = std.math.pow(i64, 10, digits);
    return a * multiplier + b;
}
