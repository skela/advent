const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.one;
const sample: bool = true;
const verbose: bool = false;

pub fn puzzle() !void {
    var points = std.ArrayList(Point).init(std.heap.page_allocator);
    defer points.deinit();
    var pointsn = std.ArrayList(Point).init(std.heap.page_allocator);
    defer pointsn.deinit();
    var areas = std.AutoArrayHashMap(u8, std.ArrayList(Point)).init(std.heap.page_allocator);
    defer areas.deinit();

    var labels = std.AutoArrayHashMap(u8, bool).init(std.heap.page_allocator);
    defer labels.deinit();

    const file = @embedFile(if (sample) "puzzle12.data.sample" else "puzzle12.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");

    var x: usize = 0;
    var y: usize = 0;
    var width: usize = 0;
    var height: usize = 0;
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        x = 0;
        for (line) |c| {
            const p = Point{ .label = c, .x = x, .y = y, .region = 0, .sides = 0 };
            try points.append(p);
            x += 1;

            if (labels.get(c)) |_| {} else {
                try labels.put(c, true);
            }
        }
        width = x;
        y += 1;
    }
    height = y;

    const map = Map{ .points = points.items, .width = width, .height = height, .bwidth = width - 1, .bheight = height - 1 };

    printMap(map);

    // print("Regions: {any}", .{labels.keys()});
    // for (labels.keys()) |label| {
    for (0..map.points.len) |i| {
        try map.points[i].navigateMap(areas, map);
    }

    for (areas.keys()) |k| {
        printRegion(map, k);
    }
}

const Point = struct {
    label: u8,
    x: usize,
    y: usize,
    region: i32,
    sides: usize,

    fn updateRegion(self: *Point, region: i32) void {
        self.region = region;
    }

    fn addSide(self: *Point) void {
        self.sides += 1;
    }

    fn navigateMap(self: *Point, areas: std.AutoArrayHashMap(u8, std.ArrayList(Point)), map: Map) !void {
        const directions: [4]Direction = [_]Direction{
            Direction.up,
            Direction.down,
            Direction.left,
            Direction.right,
        };

        for (directions) |d| {
            const next = switch (d) {
                Direction.up => getUp(map, self),
                Direction.down => getDown(map, self),
                Direction.left => getLeft(map, self),
                Direction.right => getRight(map, self),
            };
            if (next) |np| {
                var n = &np;
                if (n.label != self.label) {
                    self.sides += 1;
                    continue;
                }
                if (areas.getPtr(self.label)) |list| {
                    try list.append(self);
                } else {
                    var points = std.ArrayList(Point).init(std.heap.page_allocator);
                    try points.append(&self);
                }
                n.navigateMap(areas, map);
            } else {
                self.sides += 1;
            }
        }
    }
};

const Region = struct {
    id: i32,
    label: u8,
    points: []Point,
    sides: i32,
};

const Map = struct {
    points: []Point,
    width: usize,
    height: usize,
    bwidth: usize,
    bheight: usize,
};

fn getPointIndex(map: Map, x: usize, y: usize) usize {
    return y * map.width + x;
}

fn getPoint(map: Map, x: usize, y: usize) Point {
    return map.points[getPointIndex(map, x, y)];
}

fn printMap(map: Map) void {
    var x: usize = 0;
    var y: usize = 0;
    for (map.points) |p| {
        x = p.x;
        y = p.y;
        std.debug.print("{c}", .{p.label});
        if (x == map.bwidth) {
            std.debug.print("\n", .{});
        }
    }
}

fn printRegion(map: Map, region: i32) void {
    var x: usize = 0;
    var y: usize = 0;
    for (map.points) |p| {
        x = p.x;
        y = p.y;
        if (p.region == region) {
            std.debug.print("{c}", .{p.label});
        } else {
            std.debug.print(".", .{});
        }
        if (x == map.bwidth) {
            std.debug.print("\n", .{});
        }
    }
}

const Direction = enum(u8) { up = 0, down = 1, left = 2, right = 3 };

fn getUp(self: Map, p: *Point) ?Point {
    if (p.y == 0) return null;
    return getPoint(self, p.x, p.y - 1);
}

fn getDown(self: Map, p: *Point) ?Point {
    if (p.y == self.bheight) return null;
    return getPoint(self, p.x, p.y + 1);
}

fn getLeft(self: Map, p: *Point) ?Point {
    if (p.x == 0) return null;
    return getPoint(self, p.x - 1, p.y);
}

fn getRight(self: Map, p: *Point) ?Point {
    if (p.x == self.bwidth) return null;
    return getPoint(self, p.x + 1, p.y);
}
