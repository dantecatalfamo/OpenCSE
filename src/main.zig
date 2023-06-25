// Copyright (c) 2022 Dante Catalfamo
// SPDX-License-Identifier: GPL-3.0-or-later

const std = @import("std");

pub fn main() !void {
    var prng = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp()));
    var random = prng.random();
    var score = Score.init(random);
    score.play() catch {
        std.debug.print("Quitting\n", .{});
    };
}

const Row = struct {
    points: u32,
    number: u32,
    count: u32 = 0,

    pub fn score(row: Row) i32 {
        return switch (row.count) {
            1...4 => -200,
            0, 5 => 0,
            else => |count| @intCast(i32, (count - 5) * row.points),
        };
    }

    pub fn render(row: Row, writer: anytype, row_index: usize, fifth: ?Fifth) !void {
        const scr = row.score();
        try writer.print("| {d: >3} | {d: >2} | ", .{ row.points, row.number });
        const box1 = switch (row.count) {
            0 =>    "□ □ □ □",
            1 =>    "■ □ □ □",
            2 =>    "■ ■ □ □",
            3 =>    "■ ■ ■ □",
            else => "■ ■ ■ ■",
        };
        try writer.print("{s} | ", .{ box1 });
        const box2 = if (row.count >= 5) "■" else "□";
        try writer.print("{s} | ", .{ box2 });
        const box3 = switch (row.count) {
            6 =>     "■ □ □ □ □",
            7 =>     "■ ■ □ □ □",
            8 =>     "■ ■ ■ □ □",
            9 =>     "■ ■ ■ ■ □",
            10 =>    "■ ■ ■ ■ ■",
            else =>  "□ □ □ □ □",
        };
        try writer.print("{s} | ", .{ box3 });
        const minus = if (scr == -200) "-200" else "    ";
        try writer.print("{s} | ", .{ minus });
        const ender = switch (row_index) {
            9 => "+",
            3 => "+--------------------+",
            else => "|",
        };
        if (scr > 0) {
            try writer.print("{d: >3} {s}", .{ @intCast(u32, scr), ender });
        } else {
            try writer.print("    {s}", .{ ender });
        }
        if (fifth) |fif| {
            if (fif.number == 0) {
                try writer.print("    ", .{});
            } else {
                try writer.print(" {d: >2} ", .{ fif.number });
            }
            const box4 = switch (fif.count) {
                0 =>     "□ □ □ □ □ □ □ □",
                1 =>     "■ □ □ □ □ □ □ □",
                2 =>     "■ ■ □ □ □ □ □ □",
                3 =>     "■ ■ ■ □ □ □ □ □",
                4 =>     "■ ■ ■ ■ □ □ □ □",
                5 =>     "■ ■ ■ ■ ■ □ □ □",
                6 =>     "■ ■ ■ ■ ■ ■ □ □",
                7 =>     "■ ■ ■ ■ ■ ■ ■ □",
                else =>  "■ ■ ■ ■ ■ ■ ■ ■",
            };
            try writer.print("{s} |", .{ box4 });
        }
    }
};

const Fifth = struct {
    number: u32,
    count: u32 = 0,
};

