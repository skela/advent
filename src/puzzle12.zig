const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.one;
const sample: bool = false;
const verbose: bool = false;

pub fn puzzle() !void {
    var points = std.ArrayList(Point).init(std.heap.page_allocator);
    defer points.deinit();
    var labels = std.AutoArrayHashMap(u8, bool).init(std.heap.page_allocator);
    defer labels.deinit();

    var visitedEdges = std.AutoArrayHashMap(Edge, bool).init(std.heap.page_allocator);
    defer visitedEdges.deinit();

    const file = @embedFile(if (sample) "puzzle12.data.sample" else "puzzle12.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");

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
    var ctx = Context{ .map = map, .labels = labels, .visitedEdges = visitedEdges };
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
    var discount: i32 = 0;
    for (regions.items) |region| {
        var perimeter: i32 = 0;
        var area: i32 = 0;
        for (region.points) |p| {
            perimeter += @intCast(p.sides);
            area += 1;
        }
        const sides: i32 = @intCast(try ctx.calculateUniqueSidesForRegion(region.points));
        print("Region {d} ({c}) area is {d} perimeter {d} - sides {d}", .{ region.id, region.label, area, perimeter, sides });
        sum += (perimeter * area);
        discount += (area * sides);
        if (verbose) {
            ctx.printRegion(region.id);
            print("", .{});
        }
    }

    print("The sum is {d}", .{sum});
    print("The discount is {d}", .{discount});
}

