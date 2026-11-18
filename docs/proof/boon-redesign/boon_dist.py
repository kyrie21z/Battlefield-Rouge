import re, glob, random
from collections import defaultdict

W = [6,4,2,1,1]
SIN = ['sloth','fear','wrath','sorrow','dual']

def parse(path):
    txt = open(path, encoding='utf-8').read()
    c = {'prereq':[], 'any':[], 'sins':[], 'tsin':-1, 'tcount':0, 'rarity':0, 'core':True, 'sin':0, 'id':'', 'slot':0}
    for line in txt.splitlines():
        m = re.match(r'id = "(.*)"', line)
        if m: c['id']=m.group(1)
        m = re.match(r'rarity = (\d+)', line)
        if m: c['rarity']=int(m.group(1))
        m = re.match(r'core = (\w+)', line)
        if m: c['core']=(m.group(1)=='true')
        m = re.match(r'sin = (\d+)', line)
        if m: c['sin']=int(m.group(1))
        m = re.match(r'slot = (\d+)', line)
        if m: c['slot']=int(m.group(1))
        m = re.match(r'required_trait_sin = (-?\d+)', line)
        if m: c['tsin']=int(m.group(1))
        m = re.match(r'required_trait_count = (\d+)', line)
        if m: c['tcount']=int(m.group(1))
        m = re.match(r'prerequisites = Array\[String\]\(\[(.*)\]\)', line)
        if m: c['prereq']=[x.strip().strip('"') for x in m.group(1).split(',') if x.strip()]
        m = re.match(r'prerequisite_any = Array\[String\]\(\[(.*)\]\)', line)
        if m: c['any']=[x.strip().strip('"') for x in m.group(1).split(',') if x.strip()]
        m = re.match(r'required_sins = Array\[int\]\(\[(.*)\]\)', line)
        if m: c['sins']=[int(x) for x in m.group(1).split(',') if x.strip()]
    return c

cards = [parse(p) for p in glob.glob('buffs/resources/*/*.tres') if 'pool' not in p]
by_id = {c['id']: c for c in cards}

def has_sin_core(owned, sin):
    return any(by_id[i]['core'] and by_id[i]['sin']==sin for i in owned)

def slot_taken(owned, slot):
    return any(by_id[i]['core'] and by_id[i]['slot']==slot for i in owned)

def can_equip(owned, c):
    if c['id'] in owned: return False
    if not c['core'] and c['rarity']!=4 and not has_sin_core(owned, c['sin']):
        return False
    for i in c['prereq']:
        if i not in owned: return False
    if c['any'] and not any(i in owned for i in c['any']): return False
    for s in c['sins']:
        if not has_sin_core(owned, s): return False
    n = sum(1 for i in owned if by_id[i]['rarity']!=4 and (c['tsin']<0 or by_id[i]['sin']==c['tsin']))
    return n >= c['tcount']

def weight(c, owned):
    base = W[c['rarity']]
    if not c['core'] or c['rarity']==4:
        return base
    if slot_taken(owned, c['slot']):
        return base*2 if not has_sin_core(owned, c['sin']) else base
    return base

def draw(pool, owned, rng, count):
    picked = []
    remaining = list(pool)
    while len(picked) < count and remaining:
        total = sum(weight(c, owned) for c in remaining)
        if total <= 0: break
        r = rng.randint(1, total)
        chosen = 0
        for i, c in enumerate(remaining):
            r -= weight(c, owned)
            if r <= 0:
                chosen = i; break
        picked.append(remaining.pop(chosen))
    return picked

def pick(pool, owned, rng):
    swaps = [c for c in pool if c['core'] and c['rarity']!=4 and slot_taken(owned, c['slot'])]
    frees = [c for c in pool if not (c['core'] and c['rarity']!=4 and slot_taken(owned, c['slot']))]
    out = []
    if swaps and frees:
        out += draw(swaps, owned, rng, 1)
        out += draw(frees, owned, rng, 3-len(out))
        if len(out) < 3:
            out += draw(swaps, owned, rng, 3-len(out))
    else:
        out += draw(pool, owned, rng, 3)
    return out

def report(name, owned):
    pool = [c for c in cards if can_equip(owned, c)]
    rng = random.Random(23)
    hits = defaultdict(int); repl = 0; picks = 0; all_repl = 0; rounds = 30000
    untouched = set(SIN[:4]) - {SIN[by_id[i]['sin']] for i in owned if by_id[i]['core']}
    untouched_core_seen = 0
    for _ in range(rounds):
        got = pick(pool, owned, rng)
        flags = []
        for c in got:
            hits[SIN[c['sin']]] += 1; picks += 1
            is_repl = c['core'] and c['rarity']!=4 and slot_taken(owned, c['slot'])
            flags.append(is_repl)
            if is_repl: repl += 1
            if is_repl and SIN[c['sin']] in untouched:
                untouched_core_seen += 1
        if flags and all(flags):
            all_repl += 1
    share = "  ".join(f"{s}:{100*hits[s]/picks:4.1f}%" for s in SIN[:4] if hits[s])
    print(f"\n=== {name} ===")
    print(f"  名额占比  {share}")
    print(f"  替换卡    {100*repl/picks:4.1f}%    三张全替换 {100*all_repl/rounds:4.1f}%")
    print(f"  每轮出现'未投资系核心'的轮次: {100*untouched_core_seen/rounds:4.1f}%")

report("截图局面：枪=恐惧 刃=怠惰 冲刺=恐惧（三槽满）",
       {'fear_gaze_pierce','sloth_blade_cleave','fear_tremor_decoy'})
report("三槽 = 怠惰枪 + 恐惧枪 + 愤怒枪（悲伤未投资）",
       {'sloth_gun_pulse','fear_gaze_pierce','wrath_gun_cannon'})
report("开局空手", set())
