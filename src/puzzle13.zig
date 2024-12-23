const std = @import("std");
pub const utils = @import("utils.zig");
pub const print = utils.print;

const Task = enum { one, two };
const task: Task = Task.two;
const sample: bool = false;
const verbose: bool = false;

pub fn puzzle() !void {
    var games = std.ArrayList(Game).init(std.heap.page_allocator);
    defer games.deinit();

    const file = @embedFile(if (sample) "puzzle13.data.sample" else "puzzle13.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");

    var i: usize = 0;
    var a: Button = Button{ .dx = 0, .dy = 0, .cost = 0 };
    var b: Button = Button{ .dx = 0, .dy = 0, .cost = 0 };
    var prize: Prize = Prize{ .x = 0, .y = 0 };
    while (splits.next()) |line| {
        if (line.len == 0) {
            i = 0;
            continue;
        }

        if (i == 0) {
            a = try parseButton(line, 3);
        } else if (i == 1) {
            b = try parseButton(line, 1);
        } else if (i == 2) {
            prize = try parsePrize(line);
            try games.append(Game{ .a = a, .b = b, .prize = prize });
        }
        i += 1;
    }

    if (verbose) {
        print("Found {d} games", .{games.items.len});
        for (games.items) |game| {
            printGame(game);
        }
    }

    var prizes: i64 = 0;
    var cost: i64 = 0;
    for (games.items) |game| {
        const res = mostPrizes(game);
        if (res) |r| {
            prizes += 1;
            cost += r;
        }
    }

    print("Won {d} prizes at a cost of {d}", .{ prizes, cost });
}

fn mostPrizes(game: Game) ?i64 {
    const b = @divTrunc((game.prize.y * game.a.dx - game.prize.x * game.a.dy), (game.b.dy * game.a.dx - game.b.dx * game.a.dy));
    const a = @divTrunc((game.prize.y - b * game.b.dy), game.a.dy);

    if (a * game.a.dx + b * game.b.dx != game.prize.x) {
        return null;
    }
    if (a * game.a.dy + b * game.b.dy != game.prize.y) {
        return null;
    }

    const mincost = game.a.cost * a + game.b.cost * b;
    if (verbose) {
        std.debug.print(
            "Optimal solution: Button A = {d}, Button B = {d}, Total cost = {d}\n",
            .{ a, b, mincost },
        );
    }
    return mincost;
}

fn printGame(game: Game) void {
    print("Game:", .{});
    print("A: dx {d} dy {d}", .{ game.a.dx, game.a.dy });
    print("B: dx {d} dy {d}", .{ game.b.dx, game.b.dy });
    print("Prize: x {d} y {d}", .{ game.prize.x, game.prize.y });
    print("\n", .{});
}

fn parseButton(line: []const u8, cost: i64) !Button {
    const x_start = std.mem.indexOf(u8, line, "X");
    const y_start = std.mem.indexOf(u8, line, "Y");
    const comma_start = std.mem.indexOf(u8, line, ",");
    const x = if (x_start) |i| i else 0;
    const y = if (y_start) |i| i else 0;
    const comma = if (comma_start) |i| i else 0;
    const x_offset = try parseNumber(line[x + 2 .. comma]);
    const y_offset = try parseNumber(line[y + 2 ..]);
    const xpos = line[x + 1] == '+';
    const ypos = line[y + 1] == '+';
    return Button{ .dx = if (xpos) x_offset else x_offset * -1, .dy = if (ypos) y_offset else y_offset * -1, .cost = cost };
}

fn parsePrize(line: []const u8) !Prize {
    const x_start = std.mem.indexOf(u8, line, "X");
    const y_start = std.mem.indexOf(u8, line, "Y");
    const comma_start = std.mem.indexOf(u8, line, ",");
    const x = if (x_start) |i| i else 0;
    const y = if (y_start) |i| i else 0;
    const comma = if (comma_start) |i| i else 0;
    const x_value = try parseNumber(line[x + 2 .. comma]);
    const y_value = try parseNumber(line[y + 2 ..]);
    const crazy: i64 = 10000000000000;
    return switch (task) {
        .one => Prize{ .x = x_value, .y = y_value },
        .two => Prize{ .x = x_value + crazy, .y = y_value + crazy },
    };
}

fn parseNumber(input: []const u8) !i64 {
    return try utils.parsei64(input);
}

const Button = struct {
    dx: i64,
    dy: i64,
    cost: i64,
};

const Prize = struct {
    x: i64,
    y: i64,
};

const Game = struct {
    a: Button,
    b: Button,
    prize: Prize,
};
