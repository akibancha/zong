// raylib-zig (c) Nikolas Wipper 2023

const rl = @import("raylib");
const std = @import("std");

const screen_width = 1280;
const screen_height = 720;

const MoveBar = enum { up, down };
const Player = enum { one, two };

fn createScoreNums(score_in: u16) [3]u16 {
    var score = score_in;
    var score_nums: [3]u16 = [3]u16{ 0, 0, 0 };
    if (score >= 100) {
        score_nums[0] = score / 100;
        score -= score_nums[0] * 100;
    }
    if (score >= 10) {
        score_nums[1] = score / 10;
        score -= score_nums[1] * 10;
    }
    score_nums[2] = score;
    return score_nums;
}

const Particle = struct {
    pos: rl.Vector2,
    size: rl.Vector2,
    vel: rl.Vector2,
    lifetime: u16,
    part_of: *Game,

    pub fn init(
        pos_x: f32,
        pos_y: f32,
        height: f32,
        width: f32,
        vel_x: f32,
        vel_y: f32,
        lifetime: u16,
        part_of: *Game,
    ) Particle {
        return Particle{
            .pos = rl.Vector2.init(pos_x, pos_y),
            .size = rl.Vector2.init(width, height),
            .vel = rl.Vector2.init(vel_x, vel_y),
            .lifetime = lifetime,
            .part_of = part_of,
        };
    }

    fn draw(self: *Particle) void {
        rl.drawRectangleV(self.pos, self.size, rl.Color.red);
    }

    pub fn update(self: *Particle) bool {
        self.size.x -= self.size.x / @as(f32, @floatFromInt(self.lifetime));
        self.size.y -= self.size.y / @as(f32, @floatFromInt(self.lifetime));
        self.lifetime -= 1;
        self.pos.x += self.vel.x * 0.3;
        self.pos.y += self.vel.y * 0.3;
        self.draw();
        if (self.lifetime <= 0) {
            return false;
        }
        return true;
    }
};

const Ball = struct {
    pos: rl.Vector2,
    size: rl.Vector2,
    vel: rl.Vector2,
    part_of: *Game,

    pub fn init(
        x: f32,
        y: f32,
        size: f32,
        vel: f32,
        part_of: *Game,
    ) Ball {
        return Ball{
            .pos = rl.Vector2.init(x, y),
            .size = rl.Vector2.init(size, size),
            .vel = rl.Vector2.init(vel, vel),
            .part_of = part_of,
        };
    }

    fn move(self: *Ball) void {
        self.pos.x += self.vel.x;
        self.pos.y += self.vel.y;
    }

    fn checkYCol(self: *Ball) !void {
        if (self.pos.y <= 32) {
            self.vel.y *= -1;
            for (0..6) |p| {
                try self.part_of.particles.append(Particle.init(
                    self.part_of.ball.pos.x + @as(f32, @floatFromInt(p)) - 4.0 * @as(f32, @floatFromInt(p)),
                    self.part_of.ball.pos.y + @as(f32, @floatFromInt(p)) + 4.0 * @as(f32, @floatFromInt(p)),
                    16,
                    16,
                    self.part_of.ball.vel.x,
                    self.part_of.ball.vel.y * -1,
                    15,
                    self.part_of,
                ));
            }
        }
        if (self.pos.y + self.size.y >= screen_height) {
            self.vel.y *= -1;
            for (0..6) |p| {
                try self.part_of.particles.append(Particle.init(
                    self.part_of.ball.pos.x + @as(f32, @floatFromInt(p)) - 4.0 * @as(f32, @floatFromInt(p)),
                    self.part_of.ball.pos.y + @as(f32, @floatFromInt(p)) + 4.0 * @as(f32, @floatFromInt(p)),
                    16,
                    16,
                    self.part_of.ball.vel.x * -1,
                    self.part_of.ball.vel.y,
                    15,
                    self.part_of,
                ));
            }
        }
    }

    fn checkXCol(self: *Ball) void {
        if (self.pos.x < self.part_of.bar_p1.pos.x) {
            self.pos.x = screen_width / 2;
            self.pos.y = screen_height / 2;
            self.vel.x *= -1;
            self.part_of.score_p2 += 1;
        }
        if (self.pos.x + self.size.x > self.part_of.bar_p2.pos.x + self.part_of.bar_p2.size.x) {
            self.pos.x = screen_width / 2;
            self.pos.y = screen_height / 2;
            self.vel.x *= -1;
            self.part_of.score_p1 += 1;
        }
    }

    fn addPart(self: *Ball) !void {
        try self.part_of.particles.append(Particle.init(
            self.pos.x,
            self.pos.y,
            16,
            16,
            self.vel.x,
            self.vel.y,
            10,
            self.part_of,
        ));
    }

    fn draw(self: *Ball) void {
        rl.drawRectangleV(self.pos, self.size, rl.Color.white);
    }

    pub fn update(self: *Ball) !void {
        try self.addPart();
        self.move();
        try self.checkYCol();
        self.checkXCol();
        self.draw();
    }
};

