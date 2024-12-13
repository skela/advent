const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.one;
const sample: bool = true;
const verbose: bool = true;

pub fn puzzle() !void {
    var games = std.ArrayList(Game).init(std.heap.page_allocator);
    defer games.deinit();

    const file = @embedFile(if (sample) "puzzle13.data.sample" else "puzzle13.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");

    var i: usize = 0;
    var a: Button = Button{ .dx = 0, .dy = 0 };
    var b: Button = Button{ .dx = 0, .dy = 0 };
    var prize: Prize = Prize{ .x = 0, .y = 0 };
    while (splits.next()) |line| {
        if (line.len == 0) {
            i = 0;
            continue;
        }

        if (i == 0) {
            a = try parseButton(line);
        } else if (i == 1) {
            b = try parseButton(line);
        } else if (i == 2) {
            prize = try parsePrize(line);
            try games.append(Game{ .a = a, .b = b, .prize = prize });
        }
        i += 1;
    }
}

fn parseButton(line: []const u8) !Button {
    const x_start = try std.mem.indexOf(u8, line, 'X');
    const y_start = try std.mem.indexOf(u8, line, 'Y');
    const x_offset = try parseNumber(line[x_start + 3 .. y_start - 1]);
    const y_offset = try parseNumber(line[y_start + 3 ..]);
    return Button{ .dx = x_offset, .dy = y_offset };
}

fn parsePrize(line: []const u8) !Prize {
    const x_start = try std.mem.indexOf(u8, line, 'X');
    const y_start = try std.mem.indexOf(u8, line, 'Y');
    const x_value = try parseNumber(line[x_start + 3 .. y_start - 1]);
    const y_value = try parseNumber(line[y_start + 3 ..]);
    return Prize{ .x = x_value, .y = y_value };
}

fn parseNumber(input: []const u8) !i32 {
    var pos = 0;
    return try std.fmt.parseInt(i32, input, 10, &pos);
}
const Button = struct {
    dx: i32,
    dy: i32,
};

const Prize = struct {
    x: i32,
    y: i32,
};

const Game = struct {
    a: Button,
    b: Button,
    prize: Prize,
};
