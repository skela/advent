const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const DataSource = enum { sample, sample2, real };
const task: Task = .one;
const source: DataSource = .real;

const verbose: bool = switch (source) {
    .sample => true,
    .sample2 => true,
    .real => false,
};

const filename: []const u8 = switch (source) {
    .sample => "puzzle16.data.sample",
    .sample2 => "puzzle16.data.sample2",
    .real => "puzzle16.data",
};

pub fn puzzle() !void {
    var points = std.ArrayList(Point).init(std.heap.page_allocator);
    defer points.deinit();

    var x: i32 = 0;
    var y: i32 = 0;
    var width: i32 = 0;
    var height: i32 = 0;
    var goal = Point{ .x = 0, .y = 0, .label = 'E' };
    var reindeer = Point{ .x = 0, .y = 0, .label = 'S' };
    const file = @embedFile(filename);
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        x = 0;
        for (line) |c| {
            const p = Point{ .label = c, .x = x, .y = y };
            if (c == 'E') {
                goal = p;
            }
            if (c == 'S') {
                reindeer = p;
            }
            try points.append(p);
            x += 1;
        }
        width = x;
        y += 1;
    }
    height = y;

    var costs = std.AutoArrayHashMap(Vector, i64).init(std.heap.page_allocator);
    defer costs.deinit();

    const map = Map{ .width = width, .height = height, .bwidth = width - 1, .bheight = height - 1 };
    var ctx = Context{ .map = map, .reindeer = reindeer, .goal = goal, .points = points.items, .paths = std.ArrayList(Path).init(std.heap.page_allocator), .costs = costs };
    ctx.printMap();

    var movements = std.PriorityQueue(Movement, void, sortMovements).init(std.heap.page_allocator, undefined);
    defer movements.deinit();

    const emp = std.ArrayList(Point).init(std.heap.page_allocator);
    try movements.add(Movement{ .score = 0, .vector = Vector{ .point = reindeer, .direction = .right }, .path = emp.items });

    var bestScore: i64 = std.math.maxInt(i64);
    var numberOfBestScores: i64 = 0;

    while (movements.items.len > 0) {
        const m = movements.remove();
        if (m.vector.point.x == goal.x and m.vector.point.y == goal.y) {
            bestScore = m.score;

            try ctx.createPath(m);
            break;
        }

        if (ctx.costs.contains(m.vector)) {
            continue;
        }

        try ctx.costs.put(m.vector, m.score);

        var surroundings = std.ArrayList(Vector).init(std.heap.page_allocator);
        defer surroundings.deinit();

        for (directions) |direction| {
            if (direction == reverse(m.vector.direction)) {
                continue;
            }
            const v = velocity(direction);
            try surroundings.append(Vector{ .point = ctx.getPoint(m.vector.point.x + v.dx, m.vector.point.y + v.dy), .direction = direction });
        }

        for (surroundings.items) |s| {
            if (s.point.label == '#') {
                continue;
            }

            const newScore = rotationCost(m.vector.direction, s.direction) + 1 + m.score;

            const newPosition = s.point;
            var path = std.ArrayList(Point).init(std.heap.page_allocator);
            for (m.path) |p| {
                try path.append(p);
            }
            try path.append(newPosition);
            const nm = Movement{ .score = newScore, .vector = Vector{ .point = newPosition, .direction = s.direction }, .path = path.items };
            try movements.add(nm);
        }
    }

    try movements.add(Movement{ .score = 0, .vector = Vector{ .point = reindeer, .direction = .right }, .path = emp.items });

    while (movements.items.len > 0) {
        const m = movements.remove();
        if (m.score > bestScore) {
            continue;
        }

        if (m.vector.point.x == goal.x and m.vector.point.y == goal.y) {
            try ctx.createPath(m);
            continue;
        }

        if (ctx.costs.get(m.vector)) |c| {
            if (m.score == c) {
                numberOfBestScores += 1;
            } else {
                continue;
            }
        }

        try ctx.costs.put(m.vector, m.score);

        var surroundings = std.ArrayList(Vector).init(std.heap.page_allocator);
        defer surroundings.deinit();

        for (directions) |direction| {
            if (direction == reverse(m.vector.direction)) {
                continue;
            }
            const v = velocity(direction);
            try surroundings.append(Vector{ .point = ctx.getPoint(m.vector.point.x + v.dx, m.vector.point.y + v.dy), .direction = direction });
        }

        for (surroundings.items) |s| {
            if (s.point.label == '#') {
                continue;
            }

            const newScore = rotationCost(m.vector.direction, s.direction) + 1 + m.score;
            if (newScore > bestScore) {
                continue;
            }

            const newPosition = s.point;
            var path = std.ArrayList(Point).init(std.heap.page_allocator);
            for (m.path) |p| {
                try path.append(p);
            }
            try path.append(newPosition);
            const nm = Movement{ .score = newScore, .vector = Vector{ .point = newPosition, .direction = s.direction }, .path = path.items };
            try movements.add(nm);
        }
    }

    var warmseats = std.AutoArrayHashMap(Point, i64).init(std.heap.page_allocator);
    defer warmseats.deinit();

    for (ctx.paths.items) |path| {
        // ctx.printPath(path);
        for (0..path.path.len) |i| {
            const p = path.path[i];
            if (warmseats.get(p)) |s| {
                try warmseats.put(p, s + 1);
            } else {
                try warmseats.put(p, 1);
            }
        }
    }

    var counter: i64 = 1;
    for (warmseats.keys()) |s| {
        if (warmseats.get(s)) |c| {
            if (c > 0) counter += 1;
        }
    }

    print("Best Score is {d} - Found {d} warm seats", .{ bestScore, counter });
}

