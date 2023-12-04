const std = @import("std");
const Token = @import("tokenizer.zig").Token;
const Lexer = @import("tokenizer.zig").Lexer;
const Expression = @import("main.zig").Expression;
const Zoq = @import("main.zig");
const Rule = Zoq.Rule;
const sym = Zoq.sym;
const fun = Zoq.fun;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
const tokenize = std.mem.tokenizeAny;

pub fn parsesym(lexer: *Lexer) !Expression {
    var token = lexer.next();
    if (token.token_type == .identifier) {
        return .{ .symbol = .{ .str = token.value } };
    }
    return error.NotASymbol;
}

pub fn parseexpr(lexer: *Lexer) !Expression {
    var name = lexer.next();
    if (!name.token_type.iseql(.eof)) {
        switch (name.token_type) {
            .identifier => {
                var open = lexer.nextIf(.open_paren);
                if (open != null) {
                    var args: std.ArrayList(Expression) = std.ArrayList(Expression).init(allocator);
                    var close = lexer.nextIf(.close_paren);
                    if (close != null) {
                        var fun_name = name.value;
                        return Zoq.fun(fun_name, args.items);
                    }
                    var appen1 = try parseexpr(lexer);
                    try args.append(appen1);
                    //_ = lexer.nextIf(.comma);
                    while (lexer.nextIf(.comma) != null) {
                        var appen2 = try parseexpr(lexer);
                        try args.append(appen2);
                    }
                    if (lexer.nextIf(.close_paren) == null) {
                        return error.ExpectedCloseParen;
                    }
                    var fun_name = name.value;
                    return Zoq.fun(fun_name, args.items);
                } else {
                    var sym_name = name.value;
                    return Zoq.sym(sym_name);
                }
            },
            else => {
                return error.NotAnExpression;
            },
        }
    } else {
        return error.MalformedExpression;
    }
}

pub fn main() !void {
    const buffer = "swap(pair(a,b))";
    var lexer = Lexer.init(buffer);

    //var peeked = lexer.peek();
    //std.debug.print("peeked: {s}\n", .{peeked.value});
    //next = lexer.next();
    //std.debug.print("{}\n", .{lexer});
    //var expr = try parsesym(&lexer);
    //std.debug.print("parsed symbol: {}\n", .{expr});
    var expr2 = try parseexpr(&lexer);
    std.debug.print("parsed expression: {}\n", .{expr2});
    //std.debug.print("Type of expression is: {s}\n", .{@tagName(expr2)});
    const addition_expr = Rule{
        .expression = fun("add", &.{ sym("a"), sym("b") }),
        .equivalent = fun("add", &.{ sym("b"), sym("a") }),
    };

    const swap_expr = Rule{
        .expression = fun("swap", &.{fun("pair", &.{ sym("a"), sym("b") })}),
        .equivalent = fun("pair", &.{ sym("b"), sym("a") }),
    };
    std.debug.print("swap expression applied: {!}\n", .{addition_expr.apply(expr2)});
    std.debug.print("swap expression applied: {!}\n", .{swap_expr.apply(expr2)});
}
