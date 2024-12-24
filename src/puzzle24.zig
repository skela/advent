const std = @import("std");
const utils = @import("utils.zig");
const print = utils.print;
const deq = @import("deque.zig");
const alloc = std.heap.page_allocator;

const DataSource = enum { sample, sample2, real };
const source: DataSource = .real;

const verbose: bool = switch (source) {
    .sample => true,
    .sample2 => true,
    .real => false,
};

const filename: []const u8 = switch (source) {
    .sample => "puzzle24.data.sample",
    .sample2 => "puzzle24.data.sample2",
    .real => "puzzle24.data",
};

pub fn puzzle() !void {
    var inputs = std.StringHashMap(usize).init(alloc);
    defer inputs.deinit();

    var gates = std.StringHashMap(Gate).init(alloc);
    defer gates.deinit();

    const file = @embedFile(filename);
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        const p_c = std.mem.indexOf(u8, line, ":");
        if (p_c) |c| {
            const lbl = line[0..c];
            const res = line[c + 1 ..];
            const bres: usize = if (res[1] == '1') 1 else 0;
            try inputs.put(lbl, bres);
        } else {
            var connections = std.ArrayList([]const u8).init(alloc);
            defer connections.deinit();
            var comps = split(u8, line, " ");
            while (comps.next()) |c| {
                if (c[0] != '-') try connections.append(c);
            }

            const lbl = connections.items[3];
            const p1 = connections.items[0];
            const p2 = connections.items[2];
            const gl = connections.items[1];

            if (gl[0] == 'A') {
                try gates.put(lbl, Gate{ .p1 = p1, .p2 = p2, .gate = .AND });
            } else {
                if (gl[0] == 'X') {
                    try gates.put(lbl, Gate{ .p1 = p1, .p2 = p2, .gate = .XOR });
                } else {
                    if (gl[0] == 'O')
                        try gates.put(lbl, Gate{ .p1 = p1, .p2 = p2, .gate = .OR });
                }
            }
        }
    }

    if (verbose) {
        print("Inputs:", .{});
        var iter = inputs.iterator();
        while (iter.next()) |i| {
            const k = i.key_ptr.*;
            const v = i.value_ptr.*;
            print("{s}: {any}", .{ k, v });
        }
    }

    var zeds = std.AutoArrayHashMap(usize, usize).init(alloc);
    defer zeds.deinit();

    var context: Context = Context{ .gates = gates, .inputs = inputs };
    var giter = context.gates.iterator();
    while (giter.next()) |i| {
        const k = i.key_ptr.*;
        const v = i.value_ptr.*;
        if (verbose) {
            print("{s}: {s} {any} {s}", .{ k, v.p1, v.gate, v.p2 });
        }
        if (k[0] == 'z') {
            const ind = try utils.parseusize(k[1..]);
            const r = context.calculate(v.p1, v.gate, v.p2);
            try zeds.put(ind, r);
        }
    }

    var sum: i64 = 0;
    for (0..zeds.count()) |i| {
        if (zeds.get(i)) |z| {
            const zc: i64 = @intCast(z);
            const ic: i64 = @intCast(i);
            const r: i64 = std.math.pow(i64, 2, ic);
            sum += zc * r;
        }
    }

    print("The sum is {d}", .{sum});

    const bits = zeds.count() - 1;

    const swapped = try context.swap(bits);
    std.debug.print("Swapped: ", .{});
    sortStringSlice(swapped.items);
    for (swapped.items) |sw| {
        std.debug.print("{s},", .{sw});
    }
}

const GateType = enum {
    AND,
    XOR,
    OR,
};

const Gate = struct {
    p1: []const u8,
    p2: []const u8,
    gate: GateType,
};

