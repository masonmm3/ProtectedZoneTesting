const std = @import("std");
const pMz = @import("pMathz");
const rl = @import("raylib");

//custom types
const Mechanism = struct {
    pose: pMz.Vec2d = pMz.Vec2d{ .x = 0, .y = 0 },
    lenght: i32 = 0,
    width: i32 = 0,
    angle: i32 = 0,
};

//main run loop
pub fn main() void {
    const screenWidth = 800;
    const screenHeight = 800;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    rl.initWindow(screenWidth, screenHeight, "phyz-example");

    var elevator = Mechanism{};

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        drawMechanism(&elevator);

        rl.clearBackground(.white);
    }
}

//helper functions
fn drawMechanism(mech: *Mechanism) void {
    const position = getRLPointFromNormalPoint(mech.pose);
    const rec = rl.Rectangle{ .height = mech.lenght, .width = mech.width, .x = position.x, .y = position.y };
    rl.drawRectanglePro(rec, position, mech.angle, .orange);
}

fn getRLPointFromNormalPoint(point: pMz.Vec2d) rl.Vector2 {
    const y = point.y;
    const height: f32 = rl.getScreenHeight();
    const flippedY: f32 = height - y;
    return rl.Vector2{ .x = point.x, .y = flippedY };
}
