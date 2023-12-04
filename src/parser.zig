const std = @import("std");
const Lexer = @import("lexer.zig");
const Token = Lexer.Token;

const Zoq = @import("expression.zig");
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

pub inline fn token_length(
    comptime buffer: []const u8,
) usize {
    comptime var lexer = Lexer{};
    comptime var actual_token = lexer.next(buffer);
    comptime var length: usize = 0;
    inline while (actual_token != .eof) {
        length += 1;
        actual_token = lexer.next(buffer);
    }
    comptime {
        return length;
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

pub inline fn parse_expr_to_list(comptime buffer: []const u8, comptime list: []const Expression) ![]const Expression {
    comptime var lexer = Lexer{};

    comptime var forward_token = lexer.peek(buffer);
    comptime var expr_arr = list;
    inline while (forward_token != .eof) {
        comptime var current_token = forward_token;
        forward_token = lexer.next(buffer);
        if (forward_token == .openParen and current_token == .identifier) {
            var fun_args = &.{};
            comptime var item = Zoq.fun(current_token.identifier, fun_args);
            expr_arr = expr_arr ++ @as([]const Expression, &.{item});
        }
        comptime if (current_token == .identifier and forward_token != .openParen and !forward_token.eql(current_token)) {
            comptime var item = Zoq.sym(current_token.identifier);
            expr_arr = expr_arr ++ @as([]const Expression, &.{item});
        };
    }
    return expr_arr;
}

pub inline fn parse_expr(comptime buffer: []const u8) !Expression {
    comptime var lexer = Lexer{};
    comptime var forward_token = lexer.peek(buffer);
    inline while (forward_token != .eof) {
        comptime var current_token = forward_token;
        forward_token = lexer.next(buffer);
        if (forward_token == .openParen and current_token == .identifier) {
            comptime var fun_args: []const Expression = &.{};
            comptime var fun_name = current_token.identifier;

            current_token = forward_token;
            forward_token = lexer.next(buffer);
            if (forward_token == .closeParen) {
                return Zoq.fun(fun_name, fun_args);
            }
            inline while (lexer.peek(buffer) != .closeParen) {
                comptime var args2 = try parse_expr(buffer[lexer.index - 1 ..]);
                fun_args = fun_args ++ @as([]const Expression, &.{args2});
                current_token = forward_token;
                forward_token = lexer.next(buffer);
            }

            current_token = forward_token;
            forward_token = lexer.next(buffer);
            return Zoq.fun(fun_name, fun_args);
        } else if (current_token == .identifier and forward_token != .openParen and !forward_token.eql(current_token)) {
            comptime var item = Zoq.sym(current_token.identifier);
            return item;
        }
    }
}

//FIX: parse_2 can not handle multiple arguments. The issue is with the comma handling
pub inline fn parse_expr2(comptime buffer: []const u8) !Expression {
    comptime var lexer = Lexer{};
    comptime var current_token = lexer.peek(buffer);
    comptime var mover = lexer.next(buffer);
    inline while (current_token != .eof) {
        current_token = mover;
        mover = lexer.next(buffer);
        switch (mover) {
            .openParen, .closeParen, .comma, .identifier, .equals => {
                if (mover == .openParen) {
                    comptime var fun_args: []const Expression = &.{};
                    comptime var fun_name = current_token.identifier;
                    current_token = mover;
                    mover = lexer.next(buffer);
                    if (mover == .closeParen) {
                        comptime {
                            return Zoq.fun(fun_name, fun_args);
                        }
                    }
                    comptime var arg2 = try parse_expr2(buffer[lexer.identstart..]);
                    fun_args = fun_args ++ @as([]const Expression, &.{arg2});
                    //BUG: The bug is here, this entire "if" block needs to be fixed
                    if (lexer.peek(buffer) != .closeParen) {
                        current_token = mover;
                        mover = lexer.next(buffer);
                        inline while (mover == .comma or mover == .closeParen) {
                            current_token = mover;
                            mover = lexer.next(buffer);
                            comptime var arg3 = try parse_expr2(buffer[lexer.identstart..]);
                            fun_args = fun_args ++ @as([]const Expression, &.{arg3});
                        }
                    }
                    current_token = mover;
                    mover = lexer.next(buffer);

                    return Zoq.fun(fun_name, fun_args);
                } else {
                    return Zoq.sym(current_token.identifier);
                }
            },
            else => {
                return error.MalformedExpression;
            },
        }
    }
}

pub fn main() !void {
    var b = try parse_expr_to_list("add(a,a)", &[_]Expression{});
    for (b) |z| {
        std.debug.print("{s}\n", .{@tagName(z)});
    }
    std.debug.print("{any}\n", .{b});

    var c = try parse_expr("add(f,w)");
    std.debug.print("{s}\n", .{@tagName(c)});
    std.debug.print("{any}\n", .{c});
    for (c.function.args) |z| {
        std.debug.print("{s}\n", .{@tagName(z)});
    }
    var o = try parse_expr2("night()");
    //const x = std.fmt.comptimePrint("{any}", .{o});
    std.debug.print("{s}\n", .{o});
}

test "parser" {
    var a_symbol = Zoq.sym("a");
    var a = try parse_symbol("a");
    try std.testing.expect(a.eql(a_symbol));
}

//TODO: Write more tests for the parser.
