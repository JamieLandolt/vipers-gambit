local love = require "love"
local lg = love.graphics
local la = love.audio
local button = require "Button"
local avatar = require "Avatar"
local scandir = require "scandir"
local card = require "Card"
local stats = require "Stats"
local text = require "Text"

reference_window_width = 1440
reference_window_height = 872
time = 0

local debug = "Debug Text"
local debug2 = "Debug Text"
local debugger_enabled = true

local debug_font = love.graphics.newFont("assets/Jersey15-Regular.ttf", 20)
local font = love.graphics.newFont("assets/Jersey15-Regular.ttf", 50)

local audio = true

local card_files = {"Beach_Mum.png", "Big_Foot.png", "Big_Foot_Gold.png", "Blue_Slimey.png", "Blueberry_Djini.png", "Brain_Gooey.png", "Burning_Hand.png", "Cerebral_Bloodstorm.png", "Cornball.png", "Cornball_Gold.png", "Dark_Angel.png", "Dragon_claw.png", "Ghost_Djini.png", "Ghost_Ninja.png", "Ghost_Ninja_Gold.png", "Giant_Mummy_Hand.png", "Grape_Slimey.png", "Gray_Eyebat.png", "Gray_Eyebat_Gold.png", "Green_Cactaball.png", "Green_Cactaball_Gold.png", "Green_Mermaid.png", "Green_Merman.png", "Green_Merman_Gold.png", "Heavenly_Gazer_Gold.png", "Huskerbat.png", "Lime_slimey.png", "Mud_Angel_Gold.png", "Nicelands_Eye_Bat.png", "Orange_Slimey.png", "Ordinary_Ninja.png", "Peach_djini.png", "Sand_Angel.png", "Sand_Angel_Gold.png", "Sand_eyebat.png", "Sandfoot.png", "Travelin%27_Farmer.png", "Travelin%27_Skeleton.png", "Travelin_Wizard.png", "Unicycle_Knight.png", "Unicyclops.png", "Wall_Of_Sand.png", "Wall_of_Chocolate.png", "Wall_of_Ears.png"}
local background_files = {"background10.jpg", "background2.jpg", "background3.jpg", "background6.jpg", "background7.jpg", "background8.jpg"}

local chosen_background = ""

local info_button_height = reference_window_height * 1/3
local info_button_width = reference_window_width * 0.9/6 - 10
local info_button_x = reference_window_width * 5.05/6 + 5
local info_button_y = reference_window_height * 2/3 - 10

local info_button_hitbox = {info_button_x, info_button_y, info_button_width, info_button_height}

local w = 1440
local h = 900

local blue = {15/255, 140/255, 220/255}
local green = {116/255, 182/255, 82/255}
local purple = {101/255, 52/255, 150/255}

local g1, g2, g3 = green[1], green[2], green[3]
local b1, b2, b3 = blue[1], blue[2], blue[3]
local p1, p2, p3 = purple[1], purple[2], purple[3]

local card_hitboxes = {} --x, y, width, height

local button_width = 200
local button_height = 60

local opponent_button_width = 355
local opponent_button_height = 500

local default_button_size = 10
local letter_sizes = {
    a = 18,
    b = 18,
    c = 18,
    d = 18,
    e = 18,
    f = 15,
    g = 18,
    h = 15,
    i = 6,
    j = 9,
    k = 15,
    l = 6,
    m = 28,
    n = 18,
    o = 18,
    p = 18,
    q = 18,
    r = 17,
    s = 18,
    t = 15,
    u = 18,
    v = 18,
    w = 28,
    x = 18,
    y = 18,
    z = 20,
    A = 19,
    B = 19,
    C = 19,
    D = 19,
    E = 19,
    F = 19,
    G = 19,
    H = 19,
    I = 6,
    J = 19,
    K = 19,
    L = 19,
    M = 28,
    N = 19,
    O = 19,
    P = 19,
    Q = 19,
    R = 19,
    S = 20,
    T = 17,
    U = 19,
    V = 19,
    W = 28,
    X = 19,
    Y = 19,
    Z = 19,
    [" "] = 10,
    ["'"] = 6,
    ["1"] = 9,
    ["2"] = 19,
    ["3"] = 17,
    ["4"] = 17,
    ["5"] = 17,
    ["6"] = 19,
    ["7"] = 17,
    ["8"] = 19,
    ["9"] = 19,
    ["0"] = 17,
    [":"] = 6
}