fn sortMovements(context: void, a: Movement, b: Movement) std.math.Order {
    _ = context;
    return std.math.order(a.score, b.score);
}

const Point = struct {
    label: u8,
    x: i64,
    y: i64,
};

const Movement = struct {
    score: i64,
    vector: Vector,
    path: []Point,
};

const Path = struct {
    path: []Point,
    lookup: std.AutoArrayHashMap(usize, Point),
    score: i64,
};

const Vector = struct {
    point: Point,
    direction: Direction,
};

const Map = struct {
    width: i64,
    height: i64,
    bwidth: i64,
    bheight: i64,
};

const Velocity = struct {
    dx: i64,
    dy: i64,
};

const Direction = enum(u8) { up = 0, down = 1, left = 2, right = 3 };

const directions: [4]Direction = [_]Direction{
    Direction.up,
    Direction.down,
    Direction.left,
    Direction.right,
};

fn velocity(dir: Direction) Velocity {
    return switch (dir) {
        .left => Velocity{ .dx = -1, .dy = 0 },
        .right => Velocity{ .dx = 1, .dy = 0 },
        .up => Velocity{ .dx = 0, .dy = -1 },
        .down => Velocity{ .dx = 0, .dy = 1 },
    };
}

fn turn(dir: Direction) Direction {
    return switch (dir) {
        .left => .up,
        .right => .down,
        .up => .right,
        .down => .left,
    };
}

fn reverse(dir: Direction) Direction {
    return switch (dir) {
        .left => .right,
        .right => .left,
        .up => .down,
        .down => .up,
    };
}

fn rotationCost(dir: Direction, dir2: Direction) i64 {
    if (dir == dir2) return 0;
    if (dir == reverse(dir2)) return 2000;
    return 1000;
}

const Context = struct {
    map: Map,
    reindeer: Point,
    goal: Point,
    points: []Point,
    paths: std.ArrayList(Path),
    costs: std.AutoArrayHashMap(Vector, i64),

    fn getPoint(self: *Context, x: i64, y: i64) Point {
        return self.points[self.getIndex(x, y)];
    }

    fn getIndex(self: *Context, x: i64, y: i64) usize {
        return @intCast(y * self.map.width + x);
    }

    fn printMap(self: *Context) void {
        for (self.points) |c| {
            std.debug.print("{c}", .{c.label});
            if (c.x == self.map.bwidth) {
                std.debug.print("\n", .{});
            }
        }
        print("\n", .{});
    }

    fn createPath(self: *Context, movement: Movement) !void {
        var points = std.ArrayList(Point).init(std.heap.page_allocator);
        var lookup = std.AutoArrayHashMap(usize, Point).init(std.heap.page_allocator);

        for (movement.path) |p| {
            try points.insert(0, p);
            try lookup.put(self.getIndex(p.x, p.y), p);
        }
        // defer points.deinit();

        try self.paths.append(Path{ .score = movement.score, .path = points.items, .lookup = lookup });
    }

    fn printPath(self: *Context, path: Path) void {
        var index: usize = 0;
        var yay: i64 = 0;
        for (self.points) |c| {
            if (path.lookup.get(index)) |_| {
                std.debug.print("x", .{});
                yay += 1;
            } else {
                std.debug.print("{c}", .{c.label});
            }
            if (c.x == self.map.bwidth) {
                std.debug.print("\n", .{});
            }
            index += 1;
        }
        print("\n", .{});

        print("Found {d} yays", .{yay});
        print("Found {d} points", .{path.path.len});
    }
};
