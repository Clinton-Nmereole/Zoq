const std = @import("std");

pub const Expression = union(enum) {
    symbol: struct { str: []const u8 },
    function: struct { name: []const u8, args: []const Expression },

    fn print(self: Expression) void {
        switch (self) {
            .symbol => |s| {
                std.debug.print("{s}", .{s.str});
            },
            .function => |f| {
                std.debug.print("{s}(", .{f.name});
                for (f.args, 0..) |arg, i| {
                    if (i > 0) {
                        std.debug.print(", ", .{});
                    }
                    arg.print();
                }
                std.debug.print(")", .{});
            },
        }
    }
};

pub const Rule = struct {
    expression: Expression,
    equivalent: Expression,

    fn print(self: Rule) void {
        self.expression.print();
        std.debug.print(" -> ", .{});
        self.equivalent.print();
        std.debug.print("\n", .{});
    }
};

pub const swap_expr = Rule{
    .expression = Expression{ .function = .{ .name = "swap", .args = &.{
        Expression{ .function = .{ .name = "pair", .args = &.{ Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } } } } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "swap", .args = &.{
        Expression{ .function = .{ .name = "pair", .args = &.{ Expression{ .symbol = .{ .str = "b" } }, Expression{ .symbol = .{ .str = "a" } } } } },
    } } },
};

pub const addition_expr = Rule{
    .expression = Expression{ .function = .{ .name = "add", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "add", .args = &.{
        Expression{ .symbol = .{ .str = "b" } }, Expression{ .symbol = .{ .str = "a" } },
    } } },
};

pub const multiply_expr = Rule{
    .expression = Expression{ .function = .{ .name = "mult", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "mult", .args = &.{
        Expression{ .symbol = .{ .str = "b" } }, Expression{ .symbol = .{ .str = "a" } },
    } } },
};

pub const division_expr = Rule{
    .expression = Expression{ .function = .{ .name = "div", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "mult", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "1/b" } },
    } } },
};

pub const square_expr = Rule{
    .expression = Expression{ .function = .{ .name = "square", .args = &.{
        Expression{ .symbol = .{ .str = "a" } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "mult", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "a" } },
    } } },
};

pub const power_expr = Rule{
    .expression = Expression{ .function = .{ .name = "power", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "n" } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "mult", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .function = .{ .name = "power", .args = &.{
            Expression{ .symbol = .{ .str = "a" } },
            Expression{ .symbol = .{ .str = "n-1" } },
        } } },
    } } },
};

pub const expand_expr1 = Rule{
    .expression = Expression{ .function = .{ .name = "expand", .args = &.{
        Expression{ .function = .{ .name = "mult", .args = &.{ Expression{ .function = .{ .name = "add", .args = &.{ Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } } } } }, Expression{ .symbol = .{ .str = "c" } } } } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "add", .args = &.{
        Expression{ .symbol = .{ .str = "ac" } }, Expression{ .symbol = .{ .str = "bc" } },
    } } },
};

pub fn main() !void {

    //std.debug.print("{any}\n", .{swap_expr.expression});
    //swap_expr.expression.print();
    swap_expr.print();
    addition_expr.print();
    multiply_expr.print();
    division_expr.print();
    square_expr.print();
    power_expr.print();
    expand_expr1.print();

    // File stuff, read from a file and if the file is not empty make a new file and copy its content there
    {
        var file = try std.fs.cwd().openFile("text.txt", .{});
        defer file.close();
        var buf: [1024]u8 = undefined;
        const bytes_read = try file.read(buf[0..]);
        var message = buf[0..bytes_read];
        std.debug.print("{s}\n", .{message});

        var new_file = try std.fs.cwd().createFile("text2.txt", .{});
        defer new_file.close();
        if (message.len > 0) {
            _ = try new_file.write(message);
        } else {
            std.debug.print("empty file\n", .{});
        }
        std.debug.print("{any}\n", .{message});
    }
}
