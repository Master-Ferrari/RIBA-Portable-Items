# -*- coding: utf-8 -*-
"""Собирает данные о предметах мода RIBA Portable Items в JSON для HTML-страницы."""
import base64, io, json, os, re, sys
import xml.etree.ElementTree as ET
from PIL import Image

SRC   = r"C:\Users\Pecarnya-REREMASTER\YandexDisk\_active\_4\RIBA"
BUILD = r"F:\SteamLibrary\steamapps\common\Barotrauma\LocalMods\RIBA Portable Items"
GAME  = r"F:\SteamLibrary\steamapps\common\Barotrauma"
OUT   = os.path.dirname(os.path.abspath(__file__))

FILES = ["Items.xml", "Items2.xml", "Items3.xml", "Items4.xml", "Items6.xml"]

def low(d):
    return {k.lower(): v for k, v in d.items()}

# ---------------------------------------------------------------- локализация
def load_loc(lang):
    names, descs = {}, {}
    for suffix in ("", "2"):
        p = os.path.join(SRC, "Localization", f"{lang}{suffix}.xml")
        if not os.path.exists(p):
            continue
        txt = open(p, encoding="utf-8-sig").read()
        for m in re.finditer(r"<entityname\.([^>]+?)>(.*?)</entityname\.\1>", txt, re.S):
            names[m.group(1).lower()] = m.group(2).strip()
        for m in re.finditer(r"<entitydescription\.([^>]+?)>(.*?)</entitydescription\.\1>", txt, re.S):
            descs[m.group(1).lower()] = m.group(2).strip()
    return names, descs

EN_N, EN_D = load_loc("English")
RU_N, RU_D = load_loc("Russian")

# ------------------------------------------------- имена ванильных материалов
VANILLA_NAMES = {}
def load_vanilla_names():
    p = os.path.join(GAME, "Content", "Texts", "English", "EnglishVanilla.xml")
    cand = [p]
    tdir = os.path.join(GAME, "Content", "Texts", "English")
    if os.path.isdir(tdir):
        cand = [os.path.join(tdir, f) for f in os.listdir(tdir) if f.endswith(".xml")]
    for f in cand:
        try:
            txt = open(f, encoding="utf-8-sig", errors="ignore").read()
        except Exception:
            continue
        for m in re.finditer(r"<entityname\.([^>]+?)>(.*?)</entityname\.\1>", txt, re.S):
            VANILLA_NAMES.setdefault(m.group(1).lower(), m.group(2).strip())
load_vanilla_names()

def pretty(ident):
    k = ident.lower()
    return EN_N.get(k) or VANILLA_NAMES.get(k) or ident

# ------------------------------------------------------------------- иконки
_tex_cache = {}
def load_tex(path):
    if path in _tex_cache:
        return _tex_cache[path]
    img = None
    try:
        img = Image.open(path).convert("RGBA")
    except Exception:
        img = None
    _tex_cache[path] = img
    return img

def resolve_tex(texture):
    t = texture.replace("\\", "/")
    if t.lower().startswith("%moddir%/"):
        return os.path.join(SRC, *t[len("%moddir%/"):].split("/"))
    return os.path.join(GAME, *t.split("/"))

