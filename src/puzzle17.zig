const std = @import("std");
pub const print = @import("utils.zig").print;

const Task = enum { one, two };
const DataSource = enum { sample, sample2, real };
const task: Task = .two;
const source: DataSource = .real;

const verbose: bool = switch (source) {
    .sample => false,
    .sample2 => false,
    .real => false,
};

const filename: []const u8 = switch (source) {
    .sample => "puzzle17.data.sample",
    .sample2 => "puzzle17.data.sample2",
    .real => "puzzle17.data",
};

pub fn puzzle() !void {
    var programs = std.ArrayList(Program).init(std.heap.page_allocator);
    defer programs.deinit();

    var values = std.ArrayList(u64).init(std.heap.page_allocator);
    defer values.deinit();

    var regA: u64 = 0;
    var regB: u64 = 0;
    var regC: u64 = 0;

    const file = @embedFile(filename);
    const split = std.mem.split;
    var splits = split(u8, file, "\n");
    var regcounter: usize = 0;
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const ind = std.mem.indexOf(u8, line, "Register");
        if (ind != null) {
            const p_c = std.mem.indexOf(u8, line, ":");
            const p_ci = if (p_c) |i| i else 0;
            const w = line[p_ci + 2 ..];
            const px = try parseNumber(w);
            switch (regcounter) {
                0 => regA = px,
                1 => regB = px,
                2 => regC = px,
                else => {},
            }
            regcounter += 1;
        } else {
            const p_c = std.mem.indexOf(u8, line, ":");
            const p_ci = if (p_c) |i| i else 0;
            const suffix = line[p_ci + 2 ..];
            var comps = split(u8, suffix, ",");
            while (comps.next()) |c| {
                const p = try parseNumber(c);
                const e: Program = switch (p) {
                    0 => .zero,
                    1 => .one,
                    2 => .two,
                    3 => .three,
                    4 => .four,
                    5 => .five,
                    6 => .six,
                    7 => .seven,
                    else => .zero,
                };
                try programs.append(e);
            }
        }
    }

    var mods = std.AutoArrayHashMap(u64, u64).init(std.heap.page_allocator);
    defer mods.deinit();

    var pows = std.AutoArrayHashMap(u64, u64).init(std.heap.page_allocator);
    defer pows.deinit();

    var divs = std.AutoArrayHashMap(Div, u64).init(std.heap.page_allocator);
    defer divs.deinit();

    var instructions = std.AutoArrayHashMap(u64, Instruction).init(std.heap.page_allocator);
    defer instructions.deinit();

    var ctx: Context = Context{ .a = regA, .b = regB, .c = regC, .values = values, .programs = programs, .mods = mods, .pows = pows, .divs = divs };

    ctx.printState();

    if (task == .two) {
        var targetValues = std.ArrayList(u64).init(std.heap.page_allocator);
        defer targetValues.deinit();

        for (ctx.programs.items) |p| {
            try targetValues.append(ctx.literal(p));
        }

        const targetLen = targetValues.items.len;

        var a: u64 = 0;
        for (0..targetLen) |i| {
            const want = targetValues.items[targetLen - i - 1 ..];
            var t: usize = 0;
            while (true) {
                const aprime = (a << 3) + t;
                const r = try ctx.runFrom(Instruction{ .a = aprime, .b = 0, .c = 0, .index = 0, .v = null });
                if (ctx.sameArrays(want, r)) {
                    a = aprime;
                    break;
                }
                t += 1;
            }
        }

        print("a is {d}", .{a});

        ctx.printState();
    } else {
        var i: usize = 0;
        while (i < programs.items.len) {
            const opcode = programs.items[i];
            const operand = programs.items[i + 1];
            print("Running {any}", .{opcode});
            i = try ctx.run(i, opcode, operand);

            ctx.printState();
        }
        print("Values:", .{});
        for (ctx.values.items) |v| {
            std.debug.print("{d},", .{v});
        }
    }
}

fn parseNumber(input: []const u8) !u64 {
    return try std.fmt.parseInt(u64, input, 10);
}

const Div = struct {
    a: u64,
    b: u64,
};

const Instruction = struct {
    index: usize,
    a: u64,
    b: u64,
    c: u64,
    v: ?u64,
};

