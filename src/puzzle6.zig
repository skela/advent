const std = @import("std");

const Point = struct {
    symbol: u8,
    x: usize,
    y: usize,
};

const Map = struct {
    points: []Point,
    width: usize,
    height: usize,
    bwidth: usize,
    bheight: usize,
};

const north = '^';
const east = '>';
const west = '<';
const south = 'v';

const obstacle = '#';

fn getPoint(map: Map, x: usize, y: usize) Point {
    for (map.points) |p| {
        if (p.x == x and p.y == y) return p;
    }
    return Point{ .symbol = '.', .x = 0, .y = 0 };
}

fn markPoint(map: Map, x: usize, y: usize) void {
    var index: usize = 0;
    for (map.points) |p| {
        if (p.x == x and p.y == y) {
            break;
        }
        index += 1;
    }
    map.points[index].symbol = 'X';
}

fn countMarks(map: Map) i32 {
    var counter: i32 = 0;
    for (map.points) |p| {
        if (p.symbol == 'X') {
            counter += 1;
        }
    }
    return counter;
}

fn printMap(map: Map, guard: Point) void {
    var x: usize = 0;
    var y: usize = 0;
    for (map.points) |p| {
        x = p.x;
        y = p.y;
        if (x == guard.x and y == guard.y) {
            std.debug.print("{c}", .{guard.symbol});
        } else {
            std.debug.print("{c}", .{p.symbol});
        }
        if (x == map.bwidth) {
            std.debug.print("\n", .{});
        }
    }
}

pub fn puzzle() !void {
    const allocator = std.heap.page_allocator;
    const data = @embedFile("puzzle6.data.sample");
    const split = std.mem.split;
    var splits = split(u8, data, "\n");

    var points = std.ArrayList(Point).init(allocator);

    var x: usize = 0;
    var y: usize = 0;
    var width: usize = 0;
    var height: usize = 0;
    var guard = Point{ .symbol = '.', .x = 0, .y = 0 };
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        x = 0;
        for (line) |c| {
            if (c == north or c == south or c == east or c == west) {
                const p = Point{ .symbol = '.', .x = x, .y = y };
                try points.append(p);
                guard.symbol = c;
                guard.x = x;
                guard.y = y;
            } else {
                const p = Point{ .symbol = c, .x = x, .y = y };
                try points.append(p);
            }
            x += 1;
        }
        width = x;
        y += 1;
    }
    height = y;

    const map = Map{ .points = points.items, .width = width, .height = height, .bwidth = width - 1, .bheight = height - 1 };

    std.debug.print("Map is {d}x{d}\n", .{ map.width, map.height });
    std.debug.print("Where is guard: {d},{d}\n", .{ guard.x, guard.y });

    printMap(map, guard);

    var positions: i32 = 0;
    var turncount: i32 = 0;
    while (guard.x != 0 or guard.y != 0 or guard.x < map.bwidth or guard.y < map.bheight) {
        var turndir: u8 = '#';
        switch (guard.symbol) {
            north => {
                x = guard.x;
                y = guard.y - 1;
                turndir = east;
            },
            south => {
                x = guard.x;
                y = guard.y + 1;
                turndir = west;
            },
            east => {
                x = guard.x + 1;
                y = guard.y;
                turndir = south;
            },
            west => {
                x = guard.x - 1;
                y = guard.y;
                turndir = north;
            },
            else => {},
        }

        if (guard.x == 0 or guard.y == 0 or guard.x == map.bwidth or guard.y == map.bheight) {
            break;
        }
        markPoint(map, guard.x, guard.y);
        var p = getPoint(map, x, y);
        if (p.symbol == obstacle) {
            guard.symbol = turndir;
            turncount += 1;
        } else {
            p.symbol = obstacle;
            guard.x = x;
            guard.y = y;
            positions += 1;
        }
        // std.debug.print("=====Nav=====\n", .{});
        // printMap(map, guard);

        // std.debug.print("Where is guard: {d},{d}\n", .{ guard.x, guard.y });
        if (guard.x == 0 or guard.y == 0 or guard.x == map.bwidth or guard.y == map.bheight) {
            break;
        }
    }

    std.debug.print("\n", .{});
    printMap(map, guard);
    positions = countMarks(map) + 1;
    std.debug.print("Had {d} positions\n", .{positions});

    defer points.deinit();
}
