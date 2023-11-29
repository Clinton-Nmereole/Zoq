const std = @import("std");

const Lexer = @This();

index: comptime_int = 0,

pub const whitespace_chars: []const u8 = &[_]u8{
    ' ',
    '\t',
    '\n',
    '\r',
    std.ascii.control_code.vt,
    std.ascii.control_code.ff,
};

pub const identifier_characters: []const u8 =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ++
    "abcdefghijklmnopqrstuvwxyz" ++
    "_" //
;

//Utilities
pub inline fn eqlComptime(comptime T: type, comptime a: []const T, comptime b: []const T) bool {
    if (a.len != b.len) return false; //check if both arrays have the same length if they don't then they are not equal
    const len = a.len; // set a constant len to the length of the comptime array a
    const V = @Vector(len, T); //create a vector with a size of len and a type of T(the type of value stored in the comptime array a)
    // first we type coersion on the slice (a[0..] and b[0..]) to V(a vector of length len that holds values of type T)
    // then we check if both vectors are equal with "==" operator
    // Note that the "==" operator when used on vectors returns a new vector with boolean values of len equal to the vectors being compared.
    // So @Vector(4, u8){ 1, 2, 3, 4 } == @Vector(4, u8){ 1, 2, 3, 4 } returns @Vector(4, u8){true, true, true, true}
    // @Vector(4, u8){ 1, 2, 3, 4 } == @Vector(4, u8){ 1, 2, 8, 9 } returns @Vector(4, u8){true, true, false, false}
    // We however need to return a single boolean value, so we use @reduce.
    // All reduce does is perform a logical AND on the values of the vector returned by "==" operator
    // So Vector(4, u8){true, true, true, true} would become true because we use logical AND and it returns true when all the values are true
    // So @Vector(4, u8){true, true, true, false} if used with reduce and logical AND would return false
    comptime return @reduce(.And, @as(V, a[0..].*) == @as(V, b[0..].*));
}

//TODO: Implement a parser
pub const Token = union(enum) {
    identifier: []const u8,
    openParen,
    closeParen,
    comma,

    err: Err,

    pub const Err = union(enum(comptime_int)) {
        Unexpectedbyte: u8,
    };

    pub inline fn eql(comptime this: Token, comptime other: Token) bool {
        comptime if (std.meta.activeTag(this) != other) return false;

        return switch (this) {
            .comma, .openParen, .closeParen => true,
            inline .identifier => |str, tag| eqlComptime(u8, str, @field(other, @tagName(tag))),
            .err => |err| err == other.err,
        };
    }

    pub inline fn format(
        comptime self: Token,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = options;
        if (fmt.len != 0) comptime {
            std.fmt.invalidFmtError(fmt, self);
        };
        switch (self) {
            inline .identifier => |str, tag| try writer.writeAll(comptime std.fmt.comptimePrint("{s}({s})", .{ @tagName(tag), str })),
            .comma, .openParen, .closeParen => try writer.writeAll(@tagName(self)),
            .err => |err| try writer.writeAll(comptime std.fmt.comptimePrint("{s}({s})", .{ @tagName(self), @tagName(err) })),
        }
    }
};

test "tokenizer" {
    const mytoken = Token{
        .identifier = "test",
    };
    const mytoken2 = Token{
        .identifier = "test",
    };
    const mytoken3 = Token{
        .identifier = "wrongtest",
    };
    try std.testing.expect(mytoken.eql(mytoken2) == true);
    try std.testing.expect(mytoken.eql(mytoken3) == false);
}
