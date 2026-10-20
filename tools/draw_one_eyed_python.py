"""Draws the One_Eyed_Python card: a heavily blurred blob on a plain card (run from the project root)."""
from PIL import Image, ImageDraw, ImageFilter

cards = "assets/Snake_Cards/"
im = Image.open(cards + "Skinny_Snake.png").convert("RGBA")
strip = im.crop((12, 12, 153, 82))  # a stretch of the background with no snake on it
for y in range(12, 308, 70):
    im.paste(strip.crop((0, 0, 141, min(70, 308 - y))), (12, y))

blob = Image.new("RGBA", im.size, (0, 0, 0, 0))
d = ImageDraw.Draw(blob)
skin = (226, 160, 140, 255)
d.rounded_rectangle((68, 95, 98, 215), 15, fill=skin)
d.ellipse((46, 190, 84, 230), fill=skin)
d.ellipse((82, 190, 120, 230), fill=skin)
im.alpha_composite(blob.filter(ImageFilter.GaussianBlur(9)))
im.save(cards + "One_Eyed_Python.png")
