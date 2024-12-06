const std = @import("std");
pub const print = @import("utils.zig").print;

const Traversed = struct {
    north: bool,
    south: bool,
    east: bool,
    west: bool,

    fn reset(self: *Traversed) void {
        self.north = false;
        self.south = false;
        self.east = false;
        self.west = false;
    }

    fn all(self: *Traversed) bool {
        return self.north and self.south and self.east and self.west;
    }
};

const Route = struct {
    path: []Point,
    success: bool,
};

const Point = struct {
    symbol: u8,
    x: usize,
    y: usize,

    traversed: Traversed,

    fn reset(self: *Point, orig: Point) void {
        self.x = orig.x;
        self.y = orig.y;
        self.symbol = orig.symbol;
        self.traversed.reset();
    }

    fn navigateMap(guard: *Point, map: Map) !Route {
        var x: usize = 0;
        var y: usize = 0;
        const allocator = std.heap.page_allocator;
        var path = std.ArrayList(Point).init(allocator);
        while (guard.x != 0 or guard.y != 0 or guard.x < map.bwidth or guard.y < map.bheight) {
            if (guard.traversed.all()) {
                return Route{ .path = path.items, .success = false };
            }
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

            if (checkTraversed(map, guard, x, y)) return Route{ .path = path.items, .success = false };

            if (guard.x == 0 or guard.y == 0 or guard.x == map.bwidth or guard.y == map.bheight) {
                return Route{ .path = path.items, .success = true };
            }
            const op = getPoint(map, guard.x, guard.y);
            try path.append(op);
            markPoint(map, guard);
            markTraversed(map, guard);
            var p = getPoint(map, x, y);
            // std.debug.print("Wants to navigate to {d},{d},{c} - n:{} s:{} e:{} w: {}\n", .{ p.x, p.y, guard.symbol, p.traversed.north, p.traversed.south, p.traversed.east, p.traversed.west });
            if (p.symbol == obstacle) {
                guard.symbol = turndir;
                markTraversed(map, guard);
            } else {
                p.symbol = obstacle;
                guard.x = x;
                guard.y = y;
            }
            // std.debug.print("=====Nav=====\n", .{});
            // printMap(map, guard);

            if (guard.traversed.all()) {
                return Route{ .path = path.items, .success = false };
            }
            // std.debug.print("Where is guard: {d},{d}\n", .{ guard.x, guard.y });
            if (guard.x == 0 or guard.y == 0 or guard.x == map.bwidth or guard.y == map.bheight) {
                return Route{ .path = path.items, .success = true };
            }
        }
        return Route{ .path = path.items, .success = true };
    }

    fn updateSymbol(self: *Point, symbol: u8) void {
        self.symbol = symbol;
    }
};

const Map = struct {
    points: []Point,
    width: usize,
    height: usize,
    bwidth: usize,
    bheight: usize,

    fn reset(self: *Map, points: []Point) void {
        for (0..self.points.len) |i| {
            self.points[i].reset(points[i]);
        }
    }
};

const north = '^';
const east = '>';
const west = '<';
const south = 'v';

const obstacle = '#';

fn getPointIndex(map: Map, x: usize, y: usize) usize {
    // for (0..map.points.len) |i| {
    //     if (map.points[i].x == x and map.points[i].y == y) return i;
    // }
    // return 0;
    return y * map.width + x;
}

fn getPoint(map: Map, x: usize, y: usize) Point {
    return map.points[getPointIndex(map, x, y)];
}

fn addObstacle(map: Map, x: usize, y: usize) void {
    map.points[getPointIndex(map, x, y)].symbol = '#';
}

fn checkTraversed(map: Map, guard: *Point, x: usize, y: usize) bool {
    const p = getPoint(map, x, y);

    switch (guard.symbol) {
        north => {
            return p.traversed.north;
        },
        south => {
            return p.traversed.south;
        },
        east => {
            return p.traversed.east;
        },
        west => {
            return p.traversed.west;
        },
        else => {},
    }
    return false;
}

fn markPoint(map: Map, guard: *Point) void {
    map.points[getPointIndex(map, guard.x, guard.y)].symbol = 'X';
}

fn markTraversed(map: Map, guard: *Point) void {
    const index: usize = getPointIndex(map, guard.x, guard.y);
    switch (guard.symbol) {
        north => {
            map.points[index].traversed.north = true;
        },
        south => {
            map.points[index].traversed.south = true;
        },
        east => {
            map.points[index].traversed.east = true;
        },
        west => {
            map.points[index].traversed.west = true;
        },
        else => {},
    }
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
    const data = @embedFile("puzzle6.data");
    const split = std.mem.split;
    var splits = split(u8, data, "\n");

    var points = std.ArrayList(Point).init(allocator);
    var originalPoints = std.ArrayList(Point).init(allocator);

    var x: usize = 0;
    var y: usize = 0;
    var width: usize = 0;
    var height: usize = 0;
    var guard = Point{ .symbol = '.', .x = 0, .y = 0, .traversed = Traversed{ .north = false, .south = false, .east = false, .west = false } };
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        x = 0;
        for (line) |c| {
            const t = Traversed{ .north = false, .south = false, .east = false, .west = false };
            if (c == north or c == south or c == east or c == west) {
                const p = Point{ .symbol = '.', .x = x, .y = y, .traversed = t };
                try points.append(p);
                try originalPoints.append(p);
                guard.symbol = c;
                guard.x = x;
                guard.y = y;
            } else {
                const p = Point{ .symbol = c, .x = x, .y = y, .traversed = t };
                try points.append(p);
                try originalPoints.append(p);
            }
            x += 1;
        }
        width = x;
        y += 1;
    }
    height = y;

    const originalGuard = Point{ .symbol = guard.symbol, .x = guard.x, .y = guard.y, .traversed = Traversed{ .north = false, .south = false, .east = false, .west = false } };
    var map = Map{ .points = points.items, .width = width, .height = height, .bwidth = width - 1, .bheight = height - 1 };

    // std.debug.print("Map is {d}x{d}\n", .{ map.width, map.height });
    // std.debug.print("Where is guard: {d},{d}\n", .{ guard.x, guard.y });

    // printMap(map, guard);

    const originalRoute = try guard.navigateMap(map);

    // std.debug.print("\n", .{});
    // printMap(map, guard);
    const positions = countMarks(map) + 1;
    print("Visited positions: {d}", .{positions});

    guard.reset(originalGuard);
    map.reset(originalPoints.items);
    // printMap(map, guard);

    var stuck: i32 = 0;
    for (0..originalRoute.path.len) |i| {
        const p = originalRoute.path[i];
        if (p.symbol != '.') {
            continue;
        }
        // std.debug.print("Checking obstacle at {d},{d}\n", .{ p.x, p.y });
        addObstacle(map, p.x, p.y);

        // std.debug.print("\n", .{});
        // printMap(map, guard);
        const route = try guard.navigateMap(map);
        if (!route.success) {
            stuck += 1;
        }
        guard.reset(originalGuard);
        map.reset(originalPoints.items);
    }

    print("Number of obstacle positions: {d}", .{stuck});

    defer points.deinit();
    defer originalPoints.deinit();
}
