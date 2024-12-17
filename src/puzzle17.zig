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
    .sample => "puzzle17.data.sample",
    .real => "puzzle17.data",
};

pub fn puzzle() !void {
    var programs = std.ArrayList(Program).init(std.heap.page_allocator);
    defer programs.deinit();

    var values = std.ArrayList(i64).init(std.heap.page_allocator);
    defer values.deinit();

    var regA: i64 = 0;
    var regB: i64 = 0;
    var regC: i64 = 0;

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
            print("{any}", .{w});
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

    var ctx: Context = Context{ .a = regA, .b = regB, .c = regC, .values = values, .programs = programs };

    ctx.printState();

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

fn parseNumber(input: []const u8) !i64 {
    return try std.fmt.parseInt(i64, input, 10);
}

const Context = struct {
    a: i64,
    b: i64,
    c: i64,
    values: std.ArrayList(i64),
    programs: std.ArrayList(Program),

    fn literal(_: *Context, program: Program) i64 {
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

    fn combo(self: *Context, program: Program) i64 {
        return switch (program) {
            .zero => 0,
            .one => 1,
            .two => 2,
            .three => 3,
            .four => self.a,
            .five => self.b,
            .six => self.c,
            .seven => -1, // reserved
        };
    }

    fn run(self: *Context, index: usize, opcode: Program, operand: Program) !usize {
        switch (opcode) {
            .zero => {
                const exp: i64 = @intCast(self.combo(operand));
                const pow: i64 = try std.math.powi(i64, 2, exp);
                self.a = @divTrunc(self.a, pow);
                return index + 2;
            },
            .one => {
                self.b = self.b ^ self.literal(operand);
                return index + 2;
            },
            .two => {
                self.b = @mod(self.combo(operand), 8);
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
                try self.values.append(@mod(self.combo(operand), 8));
                return index + 2;
            },
            .six => {
                const exp: i64 = @intCast(self.combo(operand));
                const pow: i64 = try std.math.powi(i64, 2, exp);
                self.b = @divTrunc(self.a, pow);
                return index + 2;
            },
            .seven => {
                const exp: i64 = @intCast(self.combo(operand));
                const pow: i64 = try std.math.powi(i64, 2, exp);
                self.c = @divTrunc(self.a, pow);
                return index + 2;
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
};

const Program = enum { zero, one, two, three, four, five, six, seven };
