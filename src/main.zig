const std = @import("std");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
var hashmap = std.StringHashMap([]const u8).init(allocator);

//Declare a tagged union called an expression
//An expression can be a symbol, a function.
//A function has a name and a list of arguments
pub const Expression = union(enum) {
    symbol: struct { str: []const u8 },
    function: struct { name: []const u8, args: []const Expression },

    //Print an expression using the print function
    pub fn print(self: Expression) void {
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

    //Print an expression with the standard library using std.debug.print
    //This simply says how the expression should be printed when called in
    //std.debug.print
    pub fn format(
        self: Expression,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .symbol => |s| {
                try writer.print("{s}", .{s.str});
            },
            .function => |f| {
                try writer.print("{s}(", .{f.name});
                for (f.args, 0..) |arg, i| {
                    if (i > 0) {
                        try writer.print(", ", .{});
                    }
                    try arg.format("", .{}, writer);
                }
                try writer.print(")", .{});
            },
        }
    }

    pub fn isFunction(self: Expression) bool {
        return switch (self) {
            .function => true,
            else => false,
        };
    }

    pub fn isSymbol(self: Expression) bool {
        return switch (self) {
            .symbol => true,
            else => false,
        };
    }

    pub fn eql(self: Expression, other: Expression) bool {
        return switch (self) {
            .symbol => |s| switch (other) {
                .symbol => |s2| std.mem.eql(u8, s.str, s2.str),
                else => false,
            },
            .function => |f| switch (other) {
                .function => |f2| std.meta.eql(f.name, f2.name) and eqlSlice(f.args, f2.args),
                else => false,
            },
        };
    }

    pub fn eqlSlice(first: []const Expression, other: []const Expression) bool {
        if (first.len != other.len) return false;
        if (first.ptr == other.ptr) return true;
        for (first, other) |a, b| {
            switch (a) {
                .symbol => |s| switch (b) {
                    .symbol => |s2| if (std.mem.eql(u8, s.str, s2.str)) {},
                    .function => return false,
                },
                .function => |f| switch (b) {
                    .symbol => return false,
                    .function => |f2| if (std.mem.eql(u8, f.name, f2.name) and eqlSlice(f.args, f2.args)) {},
                },
            }
        }
        return true;
    }

    pub fn isPattern(self: Expression, other: Expression) bool {
        return switch (self) {
            .symbol => |s| switch (other) {
                .symbol => |s2| std.mem.eql(u8, s.str, s2.str),
                .function => false,
            },
            .function => |f| switch (other) {
                .symbol => false,
                .function => |f2| std.mem.eql(u8, f.name, f2.name) and f.args.len == f2.args.len,
            },
        };
    }
};

//A rule is a struct that has an expression and its equivalent
//A rule enforces that the expression and equivalent are the same
//i.e a + b ≡ b + a
pub const Rule = struct {
    expression: Expression,
    equivalent: Expression,

    //Print a rule using the print function from Expression
    pub fn print(self: Rule) void {
        self.expression.print();
        std.debug.print(" ≡ ", .{});
        self.equivalent.print();
        std.debug.print("\n", .{});
    }

    //Print a rule with the standard library using std.debug.print
    pub fn format(
        self: Rule,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try self.expression.format("", .{}, writer);
        try writer.print(" ≡ ", .{});
        try self.equivalent.format("", .{}, writer);
        try writer.print("\n", .{});
    }
};

//Some mathematical rules declarations
pub const swap_expr = Rule{
    .expression = Expression{ .function = .{ .name = "swap", .args = &.{
        Expression{ .function = .{ .name = "pair", .args = &.{ Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } } } } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "pair", .args = &.{ Expression{ .symbol = .{ .str = "b" } }, Expression{ .symbol = .{ .str = "a" } } } } },
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

pub const addition_expr1 = Rule{
    .expression = Expression{ .function = .{ .name = "add", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } },
    } } },
    .equivalent = Expression{ .function = .{ .name = "add", .args = &.{
        Expression{ .function = .{ .name = "mult", .args = &.{ Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } } } } },
        Expression{ .function = .{ .name = "mult", .args = &.{ Expression{ .symbol = .{ .str = "c" } }, Expression{ .symbol = .{ .str = "d" } } } } },
    } } },
};

pub fn main() !void {

    //Print some of the rules defined
    swap_expr.print();
    addition_expr.print();
    multiply_expr.print();
    division_expr.print();
    square_expr.print();
    power_expr.print();
    expand_expr1.print();

    // File stuff, read from a file and if the file is not empty make a new file and copy its content there
    //This might later be used to read rules into a file.
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
    }
    var add1 = Expression{ .function = .{ .name = "add", .args = &.{
        Expression{ .function = .{ .name = "mult", .args = &.{ Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } } } } },
        Expression{ .function = .{ .name = "mult", .args = &.{ Expression{ .symbol = .{ .str = "c" } }, Expression{ .symbol = .{ .str = "d" } } } } },
    } } };
    var add2 = Expression{ .function = .{ .name = "add", .args = &.{
        Expression{ .symbol = .{ .str = "a" } }, Expression{ .symbol = .{ .str = "b" } },
    } } };

    std.debug.print("add 1 is: {}, add 2 is: {}\n", .{ add1, add2 });

    std.debug.print("{}\n", .{add1.isPattern(add2)});
    std.debug.print("{any}\n", .{add2.equivalentTo(addition_expr)});
}