-- NOT LOCAL
mouse = {}
chosen_avatar = "Jamie"
chosen_opponent = "Ice King"
scroll_offset_y = 0
count = 0
mouse_over_hand = false
mouse_over_info = false
mouse_over_info_background = false
mouse_over_playing_field = nil
characters = {"Alem", "Gabe", "Jamie", "Darcy", "Josh", "Michael"}
played_cards = {}

turn = "Player"
venom = 10
player_venom = 10
opponent_venom = 10

venom_sprites = {lg.newImage("assets/Sprites/Venom_0.png"),
                 lg.newImage("assets/Sprites/Venom_1.png"),
                 lg.newImage("assets/Sprites/Venom_2.png"),
                 lg.newImage("assets/Sprites/Venom_3.png"),
                 lg.newImage("assets/Sprites/Venom_4.png"),
                 lg.newImage("assets/Sprites/Venom_5.png"),
                 lg.newImage("assets/Sprites/Venom_6.png"),
                 lg.newImage("assets/Sprites/Venom_7.png"),
                 lg.newImage("assets/Sprites/Venom_8.png"),
                 lg.newImage("assets/Sprites/Venom_9.png"),
                 lg.newImage("assets/Sprites/Venom_10.png")}

animation_time = 0 -- how long it has been playing
animation_length = 0.1 -- how long it lasts
animation = false
animation_next_screen = nil

local avatars = {}
local cards = {}
local icons = {}

local player_hand = {}
local held_card
local info_card

local buttons = {
    menu = {},
    settings = {},
    level_select = {},
    character_select = {},
    collection = {},
    playing = {},
    paused = {},
    ended = {},
    info = {},
    universal = {}
}

local game = {
    state = {
        menu = true,
        settings = false,
        level_select = false,
        character_select = false,
        collection = false,
        playing = false,
        paused = false,
        ended = false,
        info = false
    }
}

local card_stats = {
    Snake = stats(2, 3, 2, "N/A", "Basic", 1, nil, "N/A"),
    Big_Snake = stats(3, 3, 10, "N/A", "Basic", 2, nil, "N/A"),
    Baby_Snake = stats(1, 6, 1, "N/A", "Basic", 2, nil, "N/A"),
    Well_Fed_Snake = stats(2, 4, 2, "N/A", "Basic", 1, nil, "N/A"),
    Anaconda = stats(6, 8, 8, "N/A", "Basic", 3, nil, "N/A"),
    Copperhead = stats(5, 10, 5, "N/A", "Basic", 3, nil, "N/A"),
    Zombie_Snake = stats(3, 5, 5, "N/A", "Basic", 2, nil, "N/A"),
    Cannibal_Snake = stats(3, 12, 3, "N/A", "Basic", 2, nil, "N/A"),
    Cobra = stats(4, 8, 15, "N/A", "Basic", 3, nil, "N/A"),
    Extra_Long_Python = stats(5, 9, 13, "N/A", "Basic", 3, nil, "N/A"),
}

local function get_stats(card)
    return card_stats[string.sub(card.card_path, 1, -5)]
end

local deck1 = {}

for k, v in pairs(card_stats) do
    table.insert(deck1, tostring(k))
end


local function get_button_size(text)
    local button_size = default_button_size
    for letter in string.gmatch(text, ".") do
        button_size = button_size + letter_sizes[letter] + 4
    end
    return button_size
end

local function placeholder() end