def crop_icon(texture, rect, box=72):
    if not texture or not rect:
        return None
    img = load_tex(resolve_tex(texture))
    if img is None:
        return None
    try:
        x, y, w, h = [int(float(v)) for v in rect.split(",")]
    except Exception:
        return None
    if w <= 0 or h <= 0:
        return None
    x2, y2 = min(x + w, img.width), min(y + h, img.height)
    if x >= img.width or y >= img.height or x2 <= x or y2 <= y:
        return None
    sub = img.crop((max(x, 0), max(y, 0), x2, y2))
    bb = sub.getbbox()
    if bb:
        sub = sub.crop(bb)
    if sub.width == 0 or sub.height == 0:
        return None
    scale = min(box / sub.width, box / sub.height, 1.0)
    nw, nh = max(1, int(round(sub.width * scale))), max(1, int(round(sub.height * scale)))
    sub = sub.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (box, box), (0, 0, 0, 0))
    canvas.paste(sub, ((box - nw) // 2, (box - nh) // 2), sub)
    canvas = canvas.quantize(colors=128, method=Image.FASTOCTREE).convert("RGBA").quantize(
        colors=128, method=Image.FASTOCTREE)
    buf = io.BytesIO()
    canvas.save(buf, format="PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

def pick_icon(el):
    """InventoryIcon приоритетнее, иначе Sprite."""
    for tag in ("InventoryIcon", "Sprite"):
        for child in el:
            if child.tag.lower() == tag.lower():
                a = low(child.attrib)
                icon = crop_icon(a.get("texture"), a.get("sourcerect"))
                if icon:
                    return icon, a.get("texture"), a.get("sourcerect"), tag
    return None, None, None, None

# ------------------------------------------------------- разбор собранного XML
def parse_block_fabricate(el):
    a = low(el.attrib)
    out = {
        "requiredtime": a.get("requiredtime"),
        "fabricators": a.get("suitablefabricators", ""),
        "outamount": a.get("amount"),
        "skills": [],
        "items": [],
    }
    for c in el:
        ca = low(c.attrib)
        t = c.tag.lower()
        if t == "requiredskill":
            out["skills"].append({"id": ca.get("identifier", ""), "level": ca.get("level", "0")})
        elif t in ("requireditem", "item"):
            ident = ca.get("identifier") or ca.get("tag") or ca.get("items") or ""
            out["items"].append({
                "id": ident,
                "name": pretty(ident),
                "amount": ca.get("amount", "1"),
                "bytag": bool(ca.get("tag") and not ca.get("identifier")),
                "condition": ca.get("mincondition") or ca.get("usecondition") or None,
            })
    return out

def parse_block_deconstruct(el):
    a = low(el.attrib)
    out = {"time": a.get("time"), "chooserandom": a.get("chooserandom"), "items": []}
    for c in el:
        ca = low(c.attrib)
        if c.tag.lower() != "item":
            continue
        ident = ca.get("identifier") or ca.get("tag") or ""
        out["items"].append({
            "id": ident,
            "name": pretty(ident),
            "amount": ca.get("amount", "1"),
            "outcondition": ca.get("outcondition"),
            "commonness": ca.get("commonness"),
        })
    return out

def parse_block_price(el):
    a = low(el.attrib)
    out = {
        "baseprice": a.get("baseprice"),
        "sold": a.get("sold", "true").lower() != "false",
        "minavailable": a.get("minavailable"),
        "maxavailable": a.get("maxavailable"),
        "stores": [],
    }
    for c in el:
        if c.tag.lower() != "price":
            continue
        ca = low(c.attrib)
        out["stores"].append({
            "where": ca.get("locationtype") or ca.get("storeidentifier") or "?",
            "multiplier": ca.get("multiplier"),
            "sold": ca.get("sold", "true").lower() != "false",
            "minavailable": ca.get("minavailable"),
            "maxavailable": ca.get("maxavailable"),
        })
    return out

def first(el, tag):
    for c in el:
        if c.tag.lower() == tag.lower():
            return c
    return None

items = {}
order = []
for fn in FILES:
    p = os.path.join(BUILD, "Xml", fn)
    if not os.path.exists(p):
        print("!! нет собранного", fn); continue
    root = ET.parse(p).getroot()
    nodes = root.findall(".//Item") if root.tag.lower() == "override" else list(root)
    for el in root.iter():
        pass
    # верхний уровень: <Items><Item .../></Items>
    tops = [c for c in root if c.tag.lower() == "item"]
    if not tops:
        tops = [c for c in root.iter() if c.tag.lower() == "item" and c.get("identifier")]
    for el in tops:
        a = low(el.attrib)
        ident = a.get("identifier")
        if not ident:
            continue
        icon, tex, rect, icon_src = pick_icon(el)
        fab, dec, pr = first(el, "Fabricate"), first(el, "Deconstruct"), first(el, "Price")
        holdable = first(el, "Holdable")
        ha = low(holdable.attrib) if holdable is not None else {}
        rec = {
            "id": ident,
            "name_en": EN_N.get(ident.lower()) or a.get("name") or ident,
            "name_ru": RU_N.get(ident.lower()) or "",
            "desc_en": EN_D.get(ident.lower()) or "",
            "desc_ru": RU_D.get(ident.lower()) or "",
            "buildfile": fn,
            "category": a.get("category", ""),
            "tags": a.get("tags", ""),
            "icon": icon,
            "icon_tex": tex,
            "icon_rect": rect,
            "icon_from": icon_src,
            "attachable": ha.get("attachable", "").lower() == "true",
            "limited": ha.get("limitedattachable", "").lower() == "true",
            "pickingtime": ha.get("pickingtime"),
            "fabricate": parse_block_fabricate(fab) if fab is not None else None,
            "deconstruct": parse_block_deconstruct(dec) if dec is not None else None,
            "price": parse_block_price(pr) if pr is not None else None,
        }
        items[ident.lower()] = rec
        order.append(ident.lower())

# ------------------------------------------------ разбор исходников: файл+строка
import lxml.etree as LET

SRC_XML = os.path.join(SRC, "Xml")
src_info = {}
BLOCK_TAGS = ("Fabricate", "Deconstruct", "Price", "Sprite", "InventoryIcon",
              "Holdable", "Body", "ItemContainer")

for fn in FILES + ["Items5.xml"]:
    p = os.path.join(SRC_XML, fn)
    if not os.path.exists(p):
        continue
    root = LET.parse(p).getroot()
    # верхний уровень предметов: <Items> или <Override><Items>
    holders = [root] if root.tag.lower() == "items" else root.findall(".//Items")
    for holder in holders:
        for el in holder:
            if not isinstance(el.tag, str):
                continue                      # комментарий
            t = el.tag.lower()
            if t not in ("importitem", "item"):
                continue
            a = low(el.attrib)
            if t == "importitem":
                ident, kind = None, "import"
                for c in el:
                    if isinstance(c.tag, str) and c.tag.lower() == "editattributes":
                        ca = low(c.attrib)
                        if ca.get("identifier"):
                            ident = ca["identifier"]
                            break
                if not ident:
                    ident = a.get("item")     # ImportItem без переименования
                vanilla = (a.get("file", ""), a.get("item", ""))
            else:
                ident, kind, vanilla = a.get("identifier"), "plain", ("", "")
            if not ident:
                continue
            localb = sorted({c.tag for c in el
                             if isinstance(c.tag, str) and c.tag in BLOCK_TAGS})
            src_info[ident.lower()] = {
                "file": fn, "line": el.sourceline, "vanilla": vanilla,
                "kind": kind, "local": localb, "ident": ident,
                "inmanifest": fn in FILES,
            }

for k, rec in items.items():
    si = src_info.get(k)
    rec["srcfile"] = si["file"] if si else None
    rec["srcline"] = si["line"] if si else None
    rec["vanilla_file"] = si["vanilla"][0] if si else ""
    rec["vanilla_item"] = si["vanilla"][1] if si else ""
    rec["local_blocks"] = si["local"] if si else []
    rec["origin"] = si["kind"] if si else "?"

# --------------------------------------------- таланты: разблокировка рецептов
TALENT_RECIPES = {}
try:
    troot = LET.parse(os.path.join(SRC_XML, "Talents.xml")).getroot()
    for tal in troot.iter():
        if not isinstance(tal.tag, str) or tal.tag.lower() != "talent":
            continue
        tid = low(tal.attrib).get("identifier", "?")
        for r in tal.iter():
            if isinstance(r.tag, str) and r.tag.lower() == "addedrecipe":
                ii = low(r.attrib).get("itemidentifier")
                if ii:
                    TALENT_RECIPES.setdefault(ii.lower(), []).append(tid)
except Exception as e:
    print("!! таланты:", e)

for k, rec in items.items():
    rec["talents"] = TALENT_RECIPES.get(k, [])

# ------------------------------------------------------------ Buyable vs DIY
for rec in items.values():
    p = rec["price"]
    ident = rec["id"].lower()
    if "buyable" in ident:
        rec["variant"] = "Buyable"
    elif p and p["sold"] and p["stores"]:
        rec["variant"] = "Buyable"
    elif p and not p["sold"]:
        rec["variant"] = "DIY"
    elif rec["fabricate"]:
        rec["variant"] = "DIY"
    else:
        rec["variant"] = "—"
    rec["craftable"] = bool(rec["fabricate"])
    rec["instore"] = bool(p and p["sold"] and p["stores"])
    rec["orphan"] = not rec["craftable"] and not rec["instore"]

# ------------------------------------------- каталог компонентов (иконки+имена)
def scan_vanilla_items():
    """identifier -> (файл, элемент) по всем Content/Items ванили."""
    idx = {}
    base = os.path.join(GAME, "Content", "Items")
    for dirpath, _dirs, files in os.walk(base):
        for f in files:
            if not f.lower().endswith(".xml"):
                continue
            fp = os.path.join(dirpath, f)
            try:
                r = LET.parse(fp).getroot()
            except Exception:
                continue
            for el in r.iter():
                if not isinstance(el.tag, str):
                    continue
                ident = low(el.attrib).get("identifier")
                if not ident:
                    continue
                # настоящее определение префаба несёт свой спрайт; вложенные
                # <Item identifier="steel"/> внутри Deconstruct — нет
                has_sprite = any(isinstance(c.tag, str) and
                                 c.tag.lower() in ("sprite", "inventoryicon") for c in el)
                k = ident.lower()
                if has_sprite or k not in idx:
                    if has_sprite or k not in idx:
                        prev = idx.get(k)
                        prev_sprite = prev is not None and any(
                            isinstance(c.tag, str) and c.tag.lower() in ("sprite", "inventoryicon")
                            for c in prev)
                        if has_sprite or not prev_sprite:
                            idx[k] = el
    return idx

VANILLA_IDX = scan_vanilla_items()
print("ванильных префабов:", len(VANILLA_IDX))

used = set()
for rec in items.values():
    for b in ("fabricate", "deconstruct"):
        if rec[b]:
            for it in rec[b]["items"]:
                used.add(it["id"].lower())

catalog = {}
for cid in sorted(used):
    if cid in items:
        catalog[cid] = {"id": items[cid]["id"], "name": items[cid]["name_en"],
                        "icon": items[cid]["icon"], "mod": True}
        continue
    el = VANILLA_IDX.get(cid)
    icon = None
    if el is not None:
        icon, _t, _r, _s = pick_icon(el)
    catalog[cid] = {"id": (low(el.attrib).get("identifier") if el is not None else cid),
                    "name": pretty(cid), "icon": icon, "mod": False}

# короткий словарь для автодополнения: всё, что можно вписать в рецепт
suggest = sorted({v["id"] for v in catalog.values()} |
                 {rec["id"] for rec in items.values()} |
                 {low(e.attrib).get("identifier") for k, e in VANILLA_IDX.items()
                  if k in ("steel","aluminium","plastic","copper","tin","titanium","silicon",
                           "carbon","phosphorus","organicfiber","dementonite","lead","zinc",
                           "sulphuricacid","chlorine","oxygenite","fulgurium","incendium",
                           "titaniumaluminiumalloy","batterycell","wire","fpgacircuit",
                           "memorycomponent","wificomponent","detonator","screwdriver")})
print("каталог компонентов:", len(catalog), "| без иконки:",
      [k for k, v in catalog.items() if not v["icon"]])

missing_src = [k for k in items if not items[k]["srcfile"]]
no_icon = [k for k in items if not items[k]["icon"]]
print("предметов:", len(items))
print("без привязки к исходнику:", missing_src)
print("без иконки:", no_icon)
print("в исходниках, но не в сборке:", sorted(set(src_info) - set(items)))

data = {"items": [items[k] for k in order], "catalog": catalog,
        "suggest": suggest, "mod": "RIBA Portable Items"}
with open(os.path.join(OUT, "items.json"), "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=1)
print("json:", os.path.getsize(os.path.join(OUT, "items.json")) // 1024, "KB")
