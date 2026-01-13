const std = @import("std");
const dvui = @import("dvui");
const ArrayList = std.ArrayList;
const RaylibBackend = dvui.backend;
const raylib = @import("raylib");
comptime {
    std.debug.assert(@hasDecl(RaylibBackend, "RaylibBackend"));
}

const window_icon_png = @embedFile("resources/zig-favicon.png");

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();

const vsync = true;
var scale_val: f32 = 1.0;

var show_dialog_outside_frame: bool = false;

var isClockedIn: bool = false;

pub const c = RaylibBackend.c;

// var text_entry_buf = std.mem.zeroes([50]u8);
var text_entry_buf: ArrayList(u8) = .empty;

const inputState = struct {
    newLine: bool = false,
};

pub fn main() !void {
    defer _ = text_entry_buf.deinit(gpa);
    defer _ = gpa_instance.deinit();

    _ = try text_entry_buf.addOne(gpa);

    var backend = try RaylibBackend.initWindow(.{
        .gpa = gpa,
        .size = .{ .w = 800.0, .h = 600.0 },
        .vsync = vsync,
        .title = "Zeditor",
        .icon = window_icon_png, // can also call setIconFromFileContent()
    });
    defer backend.deinit();
    backend.log_events = true;

    var win = try dvui.Window.init(@src(), gpa, backend.backend(), .{});
    defer win.deinit();

    var input = inputState{
        .newLine = false,
    };

    try SaveClockedIn();

    while (!raylib.windowShouldClose()) {
        try backend.addAllEvents(&win);
        c.BeginDrawing();
        const nstime = win.beginWait(true);

        try win.begin(nstime);
        backend.clear();
        //{

        //content of ui
        try dvui_frame(&input);

        const end_micros = try win.end(.{});

        // cursor management
        backend.setCursor(win.cursorRequested());

        const wait_event_micros = win.waitTime(end_micros);

        //}
        backend.EndDrawingWaitEventTimeout(wait_event_micros);
    }
}

fn dvui_frame(state: *inputState) !void {
    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    const evts = dvui.events();

    for (evts) |*e| {
        if (e.evt == .key) {
            if (e.evt.key.action == .down and (e.evt.key.mod.control() or e.evt.key.mod.command())) {
                //handle ctrl shortcuts
            } else if (e.evt.key.action != .up and (e.evt.key.code == .enter or e.evt.key.code == .kp_enter)) {
                state.newLine = true;
            }

            if (e.evt.key.action == .down) {
                _ = try text_entry_buf.addOne(gpa);
            }
        }
    }

    const button = dvui.button(@src(), "clock in", .{}, .{ .expand = .horizontal });
    if (button) {
        //clock in action
    }

    var text = dvui.textEntry(@src(), .{ .text = .{ .buffer = text_entry_buf.items } }, .{ .expand = .both });
    defer text.deinit();

    if (state.newLine) {
        state.newLine = false;
        _ = try text_entry_buf.addOne(gpa);
        _ = try text_entry_buf.addOne(gpa);
        text.textTyped("\n", false);
    }
}

fn save(words: []u8) !void {
    _ = words;
    const fileName = try dvui.dialogNativeFileSave(gpa, .{});

    if (fileName) |fname| {
        var file = try std.fs.createFileAbsolute(fname, .{});
        defer file.close();
        try file.writeAll(text_entry_buf.items);
    }
}

fn SaveClockedIn() !void {
    const app_data_path = try std.process.getEnvVarOwned(gpa, "APPDATA");
    defer gpa.free(app_data_path);

    // 2. Construct the full path to your specific file
    const full_path = try std.fs.path.join(gpa, &[_][]const u8{ app_data_path, "TimeTracker", "clockedIn.txt" });
    defer gpa.free(full_path);

    if (std.fs.path.dirname(full_path)) |dir_path| {
        try std.fs.cwd().makePath(dir_path);
    }

    // 3. Open the file using the absolute path
    const file = try std.fs.createFileAbsolute(full_path, .{ .truncate = true });
    defer file.close();

    var buffer: [128]u8 = undefined;
    const content = try std.fmt.bufPrint(&buffer, "{d}\n{d}\n", .{ @as(u8, @intCast(isClockedIn)), std.time.timestamp() });
    try file.writeAll(content);
}
