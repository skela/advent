const std = @import("std");
pub const print = @import("utils.zig").print;

const sample: bool = false;

pub fn puzzle() !void {
    var points = std.ArrayList(Point).init(std.heap.page_allocator);
    defer points.deinit();

    var starts = std.ArrayList(Point).init(std.heap.page_allocator);
    defer starts.deinit();

    var ends = std.ArrayList(Point).init(std.heap.page_allocator);
    defer ends.deinit();

    const file = @embedFile(if (sample) "puzzle10.data.sample" else "puzzle10.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    const ascii_zero: i32 = @intCast('0');

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
            if (c == '.') {
                const p = Point{ .elevation = -1, .x = x, .y = y };
                try points.append(p);
            } else {
                const i: i32 = @intCast(c);
                const v: i32 = @intCast(i - ascii_zero);
                const p = Point{ .elevation = v, .x = x, .y = y };
                try points.append(p);
                if (v == 0) {
                    try starts.append(p);
                } else if (v == 9) {
                    try ends.append(p);
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

    var score: i32 = 0;
    var unique: i32 = 0;
    for (starts.items) |s| {
        for (ends.items) |e| {
            const res = navigate(map, s, e);
            if (res > 0) {
                score += 1;
            }
            unique += res;
        }
    }

    print("Trailhead score is {d}", .{score});
    print("Trailhead rating is {d}", .{unique});
}

const Point = struct {
    elevation: i32,
    x: i32,
    y: i32,
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

fn printMap(map: Map) void {
    var x: i32 = 0;
    var y: i32 = 0;
    for (map.points) |p| {
        x = p.x;
        y = p.y;
        if (p.elevation == -1) {
            std.debug.print("{c}", .{'.'});
        } else {
            std.debug.print("{d}", .{p.elevation});
        }
        if (x == map.bwidth) {
            std.debug.print("\n", .{});
        }
    }
}

fn navigate(map: Map, start: Point, end: Point) i32 {
    if (start.x == end.x and start.y == end.y) return 1;
    const directions: [4]Direction = [_]Direction{
        Direction.up,
        Direction.down,
        Direction.left,
        Direction.right,
    };
    var sum: i32 = 0;
    for (directions) |d| {
        const next = switch (d) {
            Direction.up => getUp(map, start),
            Direction.down => getDown(map, start),
            Direction.left => getLeft(map, start),
            Direction.right => getRight(map, start),
        };
        if (next) |n| {
            if (start.elevation + 1 == n.elevation) {
                sum += navigate(map, n, end);
            }
        }
    }

    return sum;
}

const Direction = enum(u8) { up = 0, down = 1, left = 2, right = 3 };

fn getUp(self: Map, p: Point) ?Point {
    if (p.y == 0) return null;
    return getPoint(self, p.x, p.y - 1);
}

fn getDown(self: Map, p: Point) ?Point {
    if (p.y == self.bheight) return null;
    return getPoint(self, p.x, p.y + 1);
}

fn getLeft(self: Map, p: Point) ?Point {
    if (p.x == 0) return null;
    return getPoint(self, p.x - 1, p.y);
}

fn getRight(self: Map, p: Point) ?Point {
    if (p.x == self.bwidth) return null;
    return getPoint(self, p.x + 1, p.y);
}
