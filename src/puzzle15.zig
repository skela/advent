const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const task: Task = Task.two;
const sample: bool = false;
const verbose: bool = false;

pub fn puzzle() !void {
    var points = std.ArrayList(Point).init(std.heap.page_allocator);
    defer points.deinit();

    var movements = std.ArrayList(Direction).init(std.heap.page_allocator);
    defer movements.deinit();

    var x: i32 = 0;
    var y: i32 = 0;
    var width: i32 = 0;
    var height: i32 = 0;
    var robot = Robot{ .p = Point{ .x = 0, .y = 0, .label = '@' } };
    const file = @embedFile(if (sample) "puzzle15.data.sample3" else "puzzle15.data");
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const i = std.mem.indexOf(u8, line, "#");
        if (i != null) {
            x = 0;
            for (line) |c| {
                if (task == .one) {
                    const p = Point{ .label = c, .x = x, .y = y };
                    try points.append(p);
                    if (c == '@') {
                        robot = Robot{ .p = p };
                    }
                    x += 1;
                } else if (task == .two) {
                    const c1: u8 = switch (c) {
                        '#' => '#',
                        '@' => '@',
                        'O' => '[',
                        '.' => '.',
                        else => ' ',
                    };
                    const c2: u8 = switch (c) {
                        '#' => '#',
                        '@' => '.',
                        'O' => ']',
                        '.' => '.',
                        else => ' ',
                    };

                    const p = Point{ .label = c1, .x = x, .y = y };
                    try points.append(p);
                    if (c == '@') {
                        robot = Robot{ .p = p };
                    }
                    const p2 = Point{ .label = c2, .x = x + 1, .y = y };
                    try points.append(p2);
                    x += 2;
                }
            }
            width = x;
            y += 1;
        } else {
            for (line) |c| {
                if (c == '>') {
                    try movements.append(.right);
                }
                if (c == '<') {
                    try movements.append(.left);
                }
                if (c == '^') {
                    try movements.append(.up);
                }
                if (c == 'v') {
                    try movements.append(.down);
                }
            }
        }
    }
    height = y;

    const map = Map{ .width = width, .height = height, .bwidth = width - 1, .bheight = height - 1 };
    var ctx = Context{ .map = map, .robot = robot, .points = points.items, .movements = movements };
    ctx.printMap();

    var j: i64 = 0;
    for (movements.items) |m| {
        if (verbose) {
            print("Move {d} - {any}", .{ j, m });
        }
        try ctx.move(m);

        // if (ctx.checkMap()) {
        //     ctx.printMap();
        //     print("Error, the map is broken", .{});
        //     break;
        // }

        if (verbose) {
            ctx.printMap();
        }
        j += 1;
    }

    var sum: i64 = 0;
    for (ctx.points) |p| {
        if (p.label == 'O' or p.label == '[') {
            sum += (100 * p.y + p.x);
        }
    }

    ctx.printMap();

    print("The sum is {d}", .{sum});
}

const Point = struct {
    label: u8,
    x: i64,
    y: i64,
};

const Box = struct {
    left: Point,
    right: Point,
};