const Point = struct {
    label: u8,
    x: i32,
    y: i32,
    region: i32,
    sides: i32,
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
    visitedEdges: std.AutoArrayHashMap(Edge, bool),

    fn getPointIndex(self: *Context, x: i32, y: i32) usize {
        return @intCast(y * self.map.width + x);
    }

    fn getPoint(self: *Context, x: i32, y: i32) Point {
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
        var top = std.ArrayList(Edge).init(std.heap.page_allocator);
        defer top.deinit();
        var bottom = std.ArrayList(Edge).init(std.heap.page_allocator);
        defer bottom.deinit();
        var left = std.ArrayList(Edge).init(std.heap.page_allocator);
        defer left.deinit();
        var right = std.ArrayList(Edge).init(std.heap.page_allocator);
        defer right.deinit();

        const directions: [4]Direction = [_]Direction{
            Direction.up,
            Direction.down,
            Direction.left,
            Direction.right,
        };

        // var unique_sides: usize = 0;
        for (region) |point| {
            for (directions) |direction| {
                const np = self.getDirection(point, direction);
                if (!isInside(np, point.region)) {
                    switch (direction) {
                        .up => try top.append(Edge{ .direction = direction, .x = point.x, .y = point.y }),
                        .down => try bottom.append(Edge{ .direction = direction, .x = point.x, .y = point.y }),
                        .left => try left.append(Edge{ .direction = direction, .x = point.x, .y = point.y }),
                        .right => try right.append(Edge{ .direction = direction, .x = point.x, .y = point.y }),
                        // if (np) |_| {
                        //     try edges.put(Edge{ .direction = direction }, true);
                        // } else {
                        //     try edges.put(Edge{ .direction = direction }, true);
                        // }
                    }
                }
            }
            // if (try self.numberOfCorners(point)) {
            //     unique_sides += 1;
            // }
        }

        var sides: usize = 0;
        sides += try self.uniqueSides(top.items);
        sides += try self.uniqueSides(left.items);
        sides += try self.uniqueSides(right.items);
        sides += try self.uniqueSides(bottom.items);
        return sides;
        // var allPoints = std.ArrayList(Edge).init(std.heap.page_allocator);

        // unique_sides = top.items.len + left.items.len + right.items.len + bottom.items.len;
        // var edge = top.pop();
        // for (top.items) |e| {
        //     if (e.y - edge.y == 1) {
        //         unique_sides -= 1;
        //     }
        // }
        // edge = bottom.pop();
        // for (bottom.items) |e| {
        //     if (e.y - edge.y == 1) {
        //         unique_sides -= 1;
        //     }
        // }
        // edge = left.pop();
        // for (top.items) |e| {
        //     if (e.x - edge.x == 1) {
        //         unique_sides -= 1;
        //     }
        // }
        // edge = right.pop();
        // for (right.items) |e| {
        //     if (e.x - edge.x == 1) {
        //         unique_sides -= 1;
        //     }
        // }
        // for (top.items) |point| {
        //     try allPoints.append(point);
        // }
        // for (left.items) |point| {
        //     try allPoints.append(point);
        // }
        // for (bottom.items) |point| {
        //     try allPoints.append(point);
        // }
        // for (right.items) |point| {
        //     try allPoints.append(point);
        // }
        //
        // const pointCount = allPoints.items.len;
        // var visited = std.ArrayList(bool).init(std.heap.page_allocator);
        //
        // for (0..pointCount) |_| try visited.append(false);
        //
        // var sidesCount: usize = 0;
        //
        // for (0..pointCount) |i| {
        //     if (!visited.items[i]) {
        //         dfs(allPoints.items, visited.items, i);
        //         sidesCount += 1;
        //     }
        // }
        // return sidesCount;
    }

    fn uniqueSides(self: *Context, edge: []const Edge) !usize {
        var count: usize = edge.len;
        for (edge) |e1| {
            try self.visitedEdges.put(e1, true);
            for (edge) |e2| {
                if (self.visitedEdges.contains(e2) or e1.direction != e2.direction) {
                    continue;
                }

                const dx = @abs(e2.x - e1.x);
                const dy = @abs(e2.y - e1.y);

                if (dx == 0 and dy == 1 or dx == 1 and dy == 0) {
                    count -= 1;
                }
            }
        }

        return count;
    }

    fn isConnected(p1: Edge, p2: Edge) bool {
        const dx = @abs(p1.x - p2.x);
        const dy = @abs(p1.x - p2.y);
        return dx <= 1 and dy <= 1;
    }

    fn dfs(points: []const Edge, visited: []bool, node: usize) void {
        if (visited[node]) return;
        visited[node] = true;

        for (0..points.len) |i| {
            if (!visited[i] and isConnected(points[node], points[i])) {
                dfs(points, visited, i);
            }
        }
    }

    fn dxDirection(direction: Direction, point: Point) ?usize {
        return switch (direction) {
            .up => null,
            .down => null,
            .left => point.x,
            .right => point.x,
        };
    }

    fn dyDirection(direction: Direction, point: Point) ?usize {
        return switch (direction) {
            .up => point.y,
            .down => point.y,
            .left => null,
            .right => null,
        };
    }

    fn isInside(tl: ?Point, region: i32) bool {
        if (tl) |n| {
            if (n.region != region) {
                return false;
            }
        } else {
            return false;
        }
        return true;
    }

    fn numberOfCorners(self: *Context, point: Point) !bool {
        const tl = self.getPointDelta(point, -1, -1);
        const tr = self.getPointDelta(point, 1, -1);
        const bl = self.getPointDelta(point, -1, 1);
        const br = self.getPointDelta(point, 1, 1);
        const u = self.getPointDelta(point, 0, -1);
        const d = self.getPointDelta(point, 0, 1);
        const l = self.getPointDelta(point, -1, 0);
        const r = self.getPointDelta(point, 1, 0);

        var tlb: bool = false;
        if (tl) |n| {
            if (n.region != point.region) {
                tlb = true;
            }
        } else {
            tlb = true;
        }
        var trb: bool = false;
        if (tr) |n| {
            if (n.region != point.region) {
                trb = true;
            }
        } else {
            trb = true;
        }
        var blb: bool = false;
        if (bl) |n| {
            if (n.region != point.region) {
                blb = true;
            }
        } else {
            blb = true;
        }
        var brb: bool = false;
        if (br) |n| {
            if (n.region != point.region) {
                brb = true;
            }
        } else {
            brb = true;
        }
        var lb: bool = false;
        if (l) |n| {
            if (n.region != point.region) {
                lb = true;
            }
        } else {
            lb = true;
        }
        var rb: bool = false;
        if (r) |n| {
            if (n.region != point.region) {
                rb = true;
            }
        } else {
            rb = true;
        }
        var ub: bool = false;
        if (u) |n| {
            if (n.region != point.region) {
                ub = true;
            }
        } else {
            ub = true;
        }
        var db: bool = false;
        if (d) |n| {
            if (n.region != point.region) {
                db = true;
            }
        } else {
            db = true;
        }

        if (tlb and brb) {
            return true;
        }
        if (trb and blb) {
            return true;
        }

        return false;
    }
};

const Edge = struct {
    direction: Direction,
    x: i32,
    y: i32,
};

const XEdge = struct {
    x: i32,
    direction: Direction,
    label: u8,
};

const YEdge = struct {
    y: i32,
    direction: Direction,
    label: u8,
};

const Vector = struct {
    x: i32,
    y: i32,
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
    width: i32,
    height: i32,
    bwidth: i32,
    bheight: i32,
};
