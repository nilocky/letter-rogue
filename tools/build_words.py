import json, re, sys

POS_MAP = {"n": 1, "v": 2, "a": 4, "r": 8}
FALLBACK = 16


def main(src: str, dst: str) -> None:
    try:
        from nltk.corpus import wordnet as wn
    except (ImportError, LookupError):
        wn = None

    pat = re.compile(r"^[A-Z]{3,}$")

    with open(src, encoding="utf-8") as f:
        raw = json.load(f)

    words_in: list = raw if isinstance(raw, list) else raw.get("words", raw)

    seen: set = set()
    out: list = []
    for w in words_in:
        wu = w.upper() if isinstance(w, str) else w
        if not pat.match(wu) or wu in seen:
            continue
        seen.add(wu)
        pos = FALLBACK
        definition = ""
        if wn is not None:
            synsets = wn.synsets(wu.lower())
            if synsets:
                s = synsets[0]
                pos = POS_MAP.get(s.pos(), FALLBACK)
                definition = s.definition()[:60]
        out.append({"w": wu, "pos": pos, "def": definition})

    with open(dst, "w", encoding="utf-8") as f:
        json.dump({"words": out}, f, separators=(",", ":"))

    print(f"wrote {len(out)} words to {dst}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
