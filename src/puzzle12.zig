const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.one;
const sample: bool = true;
const verbose: bool = true;

pub fn puzzle() !void {
    var points = std.ArrayList(Point).init(std.heap.page_allocator);
    defer points.deinit();
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
            const p = Point{ .label = c, .x = x, .y = y, .region = 0, .sides = 4 };
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
    var ctx = Context{ .map = map, .labels = labels };
    ctx.printMap();

    const directions: [4]Direction = [_]Direction{
        Direction.up,
        Direction.down,
        Direction.left,
        Direction.right,
    };

    for (0..map.points.len) |i| {
        const point: Point = ctx.map.points[i];
        var sides = point.sides;
        for (directions) |d| {
            const next = switch (d) {
                Direction.up => ctx.getUp(point),
                Direction.down => ctx.getDown(point),
                Direction.left => ctx.getLeft(point),
                Direction.right => ctx.getRight(point),
            };
            if (next) |n| {
                if (n.label == point.label) {
                    sides = sides - 1;
                }
            }
        }
        ctx.map.points[i].sides = sides;
    }

    var next_region_id: i32 = 1;

    for (0..ctx.map.points.len) |i| {
        const point: Point = ctx.map.points[i];

        if (point.region != 0) continue;

        const region_id = next_region_id;
        next_region_id += 1;

        var stack = std.ArrayList(Point).init(std.heap.page_allocator);
        defer stack.deinit();

        try stack.append(point);

        while (stack.items.len > 0) {
            const current = stack.pop();

            if (ctx.map.points[ctx.getPointIndex(current.x, current.y)].region != 0) continue;

            ctx.map.points[ctx.getPointIndex(current.x, current.y)].region = region_id;

            for (directions) |d| {
                const neighbor = switch (d) {
                    Direction.up => ctx.getUp(current),
                    Direction.down => ctx.getDown(current),
                    Direction.left => ctx.getLeft(current),
                    Direction.right => ctx.getRight(current),
                };
                if (neighbor) |n| {
                    if (n.label == current.label and n.region == 0) {
                        try stack.append(n);
                    }
                }
            }
        }
    }

    var regions = std.ArrayList(Region).init(std.heap.page_allocator);
    defer regions.deinit();

    for (0..@intCast(next_region_id)) |id| {
        var ps = std.ArrayList(Point).init(std.heap.page_allocator);
        var label: u8 = 0;
        for (ctx.map.points) |p| {
            if (p.region == id) {
                try ps.append(p);
                label = p.label;
            }
        }
        if (ps.items.len > 0) {
            try regions.append(Region{ .id = @intCast(id), .points = ps.items, .sides = 0, .label = label });
        }
    }

    var sum: i32 = 0;
    for (regions.items) |region| {
        var perimeter: i32 = 0;
        var area: i32 = 0;
        for (region.points) |p| {
            perimeter += @intCast(p.sides);
            area += 1;
        }
        const sides = try ctx.calculateUniqueSidesForRegion(region.points);
        print("Region {d} ({c}) area is {d} perimeter {d} - sides {d}", .{ region.id, region.label, area, perimeter, sides });
        sum += (perimeter * area);
        if (verbose) {
            ctx.printRegion(region.id);
            print("", .{});
        }
    }

    print("The sum is {d}", .{sum});
}

const Point = struct {
    label: u8,
    x: usize,
    y: usize,
    region: i32,
    sides: usize,
};

const Direction = enum(u8) { up = 0, down = 1, left = 2, right = 3 };

fn turnDirection(direction: Direction) Direction {
    return switch (direction) {
        .up => .right,
        .right => .down,
        .down => .left,
        .left => .up,
    };
}

