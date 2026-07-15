const std = @import("std");

const TimeParts = @import("./timestamp.zig").TimeParts;
const getYearMonthDay = @import("./timestamp.zig").getTimeParts;

const task_folder = "daily_tasks";

pub const Task = struct {
    task: []const u8,
    duration: [5]u8, // MM:SS

    pub fn write(self: *Task, io: std.Io, allocator: std.mem.Allocator) !void {
        //std.log.info("task: {s}", .{task});
        const timeparts = try getYearMonthDay(io);

        // check for dir
        try createFolder(task_folder, io);

        var file_buffer: [32]u8 = undefined;
        const path = try std.fmt.bufPrint(&file_buffer, "./{s}/{d}{:0>2}{:0>2}.md", .{
            task_folder,
            timeparts.year,
            timeparts.month,
            timeparts.day,
        });

        var content: std.ArrayList([]u8) = .empty;
        defer content.deinit(allocator);
        const cwd = std.Io.Dir.cwd();

        cwd.access(io, path, .{}) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    var title_buffer: [16]u8 = undefined;
                    const result = try std.fmt.bufPrint(&title_buffer, "# {d}{:0>2}{:0>2}\n\n", .{ timeparts.year, timeparts.month, timeparts.day });
                    try content.append(allocator, result);
                },
                else => {},
            }
        };

        var task_buffer: [1024]u8 = undefined;
        const task_fmt = try std.fmt.bufPrint(&task_buffer, "- {s}: {s}\n", .{ self.duration, self.task });

        try content.append(allocator, task_fmt);

        const joined = try std.mem.join(allocator, "", content.items);
        defer allocator.free(joined);

        try Task.writeToFile(joined, path, io);
    }

    fn writeToFile(content: []u8, path: []const u8, io: std.Io) !void {
        const cwd = std.Io.Dir.cwd();
        var can_write = true;

        // check if the file exists or is inaccessible
        (cwd.access(io, path, .{
            .write = true,
        }) catch |err| {
            switch (err) {
                // if the file doesn't exist it can be created
                error.FileNotFound,
                => can_write = false,
                // ...but any other kind of error is an error
                else => return err,
            }
        });

        const out_file = (if (can_write)
            try cwd.openFile(io, path, .{ .mode = .read_write })
        else
            try cwd.createFile(io, path, .{}));
        defer out_file.close(io);

        var stdout_buffer: [1024]u8 = undefined;
        var stdout_file_writer: std.Io.File.Writer = .initStreaming(
            out_file,
            io,
            &stdout_buffer,
        );

        const stdout_writer = &stdout_file_writer.interface;

        try stdout_file_writer.seekTo(try out_file.length(io));
        try stdout_writer.writeAll(content);

        try stdout_writer.flush();
    }

    fn createFolder(path: []const u8, io: std.Io) !void {
        const cwd = std.Io.Dir.cwd();
        try cwd.createDirPath(io, path);
    }
};