const Context = struct {
    inputs: std.StringHashMap(usize),
    gates: std.StringHashMap(Gate),

    fn calculate(self: *Context, p1: []const u8, gate: GateType, p2: []const u8) usize {
        const pi1 = if (self.inputs.get(p1)) |i| i else self.calculateGate(p1);
        const pi2 = if (self.inputs.get(p2)) |i| i else self.calculateGate(p2);
        const r = switch (gate) {
            .AND => andGate(pi1, pi2),
            .XOR => xorGate(pi1, pi2),
            .OR => orGate(pi1, pi2),
        };
        return r;
    }

    fn calculateGate(self: *Context, p: []const u8) usize {
        if (self.gates.get(p)) |g| {
            return self.calculate(g.p1, g.gate, g.p2);
        }
        return 0;
    }

    fn swap(self: *Context, bits: usize) !std.ArrayList([]const u8) {

        // half adder:
        // X1 XOR Y1 => M1
        // X1 AND Y1 => N1
        // C0 AND M1 => R1
        // C0 XOR M1 -> Z1
        // R1 OR N1 -> C1
        var swaps = std.ArrayList([]const u8).init(alloc);
        var c0: ?[]const u8 = null;
        for (0..bits) |i| {
            var m1 = try self.findGate(i, .XOR);
            var n1 = try self.findGate(i, .AND);
            var z1: ?[]const u8 = null;
            var c1: ?[]const u8 = null;

            if (c0) |c00| {
                var r1 = try self.findGateWithLabels(c00, m1, .AND);
                if (r1 == null) {
                    const temp = n1;
                    n1 = m1;
                    m1 = temp;
                    if (n1) |t| try swaps.append(t);
                    if (m1) |t| try swaps.append(t);

                    r1 = try self.findGateWithLabels(c0, m1, .AND);
                }

                z1 = try self.findGateWithLabels(c0, m1, .XOR);

                if (m1) |m11| {
                    if (m11[0] == 'z') {
                        const temp = m1;
                        m1 = z1;
                        z1 = temp;
                        if (z1) |t| try swaps.append(t);
                        if (m1) |t| try swaps.append(t);
                    }
                }

                if (n1) |n11| {
                    if (n11[0] == 'z') {
                        const temp = n1;
                        n1 = z1;
                        z1 = temp;
                        if (z1) |t| try swaps.append(t);
                        if (n1) |t| try swaps.append(t);
                    }
                }

                if (r1) |r11| {
                    if (r11[0] == 'z') {
                        const temp = r1;
                        r1 = z1;
                        z1 = temp;
                        if (z1) |t| try swaps.append(t);
                        if (r1) |t| try swaps.append(t);
                    }
                }

                c1 = try self.findGateWithLabels(r1, n1, .OR);
            } else {
                z1 = m1;
                c1 = n1;
            }

            if (c1) |c11| {
                if (c11[0] == 'z') {
                    var bz: [10]u8 = undefined;
                    const z = try std.fmt.bufPrint(&bz, "z{d:0>2}", .{bits});
                    if (!utils.isStringEqual(z, c11)) {
                        const temp = c1;
                        c1 = z1;
                        z1 = temp;
                        if (c1) |t| try swaps.append(t);
                        if (z1) |t| try swaps.append(t);
                    }
                }
            }

            if (c0 != null) {
                c0 = c1;
            } else {
                c0 = n1;
            }
        }
        return swaps;
    }

    fn findGate(self: *Context, i: usize, gate: GateType) !?[]const u8 {
        var bx: [10]u8 = undefined;
        const x = try std.fmt.bufPrint(&bx, "x{d:0>2}", .{i});

        var by: [10]u8 = undefined;
        const y = try std.fmt.bufPrint(&by, "y{d:0>2}", .{i});

        return self.findGateWithLabels(x, y, gate);
    }

    fn findGateWithLabels(self: *Context, x: ?[]const u8, y: ?[]const u8, gate: GateType) !?[]const u8 {
        if (x == null) return null;
        if (y == null) return null;
        var giter = self.gates.iterator();
        while (giter.next()) |id| {
            const k = id.key_ptr.*;
            const v = id.value_ptr.*;
            const p1 = v.p1;
            const p2 = v.p2;
            if (utils.isStringEqual(p1, x) and utils.isStringEqual(p2, y) and v.gate == gate) {
                return k;
            }
            if (utils.isStringEqual(p2, x) and utils.isStringEqual(p1, y) and v.gate == gate) {
                return k;
            }
        }
        return null;
    }
};

fn andGate(p1: usize, p2: usize) usize {
    return p1 & p2;
}

fn xorGate(p1: usize, p2: usize) usize {
    return p1 ^ p2;
}

fn orGate(p1: usize, p2: usize) usize {
    return p1 | p2;
}

fn lessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.order(u8, lhs, rhs) == .lt;
}

fn sortStringSlice(slice: [][]const u8) void {
    std.mem.sort([]const u8, slice, {}, lessThan);
}
