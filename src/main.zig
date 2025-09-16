const std = @import("std");
const pMz = @import("pMathz");
const rl = @import("raylib");
const scaleValue = 5.0;

//errors
const elevatorErrors = error{ setpointTooLow, setpointTooHigh };

//custom types
const Mechanism = struct {
    pose: pMz.Vec2d,
    pivot: pMz.Vec2d,
    length: f32 = 0,
    width: f32 = 0,
    angle: f32 = 0,
    color: rl.Color,
};

const ElevatorMech = struct {
    elevatorUpright: *Mechanism,
    elevatorSlide: *Mechanism,
    elevatorCariage: *Mechanism,

    pub fn setElevatorHeight(self: *ElevatorMech, height: f32) !void {
        const setHeight = (height * scaleValue) + self.elevatorUpright.pose.y;

        //this error is trivial to handle but I want to know if it is happening and causing an issue
        if (setHeight < self.elevatorUpright.pose.y) {
            return elevatorErrors.setpointTooLow;
        } else if (setHeight > self.elevatorUpright.pose.y + (2 * ((self.elevatorUpright.length) - (5 * scaleValue))) + (5 * scaleValue)) {
            return elevatorErrors.setpointTooHigh;
        }

        self.elevatorCariage.pose.y = setHeight;
        sequenceElevator(self);
    }

    fn sequenceElevator(self: *ElevatorMech) void {
        var setHeight = self.elevatorCariage.pose.y - self.elevatorUpright.length;
        if (setHeight > (self.elevatorUpright.length - (5 * scaleValue)) + self.elevatorUpright.pose.y) {
            setHeight = self.elevatorUpright.length - (5 * scaleValue) + self.elevatorUpright.pose.y;
        } else if (setHeight < self.elevatorUpright.pose.y) {
            setHeight = self.elevatorUpright.pose.y;
        }

        self.elevatorSlide.pose.y = setHeight;
        drawElevatorMech(self.elevatorCariage);
        drawElevatorMech(self.elevatorSlide);
        drawElevatorMech(self.elevatorUpright);
    }

    fn drawElevatorMech(mech: *Mechanism) void {
        const position = getRLPointFromNormalPoint(mech.pose);
        const pivot = offsetR1Vector(mech.pivot, mech);
        const rec = rl.Rectangle{ .height = mech.length, .width = mech.width, .x = position.x, .y = position.y };
        rl.drawRectanglePro(rec, pivot, mech.angle, mech.color);
    }
};

//main run loop
pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 800;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    rl.initWindow(screenWidth, screenHeight, "phyz-example");
    rl.setTargetFPS(60);

    var elevatorUpright = Mechanism{ .pose = .{ .x = 30 * scaleValue, .y = 4 * scaleValue }, .pivot = .{ .x = 0 * scaleValue, .y = 20 * scaleValue }, .angle = 0, .length = 40 * scaleValue, .width = 4 * scaleValue, .color = .orange };
    var elevatorSlide = Mechanism{ .pose = .{ .x = 30 * scaleValue, .y = 0 * scaleValue }, .pivot = .{ .x = 0 * scaleValue, .y = 20 * scaleValue }, .angle = 0, .length = 40 * scaleValue, .width = 3 * scaleValue, .color = .blue };
    var elevatorCarraige = Mechanism{ .pose = .{ .x = 30 * scaleValue, .y = 4 * scaleValue }, .pivot = .{ .x = -1.5 * scaleValue, .y = (10 - 8) * scaleValue }, .angle = 0, .length = 20 * scaleValue, .width = 6 * scaleValue, .color = .gray };
    var elevator = ElevatorMech{ .elevatorCariage = &elevatorCarraige, .elevatorSlide = &elevatorSlide, .elevatorUpright = &elevatorUpright };

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        try elevator.setElevatorHeight(75);

        rl.clearBackground(.white);
    }
}

//helper functions

fn drawMechanism(mech: *Mechanism) void {
    const position = getRLPointFromNormalPoint(mech.pose);
    const pivot = offsetR1Vector(mech.pivot, mech);
    const rec = rl.Rectangle{ .height = mech.length, .width = mech.width, .x = position.x, .y = position.y };
    rl.drawRectanglePro(rec, pivot, mech.angle, mech.color);
}

fn getRLPointFromNormalPoint(point: pMz.Vec2d) rl.Vector2 {
    const y = point.y;
    const height: f32 = @floatFromInt(rl.getScreenHeight());
    const flippedY: f32 = height - y;
    return rl.Vector2{ .x = point.x, .y = flippedY };
}

fn offsetR1Vector(point: pMz.Vec2d, mech: *Mechanism) rl.Vector2 {
    return rl.Vector2{ .x = (point.x + (mech.width / 2)), .y = point.y + (mech.length / 2) };
}
