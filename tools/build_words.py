import json, re, sys

def main(src: str, dst: str) -> None:
    pat = re.compile(r"^[A-Z]{3,}$")
    seen = set()
    with open(src, encoding="utf-8") as f:
        for line in f:
            w = line.strip().upper()
            if pat.match(w) and w not in seen:
                seen.add(w)
    words = sorted(seen)
    with open(dst, "w", encoding="utf-8") as f:
        json.dump({"words": words}, f, separators=(",", ":"))
    print(f"wrote {len(words)} words to {dst}")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])