const Robot = struct {
    p: Point,
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
    robot: Robot,
    points: []Point,
    movements: std.ArrayList(Direction),

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

    fn checkMap(self: *Context) bool {
        var hasBraceStart: bool = false;
        var hasBraceEnd: bool = false;
        for (self.points) |c| {
            if (c.label == ']') {
                hasBraceEnd = true;
            } else if (c.label == '[') {
                hasBraceStart = true;
            } else {
                if (c.label != '[' and c.label != ']' and (hasBraceStart or hasBraceEnd)) {
                    if (hasBraceStart and hasBraceEnd) {
                        hasBraceStart = false;
                        hasBraceEnd = false;
                    } else {
                        return true;
                    }
                } else {}
            }
        }
        return false;
    }

    fn move(self: *Context, direction: Direction) !void {
        const v = velocity(direction);
        const r = self.robot;

        const end_point = self.getPoint(r.p.x + v.dx, r.p.y + v.dy);
        var can_move = end_point.label != '#';

        if (!can_move) {
            return;
        }

        const complex = task == .two and (direction == .up or direction == .down) and (end_point.label == '[' or end_point.label == ']');

        if (complex) {
            var boxes = std.AutoArrayHashMap(Box, bool).init(std.heap.page_allocator);
            defer boxes.deinit();

            try self.addBoxes(&boxes, end_point, v);
            if (boxes.keys().len == 0) {
                return;
            }

            var points = std.ArrayList(Point).init(std.heap.page_allocator);
            defer points.deinit();
            for (boxes.keys()) |box| {
                try points.append(box.left);
                try points.append(box.right);
            }

            if (direction == .down) {
                const sortedList = try sortList(points, compareByYDescending);
                for (sortedList.items) |p| {
                    self.swap(p, self.getPoint(p.x, p.y + v.dy));
                }
                defer sortedList.deinit();
            } else {
                const sortedList = try sortList(points, compareByYAscending);
                for (sortedList.items) |p| {
                    self.swap(p, self.getPoint(p.x, p.y + v.dy));
                }
                defer sortedList.deinit();
            }
        } else {
            can_move = try self.shift(end_point, direction);
            if (!can_move) return;
        }
        self.update(self.robot.p, '.');
        self.robot.p = self.getPoint(r.p.x + v.dx, r.p.y + v.dy);
        self.update(self.robot.p, '@');
    }

    fn shift(self: *Context, point: Point, direction: Direction) !bool {
        const v = velocity(direction);
        var can_move: bool = false;
        var endPoint = point;
        var points = std.ArrayList(Point).init(std.heap.page_allocator);
        defer points.deinit();
        var chars = std.ArrayList(u8).init(std.heap.page_allocator);
        defer chars.deinit();

        while (endPoint.label != '#') {
            try points.append(endPoint);
            try chars.append(endPoint.label);
            if (endPoint.label == '.') {
                can_move = true;
                break;
            }
            endPoint = self.getPoint(endPoint.x + v.dx, endPoint.y + v.dy);
        }

        if (!can_move) {
            return false;
        }
        const period = chars.pop();
        try chars.insert(0, period);

        for (0..points.items.len) |i| {
            const c = chars.items[i];
            const p = points.items[i];
            self.update(p, c);
        }

        return true;
    }

    fn update(self: *Context, p: Point, label: u8) void {
        const index = self.getIndex(p.x, p.y);
        self.points[index].label = label;
    }

    fn swap(self: *Context, start: Point, end: Point) void {
        const index_start = self.getIndex(start.x, start.y);
        const index_end = self.getIndex(end.x, end.y);
        const temp = start.label;
        self.points[index_start].label = end.label;
        self.points[index_end].label = temp;
    }

    fn canMoveVertically(self: *Context, point: Point, delta: Velocity) !bool {
        if (point.label == '.') {
            return true;
        }
        if (point.label == '#') {
            return false;
        }
        if (point.label == 'O') {
            return try self.canMoveVertically(self.getPoint(point.x, point.y + delta.dy), delta);
        }
        if (point.label == '[') {
            return try self.canMoveVertically(self.getPoint(point.x, point.y + delta.dy), delta) and try self.canMoveVertically(self.getPoint(point.x + 1, point.y + delta.dy), delta);
        }
        if (point.label == ']') {
            return try self.canMoveVertically(self.getPoint(point.x, point.y + delta.dy), delta) and try self.canMoveVertically(self.getPoint(point.x - 1, point.y + delta.dy), delta);
        }

        return false;
    }

    fn addBoxes(self: *Context, boxes: *std.AutoArrayHashMap(Box, bool), point: Point, delta: Velocity) !void {
        if (!try self.canMoveVertically(point, delta)) {
            return;
        }

        if (point.label == '[' or point.label == ']') {
            const box: Box =
                if (point.label == '[')
                Box{ .left = point, .right = self.getPoint(point.x + 1, point.y) }
            else
                Box{ .left = self.getPoint(point.x - 1, point.y), .right = point };
            try boxes.put(box, true);
            try self.addBoxes(boxes, self.getPoint(box.left.x, box.left.y + delta.dy), delta);
            try self.addBoxes(boxes, self.getPoint(box.right.x, box.right.y + delta.dy), delta);
        }
    }
};

fn compareByYDescending(a: Point, b: Point) i32 {
    if (a.y > b.y) return -1;
    if (a.y < b.y) return 1;
    return 0;
}

fn compareByYAscending(a: Point, b: Point) i32 {
    if (a.y > b.y) return 1;
    if (a.y < b.y) return -1;
    return 0;
}

fn sortList(list: std.ArrayList(Point), comparator: fn (Point, Point) i32) !std.ArrayList(Point) {
    const allocator = std.heap.page_allocator;
    var newList = std.ArrayList(Point).init(allocator);

    for (list.items) |item| {
        try newList.append(item);
    }

    var n = newList.items.len;
    while (n > 1) : (n -= 1) {
        for (0..(n - 1)) |i| {
            if (comparator(newList.items[i], newList.items[i + 1]) > 0) {
                const temp = newList.items[i];
                newList.items[i] = newList.items[i + 1];
                newList.items[i + 1] = temp;
            }
        }
    }

    return newList;
}
