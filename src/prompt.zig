const std = @import("std");
const ansi = @import("ansi.zig").ansi;

pub const Prompt = struct {
    writer: *std.Io.Writer,
    reader: *std.Io.Reader,
    pub fn clear(self: *Prompt) !void {
        try ansi.clear.screen(self.writer);
        try ansi.cursor.show(self.writer);
    }
    pub fn message_replace(self: *Prompt, value: []const u8) !void {
        try self.writer.print("\r{s}", .{value});
        try ansi.cursor.hide(self.writer);
        try self.writer.flush();
    }
    pub fn message(self: *Prompt, value: []const u8) !void {
        try self.writer.print("{s}\n", .{value});
        try ansi.cursor.hide(self.writer);
        try self.writer.flush();
    }
    pub fn input(self: *Prompt, value: []const u8) ![]const u8 {
        try self.writer.print("{s}: ", .{value});
        try ansi.cursor.show(self.writer);
        try self.writer.flush();

        const user_input = try self.reader.takeDelimiterExclusive('\n');
        self.reader.toss(1);
        // std.log.info("Prompt#input.user_input: {s}\n", .{user_input});
        const cleaned_input = std.mem.trim(u8, user_input, "\r");
        // std.log.info("Prompt#input.clean_input: {s}\n", .{cleaned_input});
        return cleaned_input;
    }
    pub fn confirm(self: *Prompt, value: []const u8) !bool {
        var buffer: [100]u8 = undefined;
        const prompt = try std.fmt.bufPrint(&buffer, "{s} (y/n)", .{value});
        // std.log.info("Prompt#confirm.prompt: {s}\n", .{prompt});
        const user_input = try self.input(prompt);
        var result = false;

        if (std.mem.eql(u8, user_input, "y") or std.mem.eql(u8, user_input, "yes")) {
            result = true;
        }
        return result;
    }
};
