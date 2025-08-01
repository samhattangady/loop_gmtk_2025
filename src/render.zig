const std = @import("std");
const c = @import("interface.zig");
const haathi_lib = @import("haathi.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
const MouseState = @import("inputs.zig").MouseState;
const SCREEN_SIZE = @import("haathi.zig").SCREEN_SIZE;
const CursorStyle = @import("haathi.zig").CursorStyle;
const serializer = @import("serializer.zig");

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec2i = helpers.Vec2i;
const Vec4 = helpers.Vec4;
const Rect = helpers.Rect;
const Button = helpers.Button;
const TextLine = helpers.TextLine;
const Orientation = helpers.Orientation;
const ConstIndexArray = helpers.ConstIndexArray;
const ConstKey = helpers.ConstKey;
const FONTS = haathi_lib.FONTS;

const build_options = @import("build_options");
const BUILDER_MODE = build_options.builder_mode;
const WORLD_SIZE = SCREEN_SIZE;
const WORLD_OFFSET = Vec2{};
const Game = @import("loop.zig").Game;

pub const CURSOR = "img/kenney_cursors/cursor_none.png";
pub const CURSOR_HAND = "img/kenney_cursors/hand_thin_open.png";
pub const CURSOR_HAND_CLOSE = "img/kenney_cursors/hand_thin_closed.png";
pub const bg_color = colors.solarized_base3;

pub fn renderGame(self: *Game) void {
    // background
    self.haathi.drawRect(.{
        .position = .{},
        .size = WORLD_SIZE,
        .color = bg_color,
    });
    {
        const text = std.fmt.allocPrintZ(self.haathi.arena, "{d}", .{self.score}) catch unreachable;
        self.haathi.drawText(.{
            .text = text,
            .position = WORLD_SIZE.scaleVec2(.{ .x = 0.88, .y = 0.85 }),
            .color = colors.solarized_base03.alpha(0.2),
            .style = FONTS[2],
        });
    }
    for (self.zones.items) |zone| {
        if (zone.hidden) continue;
        self.haathi.drawRect(.{
            .position = zone.rect.position,
            .size = zone.rect.size,
            .color = colors.solarized_base0.alpha(0.3),
        });
        self.haathi.drawText(.{
            .text = zone.name,
            .position = zone.rect.center(),
            .color = colors.solarized_base03.alpha(0.8),
        });
        if (!zone.is_consumer and zone.available < 100000) {
            const text = std.fmt.allocPrintZ(self.haathi.arena, "{d} {s}", .{ zone.available, @tagName(zone.material) }) catch unreachable;
            self.haathi.drawText(.{
                .text = text,
                .position = zone.rect.center().add(.{ .y = -25 }),
                .color = colors.solarized_base03.alpha(0.8),
            });
        }
        if (zone.show_count) {
            const text = std.fmt.allocPrintZ(self.haathi.arena, "{d} {s}", .{ zone.count, @tagName(zone.material) }) catch unreachable;
            self.haathi.drawText(.{
                .text = text,
                .position = zone.rect.center().add(.{ .y = -25 }),
                .color = colors.solarized_base03.alpha(0.8),
            });
        } else if (zone.is_consumer) {
            const text = std.fmt.allocPrintZ(self.haathi.arena, "deliver {s} here", .{@tagName(zone.material)}) catch unreachable;
            self.haathi.drawText(.{
                .text = text,
                .position = zone.rect.center().add(.{ .y = -25 }),
                .color = colors.solarized_base03.alpha(0.8),
            });
        }
    }
    const line_width = 8;
    const arrow_point = 3;
    const arrow_len = 12;
    for (self.buttons.items) |btn| {
        const alpha: f32 = if (btn.hovered or !btn.enabled) 0.4 else 1.0;
        const color = colors.solarized_base03.alpha(alpha);
        self.haathi.drawRect(.{
            .position = btn.rect.position,
            .size = btn.rect.size,
            .color = color,
            .radius = 5,
        });
        const text_alpha: f32 = if (!btn.enabled) 0.4 else 1.0;
        self.haathi.drawText(.{
            .position = btn.rect.center().add(.{ .y = -8 }),
            .text = btn.text,
            .color = bg_color.alpha(text_alpha),
            .style = FONTS[1],
        });
        const text = std.fmt.allocPrintZ(self.haathi.arena, "{d}", .{btn.index}) catch unreachable;
        self.haathi.drawText(.{
            .position = btn.rect.center().add(.{ .x = btn.rect.size.x / 2 + 10, .y = -8 }),
            .text = text,
            .color = colors.solarized_base03,
            .style = FONTS[1],
        });
    }
    for (self.quests.items) |quest| {
        if (!quest.shown) continue;
        {
            const text_alpha: f32 = if (quest.completed) 0.4 else 1.0;
            const done = self.zones.items[quest.zone_count_index].count;
            const text = if (!quest.claimed) std.fmt.allocPrintZ(self.haathi.arena, "{s} : {d}/{d}", .{ quest.text, done, quest.reqd }) catch unreachable else quest.text;
            self.haathi.drawText(.{
                .position = quest.position,
                .text = text,
                .color = colors.solarized_base03.alpha(text_alpha),
                .style = FONTS[1],
                .alignment = .left,
            });
            if (quest.claimed) {
                self.haathi.drawLine(.{
                    .p0 = quest.position.add(.{ .y = 6 }),
                    .p1 = quest.position.add(.{ .x = 200, .y = 6 }),
                    .color = colors.solarized_base03.alpha(text_alpha),
                    .width = 3,
                });
            }
        }
        if (!quest.claimed) {
            const btn = quest.button;
            const alpha: f32 = if (btn.hovered or !btn.enabled) 0.4 else 1.0;
            const color = colors.solarized_base03.alpha(alpha);
            self.haathi.drawRect(.{
                .position = btn.rect.position,
                .size = btn.rect.size,
                .color = color,
                .radius = 5,
            });
            const text_alpha: f32 = if (!btn.enabled) 0.4 else 1.0;
            self.haathi.drawText(.{
                .position = btn.rect.center().add(.{ .y = -8 }),
                .text = btn.text,
                .color = bg_color.alpha(text_alpha),
                .style = FONTS[1],
            });
        }
    }
    for (self.points.items, 0..) |pt, i| {
        const j = if (i == self.points.items.len - 1) 0 else i + 1;
        const pt2 = self.points.items[j];
        {
            // triangle in the middle of the line
            const center = pt.position.lerp(pt2.position, 0.5);
            const direction = pt2.position.subtract(pt.position).normalize();
            const perp = direction.perpendicular().scale(line_width * 0.6);
            var path = self.haathi.arena.alloc(Vec2, 6) catch unreachable;
            path[0] = center.add(perp);
            path[1] = center.add(direction.scale(-arrow_point));
            path[2] = center.add(perp.scale(-1));
            path[3] = center.add(perp.scale(-1)).add(direction.scale(-arrow_len));
            path[4] = center.add(perp.scale(0)).add(direction.scale(-arrow_len)).add(direction.scale(-arrow_point));
            path[5] = center.add(perp.scale(1)).add(direction.scale(-arrow_len));
            self.haathi.drawPoly(.{ .points = path, .color = colors.solarized_base00.alpha(0.4) });
        }
    }
    for (self.movers.items) |mover| {
        const out_size = 25;
        const in_size = 20;
        if (false)
            self.haathi.drawRect(.{
                .position = mover.position,
                .size = .{ .x = out_size, .y = out_size },
                .color = colors.solarized_base03,
                .centered = true,
                .radius = out_size,
            });
        self.haathi.drawRect(.{
            .position = mover.position.add(.{ .y = -5 }),
            .size = .{ .x = in_size * 2, .y = in_size },
            .color = colors.solarized_base03.alpha(0.1),
            .centered = true,
            .radius = in_size,
        });
        const x_flipped = mover.position.x < mover.prev_position.x;
        self.haathi.drawSprite(.{
            .sprite = mover.getBaseSprite(),
            .scale = .{ .x = 1, .y = 1 },
            .position = mover.position.add(.{ .x = -32, .y = -10 }),
            .x_flipped = x_flipped,
        });
        if (mover.carrying) |mat| {
            const extra, const offset = mover.getExtraSprite(mat);
            if (extra) |spr| {
                self.haathi.drawSprite(.{
                    .sprite = spr,
                    .scale = .{ .x = 1, .y = 1 },
                    .position = mover.position.add(.{ .x = -32, .y = -10 }).add(offset),
                    .x_flipped = x_flipped,
                });
            }
            self.haathi.drawSprite(.{
                .sprite = mover.getCarryingSprite(mat),
                .scale = .{ .x = 1, .y = 1 },
                .position = mover.position.add(.{ .x = -32, .y = -10 }),
                .x_flipped = x_flipped,
            });
        }
    }
    const cursor = if (self.hovered_point == null) CURSOR else if (self.haathi.inputs.mouse.l_button.is_down) CURSOR_HAND_CLOSE else CURSOR_HAND;
    self.haathi.drawSprite(.{
        .sprite = .{
            .path = cursor,
            .anchor = .{},
            .size = .{ .x = 64, .y = 64 },
        },
        .scale = .{ .x = 0.5, .y = 0.5 },
        .position = self.haathi.inputs.mouse.current_pos.add(.{ .y = -32 }),
    });
}
