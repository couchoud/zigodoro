const std = @import("std");
const Io = std.Io;

const ansi = @import("./ansi.zig").ansi;
const Display = @import("./display.zig").Display;
const Timer = @import("./timer.zig").Timer;

const StateMachine = @import("./state.zig").StateMachine;
const State = @import("./state.zig").State;
const Event = @import("./state.zig").Event;
const Action = @import("./state.zig").Action;

const EventDispatcher = @import("./event_dispatcher.zig").EventDispatcher;

const TimerError = error{ InvalidTimeFormat, MaxDurationExceeded };
const TimeStruct = struct { minutes: u8, seconds: u8 };
const Context = struct { duration: i64 = 0 };

const TimerListener = struct {
    timer: *Timer,
    display: *Display,
    event_queue: *std.ArrayList(Event),
    pub fn handleEvent(self: *TimerListener, event: []const u8) void {
        if (std.mem.eql(u8, event, "progress")) {
            if (self.timer.remaining == 0) {
                // Note: Use allocator catch or change function signature to return errors
                self.event_queue.append(undefined, Event.end) catch {};
            }
            self.writeTimer() catch |err| {
                std.debug.print("TimerListener#handleEvent > writeTimer error: {}", .{err});
            };
        }
    }
    fn writeTimer(self: *TimerListener) !void {
        const seconds = self.timer.remaining;
        const ms = try convertSecondsToTimeStruct(seconds);
        var buffer: [100]u8 = undefined;
        const message = try std.fmt.bufPrint(&buffer, "Time Remaining: {:0>2}:{:0>2}", ms);
        try self.display.message_replace(message);
    }
};

pub fn main(init: std.process.Init) !void {
    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    //for (args) |arg| {
    //    std.log.info("arg: {s}", .{arg});
    //}

    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer = std.Io.File.Writer.init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_file_reader = std.Io.File.Reader.init(.stdin(), io, &stdin_buffer);
    const stdin_reader = &stdin_file_reader.interface;
    try stdout_writer.flush();

    var event_buffer: [16]Event = undefined;
    var event_queue = std.ArrayList(Event).initBuffer(&event_buffer);

    var action_buffer: [16]Action = undefined;
    var action_queue = std.ArrayList(Action).initBuffer(&action_buffer);

    var display = Display{ .reader = stdin_reader, .writer = stdout_writer };
    var dispatcher = EventDispatcher.init(arena);
    defer dispatcher.deinit();
    var timer = Timer{ .io = io, .dispatcher = &dispatcher };
    var context = Context{};
    var sm = StateMachine{};
    var timerListener = TimerListener{ .timer = &timer, .display = &display, .event_queue = &event_queue };

    const timestamp = if (args.len > 1) args[1] else null;

    if (timestamp) |time| {
        context.duration = try parseAndValidateTime(time);
        sm.state = State.running;
        try event_queue.append(undefined, .start);
    } else {
        sm.state = State.idle;
        try event_queue.append(undefined, .start);
    }

    var index: usize = 0;
    while (index < event_queue.items.len) {
        const current_event = event_queue.items[index];
        index += 1;

        std.debug.print("\n[Current State: {s}] Handling Event: {s}\n", .{ @tagName(sm.state), @tagName(current_event) });

        try sm.handleEvent(current_event, &event_queue, &action_queue);

        if (sm.state == State.running) {
            switch (current_event) {
                .start => {
                    if (context.duration > 0) {
                        try timer.dispatcher.addListener(TimerListener, &timerListener, TimerListener.handleEvent);
                        try timer.start(context.duration);
                    } else {
                        try sm.handleEvent(Event.invalid_time, &event_queue, &action_queue);
                    }
                },
                else => {},
            }
        }

        while (action_queue.items.len > 0) {
            // Pop the action
            const current_action = action_queue.items[action_queue.items.len - 1];
            action_queue.items.len -= 1;

            switch (current_action) {
                .prompt_user => |payload| {
                    const result = try display.input(payload.message);
                    if (sm.state == State.waiting_for_time) {
                        const time = try parseAndValidateTime(result);
                        context.duration = time;
                    }
                    try event_queue.append(undefined, Event.success);
                },
                .confirm_user => |payload| {
                    const result = try display.confirm(payload.message);
                    if (result) {
                        try event_queue.append(undefined, Event.success);
                    } else {
                        try event_queue.append(undefined, Event.success);
                    }
                },
                else => {},
            }
        }
    }

    // while (current_state != State.end) {}
}

fn exit(display: *Display) !void {
    try display.message("Goodbye! Stay productive. 👋\n");
    std.process.exit(0);
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
