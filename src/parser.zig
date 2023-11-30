const std = @import("std");
const Lexer = @import("lexer.zig");
const Token = Lexer.Token;

const Zoq = @import("main.zig");
const Expression = Zoq.Expression;

const ArrayList = std.ArrayList;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var arraylist = ArrayList(u8).init(allocator);

pub inline fn testparse(
    comptime buffer: []const u8,
) !void {
    comptime var lexer = Lexer{};
    //const expected_token: Token = .eof;
    comptime var i = 0;
    inline while (i < buffer.len) {
        const actual_token = lexer.next(buffer);
        std.debug.print("{}\n", .{actual_token});
        try arraylist.append(buffer[i]);
        i += 1;
    }
    std.debug.print("{s}\n", .{arraylist.items});
}

pub inline fn parse_symbol(
    comptime buffer: []const u8,
) !Expression {
    comptime var lexer = Lexer{};
    const actual_token = lexer.next(buffer);
    const expected_type = .identifier;
    comptime if (actual_token != expected_type) return error.NotSymbol;
    return Zoq.sym(actual_token.identifier);
}

pub inline fn parse_function(
    comptime buffer: []const u8,
) !Expression {
    comptime var lexer = Lexer{};
    comptime var function: []const u8 = undefined;
    comptime if (buffer.len < 3) return error.NotFunction;
    //const expected_type = .eof;
    comptime var current_token = lexer.next(buffer);
    comptime var arr = [_]Expression{undefined} ** 5;
    comptime var i = 0;
    inline while (current_token != .eof and i < buffer.len) {
        comptime var prev_token = current_token;
        current_token = lexer.next(buffer);
        std.debug.print("prev_token: {}\n", .{prev_token});
        std.debug.print("current_token: {}\n", .{current_token});
        if (prev_token == .identifier and current_token == .openParen) {
            comptime var function_name = prev_token.identifier;
            function = function_name;
        }
        comptime if (current_token == .comma and prev_token == .identifier) {
            arr[i] = Zoq.sym(prev_token.identifier);
        };
        comptime if (current_token == .closeParen and prev_token == .identifier) {
            arr[i] = Zoq.sym(prev_token.identifier);
        };
        i += 1;
    }

    return Zoq.fun(function, &arr);
}

pub fn main() !void {
    try testparse("add(a,b)");
    var a = try parse_symbol("abr");
    std.debug.print("{}\n", .{a});
    std.debug.print("{}\n", .{@TypeOf(a)});
    var b = try parse_function("add(a,b)");
    std.debug.print("{}\n", .{b});
}

test "parser" {
    var a_symbol = Zoq.sym("a");
    var a = try parse_symbol("a");
    try std.testing.expect(a.eql(a_symbol));
}