const Score = struct {
    random: std.rand.Random,
    rows: [11]Row = .{
        Row{ .points = 100, .number = 2  },
        Row{ .points = 70,  .number = 3  },
        Row{ .points = 60,  .number = 4  },
        Row{ .points = 50,  .number = 5  },
        Row{ .points = 40,  .number = 6  },
        Row{ .points = 30,  .number = 7  },
        Row{ .points = 40,  .number = 8  },
        Row{ .points = 50,  .number = 9  },
        Row{ .points = 60,  .number = 10 },
        Row{ .points = 70,  .number = 11 },
        Row{ .points = 100, .number = 12 },
    },
    fifth: [3]Fifth = .{
        Fifth{ .number = 0 },
        Fifth{ .number = 0 },
        Fifth{ .number = 0 },
    },
    dice: [5]u8 = .{ 0, 0, 0, 0, 0 },

    pub fn init(random: std.rand.Random) Score {
        return Score{ .random = random };
    }

    pub fn roll(score: *Score) void {
        for (&score.dice) |*die| {
            die.* = score.random.intRangeAtMost(u8, 1, 6);
        }
    }

    pub fn removeDie(score: *Score, die: u8) !usize {
        for (&score.dice, 0..) |*score_die, idx| {
            if (score_die.* == die) {
                score_die.* = 0;
                return idx;
            }
        }
        return error.NoDie;
    }

    pub fn removeDicePair(score: *Score, die1: u8, die2: u8) !void {
        const idx1 = try score.removeDie(die1);
        errdefer score.dice[idx1] = die1;
        const idx2 = try score.removeDie(die2);
        errdefer score.dice[idx2] = die2;
        try score.add(die1 + die2);
    }

    pub fn add(score: *Score, number: u32) !void {
        for (&score.rows) |*row| {
            if (row.number == number) {
                if (row.count >= 10) {
                    return error.RowFull;
                }
                row.count += 1;
            }
        }
    }

    pub fn addFifth(score: *Score, number: u32) void {
        for (&score.fifth) |*fifth| {
            if (fifth.number == number) {
                fifth.count += 1;
                return;
            }
            if (fifth.number == 0) {
                fifth.number = number;
                fifth.count = 1;
                return;
            }
        }
    }

    pub fn finished(score: Score) bool {
        for (score.fifth) |fifth| {
            if (fifth.count > 7) {
                return true;
            }
        }
        return false;
    }

    pub fn total(score: Score) i32 {
        var t: i32 = 0;
        for (score.rows) |row| {
            t += row.score();
        }
        return t;
    }

    pub fn render(score: Score, writer: anytype) !void {
        var total_neg: i32 = 0;
        var total_pos: i32 = 0;
        try writer.print("+----------------------------------------------------------------------+\n", .{});
        try writer.print("|  A  |  B |           C             |      D     |        5th         |\n", .{});
        try writer.print("|-----+----+-------------------------+------------+--------------------+\n", .{});
        for (score.rows, 0..) |row, row_idx| {
            if (row_idx < 3) {
                const fifth = score.fifth[row_idx];
                try row.render(writer, row_idx, fifth);
            } else {
                try row.render(writer, row_idx, null);
            }
            if (row_idx == score.rows.len - 2) {
                try writer.print("---------+", .{});
            }
            if (row_idx == score.rows.len - 1) {
                try writer.print("  Total  |", .{});
            }
            try writer.writeAll("\n");
            const row_score = row.score();
            if (row_score > 0) {
                total_pos += row_score;
            } else {
                total_neg += row_score;
            }
        }
        try writer.print("+----------+-------------------------+------------+---------+\n", .{});
        try writer.print("           |  -200   | 0 | + + + + + |", .{});
        if (total_neg == 0) {
            try writer.print("      +{d: >4} | = {d: >5} |\n", .{ @intCast(u32, total_pos), total_pos + total_neg });
        } else {
            try writer.print("{d: >5} +{d: >4} | = {d: >5} |\n", .{ total_neg, @intCast(u32, total_pos), total_pos + total_neg });
        }
        try writer.print("           +------------------------------------------------+\n", .{});
        try writer.print("\nDice: ", .{});
        for (score.dice) |die| {
            if (die == 0) continue;
            try writer.print("{d} | ", .{ die });
        }
        try writer.print("\n", .{});
    }

    pub fn play(score: *Score) !void {
        const stdin = std.io.getStdIn().reader();
        const stdout = std.io.getStdOut().writer();
        while (score.finished() == false) {
            score.roll();
            try score.render(stdout);
            try score.removeDicePairInput(stdin, stdout);
            try score.render(stdout);
            try score.removeDicePairInput(stdin, stdout);
            for (score.dice) |die| {
                if (die != 0) {
                    score.addFifth(die);
                }
            }
        }
        try score.render(stdout);
        try stdout.print("Game over! Final score: {d}\n", .{ score.total() });
    }

    pub fn removeDicePairInput(score: *Score, reader: anytype, writer: anytype) !void {
        var buff: [100]u8 = undefined;
        while (true) {
            try writer.print("Dice pair to use: ", .{});
            const input = try reader.readUntilDelimiter(buff[0..], '\n');
            var iter = std.mem.tokenize(u8, input, " ");
            const die_t1 = iter.next();
            const die_t2 = iter.next();
            if (die_t1 == null) continue;
            if (std.mem.eql(u8, die_t1.?, "?")) {
                try score.render(writer);
                continue;
            }
            if (die_t2 == null) continue;
            const die1 = std.fmt.parseInt(u8, die_t1.?, 10) catch continue;
            const die2 = std.fmt.parseInt(u8, die_t2.?, 10) catch continue;
            score.removeDicePair(die1, die2) catch |err| {
                switch (err) {
                    error.RowFull => try writer.print("Row full\n", .{}),
                    error.NoDie => try writer.print("Invalid dice pair\n", .{}),
                }
                continue;
            };
            return;
        }
    }
};

test "simple test" {
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll("\n");
    var random = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp())).random();
    var score = Score.init(random);
    try score.render(stdout);
    try score.add(2);
    try score.render(stdout);
    try score.add(2);
    try score.render(stdout);
    try score.add(2);
    try score.render(stdout);
    try score.add(2);
    try score.render(stdout);
    try score.add(2);
    try score.render(stdout);
    try score.add(2);
    try score.render(stdout);
    try score.add(2);
    try score.render(stdout);
    try score.add(2);
    try score.render(stdout);
    try score.add(2);
    try score.render(stdout);
    try score.add(2);
    try score.render(stdout);
    score.addFifth(2);
    try score.render(stdout);
    score.addFifth(2);
    try score.render(stdout);
    score.addFifth(2);
    try score.render(stdout);
    score.addFifth(2);
    try score.render(stdout);
    score.addFifth(5);
    try score.render(stdout);
    score.addFifth(5);
    try score.render(stdout);
    score.addFifth(7);
    try score.render(stdout);
    score.addFifth(11);
    try score.render(stdout);
    score.roll();
    try score.render(stdout);
}

test "rolling dice" {
    var random = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp())).random();
    var score = Score.init(random);
    std.debug.print("Dice: {any}\n", .{ score.dice });
    score.roll();
    std.debug.print("Dice: {any}\n", .{ score.dice });
}
