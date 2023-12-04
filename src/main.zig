const std = @import("std");
const Token = @import("tokenizer.zig").Token;
const Lexer = @import("tokenizer.zig").Lexer;
const Expression = @import("expression.zig").Expression;
const Zoq = @import("expression.zig");
const Rule = Zoq.Rule;
const sym = Zoq.sym;
const fun = Zoq.fun;
const Parser = @import("exprparser.zig");

pub fn main() !void {
    try Parser.interact();
}
