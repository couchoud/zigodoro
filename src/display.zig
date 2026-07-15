const std = @import("std");
const ansi = @import("ansi.zig").ansi;

pub const Display = struct {
    writer: *std.Io.Writer,
    reader: *std.Io.Reader,
    pub fn clear(self: *Display) !void {
        try ansi.clear.screen(self.writer);
        try self.writer.flush();
    }
    pub fn message_replace(self: *Display, value: []const u8) !void {
        try self.writer.print("\r\x1b[K{s}", .{value});
        try ansi.cursor.hide(self.writer);
        try self.writer.flush();
    }
    pub fn message(self: *Display, value: []const u8) !void {
        try self.writer.print("{s}", .{value});
        try ansi.cursor.hide(self.writer);
        try self.writer.flush();
    }
    pub fn input(self: *Display, value: []const u8) ![]const u8 {
        try self.writer.print("{s}: ", .{value});
        try ansi.cursor.show(self.writer);
        try self.writer.flush();

        const user_input = try self.reader.takeDelimiterExclusive('\n');
        self.reader.toss(1);
        const cleaned_input = std.mem.trim(u8, user_input, "\r");
        return cleaned_input;
    }
    pub fn confirm(self: *Display, value: []const u8) !bool {
        var buffer: [100]u8 = undefined;
        const prompt = try std.fmt.bufPrint(&buffer, "{s} (y/n)", .{value});
        const user_input = try self.input(prompt);

        return std.mem.eql(u8, user_input, "y") or std.mem.eql(u8, user_input, "yes");
    }
};