const Context = struct {
    map: Map,
    labels: std.AutoArrayHashMap(u8, bool),

    fn getPointIndex(self: *Context, x: usize, y: usize) usize {
        return y * self.map.width + x;
    }

    fn getPoint(self: *Context, x: usize, y: usize) Point {
        return self.map.points[getPointIndex(self, x, y)];
    }

    fn getPointDelta(self: *Context, point: Point, dx: isize, dy: isize) ?Point {
        const x: isize = @intCast(point.x);
        const y: isize = @intCast(point.y);

        if (dy < 0 and y == 0) return null;
        if (dy > 0 and y == self.map.bheight) return null;
        if (dx < 0 and x == 0) return null;
        if (dx > 0 and x == self.map.bwidth) return null;
        return self.map.points[getPointIndex(self, @intCast(x + dx), @intCast(y + dy))];
    }

    fn addSide(self: *Context, p: Point) void {
        self.map.points[getPointIndex(self, p.x, p.y)].sides += 1;
    }

    fn removeSide(self: *Context, p: Point) void {
        self.map.points[getPointIndex(self, p.x, p.y)].sides -= 1;
    }

    fn setSides(self: *Context, p: Point, sides: usize) void {
        self.map.points[getPointIndex(self, p.x, p.y)].sides = sides;
    }

    fn getDirection(self: *Context, p: Point, direction: Direction) ?Point {
        return switch (direction) {
            .up => self.getUp(p),
            .down => self.getDown(p),
            .right => self.getRight(p),
            .left => self.getLeft(p),
        };
    }

    fn getUp(self: *Context, p: Point) ?Point {
        if (p.y == 0) return null;
        return getPoint(self, p.x, p.y - 1);
    }

    fn getDown(self: *Context, p: Point) ?Point {
        if (p.y == self.map.bheight) return null;
        return getPoint(self, p.x, p.y + 1);
    }

    fn getLeft(self: *Context, p: Point) ?Point {
        if (p.x == 0) return null;
        return getPoint(self, p.x - 1, p.y);
    }

    fn getRight(self: *Context, p: Point) ?Point {
        if (p.x == self.map.bwidth) return null;
        return getPoint(self, p.x + 1, p.y);
    }

    fn printMap(self: *Context) void {
        for (self.map.points) |p| {
            std.debug.print("{c}", .{p.label});
            if (p.x == self.map.bwidth) {
                std.debug.print("\n", .{});
            }
        }
    }

    fn printRegion(self: *Context, id: i32) void {
        for (self.map.points) |p| {
            if (p.region == id) {
                std.debug.print("{c}", .{p.label});
            } else {
                std.debug.print(".", .{});
            }
            if (p.x == self.map.bwidth) {
                std.debug.print("\n", .{});
            }
        }
    }

    fn calculateUniqueSidesForRegion(self: *Context, region: []Point) !usize {
        if (region.len == 0) {
            return 0;
        }
        // var visited = std.AutoArrayHashMap(Vector, bool).init(std.heap.page_allocator);
        // defer visited.deinit();

        var unique_sides: usize = 0;
        for (region) |point| {
            unique_sides += try self.numberOfCorners(point);
        }
        return unique_sides;
    }

    fn numberOfCorners(self: *Context, point: Point) !usize {
        const tl = self.getPointDelta(point, -1, -1);
        const tr = self.getPointDelta(point, 1, -1);
        const bl = self.getPointDelta(point, -1, 1);
        const br = self.getPointDelta(point, 1, 1);

        var corners: usize = 0;
        if (tl) |n| {
            if (n.region != point.region) {
                corners += 1;
            }
        } else {
            corners += 1;
        }
        if (tr) |n| {
            if (n.region != point.region) {
                corners += 1;
            }
        } else {
            corners += 1;
        }
        if (bl) |n| {
            if (n.region != point.region) {
                corners += 1;
            }
        } else {
            corners += 1;
        }
        if (br) |n| {
            if (n.region != point.region) {
                corners += 1;
            }
        } else {
            corners += 1;
        }
        return corners;
    }
};

const Edge = struct {
    start: Point,
    end: ?Point,
};
const Vector = struct {
    x: usize,
    y: usize,
    direction: Direction,
};

const Region = struct {
    id: i32,
    label: u8,
    points: []Point,
    sides: i32, // wtf
};

const Map = struct {
    points: []Point,
    width: usize,
    height: usize,
    bwidth: usize,
    bheight: usize,
};
