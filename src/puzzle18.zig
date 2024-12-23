const std = @import("std");
pub const utils = @import("utils.zig");
pub const print = utils.print;
const deq = @import("deque.zig");

const Task = enum { one, two };
const DataSource = enum { sample, real };
const task: Task = .two;
const source: DataSource = .real;

const verbose: bool = switch (source) {
    .sample => true,
    .real => false,
};

const filename: []const u8 = switch (source) {
    .sample => "puzzle18.data.sample",
    .real => "puzzle18.data",
};

pub fn puzzle() !void {
    var corruptions = std.ArrayList(Point).init(std.heap.page_allocator);
    defer corruptions.deinit();

    var points = std.ArrayList(Point).init(std.heap.page_allocator);
    defer points.deinit();

    const size: i32 = switch (source) {
        .real => 70,
        .sample => 6,
    };
    const width: i32 = size + 1;
    const height: i32 = size + 1;
    const hist = Point{ .x = 0, .y = 0, .label = 'O' };
    const goal = Point{ .x = size, .y = size, .label = 'E' };
    const file = @embedFile(filename);
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const p_c = std.mem.indexOf(u8, line, ",");
        const p_ci = if (p_c) |i| i else 0;
        const wx = line[0..p_ci];
        const wy = line[p_ci + 1 ..];
        const px = try utils.parsei32(wx);
        const py = try utils.parsei32(wy);
        try corruptions.append(Point{ .x = px, .y = py, .label = '#' });
    }

    for (0..height) |y| {
        for (0..width) |x| {
            var label: u8 = '.';
            if (x == hist.x and y == hist.y) {
                label = 'O';
            } else if (x == goal.x and y == goal.y) {
                label = 'E';
            }
            try points.append(Point{ .x = @intCast(x), .y = @intCast(y), .label = label });
        }
    }

    const map = Map{ .width = width, .height = height, .bwidth = width - 1, .bheight = height - 1 };
    var ctx = Context{ .map = map, .points = points.items, .goal = goal, .hist = hist, .corruptions = corruptions };

    const time: i32 = switch (source) {
        .sample => 12,
        .real => 1024,
    };

    const score = try ctx.findScore(time);
    print("Score is {d} after {d} ticks", .{ score, time });

    if (task == .two) {
        for (time + 1..corruptions.items.len) |i| {
            const si = try ctx.findScore(@intCast(i));
            if (si == 0) {
                const corruption = corruptions.items[i - 1];
                print("Cannot find the goal after {d} ticks - coordinates of first blocking corruption {d},{d}", .{ i, corruption.x, corruption.y });
                break;
            }
        }
    }
    // ctx.printMap();
}

const Point = struct {
    x: i32,
    y: i32,
    label: u8,
};

const Map = struct {
    width: i32,
    height: i32,
    bwidth: i32,
    bheight: i32,
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

const Context = struct {
    map: Map,
    hist: Point,
    goal: Point,
    points: []Point,
    corruptions: std.ArrayList(Point),

    fn getPoint(self: *Context, x: i32, y: i32) Point {
        return self.points[self.getIndex(x, y)];
    }

    fn getUp(self: *Context, p: Point) ?Point {
        if (p.y == 0) return null;
        return self.getPoint(p.x, p.y - 1);
    }

    fn getDown(self: *Context, p: Point) ?Point {
        if (p.y == self.map.bheight) return null;
        return self.getPoint(p.x, p.y + 1);
    }

    fn getLeft(self: *Context, p: Point) ?Point {
        if (p.x == 0) return null;
        return self.getPoint(p.x - 1, p.y);
    }

    fn getRight(self: *Context, p: Point) ?Point {
        if (p.x == self.map.bwidth) return null;
        return self.getPoint(p.x + 1, p.y);
    }

    fn getNext(self: *Context, p: Point, dir: Direction) ?Point {
        return switch (dir) {
            .up => self.getUp(p),
            .down => self.getDown(p),
            .right => self.getRight(p),
            .left => self.getLeft(p),
        };
    }

    fn getIndex(self: *Context, x: i32, y: i32) usize {
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

    fn findScore(self: *Context, bytes: i32) !u32 {
        for (0..self.corruptions.items.len) |i| {
            const corruption = self.corruptions.items[i];
            self.points[self.getIndex(corruption.x, corruption.y)].label = corruption.label;
            if (i == bytes - 1) break;
        }

        var costs = std.AutoArrayHashMap(Point, u32).init(std.heap.page_allocator);
        defer costs.deinit();

        var seen = std.AutoArrayHashMap(Point, bool).init(std.heap.page_allocator);
        defer seen.deinit();

        var deque = try deq.Deque(Point).init(std.heap.page_allocator);
        defer deque.deinit();

        const start = Point{ .x = self.hist.x, .y = self.hist.y, .label = self.hist.label };
        try deque.pushBack(start);
        try costs.put(start, 0);

        const maxCost: i32 = std.math.maxInt(i32);

        while (deque.len() > 0) {
            const loc = if (deque.popBack()) |l| l else {
                continue;
            };
            const newCost = if (costs.get(loc)) |c| c + 1 else maxCost;

            var surroundings = std.ArrayList(Point).init(std.heap.page_allocator);
            defer surroundings.deinit();

            for (directions) |direction| {
                if (self.getNext(loc, direction)) |p| {
                    if (p.label != '#' and seen.get(p) == null) {
                        try surroundings.append(p);
                    }
                }
            }

            for (surroundings.items) |s| {
                const nc = if (costs.get(s)) |c| c + 1 else maxCost;
                if (newCost < nc) {
                    try costs.put(s, newCost);
                    try deque.pushFront(s);
                    try seen.put(s, true);
                }
            }
        }

        const score = if (costs.get(self.goal)) |c| c else 0;
        return score;
    }
};
