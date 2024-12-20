const std = @import("std");
pub const print = @import("utils.zig").print;
const deq = @import("deque.zig");

const Task = enum { one, two };
const DataSource = enum { sample, real };
const task: Task = .two;
const source: DataSource = .real;

const savingsAmount: i64 = switch (source) {
    .real => 100,
    .sample => 2,
};

const cheatLimit: i64 = switch (task) {
    .one => 2,
    .two => 20,
};

const verbose: bool = switch (source) {
    .sample => true,
    .real => false,
};

const filename: []const u8 = switch (source) {
    .sample => "puzzle20.data.sample",
    .real => "puzzle20.data",
};

pub fn puzzle() !void {
    var points = std.ArrayList(Point).init(std.heap.page_allocator);
    defer points.deinit();

    var x: i32 = 0;
    var y: i32 = 0;
    var width: i32 = 0;
    var height: i32 = 0;
    var goal = Point{ .x = 0, .y = 0, .label = 'E' };
    var start = Point{ .x = 0, .y = 0, .label = 'S' };
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
                start = p;
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
    var ctx = Context{ .map = map, .start = start, .goal = goal, .points = points.items, .paths = std.ArrayList(Path).init(std.heap.page_allocator), .costs = costs };
    ctx.printMap();

    const distanceFromStart = try ctx.walk(ctx.start);
    defer distanceFromStart.deinit();

    const distanceFromEnd = try ctx.walk(ctx.goal);
    defer distanceFromEnd.deinit();

    const bestScore = distanceFromStart.items[ctx.getIndex(ctx.goal.x, ctx.goal.y)];

    var queue = try deq.Deque(LengthPoint).init(std.heap.page_allocator);
    defer queue.deinit();

    var cheats = std.ArrayList(CheatPoint).init(std.heap.page_allocator);
    defer cheats.deinit();

    var visited = std.AutoArrayHashMap(Point, i64).init(std.heap.page_allocator);
    defer visited.deinit();

    for (0..ctx.points.len) |i| {
        if (ctx.points[i].label == '#' or distanceFromStart.items[i] == std.math.maxInt(i64)) continue;

        visited.clearAndFree();
        const p = ctx.points[i];
        try queue.pushFront(LengthPoint{ .point = p, .length = 0 });

        while (queue.len() > 0) {
            const n = if (queue.popBack()) |k| k else continue;
            const length = n.length;
            if (n.point.label != '#' and distanceFromEnd.items[ctx.getIndex(n.point.x, n.point.y)] != std.math.maxInt(i64)) {
                const delta = bestScore - (distanceFromStart.items[i] + length + distanceFromEnd.items[ctx.getIndex(n.point.x, n.point.y)]);
                try cheats.append(CheatPoint{ .start = p, .end = n.point, .delta = delta });
            }

            if (length < cheatLimit) {
                const nlength = length + 1;

                for (directions) |d| {
                    if (ctx.getPointChange(n.point, d, 1)) |nn| {
                        const v = if (visited.get(nn)) |ov| ov else 0;
                        if (v == 0 or v > nlength) {
                            try visited.put(nn, nlength);
                            try queue.pushFront(LengthPoint{ .point = nn, .length = nlength });
                        }
                    }
                }
            }
        }
    }

    var numberOfCheatsThatSaveSavingsAmount: i64 = 0;
    var numberOfCheatsThatSaveAtleastSavingsAmount: i64 = 0;

    print("Found {d} number of cheats", .{cheats.items.len});

    for (cheats.items) |cheat| {
        if (cheat.delta >= savingsAmount) numberOfCheatsThatSaveAtleastSavingsAmount += 1;
        if (cheat.delta == savingsAmount) numberOfCheatsThatSaveSavingsAmount += 1;
    }

    print("Best Score is {d} - Number of cheats that save {d} picoseconds: exact {d} atleast: {d}", .{ bestScore, savingsAmount, numberOfCheatsThatSaveSavingsAmount, numberOfCheatsThatSaveAtleastSavingsAmount });
}

const Point = struct {
    label: u8,
    x: i64,
    y: i64,
};

const Movement = struct {
    score: i64,
    vector: Vector,
    path: std.ArrayList(Point),
};

const LengthPoint = struct {
    length: i64,
    point: Point,
};

const CheatPoint = struct {
    start: Point,
    end: Point,
    delta: i64,
};

const Path = struct {
    path: []Point,
    lookup: std.AutoArrayHashMap(usize, Point),
    score: i64,
};

const Vector = struct {
    point: Point,
    direction: Direction,
    cost: i64,
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

fn rotationCost(dir: Direction, dir2: Direction) i64 {
    if (dir == dir2) return 0;
    return 1;
}

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

fn velocityScale(dir: Direction, scale: i64) Velocity {
    return switch (dir) {
        .left => Velocity{ .dx = -scale, .dy = 0 },
        .right => Velocity{ .dx = scale, .dy = 0 },
        .up => Velocity{ .dx = 0, .dy = -scale },
        .down => Velocity{ .dx = 0, .dy = scale },
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

fn sortMovements(context: void, a: Movement, b: Movement) std.math.Order {
    _ = context;
    return std.math.order(a.score, b.score);
}

const Context = struct {
    map: Map,
    start: Point,
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

    fn getPointChange(self: *Context, p: Point, dir: Direction, scale: i64) ?Point {
        const v = velocityScale(dir, scale);
        switch (dir) {
            .up => {
                if (p.y == 0) return null;
                if (scale == 2 and p.y == 1) return null;
            },
            .down => {
                if (p.y == self.map.bheight) return null;
                if (scale == 2 and p.y == self.map.bheight - 1) return null;
            },
            .left => {
                if (p.x == 0) return null;
                if (scale == 2 and p.x == 1) return null;
            },
            .right => {
                if (p.x == self.map.bwidth) return null;
                if (scale == 2 and p.x == self.map.bwidth - 1) return null;
            },
        }
        return getPoint(self, p.x + v.dx, p.y + v.dy);
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

    fn walk(self: *Context, start: Point) !std.ArrayList(i64) {
        var queue = try deq.Deque(Point).init(std.heap.page_allocator);
        defer queue.deinit();
        try queue.pushFront(start);

        var distances = std.ArrayList(i64).init(std.heap.page_allocator);
        for (0..self.points.len) |_| {
            try distances.append(std.math.maxInt(i64));
        }
        distances.items[self.getIndex(start.x, start.y)] = 0;

        while (queue.len() > 0) {
            const p = if (queue.popBack()) |k| k else continue;

            for (directions) |direction| {
                if (self.getPointChange(p, direction, 1)) |np| {
                    if (np.label == '#') continue;
                    const ni = self.getIndex(np.x, np.y);
                    const pi = self.getIndex(p.x, p.y);
                    const newScore = distances.items[pi] + 1;
                    if (distances.items[ni] > newScore) {
                        distances.items[ni] = newScore;
                        try queue.pushFront(np);
                    }
                }
            }
        }
        return distances;
    }
};
