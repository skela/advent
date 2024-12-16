const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const DataSource = enum { sample, real };
const task: Task = .two;
const source: DataSource = .sample;

const verbose: bool = switch (source) {
    .sample => true,
    .real => false,
};

const filename: []const u8 = switch (source) {
    .sample => "puzzle16.data.sample",
    .real => "puzzle16.data",
};

pub fn puzzle() !void {
    var points = std.ArrayList(Point).init(std.heap.page_allocator);
    defer points.deinit();

    var points2 = std.ArrayList(Point).init(std.heap.page_allocator);
    defer points2.deinit();

    var movements = std.ArrayList(Direction).init(std.heap.page_allocator);
    defer movements.deinit();

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
            try points2.append(Point{ .label = c, .x = x, .y = y });
            x += 1;
        }
        width = x;
        y += 1;
    }
    height = y;

    const map = Map{ .width = width, .height = height, .bwidth = width - 1, .bheight = height - 1, .points = points2 };
    var ctx = Context{ .map = map, .reindeer = reindeer, .goal = goal, .points = points.items, .paths = std.ArrayList(Path).init(std.heap.page_allocator) };
    ctx.printMap();

    try ctx.go(Direction.right);

    var score: i64 = std.math.maxInt(i64);
    for (paths) |p| {
        if (score > p.score) {
            score = p.score;
        }
    }

    print("The path with the lowest score has a score of {d}", .{score});
}

const Point = struct {
    label: u8,
    x: i64,
    y: i64,
};

const Path = struct {
    id: i64,
    path: std.ArrayList(Point),
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
    points: []Point,
};

const Velocity = struct {
    dx: i64,
    dy: i64,
};

const Direction = enum(u8) { up = 0, down = 1, left = 2, right = 3 };

fn velocity(dir: Direction) Velocity {
    return switch (dir) {
        .left => Velocity{ .dx = -1, .dy = 0 },
        .right => Velocity{ .dx = 1, .dy = 0 },
        .up => Velocity{ .dx = 0, .dy = -1 },
        .down => Velocity{ .dx = 0, .dy = 1 },
    };
}

fn turn(dir: Direction) Velocity {
    return switch (dir) {
        .left => .up,
        .right => .down,
        .up => .right,
        .down => .left,
    };
}

const Context = struct {
    map: Map,
    reindeer: Point,
    goal: Point,
    points: []Point,
    paths: std.ArrayList(Path),

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

    fn go(self: *Context, direction: Direction) !void {
        var path = Path{ .id = 1, .path = std.ArrayList(Point).init(std.heap.page_allocator), .score = 0 };

        while (self.canWalk(&path, self.reindeer, direction)) {
            self.walk(&path, self.reindeer, direction);
        }
    }

    fn canWalk(self: *Context, path: *Path, point: Point, direction: Direction) !bool {
        const v = velocity(direction);
        const np = self.getPoint(point.x + v.dx, point.y + v.dy);
        if (np == self.goal) {
            return false;
        }
        if (path.points.contains(np)) {
            return false;
        }
        if (np.label == '#') {
            return false;
        }
        return true;
    }

    fn walk(self: *Context, path: *Path, point: Point, direction: Direction) !bool {
        if (!self.canWalk(path, point, direction)) {}
        const v = velocity(direction);
        const np = self.getPoint(point.x + v.dx, point.y + v.dy);
        if (np == self.goal) {
            return true;
        }
        if (path.points.contains(np)) {
            return false;
        }
        if (np.label == '.') {
            path.score += 1;
            try path.points.append(np);
            self.walk(path, np, direction);
        } else if (np.label == '#') {
            path.score += 1000;
            self.walk(path, np, turn(direction));
        }
    }
};