const Context = struct {
    a: u64,
    b: u64,
    c: u64,
    values: std.ArrayList(u64),
    programs: std.ArrayList(Program),
    mods: std.AutoArrayHashMap(u64, u64),
    pows: std.AutoArrayHashMap(u64, u64),
    divs: std.AutoArrayHashMap(Div, u64),

    fn literal(_: *Context, program: Program) u64 {
        return switch (program) {
            .zero => 0,
            .one => 1,
            .two => 2,
            .three => 3,
            .four => 4,
            .five => 5,
            .six => 6,
            .seven => 7,
        };
    }

    fn combo(self: *Context, program: Program) u64 {
        return switch (program) {
            .zero => 0,
            .one => 1,
            .two => 2,
            .three => 3,
            .four => self.a,
            .five => self.b,
            .six => self.c,
            .seven => 0, // reserved
        };
    }

    fn power(self: *Context, exp: u64) !u64 {
        if (self.pows.get(exp)) |p| {
            return p;
        } else {
            const p: u64 = try std.math.powi(u64, 2, exp);
            try self.pows.put(exp, p);
            return p;
        }
    }

    fn modi(self: *Context, v: u64) !u64 {
        if (self.mods.get(v)) |m| {
            return m;
        } else {
            const m: u64 = @mod(v, 8);
            try self.mods.put(v, m);
            return m;
        }
    }

    fn div(self: *Context, a: u64, b: u64) !u64 {
        const d = Div{ .a = a, .b = b };
        if (self.divs.get(d)) |m| {
            return m;
        } else {
            const m = @divTrunc(a, b);
            try self.divs.put(d, m);
            return m;
        }
    }

    fn run(self: *Context, index: usize, opcode: Program, operand: Program) !usize {
        switch (opcode) {
            .zero => {
                const exp: u64 = @intCast(self.combo(operand));
                const pow = try self.power(exp);
                self.a = try self.div(self.a, pow);
                return index + 2;
            },
            .one => {
                self.b = self.b ^ self.literal(operand);
                return index + 2;
            },
            .two => {
                self.b = try self.modi(self.combo(operand));
                return index + 2;
            },
            .three => {
                if (self.a == 0) {
                    return index + 2;
                } else {
                    return @intCast(self.literal(operand));
                }
            },
            .four => {
                self.b = self.b ^ self.c;
                return index + 2;
            },
            .five => {
                const m = try self.modi(self.combo(operand));
                try self.values.append(m);
                return index + 2;
            },
            .six => {
                const exp: u64 = @intCast(self.combo(operand));
                const pow = try self.power(exp);
                self.b = try self.div(self.a, pow);
                return index + 2;
            },
            .seven => {
                const exp: u64 = @intCast(self.combo(operand));
                const pow = try self.power(exp);
                self.c = @divTrunc(self.a, pow);
                return index + 2;
            },
        }
    }

    fn runFrom(self: *Context, instruction: Instruction) ![]u64 {
        var values = std.ArrayList(u64).init(std.heap.page_allocator);
        var state = instruction;
        while (state.index < self.programs.items.len) {
            state = try self.runCalc(state);
            if (state.v) |r| {
                try values.append(r);
            }
        }
        return values.items;
    }

    fn runCalc(self: *Context, instruction: Instruction) !Instruction {
        self.a = instruction.a;
        self.b = instruction.b;
        self.c = instruction.c;
        const opcode = self.programs.items[instruction.index];
        const operand = self.programs.items[instruction.index + 1];
        switch (opcode) {
            .zero => {
                const exp: u64 = @intCast(self.combo(operand));
                const pow = try self.power(exp);
                self.a = try self.div(self.a, pow);
                return Instruction{ .a = self.a, .b = self.b, .c = self.c, .index = instruction.index + 2, .v = null };
            },
            .one => {
                self.b = self.b ^ self.literal(operand);
                return Instruction{ .a = self.a, .b = self.b, .c = self.c, .index = instruction.index + 2, .v = null };
            },
            .two => {
                self.b = try self.modi(self.combo(operand));
                return Instruction{ .a = self.a, .b = self.b, .c = self.c, .index = instruction.index + 2, .v = null };
            },
            .three => {
                if (self.a == 0) {
                    return Instruction{ .a = self.a, .b = self.b, .c = self.c, .index = instruction.index + 2, .v = null };
                } else {
                    return Instruction{ .a = self.a, .b = self.b, .c = self.c, .index = @intCast(self.literal(operand)), .v = null };
                }
            },
            .four => {
                self.b = self.b ^ self.c;
                return Instruction{ .a = self.a, .b = self.b, .c = self.c, .index = instruction.index + 2, .v = null };
            },
            .five => {
                const m = try self.modi(self.combo(operand));
                try self.values.append(m);
                return Instruction{ .a = self.a, .b = self.b, .c = self.c, .index = instruction.index + 2, .v = m };
            },
            .six => {
                const exp: u64 = @intCast(self.combo(operand));
                const pow = try self.power(exp);
                self.b = try self.div(self.a, pow);
                return Instruction{ .a = self.a, .b = self.b, .c = self.c, .index = instruction.index + 2, .v = null };
            },
            .seven => {
                const exp: u64 = @intCast(self.combo(operand));
                const pow = try self.power(exp);
                self.c = @divTrunc(self.a, pow);
                return Instruction{ .a = self.a, .b = self.b, .c = self.c, .index = instruction.index + 2, .v = null };
            },
        }
    }

    fn printState(self: *Context) void {
        if (verbose) {
            print("Reg A: {d}", .{self.a});
            print("Reg B: {d}", .{self.b});
            print("Reg C: {d}", .{self.c});
        }
    }

    fn printPrograms(self: *Context) void {
        print("Programs:", .{});
        for (self.programs.items) |p| {
            print(" {any}", .{p});
        }
    }

    fn sameValues(self: *Context, target: []u64) bool {
        if (verbose) {
            print("Comparing values {any}", .{self.values.items});
            print(" with: {any}", .{target});
        }

        if (target.len != self.values.items.len) {
            return false;
        }
        for (0..target.len) |i| {
            if (target[i] != self.values.items[i]) return false;
        }
        return true;
    }

    fn sameArrays(_: *Context, a: []u64, target: []u64) bool {
        if (verbose) {
            print("Comparing values {any}", .{a});
            print(" with: {any}", .{target});
        }
        if (target.len != a.len) {
            return false;
        }
        for (0..target.len) |i| {
            if (target[i] != a[i]) return false;
        }
        return true;
    }

    fn clearValues(self: *Context) void {
        // defer self.values.deinit();
        // const values = std.ArrayList(u64).init(std.heap.page_allocator);
        // self.values = values;
        self.values.shrinkAndFree(0);
    }
};

const Program = enum { zero, one, two, three, four, five, six, seven };