function love.load()
    math.randomseed(os.time())

    playing_field = lg.newImage("assets/Sprites/Playing_field.png")
    local playing_field_sector_width, playing_field_sector_height = 240, 270
    playing_field_hitboxes = {{245, 15, playing_field_sector_width, playing_field_sector_height, 1},
                              {245 + playing_field_sector_width - 10, 15, playing_field_sector_width + 5, playing_field_sector_height, 2},
                              {245 + playing_field_sector_width * 2 - 5, 15, playing_field_sector_width - 5, playing_field_sector_height, 3},
                              {245 + playing_field_sector_width * 3 - 10, 15, playing_field_sector_width, playing_field_sector_height, 4},
                              {245, 285, playing_field_sector_width, playing_field_sector_height, 5},
                              {245 + playing_field_sector_width - 10, 285, playing_field_sector_width + 5, playing_field_sector_height, 6},
                              {245 + playing_field_sector_width * 2 - 5, 285, playing_field_sector_width - 5, playing_field_sector_height, 7},
                              {245 + playing_field_sector_width * 3 - 10, 285, playing_field_sector_width, playing_field_sector_height, 8}}

    --love.window.setFullscreen(true)
    love.window.setMode(reference_window_width, reference_window_height, {resizable=true, vsync=0})

    local card_background_height = reference_window_height * 1/3
    local card_background_width = reference_window_width * 2/3 - 10
    local card_background_x = reference_window_width * 1/6 + 5
    local card_background_y = reference_window_height - card_background_height - 10

    local info_background_height = reference_window_height * 5/6
    local info_background_width = reference_window_width * 5/6
    local info_background_x = reference_window_width * 0.7/6 + 5
    info_background_y = reference_window_height * 1/12

    local button_background_width, button_background_height = resize(240, 1), resize(425, 2)

    for i, card in pairs(scandir("/Users/jameslandolt/IdeaProjects/SnakeGame/assets/Snake_Cards")) do
        if i > 3 then
            cards[i-3] = lg.newImage("assets/Snake_Cards/" .. card)
        end
    end

    img_widths = cards[1]:getWidth()
    img_heights = cards[1]:getHeight()

    hover_sound = la.newSource("assets/audio/hover.mp3", "static")

    --shader = lg.newShader(shader_code)

    avatars.gabe = love.graphics.newImage("assets/characters/gabe.jpg")
    avatars.jamie = love.graphics.newImage("assets/characters/jamie.jpg")
    avatars.alem = love.graphics.newImage("assets/characters/alem.jpg")
    avatars.josh = love.graphics.newImage("assets/characters/josh.jpg")
    avatars.michael = love.graphics.newImage("assets/characters/michael.jpg")
    avatars.darcy = love.graphics.newImage("assets/characters/darcy.jpg")

    icons.audio_enabled = love.graphics.newImage("assets/icons/audio_enabled.png")
    icons.audio_disabled = love.graphics.newImage("assets/icons/audio_disabled.png")

    --love.window.setMode(reference_window_width, reference_window_height)

    new_background()

    -- If adding new button, remember to draw it, may need to add game state too
    buttons.menu["Play Game"] = button("Play Game", update_animation_screen, "playing", lg.getWidth() / 2 - button_width / 2, lg.getHeight() / 2 - 150, button_width, button_height, font, 9, 4, debugger)
    buttons.menu["Collection"] = button("Collection", update_animation_screen, "collection", lg.getWidth() / 2 - button_width / 2, lg.getHeight() / 2 - 50, button_width, button_height, font, 11, 4, debugger)
    buttons.menu["Character"] = button("Character", update_animation_screen, "character_select", lg.getWidth() / 2 - button_width / 2, lg.getHeight() / 2 + 50, button_width, button_height, font, 6, 4, debugger)
    buttons.menu["Settings"] = button("Settings", update_animation_screen, "settings", lg.getWidth() / 2 - button_width / 2, lg.getHeight() / 2 + 150, button_width, button_height, font, 19, 4, debugger)
    buttons.menu["Button Background"] = button("", nil, nil, lg.getWidth() / 2 - button_background_width / 2, lg.getHeight() / 2 - button_background_height / 2 + resize(30, 2), button_background_width, button_background_height, font, 19, 4, debugger, nil, nil, nil, nil, true)

    buttons.menu["Switch Background"] = button("Switch Background", new_background, nil, lg.getWidth() - get_button_size("Switch Background") - 5, 5, get_button_size("Switch Background"), button_height, font, 5, 4, debugger)

    buttons.collection["Collection Header"] = button("Collection", nil, nil, lg.getWidth() / 2 - button_width / 2, 5, button_width, button_height, font, 14, 4, debugger)
    buttons.universal["Back"] = button("Back", update_animation_screen, "menu", 5, 5, button_width * 5/8, button_height, font, 19, 4, debugger)

    buttons.settings["Toggle Audio"] = button("Toggle Audio", toggle_audio, nil, lg.getWidth() / 2 - button_width * 1/4, lg.getHeight() / 2 - 100, button_width * 1.315, button_height, font, 19, 4, debugger)
    buttons.settings["Audio Enabled"] = button("", nil, nil, lg.getWidth() / 2 - button_width * 3/4, lg.getHeight() / 2 - 100, button_width * 0.3, button_height, font, 19, 4, debugger, false, icons.audio_enabled, 1/4, -6, 16)
    buttons.settings["Audio Disabled"] = button("", nil, nil, lg.getWidth() / 2 - button_width * 3/4, lg.getHeight() / 2 - 100, button_width * 0.3, button_height, font, 19, 4, debugger, false, icons.audio_disabled, 1/4, -6, 16)

    buttons.level_select["Select Opponent"] = button("Select Opponent", nil, nil, 5, 5, button_width * 5/8, button_height, font, 19, 4, debugger)

    buttons.character_select["Gabe"] = avatar("Gabe", "Gabe", update_game_state, "menu", 95, 20, font, opponent_button_width, opponent_button_height, avatars.gabe, 0.7, debugger)
    buttons.character_select["Jamie"] = avatar("Jamie", "Jamie", update_game_state, "menu", 85, 20, font, opponent_button_width, opponent_button_height, avatars.jamie, 0.7, debugger)
    buttons.character_select["Michael"] = avatar("Michael", "Michael", update_game_state, "menu", 75, 20, font, opponent_button_width, opponent_button_height, avatars.michael, 0.7, debugger)
    buttons.character_select["Josh"] = avatar("Josh", "Josh", update_game_state, "menu", 95, 20, font, opponent_button_width, opponent_button_height, avatars.josh, 0.7, debugger)
    buttons.character_select["Alem"] = avatar("Alem", "Alem", update_game_state, "menu", 95, 20, font, opponent_button_width, opponent_button_height, avatars.alem, 0.7, debugger)
    buttons.character_select["Darcy"] = avatar("Darcy", "Darcy", update_game_state, "menu", 85, 20, font, opponent_button_width, opponent_button_height, avatars.darcy, 0.7, debugger)

    buttons.playing["Card Background"] = button("", placeholder, nil, card_background_x, card_background_y, card_background_width, card_background_height, font, 19, 4, debugger)
    buttons.playing["Info"] = button("Info", placeholder, nil, info_button_x, info_button_y, info_button_width, info_button_height, font, 19, 4, debugger, true)

    buttons.info["Back"] = button("Back", update_animation_screen, "playing", 5, 5, button_width * 5/8, button_height, font, 19, 4, debugger)
    buttons.info["Info Background"] = button("Card Stats:", placeholder, nil, info_background_x, info_background_y, info_background_width, info_background_height, font, 19, 4, debugger)
