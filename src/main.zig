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
        var setHeight = (height * scaleValue) + self.elevatorUpright.pose.y;

        //this error is trivial to handle but I want to know if it is happening and causing an issue
        if (setHeight < self.elevatorUpright.pose.y) {
            if (setHeight < self.elevatorUpright.pose.y - (10 * scaleValue)) {
                return elevatorErrors.setpointTooLow;
            } else {
                setHeight = self.elevatorUpright.pose.y;
            }
        } else if (setHeight > self.elevatorUpright.pose.y + (2 * ((self.elevatorUpright.length) - (5 * scaleValue))) + (5 * scaleValue) - (8 * scaleValue)) {
            if (setHeight > self.elevatorUpright.pose.y + (2 * ((self.elevatorUpright.length) - (5 * scaleValue))) + (5 * scaleValue) - (8 * scaleValue) + (10 * scaleValue)) {
                return elevatorErrors.setpointTooHigh;
            } else {
                setHeight = self.elevatorUpright.pose.y + (2 * ((self.elevatorUpright.length) - (5 * scaleValue))) + (5 * scaleValue) - (8 * scaleValue);
            }
        }

        self.elevatorCariage.pose.y = setHeight;
        sequenceElevator(self);
    }

    fn sequenceElevator(self: *ElevatorMech) void {
        var setHeight = self.elevatorCariage.pose.y + (8 * scaleValue) - self.elevatorUpright.length;
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

const Motor = struct {
    stall_torque: f32 = 7.0,
    _moment_of_inertia: f32 = 0.0000105,
    gear_ratio: f32 = 15,
    motor_speed: f32 = 0.0,
    position: f32 = 0.0,
    kv: f32 = 6000.0 / 12.0,

    pub fn update(self: *Motor, voltage: f32, dt: f32) f32 {
        const effective_moi = self._moment_of_inertia / (self.gear_ratio * self.gear_ratio);

        const numerator = voltage * self.kv - self.motor_speed;
        const denominator = (144 * self.kv * self.kv * effective_moi) / self.stall_torque;

        const angular_acceleration = numerator / denominator;

        self.motor_speed += angular_acceleration * dt;
        self.position += (self.motor_speed / self.gear_ratio) * dt;

        if (self.drive_broke()) {
            self.reset_motor();
        }

        return self.motor_speed;
    }

    pub fn reset_motor(self: *Motor) void {
        self.motor_speed = 0.0;
        self.position = 0.0;
    }

    pub fn drive_broke(self: *Motor) bool {
        return std.math.isNan(self.motor_speed) or std.math.isInf(self.motor_speed) or std.math.isNan(self.position) or std.math.isInf(self.position);
    }
};

const PIDController = struct {
    kp: f32,
    ki: f32,
    kd: f32,
    integral: f32,
    previous_error: f32,

    pub fn init(kp: f32, ki: f32, kd: f32) PIDController {
        return PIDController{
            .kp = kp,
            .ki = ki,
            .kd = kd,
            .integral = 0.0,
            .previous_error = 0.0,
        };
    }

    pub fn update(self: *PIDController, target_speed: f32, current_speed: f32, dt: f32) f32 {
        const targetError = target_speed - current_speed;

        // Proportional term
        const proportional = self.kp * targetError;

        // Integral term
        self.integral += targetError * dt;
        const integral = self.ki * self.integral;

        // Derivative term
        const derivative = self.kd * (targetError - self.previous_error) / dt;
        self.previous_error = targetError;

        return proportional + integral + derivative;
    }

    pub fn updateMotorLoop(self: *PIDController, motor: *Motor, target_position: f32, dt: f32) void {
        const targetError = target_position - motor.position;

        // Proportional term
        const proportional = self.kp * targetError;

        // Integral term
        self.integral += targetError * dt;
        const integral = self.ki * self.integral;

        // Derivative term
        const derivative = self.kd * (targetError - self.previous_error) / dt;
        self.previous_error = targetError;

        var voltage = proportional + integral + derivative;

        if (voltage > 12) {
            voltage = 12;
        } else if (voltage < -12) {
            voltage = -12;
        }

        _ = motor.update(voltage, dt);
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
    var elevatorCarraige = Mechanism{ .pose = .{ .x = 30 * scaleValue, .y = 4 * scaleValue }, .pivot = .{ .x = -1.5 * scaleValue, .y = (10) * scaleValue }, .angle = 0, .length = 20 * scaleValue, .width = 6 * scaleValue, .color = .gray };
    var elevator = ElevatorMech{ .elevatorCariage = &elevatorCarraige, .elevatorSlide = &elevatorSlide, .elevatorUpright = &elevatorUpright };

    var elevatorMotor = Motor{};
    var elevatorPid = PIDController.init(5, 0.0, 0.5);

    var elevatorArm = Mechanism{ .pose = .{ .x = 33 * scaleValue, .y = 14 * scaleValue }, .pivot = .{ .x = 0, .y = (-30.0 / 2.0) * scaleValue }, .angle = 0, .length = 30 * scaleValue, .width = 2 * scaleValue, .color = .red };
    var armMotor = Motor{ .gear_ratio = 10 };
    var armPid = PIDController.init(5, 0.0, 0.5);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        var TargetPosition: f32 = 75;
        var TargetAngle: f32 = 0;

        if (rl.isKeyDown(.one)) {
            TargetPosition = 70;
            TargetAngle = 25;
        } else if (rl.isKeyDown(.two)) {
            TargetPosition = 40;
            TargetAngle = 25;
        } else if (rl.isKeyDown(.three)) {
            TargetPosition = 0;
            TargetAngle = 40;
        }

        elevatorPid.updateMotorLoop(&elevatorMotor, TargetPosition, rl.getFrameTime());

        try elevator.setElevatorHeight(elevatorMotor.position);

        elevatorArm.pose.y = elevator.elevatorCariage.pose.y + (20 * scaleValue);

        armPid.updateMotorLoop(&armMotor, TargetAngle, rl.getFrameTime());

        elevatorArm.angle = -armMotor.position;

        drawMechanism(&elevatorArm);

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
