const std = @import("std");
const Io = std.Io;

const ansi = @import("./ansi.zig").ansi;
const Prompt = @import("./prompt.zig").Prompt;
const Timer = @import("./timer.zig").Timer;

const TimerError = error{ InvalidTimeFormat, MaxDurationExceeded };
const TimeStruct = struct { minutes: u8, seconds: u8 };

const State = enum { idle, run, end };
const Event = enum { prompt_time, prompt_start, prompt_task, prompt_continue, prompt_exit, prompt_stop, run_start, run_pause, run_exit, run_end };

var current_state: State = State.idle;
var prompt: Prompt = undefined;
var timer: Timer = undefined;
var interval: ?i64 = null;

pub fn main(init: std.process.Init) !void {
    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_file_reader = std.Io.File.Reader.init(.stdin(), io, &stdin_buffer);
    const stdin_reader = &stdin_file_reader.interface;
    try stdout_writer.flush();

    prompt = Prompt{ .reader = stdin_reader, .writer = stdout_writer };
    timer = Timer{ .io = io, .progress = handleTimerProgress };

    const timestamp = if (args.len > 1) args[1] else null;

    if (timestamp) |time| {
        const seconds = try parseAndValidateTime(time);
        try timer.start(seconds);
        try handleEvent(Event.run_start);
    } else {
        try handleEvent(Event.prompt_time);
    }

    while (current_state != State.end) {}
}

fn handleEvent(event: Event) !void {
    switch (current_state) {
        .idle => {
            switch (event) {
                .run_start => {
                    if (interval) |seconds| {
                        current_state = State.run;
                        try writeClock(seconds);
                        timer.stop();
                        try timer.start(seconds);
                    } else {
                        try handleEvent(Event.prompt_time);
                    }
                },
                .prompt_time => {
                    timer.stop();
                    const result = try prompt.input("Enter time (MM:SS)");
                    interval = try parseAndValidateTime(result);
                    try handleEvent(Event.prompt_start);
                },
                .prompt_start => {
                    if (interval != null) {
                        const confirmed = try prompt.confirm("Start timer?");
                        if (confirmed) {
                            try handleEvent(Event.run_start);
                        } else {
                            try handleEvent(Event.prompt_time);
                        }
                    } else {
                        try handleEvent(Event.prompt_time);
                    }
                },
                .prompt_continue => {
                    const confirmed = try prompt.confirm("Run again?");
                    if (confirmed) {
                        try handleEvent(Event.run_start);
                    } else {
                        try exit();
                    }
                },
                .prompt_task => {
                    const response = try prompt.input("Enter task");
                    const success = try writeTask(response);
                    if (success) {
                        try handleEvent(Event.prompt_continue);
                    }
                },
                .prompt_exit => {},
                else => {},
            }
        },
        .run => {
            switch (event) {
                .run_end => {
                    try prompt.message_replace("Timer Complete\n");
                    current_state = State.idle;
                    try handleEvent(Event.prompt_task);
                },
                .run_pause => {},
                .run_exit => {},
                else => {},
            }
        },
        .end => {},
    }
}

fn exit() !void {
    try prompt.message("Goodbye! Stay productive. 👋\n");
    std.process.exit(0);
}

fn handleTimerProgress(seconds: i64) !void {
    if (seconds == 0) {
        try handleEvent(Event.run_end);
    } else {
        try writeClock(seconds);
    }
}

fn writeClock(seconds: i64) !void {
    const ms = try convertSecondsToTimeStruct(seconds);
    var buffer: [100]u8 = undefined;
    const message = try std.fmt.bufPrint(&buffer, "Time Remaining: {:0>2}:{:0>2}", ms);
    try prompt.message_replace(message);
}

fn writeTask(task: []const u8) !bool {
    std.log.info("task: {s}", .{task});
    return true;
}

fn convertSecondsToTimeStruct(total_seconds: i64) !TimeStruct {
    const minutes = @divTrunc(@mod(total_seconds, 3600), 60);
    const seconds = @mod(total_seconds, 60);

    return .{ .minutes = @intCast(minutes), .seconds = @intCast(seconds) };
}

fn parseAndValidateTime(time_str: []const u8) !i64 {
    if (time_str.len != 5) return TimerError.InvalidTimeFormat;
    if (time_str[2] != ':') return TimerError.InvalidTimeFormat;

    const min_str = time_str[0..2];
    const sec_str = time_str[3..5];

    const minutes = std.fmt.parseInt(u8, min_str, 10) catch return TimerError.InvalidTimeFormat;
    const seconds = std.fmt.parseInt(u8, sec_str, 10) catch return TimerError.InvalidTimeFormat;

    if (minutes > 59) return TimerError.InvalidTimeFormat;
    if (seconds > 59) return TimerError.InvalidTimeFormat;

    const min_seconds = minutes * @as(i64, std.time.s_per_min);
    return seconds + min_seconds;
}

// fn resetOut(writer: *std.Io.Writer) !void {
//     try ansi.clear.screen(writer);
//     try ansi.cursor.show(writer);
// }
//
// fn promptInput(settings: Settings) !void {
//     try resetOut(settings.writer);
//     try settings.writer.writeAll("Enter time (MM:SS): ");
//     try settings.writer.flush();
//     const user_input = try settings.reader.takeDelimiterExclusive('\n');
//     const cleaned_input = std.mem.trim(u8, user_input, "\r");
//
//     current_settings = Settings{ .time = cleaned_input, .reader = settings.reader, .writer = settings.writer, .io = settings.io };
//     handleEvent(Event.run_start, current_settings);
// }
//
// fn promptTask(settings: Settings) !bool {
//     try resetOut(settings.writer);
//     try settings.writer.writeAll("Enter task: ");
//     try settings.writer.flush();
//     const user_input = try settings.reader.takeDelimiterExclusive('\n');
//     const cleaned_input = std.mem.trim(u8, user_input, "\r");
//
//     try settings.writer.print("Hello, {s}!\n", .{cleaned_input});
//     try settings.writer.flush();
//
//     return true;
// }
//
// fn promptContinue(settings: Settings) !bool {
//     try resetOut(settings.writer);
//     try settings.writer.writeAll("Continue (y/n)?: ");
//     try settings.flush();
//     const user_input = try settings.reader.takeDelimiterExclusive('\n');
//     const cleaned_input = std.mem.trim(u8, user_input, "\r");
//
//     if (std.mem.eql(u8, cleaned_input, "y") or std.mem.eql(u8, cleaned_input, "yes")) {
//         return true;
//     } else {
//         return false;
//     }
// }
//
// fn startTimer(settings: Settings) !void {
//     if (settings.time) |stamp| {
//         try ansi.clear.screen(settings.writer);
//         try ansi.cursor.hide(settings.writer);
//         try timer.runTimer(stamp, settings.io, settings.writer);
//     }
// }
