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
const BORDER = 10;

const POP_SOUNDS = [_][]const u8{
    "audio/pop1.mp3",
    "audio/pop2.mp3",
    "audio/pop3.mp3",
    "audio/pop4.mp3",
    "audio/pop5.mp3",
};
const CLICK_SOUNDS = [_][]const u8{
    "audio/click_down_1.mp3",
    "audio/click_down_2.mp3",
    "audio/click_down_3.mp3",
};

const ALL_SPRITES = [_][]const u8{
    "img/bg.png",
    "img/sets.png",
    "img/bdg1.png",
    "img/bdg2.png",
    "img/bdg3.png",
    "img/bdg4.png",
    "img/bdg5.png",
    "img/digger.png",
    "img/material.png",
    "img/carrier.png",
    "img/builder.png",
};

// TODO (23 Jul 2024 sam): lol
const NUMBER_STR = [_][]const u8{ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32", "33", "34", "35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "47", "48", "49" };

const LANES_MAX_COUNT = 10;
const MINER_MAX_TARGET_SLOTS = 10;
const MINER_MAX_COUNT = 100;
const STORAGE_MAX_SIZE = 100;
const STORAGE_PER_ROW = 10;
const ANIM_MAX_COUNT = 256;
const CARRIERS_PER_LANE = 3;
const BUILDER_PER_LANE = 2;

const MINER_0_POSITION = Vec2{ .x = 801, .y = 89 };
const MINER_LAST_POSITION = Vec2{ .x = 1167, .y = 89 };
const BUILDER0_POSITION = Vec2{ .x = 809, .y = 418 };
const BUILDER_LAST_POSITION = Vec2{ .x = 1154, .y = 418 };
const MINER_OFFSET = Vec2{ .x = (MINER_LAST_POSITION.x - MINER_0_POSITION.x) / 9 };
const BUILDER_OFFSET = Vec2{ .x = (BUILDER_LAST_POSITION.x - BUILDER0_POSITION.x) / 9 };
const LANE_OFFSET = Vec2{ .x = (SCREEN_SIZE.x * 0.45) / (LANES_MAX_COUNT + 1) };
const STORAGE_SLOT = Vec2{ .x = 847, .y = 195 };
const BASE_STORAGE_SLOT = Vec2{ .x = 805, .y = 331 };
const STORAGE_ROW = Vec2{ .y = 30 };
const STORAGE_LANE = Vec2{ .x = 29 };
const CARRIER_SLOT = Vec2{ .x = 768, .y = 212 };
const CARRIER_LANE = Vec2{ .x = SCREEN_SIZE.x * 0.4 / (LANES_MAX_COUNT + 1) };
const CARRIER_OFFSET = Vec2{ .x = 20 };
const CARRIER_DROPOFF_SLOT = Vec2{ .x = 844, .y = 319 };
const CARRIER_DROPOFF_LANE = Vec2{ .x = SCREEN_SIZE.x * 0.2 / (LANES_MAX_COUNT + 1) };
const CARRIER_DROPOFF_OFFSET = Vec2{ .x = 20 };

const UPGRADE_SCORE_MULTIPLIER = 8;
const NUM_UPGRADE_LEVELS = 30;

const CARRIER_TIMER = 150;
const BUILDER_TIMER = 90;
const MINER_TIMER = 90;

const UPGRADE_COSTS = @import("upgrade_costs.zig").UPGRADE_COSTS;
const TechUpgrade = struct {
    score: usize,
    unlock: ButtonAction,
    text: []const u8,
    subtext: []const u8,
    msg_index: u8,
};
const TECH_UPGRADES = [_]TechUpgrade{
    .{
        .score = 500,
        .unlock = .carrier_speedup,
        .text = "Consult the Golem Union",
        .subtext = "Golems are known for their ability to transport items",
        .msg_index = 3,
    },
    .{
        .score = 1000,
        .unlock = .builder_speedup,
        .text = "Consult the Masons Organization",
        .subtext = "The Masons have technology to increase the speed of building.",
        .msg_index = 4,
    },
    .{
        .score = 2000,
        .unlock = .carrier_strength,
        .text = "Consult the Blacksmith",
        .subtext = "The Blacksmith can allow carriers to carry more material at a time.",
        .msg_index = 5,
    },
    .{
        .score = 3000,
        .unlock = .resource_upgrade,
        .text = "Consult the Alchemist Guild",
        .subtext = "The Alchemists will have techniques for our material to be more valuable",
        .msg_index = 6,
    },
    .{
        .score = 7500,
        .unlock = .miner_speedup,
        .text = "Consult the Dwarven Court",
        .subtext = "The Dwarves will know how to dig faster.",
        .msg_index = 7,
    },
    .{
        .score = 40000,
        .unlock = .anim_speedup,
        .text = "Consult the Fairy Queendom",
        .subtext = "The Fairies will know how to transport material faster.",
        .msg_index = 8,
    },
    .{
        .score = 75000,
        .unlock = .rep_mult_increase,
        .text = "Consult the Elvish High Council",
        .subtext = "The Elves will allow our monument to gain reputation faster.",
        .msg_index = 9,
    },
    .{
        .score = 10000000,
        .unlock = .complete_game,
        .text = "Prepare for Opening",
        .subtext = "The Monument is almost complete",
        .msg_index = 10,
    },
};

const MESSAGES = [12][]const []const u8{
    &.{
        "We are driven by a compulsion to build",
        "We are driven by a compulsion to build",
        "And so we build",
        "Recruit Diggers to dig for building material",
    },
    &.{
        "Recruit Carriers to carry material to the building site",
    },
    &.{
        "Recruit Builders to build our monument",
    },
    &.{
        "The Golems feel compelled by our cause",
        "They grant us the technology to speed up our carriers",
        "And so we build.",
    },
    &.{
        "The Masons feel compelled by our cause",
        "They grant us the technology to speed up our building",
        "And so we build.",
    },
    &.{
        "The Blacksmith feel compelled by our cause",
        "They grant us the technology to carry more",
        "And so we build.",
    },
    &.{
        "The Alchemists feel compelled by our cause",
        "They allow us to make our material more valuable",
        "And so we build.",
    },
    &.{
        "The Dwarves feel compelled by our cause",
        "They grant us the technology to dig faster",
        "And so we build.",
    },
    &.{
        "The Fairies feel compelled by our cause",
        "They grant us the technology to speed up material transfer",
        "And so we build.",
    },
    &.{
        "The Elves feel compelled by our cause",
        "They grant us the technology to make building more valuable",
        "And so we build.",
    },
    &.{
        "The Monument is ready to be completed.",
        "There is just one final step that remains.",
        "And so we build.",
    },
    &.{
        "We have completed building this monument.",
        "We did not build this monument for any religion",
        "Not for any country or any person.",
        "We built this monument for the joy of building.",
        "Building gives us purpose and meaning.",
        "Aspiring to build great things brings us all together",
        "All the land has felt compelled by our cause.",
        "We create meaning and purpose through the act of building",
        "And there is nothing more sacred and noble",
        "And so we build.",
        "Thank you for playing.",
        "I look forward to see what you will build",
    },
};

