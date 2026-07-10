const std = @import("std");

pub const State = enum { idle, waiting_for_time, waiting_for_start_confirm, waiting_for_restart_confirm, waiting_for_task, running };
pub const Event = enum { start, timer_complete, success, failure, progress, end, pause, exit, invalid_time };

pub const ActionType = enum { prompt_user, confirm_user, start, end };
pub const Action = union(ActionType) { prompt_user: struct { message: []const u8 }, confirm_user: struct { message: []const u8 }, start: struct {}, end: struct {} };

pub const StateMachine = struct {
    state: State = .idle,
    pub fn handleEvent(self: *StateMachine, event: Event, event_queue: *std.ArrayList(Event), action_queue: *std.ArrayList(Action)) !void {
        switch (self.state) {
            .idle => switch (event) {
                .start => {
                    self.state = .waiting_for_time;
                    try action_queue.append(undefined, .{ .prompt_user = .{ .message = "Enter time (MM:SS)" } });
                },
                .timer_complete => {
                    self.state = .waiting_for_task;
                    try action_queue.append(undefined, .{ .prompt_user = .{ .message = "Enter task" } });
                },
                else => {},
            },
            .waiting_for_time => switch (event) {
                .success => {
                    self.state = .waiting_for_start_confirm;
                    try action_queue.append(undefined, .{ .prompt_user = .{ .message = "Start timer?" } });
                },
                .failure => {
                    self.state = .idle;
                    try event_queue.append(undefined, .start);
                },
                else => {},
            },
            .waiting_for_start_confirm => switch (event) {
                .success => {
                    self.state = .running;
                    try event_queue.append(undefined, .start);
                },
                .failure => {
                    self.state = .idle;
                    try event_queue.append(undefined, .start);
                },
                else => {},
            },
            .waiting_for_restart_confirm => switch (event) {
                .success => {
                    self.state = .running;
                    try event_queue.append(undefined, .start);
                },
                .failure => {
                    self.state = .idle;
                    try event_queue.append(undefined, .start);
                },
                else => {},
            },
            .waiting_for_task => switch (event) {
                .success => {
                    self.state = .waiting_for_restart_confirm;
                    try action_queue.append(undefined, .{ .prompt_user = .{ .message = "Run again?" } });
                },
                .failure => {
                    self.state = .idle;
                    try event_queue.append(undefined, .start);
                },
                else => {},
            },
            .running => switch (event) {
                .start => {
                    try action_queue.append(undefined, .{ .start = .{} });
                },
                .end => {
                    self.state = .waiting_for_task;
                    try action_queue.append(undefined, .{ .prompt_user = .{ .message = "Enter task" } });
                },
                .invalid_time => {
                    self.state = .idle;
                    try event_queue.append(undefined, .start);
                },
                .pause => {},
                .exit => {},
                else => {},
            },
        }
    }
};
