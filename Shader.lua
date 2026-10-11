-- Balatro-style background: the snake picture swirls apart and becomes a looping paint swirl.
local MORPH_TIME = 8    -- seconds for the picture to dissolve into pure colour
local SWIRL_SPEED = 1   -- animation speed of the swirl
local PIXELS_TALL = 110 -- paint resolution (pixel-art look)
local SNAKE_MASK = 0.15  -- g-b threshold separating snake (green/tan) from the purple background
local SOFTNESS = 0.45   -- colour blend width between palette colours (small = sharper bands, must be > 0)

local src = [[
uniform float time;
const vec3 c0 = vec3(0.247, 0.247, 0.455); // navy (63,63,116)
const vec3 c1 = vec3(0.463, 0.259, 0.541); // purple (118,66,138)
const vec3 c2 = vec3(0.373, 0.804, 0.894); // cyan (95,205,228)
const vec3 c3 = vec3(0.600, 0.898, 0.314); // green (153,229,80)
const vec3 dark = vec3(0.09, 0.08, 0.17);

vec2 mirror(vec2 x) { return 1.0 - abs(1.0 - mod(x, 2.0)); }

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float m = smoothstep(0.0, 1.0, time / MORPH);
    float speed = time * SPEED;
    vec2 size = love_ScreenSize.xy;
    vec2 uv0 = sc / size;
    vec2 grid = vec2(PIXELS * size.x / size.y, PIXELS);
    vec2 puv = mix(uv0, (floor(uv0 * grid) + 0.5) / grid, smoothstep(0.5, 0.9, m));

    // polar swirl, strength s (0 = identity)
    vec2 q = (puv - 0.5) * vec2(size.x / size.y, 1.0);
    float r = length(q);
    float s = m;
    float a = atan(q.y, q.x) + s * ((2.2 + 0.4 * min(6.0, speed)) * r - 1.0 - speed * 0.05);
    vec2 sw = vec2(cos(a), sin(a)) * r;
    vec2 imgOff = (sw - q) * vec2(size.y / size.x, 1.0);

    // iterative domain warp (full strength, for the paint)
    vec2 uv = sw * 30.0;
    vec2 uv2 = vec2(uv.x + uv.y);
    vec2 w = vec2(0.0);
    for (int i = 0; i < 5; i++) {
        uv2 += sin(max(uv.x, uv.y)) + uv;
        vec2 d = 0.5 * vec2(cos(5.1123314 + 0.353 * uv2.y + speed * 0.131121), sin(uv2.x - 0.113 * speed));
        uv += d; w += d;
        uv -= cos(uv.x + uv.y) - sin(uv.x * 0.711 - uv.y);
    }
    // the picture, smeared along the swirl; snake = pixels with g > b (green/tan), purple background has g < b
    vec2 iuv = tc + imgOff * 1.5 + s * 0.02 * w;
    vec3 img = Texel(tex, mirror(iuv)).rgb;
    float snake = smoothstep(MASK - 0.06, MASK + 0.06, img.g - img.b);
    // snake becomes the light end of the palette (cyan/green), background the dark end (navy/purple)
    float p = clamp(length(uv) * 0.035 * 1.8, 0.0, 3.0) * 0.5 + 1.5 * snake;
    vec3 paint = mix(dark, c0, smoothstep(0.4 - SOFT, 0.4 + SOFT, p));
    paint = mix(paint, c1, smoothstep(0.9 - SOFT, 0.9 + SOFT, p));
    paint = mix(paint, c2, smoothstep(1.6 - SOFT, 1.6 + SOFT, p));
    paint = mix(paint, c3, 0.7 * smoothstep(2.3 - SOFT, 2.3 + SOFT, p));

    paint = mix(paint, paint * (0.5 + img), 0.5 * (1.0 - m)); // tint paint with picture colours
    float gone = clamp((m - 0.15) * 1.3 + (p - 1.5) * 0.15 * m, 0.0, 1.0);
    gone = smoothstep(0.0, 1.0, gone);
    return vec4(mix(img, paint, gone), 1.0) * color;
}
]]

local function num(x) return string.format("%.4f", x) end
src = src:gsub("MORPH", num(MORPH_TIME)):gsub("SPEED", num(SWIRL_SPEED)):gsub("PIXELS", num(PIXELS_TALL)):gsub("MASK", num(SNAKE_MASK)):gsub("SOFT", num(SOFTNESS))

return love.graphics.newShader(src)