// World has origin at the center, x-right, y-up.
// Screen has origin at bottomleft, x-right, y-up
const World = struct {
    size: Vec2 = WORLD_SIZE,
    offset: Vec2 = WORLD_OFFSET,
    center: Vec2 = WORLD_OFFSET.add(WORLD_SIZE.scale(0.5)),

    pub fn init(allocator: std.mem.Allocator) World {
        _ = allocator;
        return .{};
    }

    pub fn setup(self: *World) void {
        _ = self;
    }

    pub fn deinit(self: *World) void {
        _ = self;
    }

    pub fn clear(self: *World) void {
        _ = self;
    }

    pub fn worldToScreen(self: *const World, position: Vec2) Vec2 {
        return position.add(self.center);
    }

    pub fn screenToWorld(self: *const World, position: Vec2) Vec2 {
        return position.subtract(self.center);
    }
};

pub const Mountain = struct {
    mass: usize = 1000000,
};

const ResType = enum {
    none,
    reserved,
    stone,
    ore,
    ore2,
    ore3,
    ore4,

    fn score(self: ResType) usize {
        return switch (self) {
            .none, .reserved => 0,
            .stone => 9,
            .ore => 9 * UPGRADE_SCORE_MULTIPLIER,
            .ore2 => 9 * (std.math.powi(usize, UPGRADE_SCORE_MULTIPLIER, 2) catch unreachable),
            .ore3 => 9 * (std.math.powi(usize, UPGRADE_SCORE_MULTIPLIER, 3) catch unreachable),
            .ore4 => 9 * (std.math.powi(usize, UPGRADE_SCORE_MULTIPLIER, 4) catch unreachable),
        };
    }
    fn upgrade(self: ResType) ResType {
        return switch (self) {
            .none, .reserved => .none,
            .stone => .ore,
            .ore => .ore2,
            .ore2 => .ore3,
            .ore3 => .ore4,
            .ore4 => .ore4,
        };
    }
    fn color(self: ResType) Vec4 {
        return switch (self) {
            .none, .reserved => .{},
            .stone => colors.apollo_dark_1,
            .ore => colors.apollo_dark_2,
            .ore2 => colors.apollo_dark_3,
            .ore3 => colors.apollo_dark_4,
            .ore4 => colors.apollo_dark_5,
        };
    }
};

pub const Storage = struct {
    num_rows: usize = 1,
    storage: [STORAGE_MAX_SIZE]ResType = [_]ResType{.none} ** STORAGE_MAX_SIZE,
};

pub const Miner = struct {
    timer: u8,
};

pub const Builder = struct {
    timer: u8,
    reserved: bool = false,
};

pub const Carrier = struct {
    timer: u16,
    state: enum {
        waiting,
        carrying,
        delivering,
        returning,
    } = .waiting,
    res: [10]ResType = [_]ResType{.none} ** 10,

    pub fn numFull(self: *Carrier) u8 {
        var count: u8 = 0;
        for (self.res) |res| {
            if (res != .none) count += 1;
        }
        return count;
    }
    pub fn numCarried(self: *Carrier) u8 {
        var count: u8 = 0;
        for (self.res) |res| {
            if (res != .none and res != .reserved) count += 1;
        }
        return count;
    }
    pub fn numReserved(self: *Carrier) u8 {
        var count: u8 = 0;
        for (self.res) |res| {
            if (res == .reserved) count += 1;
        }
        return count;
    }
};

const AnimData = union(enum) {
    none: void,
    miner: struct {
        mine_index: u8,
        storage_index: u8,
    },
    carrier_pickup: struct {
        carrier_index: u8,
        storage_index: u8,
        carrier_slot_index: u8,
    },
    carrier_dropoff: struct {
        carrier_index: u8,
        storage_index: u8,
        carrier_slot_index: u8,
    },
    builder: struct {
        builder_index: u8,
        storage_index: u8,
    },
};

pub const Animation = struct {
    data: AnimData,
    start_step: u32,
    res: ResType,
};

const ButtonAction = enum {
    miner_recruit,
    carrier_recruit,
    builder_recruit,
    miner_speedup,
    carrier_speedup,
    builder_speedup,
    carrier_strength,
    resource_upgrade,
    anim_speedup,
    rep_mult_increase,
    complete_game,
    //mine_storage_add_row,
    //base_storage_add_row,
};
const NUM_ACTIONS = @typeInfo(ButtonAction).Enum.fields.len;

const UpgradeButton = struct {
    button: Button,
    cost: u64,
};