const Bar = struct {
    pos: rl.Vector2,
    size: rl.Vector2,
    part_of: *Game,
    owner: Player,

    pub fn init(
        pos_x: f32,
        pos_y: f32,
        width: f32,
        height: f32,
        part_of: *Game,
        owner: Player,
    ) Bar {
        return Bar{
            .pos = rl.Vector2.init(pos_x, pos_y),
            .size = rl.Vector2.init(width, height),
            .part_of = part_of,
            .owner = owner,
        };
    }

    fn checkBallCol(self: *Bar) void {
        if (self.part_of.ball.pos.x >= self.pos.x and
            self.part_of.ball.pos.x <= self.pos.x + self.size.x and
            self.part_of.ball.pos.y >= self.pos.y and
            self.part_of.ball.pos.y <= self.pos.y + self.size.y)
        {
            self.part_of.ball.vel.x *= -1;
            self.part_of.ball.vel.y *= -1;
        }
    }

    fn move(self: *Bar, dir: MoveBar) void {
        switch (dir) {
            .up => {
                if (self.pos.y - 16 > 33)
                    self.pos.y -= 16;
            },
            .down => {
                if (self.pos.y + 16 + self.size.y < screen_height)
                    self.pos.y += 16;
            },
        }
    }

    fn handleInput(self: *Bar) void {
        switch (self.owner) {
            .one => {
                if (rl.isKeyDown(rl.KeyboardKey.key_q)) {
                    self.move(MoveBar.up);
                }
                if (rl.isKeyDown(rl.KeyboardKey.key_w)) {
                    self.move(MoveBar.down);
                }
            },
            .two => {
                if (rl.isKeyDown(rl.KeyboardKey.key_i)) {
                    self.move(MoveBar.up);
                }
                if (rl.isKeyDown(rl.KeyboardKey.key_o)) {
                    self.move(MoveBar.down);
                }
            },
        }
    }

    fn draw(self: *Bar) void {
        rl.drawRectangleV(self.pos, self.size, rl.Color.white);
    }

    pub fn update(self: *Bar) void {
        self.handleInput();
        self.checkBallCol();
        self.draw();
    }
};

const Game = struct {
    ball: Ball,
    score_p1: u16,
    score_p2: u16,
    bar_p1: Bar,
    bar_p2: Bar,
    particles: std.ArrayList(Particle),
    allocater: std.mem.Allocator,

    pub fn init(alloactor: std.mem.Allocator) Game {
        return Game{
            .ball = undefined,
            .score_p1 = 0,
            .score_p2 = 0,
            .bar_p1 = undefined,
            .bar_p2 = undefined,
            .particles = undefined,
            .allocater = alloactor,
        };
    }

    pub fn registerGameElements(self: *Game) void {
        self.ball = Ball.init(screen_width / 2, screen_height / 2, 16, 8, self);
        self.bar_p1 = Bar.init(32, 45, 16, 160, self, Player.one);
        self.bar_p2 = Bar.init(screen_width - 48, 45, 16, 160, self, Player.two);
        self.particles = std.ArrayList(Particle).init(self.allocater);
    }

    fn drawScores(self: *Game) !void {
        var buffer: [10]u8 = undefined;
        const score_p1_nums = createScoreNums(self.score_p1);
        const str_score_p1 = try std.fmt.bufPrintZ(&buffer, "{}{}{}", .{ score_p1_nums[0], score_p1_nums[1], score_p1_nums[2] });
        rl.drawText(str_score_p1, 4, 12, 24, rl.Color.white);
        const score_p2_nums = createScoreNums(self.score_p2);
        const str_score_p2 = try std.fmt.bufPrintZ(&buffer, "{}{}{}", .{ score_p2_nums[0], score_p2_nums[1], score_p2_nums[2] });
        rl.drawText(str_score_p2, screen_width - 3 * 15, 12, 24, rl.Color.white);
    }

    pub fn update(self: *Game) !void {
        rl.clearBackground(rl.Color.black);
        rl.drawRectangle(0, 32, screen_width, 2, rl.Color.white);
        try self.drawScores();
        self.bar_p1.update();
        self.bar_p2.update();
        try self.ball.update();
        var index = self.particles.items.len;
        while (index > 0) {
            index -= 1;
            var p = self.particles.swapRemove(index);
            const is_alive = p.update();
            if (is_alive) {
                try self.particles.append(p);
            }
        }
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var game = Game.init(allocator);
    game.registerGameElements();
    defer game.particles.deinit();

    rl.initWindow(screen_width, screen_height, "Wannabe Pong - Zong");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        try game.update();
    }
}
