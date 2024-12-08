const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.two;
const sample: bool = false;

pub fn puzzle() !void {
    const allocator = std.heap.page_allocator;
    const data = @embedFile(if (sample) "puzzle8.data.sample" else "puzzle8.data");
    const split = std.mem.split;
    var splits = split(u8, data, "\n");

    var points = std.ArrayList(Point).init(allocator);
    defer points.deinit();

    var antennas = std.AutoArrayHashMap(u8, std.ArrayList(Point)).init(allocator);
    defer antennas.deinit();

    var x: i32 = 0;
    var y: i32 = 0;
    var width: i32 = 0;
    var height: i32 = 0;
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        x = 0;
        for (line) |c| {
            const p = Point{ .symbol = c, .x = x, .y = y };
            try points.append(p);
            if (c != '.') {
                if (antennas.getPtr(c)) |existing_list| {
                    try existing_list.append(p);
                } else {
                    var new_list = std.ArrayList(Point).init(allocator);
                    try new_list.append(p);
                    try antennas.put(c, new_list);
                }
            }

            x += 1;
        }
        width = x;
        y += 1;
    }
    height = y;

    const map = Map{ .points = points.items, .width = width, .height = height, .bwidth = width - 1, .bheight = height - 1 };

    printMap(map);

    var antinodes = std.ArrayList(Point).init(allocator);
    defer antinodes.deinit();

    var it = antennas.iterator();
    while (it.next()) |entry| {
        const list = entry.value_ptr;
        for (0..list.items.len) |i| {
            for (0..list.items.len) |j| {
                if (i == j) {
                    continue;
                }

                const pi = list.items[i];
                const pj = list.items[j];
                const dx: i32 = pi.x - pj.x;
                const dy: i32 = pi.y - pj.y;

                switch (task) {
                    Task.one => try antinodes.append(Point{ .x = pi.x + dx, .y = pi.y + dy, .symbol = pi.symbol }),
                    Task.two => {
                        var nx = pi.x;
                        var ny = pi.y;

                        while (isPointInside(map, nx, ny)) {
                            try antinodes.append(Point{ .x = nx, .y = ny, .symbol = pi.symbol });
                            ny = ny + dy;
                            nx = nx + dx;
                        }
                    },
                }
            }
        }
    }

    for (antinodes.items) |node| {
        if (isPointInside(map, node.x, node.y)) {
            mark(map, node.x, node.y, '#');
        }
    }

    const sum = count(map, '#');
    print("Number of antinodes: {d}", .{sum});
}

const Point = struct {
    symbol: u8,
    x: i32,
    y: i32,

    fn updateSymbol(self: *Point, symbol: u8) void {
        self.symbol = symbol;
    }
};

const Map = struct {
    points: []Point,
    width: i32,
    height: i32,
    bwidth: i32,
    bheight: i32,
};

fn getPointIndex(map: Map, x: i32, y: i32) usize {
    return @intCast(y * map.width + x);
}

fn getPoint(map: Map, x: i32, y: i32) Point {
    return map.points[getPointIndex(map, x, y)];
}

fn isPointInside(map: Map, x: i32, y: i32) bool {
    return x >= 0 and x < map.width and y >= 0 and y < map.height;
}

fn mark(map: Map, x: i32, y: i32, symbol: u8) void {
    map.points[getPointIndex(map, x, y)].symbol = symbol;
}

fn count(map: Map, symbol: u8) i32 {
    var counter: i32 = 0;
    for (map.points) |p| {
        if (p.symbol == symbol) {
            counter += 1;
        }
    }
    return counter;
}

fn printMap(map: Map) void {
    var x: i32 = 0;
    var y: i32 = 0;
    for (map.points) |p| {
        x = p.x;
        y = p.y;
        std.debug.print("{c}", .{p.symbol});
        if (x == map.bwidth) {
            std.debug.print("\n", .{});
        }
    }
}