end

function resize(num, type)
    -- type 1: x, type2: y
    if type == 1 then
        return num * lg.getWidth() / reference_window_width
    elseif type == 2 then
        return num * lg.getHeight() / reference_window_height
    else
        error("Unrecognised Type: (" .. tostring(type) .. ") passed to function: resize")
    end
end

function play_sound(sound)
    if audio then
        la.play(sound)
    end
end

function toggle_audio()
    audio = not audio
end

function new_background()
    local num
    --repeat
    --    num = math.random(1, #background_files)
    --until background_files[num] ~= chosen_background
    --
    --chosen_background = background_files[num]
    --background = lg.newImage("assets/backgrounds/" .. chosen_background)
    background = lg.newImage("assets/backgrounds/SnakeBackground.png")
end

function debugger(debug_text)
    debug = debug_text
end

function print_kvarray(arr) -- can only be used in the love.draw function
    x_pos = 10
    y_pos = 200
    lg.setColor(0, 0, 0)
    for k, v in pairs(arr) do
        lg.print(tostring(k) .. ": " .. tostring(v), x_pos, y_pos)
        y_pos = y_pos + 20
    end
end

function print_array(arr, y_offset) -- can only be used in the love.draw function
    x_pos = 10
    y_pos = 200
    lg.setColor(1, 0, 0)
    for i, v in ipairs(arr) do
        lg.print(tostring(v), x_pos, y_pos + y_offset)
        x_pos = x_pos + 100
        if x_pos > 1000 then
            x_pos = 20
            y_pos = y_pos + 20
        end
    end
end

function update_animation_screen(screen)
    animation_next_screen = screen
end

function update_game_state(state)
    for state_name, state_value in pairs(game.state) do
        game.state[state_name] = false
    end
    animation = false
    game.state[state] = true

end

local function renderBackground()
    lg.scale(3/4) -- can just be 2 as window is unable to be resized
    lg.setColor(1, 1, 1)
    lg.draw(background, 0, 0)
    lg.scale(4/3)
end

local function render_main_menu()
    scroll_offset_y = 0
    renderBackground()
    buttons.menu["Button Background"]:draw()
    buttons.menu["Play Game"]:draw()
    buttons.menu["Collection"]:draw()
    buttons.menu["Character"]:draw()
    buttons.menu["Settings"]:draw()
    --buttons.menu["Avatar " .. chosen_avatar]:draw()
    --buttons.menu["Switch Background"]:draw()
    --buttons.menu["nums"]:draw()
end

local function render_cards()
    local offset_x = 69
    local offset_y = scroll_offset_y * 5 or 0
    if offset_y > 0 then
        offset_y = 0
    end
    renderBackground()

    for c, s in pairs(cards) do
        if offset_x + resize(img_widths, 1) > reference_window_width then
            offset_x = 69
            offset_y = offset_y + img_heights
        end

        love.graphics.draw(s, offset_x, offset_y + button_height + 10)
        offset_x = offset_x + img_widths
    end

    buttons.collection["Collection Header"]:draw()
    buttons.universal["Back"]:draw()
end

local function render_character_select()
    renderBackground()

    --buttons.character_select["Gabe"]:draw(150, 50 + scroll_offset_y * 5)
    --buttons.character_select["Jamie"]:draw(550, 50 + scroll_offset_y * 5)
    --buttons.character_select["Alem"]:draw(950, 50 + scroll_offset_y * 5)
    --
    --buttons.character_select["Michael"]:draw(150, 550 + scroll_offset_y * 5)
    --buttons.character_select["Darcy"]:draw(550, 550 + scroll_offset_y * 5)
    --buttons.character_select["Josh"]:draw(950, 550 + scroll_offset_y * 5)

    buttons.universal["Back"]:draw()
end

local function render_settings()
    renderBackground()
    buttons.universal["Back"]:draw()
    buttons.settings["Toggle Audio"]:draw()
    if audio then
        buttons.settings["Audio Enabled"]:draw()
    else
        buttons.settings["Audio Disabled"]:draw()
    end
end

local function render_level_select()
    local x, y = 45, 100
    renderBackground()
    buttons.universal["Back"]:draw(0, 800)
end

local function inc(x)
    x = x + 1
end

function contains(table, val)
    for _, v in ipairs(table) do
        if v == val then
            return true
        end
    end
    return false
end

local function player_turn()
    local chosen_indices = {}

    if not love.mouse.isDown(1) then
        -- Choose initially/Add cards to hand
        while #player_hand < 8 and not held_card do
            local index = math.random(1, #deck1)
            if not contains(chosen_indices, index) then
                table.insert(player_hand, card(deck1[index] .. ".png", img_widths, img_heights))
                table.insert(chosen_indices, index)
            end
        end
    end
end

local function render_playing_state()
    renderBackground()

    buttons.universal["Back"]:draw()
    buttons.playing["Card Background"]:draw()

    lg.setColor(1, 1, 1)
    lg.draw(playing_field, 245, 15)

    local scale = 2
    lg.scale(scale)
    lg.draw(venom_sprites[opponent_venom+1], (245 - scale*36)/2, 15/2)
    lg.draw(venom_sprites[player_venom+1], (245 - scale*36)/2, (555 - scale*36)/2)
    lg.scale(1/scale)

    if held_card then
        buttons.playing["Info"]:draw()
    end

    local x_pos = reference_window_width * 1.1/6 + 5
    local x_offset = reference_window_width * 0.44/6
    local y_pos = reference_window_height*16.6/24 - 5

    for i, card in ipairs(player_hand) do
        card:draw(x_pos + x_offset * (i-1), y_pos, 0)

        -- x and y positions need to be base on the reference w and h NOT current w and h
        -- bc everything should be placed according to the reference size and is later scaled

        --Store Card Hitboxes
        if i ~= #player_hand then
            card_hitboxes[card] = {x_pos + x_offset * (i-1), y_pos, x_offset, img_heights}
        else
            card_hitboxes[card] = {x_pos + x_offset * (i-1), y_pos, 165, img_heights}
        end
    end

    for k, card in pairs(played_cards) do
        card:draw(playing_field_hitboxes[k][1] + 54, playing_field_hitboxes[k][2] + 34, 0, 0.8)
    end

    if held_card then
        held_card:draw((mouse.x) * reference_window_width / lg.getWidth()  - img_widths/2, (mouse.y)  * reference_window_height / lg.getHeight()  - img_heights/2, 0)
    end
end

local function render_info()
    renderBackground()
    buttons.info["Back"]:draw()
    buttons.info["Info Background"]:draw()

    if info_card then
        info_card:draw(reference_window_width * 0.8/6 + 5, reference_window_height * 1/6, 0, 2.65)
    end

    if mouse_over_info_background then
        lg.setColor(p1, p2, p3)
    else
        lg.setColor(g1, g2, g3)
    end

    local info_card_stats = get_stats(info_card)
    if info_card then
        lg.print("Cost: " .. tostring(info_card_stats.cost), font, reference_window_width / 2, info_background_y + reference_window_height * 0.7/10)
        lg.print("Defense: " .. tostring(info_card_stats.defense), font, reference_window_width / 2, info_background_y + reference_window_height * 1.7/10)
        lg.print("Attack: " .. tostring(info_card_stats.attack), font, reference_window_width / 2, info_background_y + reference_window_height * 3.7/10)
        lg.print("Rarity: " .. tostring(info_card_stats.rarity), font, reference_window_width / 2, info_background_y + reference_window_height * 4.7/10)
        lg.print("Tier: " .. tostring(info_card_stats.border), font, reference_window_width / 2, info_background_y + reference_window_height * 2.7/10)
        lg.print("Ability: " .. tostring(info_card_stats.ability), font, reference_window_width / 2, info_background_y + reference_window_height * 5.7/10)
        lg.print("Lore: " .. tostring(info_card_stats.ability), font, reference_window_width / 2, info_background_y + reference_window_height * 6.7/10)
    end
end

local function abs(x)
    if x < 0 then
        return -x
    else
        return x
    end
end

local function is_hitbox(x, y, hitbox)
    return x * reference_window_width / lg.getWidth() > hitbox[1] and x * reference_window_width / lg.getWidth() <= hitbox[1] + hitbox[3] and y * reference_window_height / lg.getHeight() > hitbox[2] and y * reference_window_height / lg.getHeight() <= hitbox[2] + hitbox[4]
end

local function can_play(card, sector)
    if turn == "Player" then
        return get_stats(card).cost <= player_venom and sector > 4
    else
        return get_stats(card).cost <= opponent_venom and sector < 5
    end
end

local function get_playing_field_hitbox()
    for i, hitbox in ipairs(playing_field_hitboxes) do
        if is_hitbox(mouse.x, mouse.y, hitbox) then
            return hitbox[5]
        end
    end
    return false
end

function love.update(dt)
    time = time + dt

    local aspect_ratio = 1440 / 872
    if abs(w / h - aspect_ratio) > 0.008 then
        -- Width is too wide, so adjust height
        h = w / aspect_ratio
        love.window.setMode(w, h, {resizable=true})
    end

    w = lg.getWidth()
    h = lg.getHeight()

    if game.state["playing"] then
        player_turn()
    end

    mouse.x, mouse.y = love.mouse.getPosition()

    if animation then
        animation_time = animation_time + dt
        if animation_time > animation_length * 3 then
            if animation_next_screen then
                update_game_state(animation_next_screen)
                update_animation_screen(nil)
            end
            animation = false
        end
    else
        animation_time = 0
    end

    if game.state["info"] then
        if buttons.info["Info Background"]:hover() then
            mouse_over_info_background = true
        else
            mouse_over_info_background = false
        end
    end

    if game.state["playing"] then
        if buttons.playing["Info"]:hover() then
            mouse_over_info = true
        else
            mouse_over_info = false
        end

        if buttons.playing["Card Background"]:hover() then
            mouse_over_hand = true
        else
            mouse_over_hand = false
        end
    end

    -- If mouse is let go when a card is in hand put it back in the hand
    if not love.mouse.isDown(1) and held_card then
        -- If card is dropped onto info button
        playing_field_sector = get_playing_field_hitbox()
        if mouse_over_info then
            update_game_state('info')
            info_card = held_card
        elseif playing_field_sector and can_play(held_card, playing_field_sector) then
            -- If card is dropped onto playing field
            played_cards[playing_field_sector] = held_card
            print(playing_field_sector)
            if turn == "Player" then
                player_venom = player_venom - get_stats(held_card).cost
            else
                opponent_venom = opponent_venom - get_stats(held_card).cost
            end
            held_card = nil
            play_sound(hover_sound)
        end

        -- If card is dropped but not played
        table.insert(player_hand, held_card)
        held_card = nil
        play_sound(hover_sound)
    end
end

local function get_game_state()
    for state, val in pairs(game.state) do
        if val == true then
            return state
        end
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    local pressed = false
    if button == 1 then
        -- Check if button on screen is clicked
        for button_name, button in pairs(buttons[get_game_state()]) do
            if button:checkPressed(x, y) then
                pressed = true
            end
        end

        -- Check universal buttons only if a screen button wasn't pressed
        if not pressed then
            for button_name, button in pairs(buttons["universal"]) do
                button:checkPressed(x, y)
            end
        end

        if game.state["playing"] then
            local card_number = 0
            -- Check if card is clicked with no card in hand
            for card, hitbox in pairs(card_hitboxes) do
                card_number = card_number + 1
                if is_hitbox(x, y, hitbox) then
                    -- Find index of clicked card
                    for i, c in pairs(player_hand) do
                        if c == card then
                            table.remove(player_hand, i)
                        end
                    end
                    card_hitboxes[card] = nil
                    held_card = card
                end
            end
        end
    end
end

function love.wheelmoved(x, y)
    if scroll_offset_y + y < 0 then
        scroll_offset_y = scroll_offset_y + y * 2
    else
        scroll_offset_y = 0
    end
end

local function render_game_state()
    local funcs = {
        menu = render_main_menu,
        settings = render_settings,
        level_select = render_level_select,
        character_select = render_character_select,
        collection = render_cards,
        playing = render_playing_state,
        --paused = render_paused_state,
        --ended = render_ended_state,
        info = render_info
    }
    return funcs[get_game_state()]
end

function love.draw()
    lg.scale(lg.getWidth()/reference_window_width)

    --lg.setShader(shader)
    render_game_state()()
    --lg.setShader()

    if debugger_enabled then
        lg.setColor(1, 0, 0)
        lg.printf(tostring(debug), debug_font, 10, 70, reference_window_width)
        lg.print(debug2, 20, 260)
        --lg.print(debug3, 20, 140)

        lg.setColor(1, 1, 1)
    end
    lg.scale(reference_window_width/lg.getWidth())
end
