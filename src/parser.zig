const std = @import("std");
const Lexer = @import("lexer.zig");
const Token = Lexer.Token;

const Zoq = @import("main.zig");
const Expression = Zoq.Expression;

//reads tokens from a buffer and prints them to console.
pub inline fn list_tokens(
    comptime buffer: []const u8,
) !void {
    comptime var lexer = Lexer{};
    comptime var actual_token = lexer.next(buffer);
    inline while (actual_token != .eof) {
        std.debug.print("{}\n", .{actual_token});
        actual_token = lexer.next(buffer);
    }
}

// Return the first token in a buffer in a list
pub inline fn firsttok_list(
    comptime buffer: []const u8,
) *const [1]Token {
    comptime var lexer = Lexer{};
    const actual_token = lexer.next(buffer);
    comptime {
        return &[1]Token{actual_token};
    }
}

// Given a buffer and an empty list, return a slice of tokens
pub inline fn make_token_list(
    comptime buffer: []const u8,
    comptime list: []const Token,
) []const Token {
    comptime var lexer = Lexer{};
    comptime var newlist = list;
    comptime var actual_token = lexer.next(buffer);
    inline while (actual_token != .eof) {
        newlist = newlist ++ @as([]const Token, &.{actual_token});
        actual_token = lexer.next(buffer);
    }
    comptime {
        return newlist;
    }
}

//Append a token to a slice of tokens. Add the token to the end of the list
pub inline fn append_token(
    comptime token: Token,
    comptime list: []const Token,
) []const Token {
    comptime var newlist = list;
    newlist = newlist ++ @as([]const Token, &.{token});
    comptime {
        return newlist;
    }
}

//Prepend a token to a slice of tokens. Add the token to the front of the list
pub inline fn prepend_token(
    comptime token: Token,
    comptime list: []const Token,
) []const Token {
    comptime var newlist = list;
    newlist = @as([]const Token, &.{token}) ++ newlist;
    comptime {
        return newlist;
    }
}

//makes an token which is of type identifier into an Expression of type symbol
pub inline fn parse_symbol(
    comptime buffer: []const u8,
) !Expression {
    comptime var lexer = Lexer{};
    const actual_token = lexer.next(buffer);
    const expected_type = .identifier;
    comptime if (actual_token != expected_type) return error.NotSymbol;
    return Zoq.sym(actual_token.identifier);
}

//FIX: parse function does not yet work for nested functions
pub inline fn parse_function(
    comptime buffer: []const u8,
) !Expression {
    comptime var lexer = Lexer{};
    comptime var function: []const u8 = undefined;
    comptime var current_token = lexer.peek(buffer);
    comptime var arr = [_]Expression{undefined} ** buffer.len;
    comptime var i = 0;
    inline while (current_token != .eof) {
        comptime var prev_token = current_token;
        current_token = lexer.next(buffer);
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

//TODO: Make an Abstract Syntax Tree
const AST = struct {
    pub const Exprs = union(enum) {
        symbol: []const u8,
        function: []const u8,
        func_args: []const u8,
    };

    root: ?*Node,
    const Node = struct {
        value: ?Token,
        left: ?*Node,
        right: ?*Node,
    };
};

pub fn main() !void {
    var a = try parse_symbol("abr");
    std.debug.print("{}\n", .{a});
    std.debug.print("{}\n", .{@TypeOf(a)});
    var b = try parse_function("add(a,b)");
    std.debug.print("{}\n", .{b});
    //var k = try parse_function("f(x)");
    //std.debug.print("{}\n", .{k});
    comptime var buffer = "add(a,b)";
    try list_tokens(buffer);
    comptime var k = firsttok_list(buffer);
    std.debug.print("{any}\n", .{k});
    //comptime var j = &[_]Token{};
    comptime var l = make_token_list(buffer, &[_]Token{});
    std.debug.print("{any}\n", .{@TypeOf(l)});
    const f = std.fmt.comptimePrint("{any}", .{l});
    std.debug.print("{s}\n", .{f});

    comptime var m = append_token(.{ .identifier = "happy" }, &[_]Token{.comma});
    m = append_token(.{ .identifier = "ok" }, m);
    m = prepend_token(.openParen, m);
    std.debug.print("{any}\n", .{@TypeOf(m)});
    comptime var j = std.fmt.comptimePrint("{any}", .{m});
    std.debug.print("{s}\n", .{j});
}

test "parser" {
    var a_symbol = Zoq.sym("a");
    var a = try parse_symbol("a");
    try std.testing.expect(a.eql(a_symbol));
}

//TODO: Write more tests for the parser.
