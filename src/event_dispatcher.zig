const std = @import("std");

pub const EventDispatcher = struct {
    // The vtable pattern allows you to pass context (e.g., your game state or app instance)
    // to your event listeners without making them global state.
    const Listener = struct {
        ctx: *anyopaque,
        dispatchFn: *const fn (ctx: *anyopaque, event: []const u8) void,
    };

    allocator: std.mem.Allocator,
    listeners: std.ArrayList(Listener),

    pub fn init(allocator: std.mem.Allocator) EventDispatcher {
        return .{
            .allocator = allocator,
            .listeners = .empty,
        };
    }

    pub fn deinit(self: *EventDispatcher) void {
        self.listeners.deinit(self.allocator);
    }

    // Register a listener using a generic context and a typed function
    pub fn addListener(self: *EventDispatcher, comptime T: type, listener: *T, comptime callback: fn (ctx: *T, event: []const u8) void) !void {
        const wrapper = struct {
            pub fn dispatch(ctx: *anyopaque, ev: []const u8) void {
                const concrete_ctx: *T = @ptrCast(@alignCast(ctx));
                callback(concrete_ctx, ev);
            }
        };

        try self.listeners.append(self.allocator, .{
            .ctx = @ptrCast(listener),
            .dispatchFn = wrapper.dispatch,
        });
    }

    // Trigger an event, dispatching it to all registered listeners
    pub fn dispatch(self: *EventDispatcher, event: []const u8) void {
        for (self.listeners.items) |listener| {
            listener.dispatchFn(listener.ctx, event);
        }
    }
};
