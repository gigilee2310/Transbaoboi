# Generates the 1024x1024 app icon (run locally with Pillow).
from PIL import Image, ImageDraw, ImageFont
import os

S = 1024
img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
top, bottom = (255, 94, 98), (255, 153, 102)
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))

def font(names, size):
    for n in names:
        try:
            return ImageFont.truetype(n, size)
        except OSError:
            pass
    return ImageFont.load_default()

# Speech bubble
d.rounded_rectangle([150, 200, 874, 720], radius=120, fill=(255, 255, 255))
d.polygon([(300, 700), (260, 860), (440, 710)], fill=(255, 255, 255))
cjk = font(["msyhbd.ttc", "msyh.ttc", "malgunbd.ttf"], 150)
vi = font(["segoeuib.ttf", "arialbd.ttf"], 210)

ko = font(["malgunbd.ttf", "malgun.ttf"], 150)
d.text((330, 330), "文", font=cjk, fill=(255, 120, 100), anchor="mm")
d.text((512, 330), "→", font=vi, fill=(255, 120, 100), anchor="mm")
d.text((694, 330), "한", font=ko, fill=(255, 120, 100), anchor="mm")
d.text((512, 540), "Việt", font=vi, fill=(40, 40, 60), anchor="mm")
out = os.path.join(os.path.dirname(__file__), "..", "Baoboiii", "Resources", "Assets.xcassets", "AppIcon.appiconset", "icon.png")
img.save(out)
print("saved", out)