// gameStruct
pub const Game = struct {
    haathi: *Haathi,
    ticks: u32 = 0,
    steps: u32 = 0,
    world: World,
    ff_mode: bool = false,
    anim_steps: u16 = 37,
    load_page: bool = true,

    miners: std.ArrayList(Miner),
    carriers: std.ArrayList(Carrier),
    builders: std.ArrayList(Builder),
    // TODO (20 Sep 2024 sam): make this some kind of ring buffer
    animations: std.ArrayList(Animation),
    buttons: std.ArrayList(UpgradeButton),
    tech_buttons: std.ArrayList(UpgradeButton),
    mountain: Mountain = .{},
    mine_storage: Storage = .{},
    base_storage: Storage = .{},
    miner_timer: u8 = MINER_TIMER,
    carrier_timer: u16 = CARRIER_TIMER,
    builder_timer: u8 = BUILDER_TIMER,
    miner_strength: u8 = 1,
    carrier_capacity: u8 = 2,
    rep_mult: u64 = 1,
    miner_ore: ResType = .stone,
    score: u64 = 10,
    points: u64 = 10,
    score_display: u64 = 0,
    points_display: u64 = 0,
    levels: [NUM_ACTIONS]u8 = [_]u8{0} ** NUM_ACTIONS,
    unlocked: [NUM_ACTIONS]bool = [_]bool{false} ** NUM_ACTIONS,
    tech_index: u8 = 0,
    show_message: bool = true,
    message_index: u8 = 0,
    message_subindex: u8 = 0,
    palace_completion: u8 = 0,
    building_complete: bool = false,
    pops_queued: u8 = 0,

    xosh: std.Random.Xoshiro256,
    rng: std.Random = undefined,
    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub const serialize_fields = [_][]const u8{
        "ticks",
        "steps",
        "world",
        "miners",
        "carriers",
        "builders",
        "mine_storage",
        "base_storage",
        "animations",
        "score",
    };

    pub fn init(haathi: *Haathi) Game {
        // // TODO (19 Sep 2024 sam): load sounds and images
        haathi.loadSound("audio/pop1.mp3", false);
        haathi.loadSound("audio/pop2.mp3", false);
        haathi.loadSound("audio/pop3.mp3", false);
        haathi.loadSound("audio/pop4.mp3", false);
        haathi.loadSound("audio/pop5.mp3", false);
        haathi.loadSound("audio/click_down_1.mp3", false);
        haathi.loadSound("audio/click_down_2.mp3", false);
        haathi.loadSound("audio/click_down_3.mp3", false);
        for (ALL_SPRITES) |path| haathi.loadSpriteMap(path);
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const world = World.init(haathi.allocator);
        return .{
            .haathi = haathi,
            .xosh = std.Random.Xoshiro256.init(0),
            .world = world,
            .miners = std.ArrayList(Miner).initCapacity(allocator, MINER_MAX_COUNT) catch unreachable,
            .carriers = std.ArrayList(Carrier).initCapacity(allocator, CARRIERS_PER_LANE * LANES_MAX_COUNT) catch unreachable,
            .builders = std.ArrayList(Builder).initCapacity(allocator, BUILDER_PER_LANE * LANES_MAX_COUNT) catch unreachable,
            .animations = std.ArrayList(Animation).initCapacity(allocator, ANIM_MAX_COUNT) catch unreachable,
            .buttons = std.ArrayList(UpgradeButton).initCapacity(allocator, 32) catch unreachable,
            .tech_buttons = std.ArrayList(UpgradeButton).initCapacity(allocator, 8) catch unreachable,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
    }

    pub fn deinit(self: *Game) void {
        self.world.deinit();
        self.miners.deinit();
        self.animations.deinit();
        self.carriers.deinit();
    }

    fn clear(self: *Game) void {
        self.world.clear();
    }

    fn reset(self: *Game) void {
        self.clear();
        self.setup();
    }

    pub fn setup(self: *Game) void {
        self.rng = self.xosh.random();
        self.unlocked[@intFromEnum(ButtonAction.miner_recruit)] = true;
        if (false) {
            for (&self.unlocked) |*unl| unl.* = true;
            self.checkTechUpgrades();
        }
        self.resetButtons();
    }

    pub fn resetButtons(self: *Game) void {
        self.buttons.clearRetainingCapacity();
        if (self.unlocked[@intFromEnum(ButtonAction.miner_recruit)])
            self.buttons.appendAssumeCapacity(.{
                .button = .{
                    .rect = .{
                        .position = .{ .x = 50, .y = 60 },
                        .size = .{ .x = 260, .y = 60 },
                    },
                    .value = @intFromEnum(ButtonAction.miner_recruit),
                    .text = "Recruit Digger",
                },
                .cost = 0,
            });
        if (self.unlocked[@intFromEnum(ButtonAction.miner_speedup)])
            self.buttons.appendAssumeCapacity(.{
                .button = .{
                    .rect = .{
                        .position = .{ .x = 330, .y = 60 },
                        .size = .{ .x = 260, .y = 60 },
                    },
                    .value = @intFromEnum(ButtonAction.miner_speedup),
                    .text = "Digger Speedup",
                },
                .cost = 0,
            });
        // self.buttons.appendAssumeCapacity(.{
        //     .rect = .{
        //         .position = .{ .x = 350, .y = 30 },
        //         .size = .{ .x = 150, .y = 26 },
        //     },
        //     .value = @intFromEnum(ButtonAction.mine_storage_add_row),
        //     .text = "Storage Add Row",
        // });
        if (self.unlocked[@intFromEnum(ButtonAction.carrier_recruit)])
            self.buttons.appendAssumeCapacity(.{
                .button = .{
                    .rect = .{
                        .position = .{ .x = 50, .y = 140 },
                        .size = .{ .x = 260, .y = 60 },
                    },
                    .value = @intFromEnum(ButtonAction.carrier_recruit),
                    .text = "Recruit Carrier",
                },
                .cost = 0,
            });
        if (self.unlocked[@intFromEnum(ButtonAction.carrier_speedup)])
            self.buttons.appendAssumeCapacity(.{
                .button = .{
                    .rect = .{
                        .position = .{ .x = 330, .y = 140 },
                        .size = .{ .x = 260, .y = 60 },
                    },
                    .value = @intFromEnum(ButtonAction.carrier_speedup),
                    .text = "Carrier Speedup",
                },
                .cost = 0,
            });
        if (self.unlocked[@intFromEnum(ButtonAction.carrier_strength)])
            self.buttons.appendAssumeCapacity(.{
                .button = .{
                    .rect = .{
                        .position = .{ .x = 50, .y = 220 },
                        .size = .{ .x = 260, .y = 60 },
                    },
                    .value = @intFromEnum(ButtonAction.carrier_strength),
                    .text = "Carrier Strength",
                },
                .cost = 0,
            });
        if (self.unlocked[@intFromEnum(ButtonAction.builder_recruit)])
            self.buttons.appendAssumeCapacity(.{
                .button = .{
                    .rect = .{
                        .position = .{ .x = 50, .y = 300 },
                        .size = .{ .x = 260, .y = 60 },
                    },
                    .value = @intFromEnum(ButtonAction.builder_recruit),
                    .text = "Recruit Builder",
                },
                .cost = 0,
            });
        if (self.unlocked[@intFromEnum(ButtonAction.builder_speedup)])
            self.buttons.appendAssumeCapacity(.{
                .button = .{
                    .rect = .{
                        .position = .{ .x = 330, .y = 300 },
                        .size = .{ .x = 260, .y = 60 },
                    },
                    .value = @intFromEnum(ButtonAction.builder_speedup),
                    .text = "Builder Speedup",
                },
                .cost = 0,
            });
        if (self.unlocked[@intFromEnum(ButtonAction.resource_upgrade)])
            self.buttons.appendAssumeCapacity(.{
                .button = .{
                    .rect = .{
                        .position = .{ .x = 50, .y = 380 },
                        .size = .{ .x = 260, .y = 60 },
                    },
                    .value = @intFromEnum(ButtonAction.resource_upgrade),
                    .text = "Resource Alchemy",
                },
                .cost = 0,
            });
        if (self.unlocked[@intFromEnum(ButtonAction.anim_speedup)])
            self.buttons.appendAssumeCapacity(.{
                .button = .{
                    .rect = .{
                        .position = .{ .x = 330, .y = 380 },
                        .size = .{ .x = 260, .y = 60 },
                    },
                    .value = @intFromEnum(ButtonAction.anim_speedup),
                    .text = "Fairy Magic",
                },
                .cost = 0,
            });
        if (self.unlocked[@intFromEnum(ButtonAction.rep_mult_increase)])
            self.buttons.appendAssumeCapacity(.{
                .button = .{
                    .rect = .{
                        .position = .{ .x = 50, .y = 460 },
                        .size = .{ .x = 260, .y = 60 },
                    },
                    .value = @intFromEnum(ButtonAction.rep_mult_increase),
                    .text = "Elven Bonus",
                },
                .cost = 0,
            });
        if (self.unlocked[@intFromEnum(ButtonAction.complete_game)])
            self.buttons.appendAssumeCapacity(.{
                .button = .{
                    .rect = .{
                        .position = .{ .x = 330, .y = 460 },
                        .size = .{ .x = 260, .y = 60 },
                    },
                    .value = @intFromEnum(ButtonAction.complete_game),
                    .text = "Complete Construction",
                },
                .cost = 0,
            });
        for (0..NUM_ACTIONS) |i| self.setButtonCost(@enumFromInt(i));
    }

    pub fn saveGame(self: *Game) void {
        var stream = serializer.JsonStream.new(self.haathi.arena);
        var js = stream.serializer();
        js.beginObject() catch unreachable;
        serializer.serialize("game", self.*, &js) catch unreachable;
        js.endObject() catch unreachable;
        stream.webSave("save") catch unreachable;
    }

    pub fn loadGame(self: *Game) void {
        if (helpers.webLoad("save", self.haathi.arena)) |savefile| {
            const tree = std.json.parseFromSlice(std.json.Value, self.haathi.arena, savefile, .{}) catch |err| {
                helpers.debugPrint("parsing error {}\n", .{err});
                unreachable;
            };
            //self.sim.clearSim();
            serializer.deserialize("game", self, tree.value, .{ .allocator = self.haathi.allocator, .arena = self.haathi.arena });
            // self.resetMenu();
            // self.setupContextual();
        } else {
            helpers.debugPrint("no savefile found", .{});
        }
    }

    fn verify(self: *Game) void {
        // make sure that every reserved slot has a corresponding animation
        for (self.mine_storage.storage, 0..) |str, str_index| {
            if (str == .reserved) {
                var found = false;
                for (self.animations.items, 0..) |anim, anim_index| {
                    _ = anim_index;
                    switch (anim.data) {
                        .miner => |data| {
                            if (data.storage_index == str_index) {
                                found = true;
                                break;
                            }
                        },
                        else => {},
                    }
                }
                if (!found) helpers.debugPrint("{d}: mine_storage_slot_{d} has no animation.", .{ self.score, str_index });
            }
        }
        for (self.base_storage.storage, 0..) |str, str_index| {
            if (str == .reserved) {
                var found = false;
                for (self.animations.items, 0..) |anim, anim_index| {
                    _ = anim_index;
                    switch (anim.data) {
                        .carrier_dropoff => |data| {
                            if (data.storage_index == str_index) {
                                found = true;
                                break;
                            }
                        },
                        else => {},
                    }
                }
                if (!found) helpers.debugPrint("{d}: base_storage_slot_{d} has no animation.", .{ self.score, str_index });
            }
        }
    }

    fn doButtonAction(self: *Game, action: ButtonAction) void {
        self.levels[@intFromEnum(action)] += 1;
        self.setButtonCost(action);
        switch (action) {
            .miner_recruit => {
                self.miners.appendAssumeCapacity(.{ .timer = self.miner_timer });
                if (!self.unlocked[@intFromEnum(ButtonAction.carrier_recruit)]) {
                    self.message_index = 1;
                    self.message_subindex = 0;
                    self.show_message = true;
                    self.unlocked[@intFromEnum(ButtonAction.carrier_recruit)] = true;
                    self.resetButtons();
                }
            },
            .carrier_recruit => {
                self.carriers.appendAssumeCapacity(.{ .timer = 0, .state = .waiting });
                if (!self.unlocked[@intFromEnum(ButtonAction.builder_recruit)]) {
                    self.message_index = 2;
                    self.message_subindex = 0;
                    self.show_message = true;
                    self.unlocked[@intFromEnum(ButtonAction.builder_recruit)] = true;
                    self.resetButtons();
                }
            },
            .builder_recruit => {
                self.builders.appendAssumeCapacity(.{ .timer = 0 });
            },
            .carrier_speedup => {
                self.carrier_timer -= @divFloor(self.carrier_timer, 5);
                for (self.carriers.items) |*carrier| {
                    if (carrier.timer > self.carrier_timer) carrier.timer = self.carrier_timer;
                }
            },
            .miner_speedup => {
                self.miner_timer -= @divFloor(self.miner_timer, 4);
            },
            .builder_speedup => {
                self.builder_timer -= @divFloor(self.builder_timer, 4);
            },
            .carrier_strength => {
                self.carrier_capacity += 1;
            },
            .anim_speedup => self.anim_steps -= @divFloor(self.anim_steps, 5),
            .rep_mult_increase => self.rep_mult *= self.rep_mult + 1,
            .complete_game => {
                self.show_message = true;
                self.message_subindex = 0;
                self.message_index = MESSAGES.len - 1;
                self.building_complete = true;
            },
            // .mine_storage_add_row => self.mine_storage.num_rows += 1,
            // .base_storage_add_row => self.base_storage.num_rows += 1,
            .resource_upgrade => {
                self.miner_ore = self.miner_ore.upgrade();
            },
        }
    }

    fn setButtonCost(self: *Game, action: ButtonAction) void {
        const level = self.levels[@intFromEnum(action)];
        const cost = UPGRADE_COSTS[@intFromEnum(action)][level];
        for (self.buttons.items) |*button| {
            if (button.button.value == @intFromEnum(action)) {
                button.cost = cost;
                return;
            }
        }
    }

    fn addAnimation(self: *Game, anim: Animation) void {
        for (self.animations.items) |*ani| {
            if (ani.data == .none) {
                ani.* = anim;
                return;
            }
        }
        if (self.animations.items.len >= ANIM_MAX_COUNT) unreachable;
        self.animations.appendAssumeCapacity(anim);
    }

    fn getMinerPosition(self: *Game, index: usize) Vec2 {
        _ = self;
        const lane = @mod(index, LANES_MAX_COUNT);
        const position = MINER_0_POSITION.add(MINER_OFFSET.scale(@floatFromInt(lane)));
        return position;
    }

    fn getMineStoragePosition(self: *Game, index: usize) Vec2 {
        _ = self;
        const str_lane = @mod(index, STORAGE_PER_ROW);
        const position = STORAGE_SLOT.add(STORAGE_LANE.scale(@floatFromInt(str_lane)));
        return position;
    }

    fn getBaseStoragePosition(self: *Game, index: usize) Vec2 {
        _ = self;
        const str_lane = @mod(index, STORAGE_PER_ROW);
        const str_row = @divFloor(index, STORAGE_PER_ROW);
        const position = BASE_STORAGE_SLOT.add(STORAGE_LANE.scale(@floatFromInt(str_lane))).add(STORAGE_ROW.scale(@floatFromInt(str_row)));
        return position;
    }

    fn getBuilderPosition(self: *Game, index: usize) Vec2 {
        _ = self;
        const lane = @mod(index, LANES_MAX_COUNT);
        const position = BUILDER0_POSITION.add(BUILDER_OFFSET.scale(@floatFromInt(lane)));
        return position;
    }

    fn getCarrierWaitingPosition(self: *Game, index: usize) Vec2 {
        _ = self;
        const carrier_lane = @mod(index, LANES_MAX_COUNT);
        const carrier_row = @divFloor(index, LANES_MAX_COUNT);
        const position = CARRIER_SLOT.add(CARRIER_LANE.scale(@floatFromInt(carrier_lane))).add(CARRIER_OFFSET.scale(@floatFromInt(carrier_row)));
        return position;
    }

    fn getCarrierDropoffPosition(self: *Game, index: usize) Vec2 {
        _ = self;
        const carrier_lane = @mod(index, LANES_MAX_COUNT);
        const carrier_row = @divFloor(index, LANES_MAX_COUNT);
        const position = CARRIER_DROPOFF_SLOT.add(CARRIER_DROPOFF_LANE.scale(@floatFromInt(carrier_lane))).add(CARRIER_DROPOFF_OFFSET.scale(@floatFromInt(carrier_row)));
        return position;
    }

    fn tryCarrierPickup(self: *Game, carrier_index: u8, res: ResType, carrier_slot: u8) void {
        var carrier = &self.carriers.items[carrier_index];
        carrier.res[carrier_slot] = res;
        if (carrier.numCarried() == self.carrier_capacity) {
            carrier.timer = self.carrier_timer;
            carrier.state = .carrying;
        }
    }

    fn checkTechUpgrades(self: *Game) void {
        self.tech_buttons.clearRetainingCapacity();
        var pos = Vec2{ .x = 50, .y = 560 };
        for (TECH_UPGRADES) |tu| {
            if (self.unlocked[@intFromEnum(tu.unlock)]) continue;
            if (self.score >= (tu.score - @divFloor(tu.score, 5))) {
                self.tech_buttons.appendAssumeCapacity(.{
                    .button = .{
                        .rect = .{
                            .position = pos,
                            .size = .{ .x = 540, .y = 60 },
                        },
                        .text = tu.text,
                        .text2 = tu.subtext,
                        .value = @intFromEnum(tu.unlock),
                        .index = tu.msg_index,
                    },
                    .cost = tu.score,
                });
                pos = pos.add(.{ .y = -50 });
                break;
            } else {
                break;
            }
        }
        const limits = [_]u64{ 0, 500, 50000, 500000 };
        for (limits, 0..) |limit, i| {
            if (self.score_display > limit) {
                self.palace_completion = @intCast(i);
            }
        }
        if (self.building_complete) self.palace_completion = 4;
    }

    fn updateScore(self: *Game) void {
        if (self.score_display < self.score) {
            const change = @divFloor(self.score - self.score_display, 10) + 1;
            self.score_display += change;
        }
        if (self.points_display < self.points) {
            const change = @divFloor(self.points - self.points_display, 10) + 1;
            self.points_display += change;
        }
    }

    fn popRate(self: *Game) usize {
        if (self.score < 100) return 60;
        if (self.score < 500) return 40;
        if (self.score < 660) return 35;
        if (self.score < 1000) return 30;
        if (self.score < 1200) return 29;
        if (self.score < 3000) return 28;
        if (self.score < 4000) return 26;
        if (self.score < 5000) return 25;
        if (self.score < 10000) return 20;
        if (self.score < 25000) return 16;
        if (self.score < 50000) return 13;
        if (self.score < 100000) return 10;
        if (self.score < 200000) return 7;
        if (self.score < 300000) return 5;
        if (self.score < 1000000) return 4;
        return 3;
    }

    fn playPopSound(self: *Game) void {
        if (self.pops_queued > 0) {
            const rate = self.popRate();
            if (@mod(self.steps, rate) == 0) {
                self.pops_queued -= 1;
                const index = self.rng.uintLessThan(u8, POP_SOUNDS.len);
                self.haathi.setSoundVolume(POP_SOUNDS[index], 0.3);
                self.haathi.playSound(POP_SOUNDS[index], false);
            }
        }
    }

    fn playClickSound(self: *Game) void {
        const index = self.rng.uintLessThan(u8, CLICK_SOUNDS.len);
        self.haathi.playSound(CLICK_SOUNDS[index], false);
    }

    // updateGame
    pub fn update(self: *Game, ticks: u64) void {
        // clear the arena and reset.
        self.steps += 1;
        _ = self.arena_handle.reset(.retain_capacity);
        self.arena = self.arena_handle.allocator();
        self.ticks = @intCast(ticks);
        if (self.load_page) {
            if (self.haathi.inputs.mouse.l_button.is_clicked) {
                self.load_page = false;
            } else {
                return;
            }
        }
        self.updateScore();
        if (self.score_display < 10000000) self.playPopSound();
        if (self.haathi.inputs.getKey(.control).is_down and self.haathi.inputs.getKey(.s).is_clicked) {
            self.saveGame();
        }
        if (self.haathi.inputs.getKey(.control).is_clicked) {
            helpers.debugPrint(".{{ .x={d}, .y={d} }}", .{ self.haathi.inputs.mouse.current_pos.x, self.haathi.inputs.mouse.current_pos.y });
        }
        if (self.show_message and self.haathi.inputs.mouse.l_button.is_clicked) {
            const len = MESSAGES[self.message_index].len;
            self.message_subindex += 1;
            if (self.message_subindex > len) {
                self.show_message = false;
                self.message_subindex = 0;
            }
        }
        if (!self.show_message) {
            for (self.buttons.items) |*button| button.button.update(self.haathi.inputs.mouse);
            for (self.buttons.items) |button| {
                if (button.button.clicked) {
                    if (self.points_display >= button.cost) {
                        self.points_display -= button.cost;
                        self.points -= button.cost;
                        self.doButtonAction(@enumFromInt(button.button.value));
                        self.playClickSound();
                    }
                }
            }
            for (self.tech_buttons.items) |*button| button.button.update(self.haathi.inputs.mouse);
            for (self.tech_buttons.items) |button| {
                if (button.button.clicked) {
                    if (self.score >= button.cost) {
                        self.unlocked[button.button.value] = true;
                        self.message_index = @intCast(button.button.index);
                        self.message_subindex = 0;
                        self.show_message = true;
                        self.checkTechUpgrades();
                        self.resetButtons();
                        self.playClickSound();
                    }
                }
            }
        }
        // update miners
        for (self.miners.items) |*miner| {
            if (miner.timer > 0) miner.timer -= 1;
        }
        for (self.carriers.items) |*carrier| {
            if (carrier.timer > 0) carrier.timer -= 1;
        }
        for (self.builders.items) |*builder| {
            if (builder.timer > 0) builder.timer -= 1;
        }
        {
            // create resources if space exists
            for (self.miners.items, 0..) |*miner, miner_index| {
                if (miner.timer != 0) continue;
                var mined: usize = 0;
                // miner is done mining, find a space for the materials to go.
                const mine_storage_max = self.mine_storage.num_rows * STORAGE_PER_ROW;
                for (self.mine_storage.storage[0..mine_storage_max], 0..) |*str, i| {
                    if (str.* == .none) {
                        str.* = .reserved;
                        miner.timer = self.miner_timer;
                        mined += 1;
                        // create animation
                        self.addAnimation(.{
                            .res = self.miner_ore,
                            .start_step = self.steps,
                            .data = .{ .miner = .{
                                .mine_index = @intCast(miner_index),
                                .storage_index = @intCast(i),
                            } },
                        });
                        if (mined == self.miner_strength) {
                            break;
                        }
                    }
                }
            }
        }
        {
            for (self.carriers.items, 0..) |*carrier, carrier_index| {
                if (carrier.timer != 0) continue;
                switch (carrier.state) {
                    .waiting => {
                        var carried: u8 = carrier.numFull();
                        const mine_storage_max = self.mine_storage.num_rows * STORAGE_PER_ROW;
                        for (self.mine_storage.storage[0..mine_storage_max], 0..) |*str, i| {
                            if (str.* == .none or str.* == .reserved) continue;
                            if (carried >= self.carrier_capacity) {
                                break;
                            }
                            {
                                const res = str.*;
                                str.* = .none;
                                carrier.res[carried] = .reserved;
                                // create animation
                                self.addAnimation(.{
                                    .res = res,
                                    .start_step = self.steps,
                                    .data = .{ .carrier_pickup = .{
                                        .carrier_index = @intCast(carrier_index),
                                        .storage_index = @intCast(i),
                                        .carrier_slot_index = @intCast(carried),
                                    } },
                                });
                                carried += 1;
                            }
                        }
                    },
                    .carrying => {
                        carrier.state = .delivering;
                    },
                    .returning => {
                        carrier.state = .waiting;
                    },
                    .delivering => {
                        const base_storage_max = self.base_storage.num_rows * STORAGE_PER_ROW;
                        var base_dropped: u8 = carrier.numCarried();
                        for (self.base_storage.storage[0..base_storage_max], 0..) |*str, i| {
                            if (str.* == .none) {
                                str.* = .reserved;
                                // create animation
                                base_dropped -= 1;
                                self.addAnimation(.{
                                    .res = carrier.res[base_dropped],
                                    .start_step = self.steps,
                                    .data = .{ .carrier_dropoff = .{
                                        .carrier_index = @intCast(carrier_index),
                                        .storage_index = @intCast(i),
                                        .carrier_slot_index = base_dropped,
                                    } },
                                });
                                carrier.res[base_dropped] = .none;
                                if (base_dropped == 0) {
                                    carrier.timer = self.carrier_timer;
                                    carrier.state = .returning;
                                    break;
                                }
                            }
                        }
                    },
                }
            }
        }
        {
            const base_storage_max = self.base_storage.num_rows * STORAGE_PER_ROW;
            for (self.builders.items, 0..) |*builder, builder_index| {
                if (builder.timer != 0) continue;
                if (builder.reserved) continue;
                for (self.base_storage.storage[0..base_storage_max], 0..) |*str, i| {
                    if (str.* == .none or str.* == .reserved) continue;
                    {
                        const res = str.*;
                        str.* = .none;
                        builder.reserved = true;
                        self.score += res.score() * self.rep_mult;
                        self.points += res.score() * self.rep_mult;
                        if (self.pops_queued < 15) self.pops_queued += 1;
                        // create animation
                        self.addAnimation(.{
                            .res = res,
                            .start_step = self.steps,
                            .data = .{ .builder = .{
                                .builder_index = @intCast(builder_index),
                                .storage_index = @intCast(i),
                            } },
                        });
                        self.checkTechUpgrades();
                        break;
                    }
                }
            }
        }
        for (self.animations.items) |*anim| {
            if (self.steps < anim.start_step) unreachable;
            if (self.steps > anim.start_step + self.anim_steps) {
                switch (anim.data) {
                    .miner => |data| self.mine_storage.storage[data.storage_index] = anim.res,
                    .carrier_pickup => |data| {
                        self.tryCarrierPickup(data.carrier_index, anim.res, data.carrier_slot_index);
                    },
                    .carrier_dropoff => |data| {
                        self.base_storage.storage[data.storage_index] = anim.res;
                    },
                    .builder => |data| {
                        self.builders.items[data.builder_index].reserved = false;
                        self.builders.items[data.builder_index].timer = self.builder_timer;
                    },
                    .none => {},
                }
                anim.data = .none;
                anim.start_step = 0;
            }
        }
        // self.verify();
    }

    pub fn render(self: *Game) void {
        // background
        self.haathi.drawSprite(.{
            .sprite = .{
                .path = "img/bg.png",
                .anchor = .{},
                .size = SCREEN_SIZE,
            },
            .position = .{},
        });
        if (self.load_page) {
            self.haathi.drawText(.{
                .text = "and so we build",
                .position = .{ .x = SCREEN_SIZE.x * 0.5, .y = SCREEN_SIZE.y * 0.86 },
                .color = colors.apollo_light_4,
                .style = FONTS[2],
            });
            self.haathi.drawText(.{
                .text = "click to start",
                .position = .{ .x = SCREEN_SIZE.x * 0.5, .y = SCREEN_SIZE.y * 0.82 },
                .color = colors.apollo_light_4,
                .style = "20px InterMedium",
            });
            return;
        }
        self.haathi.drawSprite(.{
            .sprite = .{
                .path = "img/sets.png",
                .anchor = .{},
                .size = SCREEN_SIZE,
            },
            .position = .{},
        });
        self.haathi.drawSprite(.{
            .sprite = .{
                .path = "img/bdg1.png",
                .anchor = .{},
                .size = .{ .x = 440, .y = 258 },
            },
            .position = .{ .x = 769, .y = 389 },
        });
        if (self.palace_completion > 0)
            self.haathi.drawSprite(.{
                .sprite = .{
                    .path = "img/bdg2.png",
                    .anchor = .{},
                    .size = .{ .x = 440, .y = 258 },
                },
                .position = .{ .x = 769, .y = 389 },
            });
        if (self.palace_completion > 1)
            self.haathi.drawSprite(.{
                .sprite = .{
                    .path = "img/bdg3.png",
                    .anchor = .{},
                    .size = .{ .x = 440, .y = 258 },
                },
                .position = .{ .x = 769, .y = 389 },
            });
        if (self.palace_completion > 2)
            self.haathi.drawSprite(.{
                .sprite = .{
                    .path = "img/bdg4.png",
                    .anchor = .{},
                    .size = .{ .x = 440, .y = 258 },
                },
                .position = .{ .x = 769, .y = 389 },
            });
        if (self.palace_completion > 3)
            self.haathi.drawSprite(.{
                .sprite = .{
                    .path = "img/bdg5.png",
                    .anchor = .{},
                    .size = .{ .x = 440, .y = 258 },
                },
                .position = .{ .x = 769, .y = 389 },
            });
        // self.haathi.drawRect(.{
        //     .position = .{ .x = 0, .y = SCREEN_SIZE.y * 0.8 },
        //     .size = .{ .x = SCREEN_SIZE.x, .y = SCREEN_SIZE.y * 0.2 },
        //     .color = colors.apollo_blue_3,
        // });
        {
            const score_text = std.fmt.allocPrintZ(self.arena, "{d}", .{self.score_display}) catch unreachable;
            self.haathi.drawText(.{
                .text = score_text,
                .position = .{ .x = SCREEN_SIZE.x * 0.75, .y = SCREEN_SIZE.y * 0.86 },
                .color = colors.apollo_light_4,
                .style = FONTS[2],
            });
        }
        {
            // shadow of pane
            self.haathi.drawRect(.{
                .position = .{ .x = 25, .y = 15 },
                .size = .{ .y = SCREEN_SIZE.y - 100, .x = (SCREEN_SIZE.x * 0.5) - 30 },
                .color = colors.apollo_green_3,
                .radius = 15,
            });
            self.haathi.drawRect(.{
                .position = .{ .x = 25, .y = 446 },
                .size = .{ .y = 76, .x = (SCREEN_SIZE.x * 0.5) - 30 },
                .color = colors.apollo_blue_4,
            });
            self.haathi.drawRect(.{
                .position = .{ .x = 25, .y = 529 },
                .size = .{ .y = 159, .x = (SCREEN_SIZE.x * 0.5) - 30 },
                .color = colors.apollo_blue_2,
                .radius = 10,
            });
            self.haathi.drawRect(.{
                .position = .{ .x = 25, .y = 522 },
                .size = .{ .y = 32, .x = (SCREEN_SIZE.x * 0.5) - 30 },
                .color = colors.apollo_blue_3,
            });
            self.haathi.drawRect(.{
                .position = .{ .x = 15, .y = 25 },
                .size = .{ .y = SCREEN_SIZE.y - 40, .x = (SCREEN_SIZE.x * 0.5) - 30 },
                .color = colors.apollo_brown_2,
                .radius = 10,
            });
            self.haathi.drawRect(.{
                .position = .{ .x = 15 + BORDER, .y = 25 + BORDER },
                .size = .{ .y = SCREEN_SIZE.y - 40 - (2 * BORDER), .x = (SCREEN_SIZE.x * 0.5) - 30 - (2 * BORDER) },
                .color = colors.apollo_brown_6,
                .radius = 10,
            });
        }
        {
            const points_text = std.fmt.allocPrintZ(self.arena, "{d}", .{self.points_display}) catch unreachable;
            self.haathi.drawText(.{
                .text = points_text,
                .position = .{ .x = 0.315 * SCREEN_SIZE.x, .y = SCREEN_SIZE.y * 0.88 },
                .color = colors.apollo_brown_3,
                .style = "60px InterBlack",
            });
            self.haathi.drawText(.{
                .text = "Points:",
                .position = .{ .x = 0.11 * SCREEN_SIZE.x, .y = SCREEN_SIZE.y * 0.89 },
                .color = colors.apollo_brown_4,
                .style = "40px InterBlack",
            });
        }
        for (self.buttons.items) |button| {
            const progress: f32 = @min(1.0, @as(f32, @floatFromInt(self.points_display)) / @as(f32, @floatFromInt(button.cost)));
            const border = 8;
            const complete = self.points_display > button.cost;
            const border_color = if (complete) colors.apollo_blue_2 else colors.apollo_dark_5;
            const offset = if (complete and button.button.hovered) Vec2{ .x = -10, .y = 10 } else Vec2{};
            self.haathi.drawRect(.{
                .position = button.button.rect.position,
                .size = button.button.rect.size,
                .color = colors.apollo_brown_4,
                .radius = 5,
            });
            self.haathi.drawRect(.{
                .position = button.button.rect.position.add(offset),
                .size = button.button.rect.size,
                .color = border_color,
                .radius = 5,
            });
            self.haathi.drawRect(.{
                .position = button.button.rect.position.add(offset).add(.{ .x = border, .y = border }),
                .size = button.button.rect.size.add(.{ .x = -border * 2, .y = -border * 2 }),
                .color = colors.apollo_dark_4,
                .radius = 5,
            });
            self.haathi.drawRect(.{
                .position = button.button.rect.position.add(offset).add(.{ .x = border, .y = border }),
                .size = button.button.rect.size.add(.{ .x = -border * 2, .y = -border * 2 }).scaleVec2(.{ .x = progress, .y = 1 }),
                .color = colors.apollo_blue_3,
                .radius = 5,
            });
            const strip_color = if (complete) colors.apollo_blue_4 else colors.apollo_dark_6;
            const text_color = if (complete) colors.apollo_light_4 else colors.apollo_light_2;
            self.haathi.drawRect(.{
                .position = button.button.rect.position.add(offset).add(.{ .y = border }),
                .size = .{ .x = border, .y = border },
                .color = strip_color,
            });
            self.haathi.drawRect(.{
                .position = button.button.rect.position.add(offset).add(.{ .x = border, .y = border }),
                .size = .{ .x = (button.button.rect.size.x - (2 * border)) * progress, .y = border },
                .color = strip_color,
            });
            if (complete) self.haathi.drawRect(.{
                .position = button.button.rect.position.add(offset).add(.{ .x = button.button.rect.size.x - border, .y = border }),
                .size = .{ .x = border, .y = border },
                .color = strip_color,
            });
            const text_center = button.button.rect.position.add(button.button.rect.size.scaleVec2(.{ .x = 0.5, .y = 1 }).add(.{ .y = -33 })).add(offset);
            self.haathi.drawText(.{ .text = button.button.text, .position = text_center, .color = text_color });
            if (button.cost > 0) {
                const cost_text = if (button.cost < 1000000000) std.fmt.allocPrintZ(self.arena, "{d}", .{button.cost}) catch unreachable else "MAX";
                self.haathi.drawText(.{ .text = cost_text, .position = text_center.add(.{ .x = 0, .y = -19 }), .color = text_color, .style = FONTS[1] });
            }
        }
        for (self.tech_buttons.items) |button| {
            const progress: f32 = @min(1.0, @as(f32, @floatFromInt(self.score_display)) / @as(f32, @floatFromInt(button.cost)));
            const border = 8;
            const complete = self.score_display > button.cost;
            const border_color = if (complete) colors.apollo_red_2 else colors.apollo_dark_5;
            const offset = if (complete and button.button.hovered) Vec2{ .x = -10, .y = 10 } else Vec2{};
            self.haathi.drawRect(.{
                .position = button.button.rect.position,
                .size = button.button.rect.size,
                .color = colors.apollo_brown_4,
                .radius = 5,
            });
            self.haathi.drawRect(.{
                .position = button.button.rect.position.add(offset),
                .size = button.button.rect.size,
                .color = border_color,
                .radius = 5,
            });
            self.haathi.drawRect(.{
                .position = button.button.rect.position.add(offset).add(.{ .x = border, .y = border }),
                .size = button.button.rect.size.add(.{ .x = -border * 2, .y = -border * 2 }),
                .color = colors.apollo_dark_4,
                .radius = 5,
            });
            self.haathi.drawRect(.{
                .position = button.button.rect.position.add(offset).add(.{ .x = border, .y = border }),
                .size = button.button.rect.size.add(.{ .x = -border * 2, .y = -border * 2 }).scaleVec2(.{ .x = progress, .y = 1 }),
                .color = colors.apollo_red_3,
                .radius = 5,
            });
            const strip_color = if (complete) colors.apollo_red_4 else colors.apollo_dark_6;
            const text_color = if (complete) colors.apollo_light_4 else colors.apollo_light_2;
            self.haathi.drawRect(.{
                .position = button.button.rect.position.add(offset).add(.{ .y = border }),
                .size = .{ .x = border, .y = border },
                .color = strip_color,
            });
            self.haathi.drawRect(.{
                .position = button.button.rect.position.add(offset).add(.{ .x = border, .y = border }),
                .size = .{ .x = (button.button.rect.size.x - (2 * border)) * progress, .y = border },
                .color = strip_color,
            });
            if (complete) self.haathi.drawRect(.{
                .position = button.button.rect.position.add(offset).add(.{ .x = button.button.rect.size.x - border, .y = border }),
                .size = .{ .x = border, .y = border },
                .color = strip_color,
            });
            const text_center = button.button.rect.position.add(button.button.rect.size.scaleVec2(.{ .x = 0.5, .y = 1 }).add(.{ .y = -33 })).add(offset);
            self.haathi.drawText(.{ .text = button.button.text, .position = text_center, .color = text_color });
            if (button.cost > 0) {
                const cost_text = if (button.cost < 1000000000) std.fmt.allocPrintZ(self.arena, "{d}", .{button.cost}) catch unreachable else "MAX";
                self.haathi.drawText(.{ .text = cost_text, .position = text_center.add(.{ .x = 0, .y = -19 }), .color = text_color, .style = FONTS[1] });
            }
        }
        for (self.miners.items, 0..) |miner, miner_index| {
            const position = self.getMinerPosition(miner_index);
            self.haathi.drawRect(.{
                .position = position.add(.{ .x = -30, .y = -30 }),
                .size = .{ .x = 30, .y = 12 },
                .color = colors.apollo_red_1,
                .radius = 2,
            });
            const progress: f32 = @as(f32, @floatFromInt(miner.timer)) / @as(f32, @floatFromInt(@max(miner.timer, self.miner_timer)));
            self.haathi.drawRect(.{
                .position = position.add(.{ .x = -30, .y = -30 }),
                .size = .{ .x = 30 * (1.0 - progress), .y = 12 },
                .color = colors.apollo_red_4,
                .radius = 2,
            });
            self.haathi.drawSprite(.{
                .sprite = .{
                    .path = "img/digger.png",
                    .anchor = .{},
                    .size = .{ .x = 40, .y = 70 },
                },
                .position = position.add(.{ .x = -30, .y = -15 }),
            });
        }
        for (self.animations.items) |anim| {
            if (anim.start_step == 0) continue;
            const progress: f32 = @as(f32, @floatFromInt(self.steps - anim.start_step)) / @as(f32, @floatFromInt(self.anim_steps));
            switch (anim.data) {
                .none => {},
                .miner => |data| {
                    const start = self.getMinerPosition(data.mine_index);
                    const end = self.getMineStoragePosition(data.storage_index);
                    const pos = start.ease(end, progress);
                    self.haathi.drawSprite(.{
                        .sprite = .{
                            .path = "img/material.png",
                            .anchor = .{},
                            .size = .{ .x = 10, .y = 10 },
                        },
                        .position = pos.add(.{ .x = -1, .y = -1 }),
                    });
                },
                .carrier_pickup => |data| {
                    const start = self.getMineStoragePosition(data.storage_index);
                    const end = self.getCarrierWaitingPosition(data.carrier_index);
                    const pos = start.ease(end, progress);
                    self.haathi.drawSprite(.{
                        .sprite = .{
                            .path = "img/material.png",
                            .anchor = .{},
                            .size = .{ .x = 10, .y = 10 },
                        },
                        .position = pos.add(.{ .x = -1, .y = -1 }),
                    });
                },
                .carrier_dropoff => |data| {
                    const start = self.getCarrierDropoffPosition(data.carrier_index);
                    const end = self.getBaseStoragePosition(data.storage_index);
                    const pos = start.ease(end, progress);
                    self.haathi.drawSprite(.{
                        .sprite = .{
                            .path = "img/material.png",
                            .anchor = .{},
                            .size = .{ .x = 10, .y = 10 },
                        },
                        .position = pos.add(.{ .x = -1, .y = -1 }),
                    });
                },
                .builder => |data| {
                    const start = self.getBaseStoragePosition(data.storage_index);
                    const end = self.getBuilderPosition(data.builder_index);
                    const pos = start.ease(end, progress);
                    self.haathi.drawSprite(.{
                        .sprite = .{
                            .path = "img/material.png",
                            .anchor = .{},
                            .size = .{ .x = 10, .y = 10 },
                        },
                        .position = pos.add(.{ .x = -1, .y = -1 }),
                    });
                },
            }
        }
        for (self.mine_storage.storage[0 .. self.mine_storage.num_rows * STORAGE_PER_ROW], 0..) |str, storage_index| {
            const pos = self.getMineStoragePosition(storage_index);
            if (str == .none or str == .reserved) continue;
            self.haathi.drawSprite(.{
                .sprite = .{
                    .path = "img/material.png",
                    .anchor = .{},
                    .size = .{ .x = 10, .y = 10 },
                },
                .position = pos.add(.{ .x = -1, .y = -1 }),
            });
        }

        for (self.base_storage.storage[0 .. self.base_storage.num_rows * STORAGE_PER_ROW], 0..) |str, storage_index| {
            const pos = self.getBaseStoragePosition(storage_index);
            if (str == .none or str == .reserved) continue;
            self.haathi.drawSprite(.{
                .sprite = .{
                    .path = "img/material.png",
                    .anchor = .{},
                    .size = .{ .x = 10, .y = 10 },
                },
                .position = pos.add(.{ .x = -1, .y = -1 }),
            });
        }
        for (self.builders.items, 0..) |builder, builder_index| {
            const position = self.getBuilderPosition(builder_index);
            const progress: f32 = @as(f32, @floatFromInt(builder.timer)) / @as(f32, @floatFromInt(@max(builder.timer, self.builder_timer)));
            self.haathi.drawRect(.{
                .position = position.add(.{ .x = -30, .y = -30 }),
                .size = .{ .x = 30, .y = 12 },
                .color = colors.apollo_dark_2,
                .radius = 2,
            });
            self.haathi.drawRect(.{
                .position = position.add(.{ .x = -30, .y = -30 }),
                .size = .{ .x = 30 * (progress), .y = 12 },
                .color = colors.apollo_green_3,
                .radius = 2,
            });
            self.haathi.drawSprite(.{
                .sprite = .{
                    .path = "img/builder.png",
                    .anchor = .{},
                    .size = .{ .x = 40, .y = 70 },
                },
                .position = position.add(.{ .x = -30, .y = -15 }),
            });
        }
        for (self.carriers.items, 0..) |*carrier, carrier_index| {
            const progress: f32 = 1.0 - (@as(f32, @floatFromInt(carrier.timer)) / @as(f32, @floatFromInt(@max(carrier.timer, self.carrier_timer))));
            const start = self.getCarrierWaitingPosition(carrier_index);
            const end = self.getCarrierDropoffPosition(carrier_index);
            const pos = switch (carrier.state) {
                .waiting => start,
                .carrying => start.ease(end, progress),
                .delivering => end,
                .returning => end.ease(start, progress),
            };
            self.haathi.drawSprite(.{
                .sprite = .{
                    .path = "img/carrier.png",
                    .anchor = .{},
                    .size = .{ .x = 30, .y = 40 },
                },
                .position = pos.add(.{ .x = -10, .y = -5 }),
            });
            for (carrier.res, 0..) |res, i| {
                if (res == .none or res == .reserved) continue;
                const position = pos.add(.{ .y = 30 }).add(.{ .y = 10 * @as(f32, @floatFromInt(i)) });
                self.haathi.drawSprite(.{
                    .sprite = .{
                        .path = "img/material.png",
                        .anchor = .{},
                        .size = .{ .x = 10, .y = 10 },
                    },
                    .position = position.add(.{ .x = -1, .y = 5 }),
                });
            }
        }
        if (self.show_message) {
            if (self.message_index == MESSAGES.len - 1) {
                self.haathi.drawRect(.{
                    .position = .{},
                    .size = SCREEN_SIZE,
                    .color = colors.apollo_dark_1,
                });
                self.haathi.drawText(.{
                    .position = SCREEN_SIZE.scaleVec2(.{ .x = 0.5, .y = 0.5 }),
                    .text = MESSAGES[self.message_index][self.message_subindex],
                    .color = colors.apollo_light_4,
                    .style = "20px InterBold",
                    .width = SCREEN_SIZE.x * 0.6,
                });
            } else {
                self.haathi.drawRect(.{
                    .position = .{ .x = 15 + BORDER, .y = 25 + BORDER },
                    .size = .{ .y = SCREEN_SIZE.y - 40 - (2 * BORDER), .x = (SCREEN_SIZE.x * 0.5) - 30 - (2 * BORDER) },
                    .color = colors.apollo_brown_1,
                    .radius = 10,
                });
                self.haathi.drawText(.{
                    .position = SCREEN_SIZE.scaleVec2(.{ .x = 0.25, .y = 0.5 }),
                    .text = MESSAGES[self.message_index][self.message_subindex],
                    .color = colors.apollo_light_4,
                    .style = "20px InterBold",
                    .width = SCREEN_SIZE.x * 0.45,
                });
            }
        }
    }
};
