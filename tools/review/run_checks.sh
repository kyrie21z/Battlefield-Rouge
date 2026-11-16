#!/usr/bin/env bash
# PR review checks (docs/REVIEW.md, R1–R6).
#
# Usage: tools/review/run_checks.sh [BASE]        BASE defaults to origin/main
# Env:   GODOT=path/to/godot                      defaults to `godot` on PATH
#        REVIEW_LOG_DIR=dir                       defaults to /tmp/review_logs
#        REVIEW_TIER=docs|assets|map|code          force a tier instead of detecting it
#        REVIEW_NO_BASELINE=1                     skip the fixture baseline run on BASE
#
# Prints a short summary only; full logs go to REVIEW_LOG_DIR. Exit code is 1 if
# any check FAILs. WARN lines do not fail the run; the reviewer must look at them.
# Runs on a clean checkout of the PR head. It regenerates maps/ for R5 and then
# restores maps/, and creates a temporary worktree of BASE for the fixture baseline.

set -u
BASE="${1:-origin/main}"
GODOT="${GODOT:-godot}"
command -v "$GODOT" > /dev/null 2>&1 || [ ! -x "$HOME/.local/bin/godot" ] || GODOT="$HOME/.local/bin/godot"
LOG="${REVIEW_LOG_DIR:-/tmp/review_logs}"
TEST_TIMEOUT=900
ROOT="$(git rev-parse --show-toplevel)" || exit 2
cd "$ROOT"
rm -rf "$LOG" && mkdir -p "$LOG"

FAILS=0
WARNS=0
fail() { echo "FAIL  $*"; FAILS=$((FAILS + 1)); }
warn() { echo "WARN  $*"; WARNS=$((WARNS + 1)); }
ok()   { echo "ok    $*"; }
info() { echo "      $*"; }

MB="$(git merge-base "$BASE" HEAD)" || { echo "cannot find merge base with $BASE"; exit 2; }
git diff --name-status -M "$MB" HEAD > "$LOG/changed.txt"
CHANGED="$(cut -f2- "$LOG/changed.txt" | tr '\t' '\n' | sort -u)"
ADDED="$(awk -F'\t' '$1=="A"{print $2} $1 ~ /^R/{print $3}' "$LOG/changed.txt")"
# Added lines of text files, with their file names, for the grep checks below.
git diff -U0 --no-color "$MB" HEAD -- . ':!*.glb' ':!*.blend' ':!*.png' ':!*.jpg' ':!*.jpeg' ':!*.webp' \
	':!*.wav' ':!*.ogg' ':!*.mp3' ':!*.ttf' ':!*.otf' ':!*.zip' \
	| awk '/^\+\+\+ b\//{f=substr($0,7); next} /^\+/ && !/^\+\+\+/{print f ":" substr($0,2)}' > "$LOG/added_lines.txt"

echo "== review checks: $(git rev-parse --short HEAD) against $BASE ($(git rev-parse --short "$MB"))"
info "$(echo "$CHANGED" | grep -c . ) files changed, $(wc -l < "$LOG/added_lines.txt") added text lines"

# ---------------------------------------------------------------- tier
tier_of() {
	case "$1" in
		*.md|docs/*|LICENSE*|.github/*|.cursor/*) echo 0 ;;
		assets/*|art_source/*) echo 1 ;;
		maps/*|tools/gen_zones.py) echo 2 ;;
		*) echo 3 ;;
	esac
}
TIER=0
while IFS= read -r f; do
	[ -z "$f" ] && continue
	t="$(tier_of "$f")"; [ "$t" -gt "$TIER" ] && TIER="$t"
done <<< "$CHANGED"
case "${REVIEW_TIER:-}" in docs) TIER=0;; assets) TIER=1;; map) TIER=2;; code) TIER=3;; esac
TIER_NAME=(docs assets map code)
echo "== tier: ${TIER_NAME[$TIER]}"

# Paths that need Kyrie's own approval (docs/REVIEW.md section 4).
HUMAN="$(echo "$CHANGED" | grep -E '^(ARCHITECTURE\.md|CONTRIBUTING\.md|AGENTS\.md|docs/REVIEW\.md|docs/adr/|autoload/|project\.godot$|components/collision_layers\.gd|\.github/|\.cursor/|tools/review/)' )"
DELETED="$(awk -F'\t' '$1=="D"{print $2}' "$LOG/changed.txt")"
[ -n "$HUMAN" ] && warn "needs Kyrie (protected paths): $(echo $HUMAN | tr ' ' ',')"
[ -n "$DELETED" ] && warn "needs Kyrie (deleted files): $(echo $DELETED | tr ' ' ',')"

# ---------------------------------------------------------------- R1 merge
echo "== R1 merge with $BASE"
if git merge-tree --write-tree --quiet "$BASE" HEAD > /dev/null 2>&1; then
	ok "merges cleanly"
else
	fail "conflicts with $BASE"
	git merge-tree --write-tree --name-only "$BASE" HEAD 2>/dev/null | sed -n '2,20p' | sed 's/^/      /'
fi

# ---------------------------------------------------------------- R6 hygiene (every tier)
echo "== R6 file hygiene"
r6=0
bad_paths="$(echo "$CHANGED" | grep -E '(^|/)\.godot/|(^|/)export_presets\.cfg$|\.(zip|rar|7z|unitypackage)$|^third_party_sources/')"
[ -n "$bad_paths" ] && { fail "files that must not be committed: $(echo $bad_paths)"; r6=1; }
while IFS= read -r f; do
	[ -z "$f" ] && continue
	case "$f" in
		*.gd)
			git cat-file -e "HEAD:$f.uid" 2>/dev/null || { fail "$f has no $f.uid"; r6=1; } ;;
		assets/*.glb|assets/*.gltf)
			git cat-file -e "HEAD:$f.import" 2>/dev/null || { fail "$f has no $f.import"; r6=1; }
			git show HEAD:docs/ASSETS.md 2>/dev/null | grep -qF "$(basename "$f")" \
				|| info "$f has no entry in docs/ASSETS.md (treated as self-made model)" ;;
		assets/*.png|assets/*.jpg|assets/*.jpeg|assets/*.webp|assets/*.wav|assets/*.ogg|assets/*.mp3|assets/*.ttf|assets/*.otf)
			git cat-file -e "HEAD:$f.import" 2>/dev/null || { fail "$f has no $f.import"; r6=1; }
			git show HEAD:docs/ASSETS.md 2>/dev/null | grep -qF "$(basename "$f")" \
				|| { fail "$f is not listed in docs/ASSETS.md"; r6=1; } ;;
	esac
done <<< "$ADDED"
grep -E '^docs/ASSETS\.md:.*(待确认|待定|未知|不明|TBD|TODO|unknown|\?\?)' "$LOG/added_lines.txt" > "$LOG/r6_license.txt" \
	&& { fail "docs/ASSETS.md has an unconfirmed source or license:"; head -5 "$LOG/r6_license.txt" | sed 's/^/      /'; r6=1; }
grep -E '(/home/[a-z]|/Users/[A-Za-z]|[A-Z]:\\\\(Users|Program)|/mnt/[a-z]/)' "$LOG/added_lines.txt" | grep -vE '^(docs|tools/review)/' > "$LOG/r6_paths.txt" \
	&& { fail "absolute local paths outside docs/:"; head -5 "$LOG/r6_paths.txt" | sed 's/^/      /'; r6=1; }
grep -E '(BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|(api[_-]?key|secret|password|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,})' "$LOG/added_lines.txt" | grep -v '^tools/review/' > "$LOG/r6_secrets.txt" \
	&& { fail "looks like a secret:"; cut -c1-120 "$LOG/r6_secrets.txt" | head -5 | sed 's/^/      /'; r6=1; }
[ "$r6" = 0 ] && ok "no hygiene problems"

# Architecture hints from added lines. Heuristics: WARN, the reviewer decides.
grep -E '^(components|weapons|actors)/[^:]*\.gd:.*\bRunState\b' "$LOG/added_lines.txt" > "$LOG/arch_runstate.txt" \
	&& { warn "rule 1: RunState used in components/weapons/actors:"; head -5 "$LOG/arch_runstate.txt" | sed 's/^/      /'; }
grep -E '^(components|weapons|actors|zone|buffs)/[^:]*\.gd:.*(get_node\("/root|get_tree\(\)\.get_nodes_in_group|get_first_node_in_group)' "$LOG/added_lines.txt" > "$LOG/arch_lookup.txt" \
	&& { warn "rule 1: path or group lookup:"; head -5 "$LOG/arch_lookup.txt" | sed 's/^/      /'; }
grep -E '^(components|weapons|actors)/[^:]*\.gd:.*\b(ZoneDirector|zone_director|HUD|ui/)' "$LOG/added_lines.txt" > "$LOG/arch_direction.txt" \
	&& { warn "rule 4: lower layer refers to zone/ui:"; head -5 "$LOG/arch_direction.txt" | sed 's/^/      /'; }
grep -E '^(zone|actors|components|weapons|buffs)/[^:]*\.gd:.*(randomize\(\)|Time\.get_ticks_|Time\.get_unix_time|OS\.get_unix_time|Time\.get_datetime)' "$LOG/added_lines.txt" > "$LOG/arch_clock.txt" \
	&& { warn "rule 5 (AC-07): wall clock or randomize():"; head -5 "$LOG/arch_clock.txt" | sed 's/^/      /'; }
grep -E '\.gd:.*collision_(layer|mask)[[:space:]]*=[[:space:]]*[0-9]' "$LOG/added_lines.txt" > "$LOG/arch_layers.txt" \
	&& { warn "collision layer as a number, use CollisionLayers:"; head -5 "$LOG/arch_layers.txt" | sed 's/^/      /'; }

# ---------------------------------------------------------------- Godot steps
run_godot() { # name, timeout, args...
	local name="$1" t="$2"; shift 2
	timeout "$t" "$GODOT" --headless "$@" > "$LOG/$name.log" 2>&1
}
# Leak reports printed at exit exist on main already (weapons_test); they are not PR errors.
godot_errors() {
	grep -E '^(SCRIPT )?ERROR|^USER ERROR|Parse Error|Failed to load' "$1" \
		| grep -vE 'resources still in use at exit|ObjectDB instances leaked at exit|RID allocations .* leaked at exit'
}

if [ "$TIER" -ge 1 ]; then
	echo "== R2 import"
	if ! command -v "$GODOT" > /dev/null 2>&1 && [ ! -x "$GODOT" ]; then
		fail "Godot not found (set GODOT)"
	else
		run_godot import 600 --import --path .
		rc=$?
		errs="$(godot_errors "$LOG/import.log")"
		if [ "$rc" != 0 ] || [ -n "$errs" ]; then
			fail "import exit $rc, $(echo "$errs" | grep -c .) error lines"
			echo "$errs" | sort | uniq -c | sort -rn | head -10 | sed 's/^/      /'
		else
			ok "imports with no errors ($("$GODOT" --version 2>/dev/null | head -1))"
		fi
	fi
fi

if [ "$TIER" -ge 2 ] && echo "$CHANGED" | grep -qE '^(maps/|tools/gen_zones\.py)'; then
	echo "== R5 maps come from tools/gen_zones.py"
	if python3 tools/gen_zones.py > "$LOG/gen_zones.log" 2>&1; then
		drift="$(git status --porcelain -- maps/)"
		if [ -n "$drift" ]; then
			fail "regenerating changes maps/ (edited by hand, or not regenerated):"
			echo "$drift" | head -10 | sed 's/^/      /'
		else
			ok "regenerated maps/ match the commit"
		fi
		git checkout -q -- maps/ && git clean -qfd -- maps/
	else
		fail "tools/gen_zones.py failed:"; tail -5 "$LOG/gen_zones.log" | sed 's/^/      /'
	fi
fi

fixture_hashes() { sed -n '/^== hashes/,$p' "$1" | grep -E '^   FX-' ; }

if [ "$TIER" -ge 3 ]; then
	echo "== R3 headless tests"
	pass=0; total=0
	for t in tests/*_test.tscn; do
		n="$(basename "$t" .tscn)"; total=$((total + 1))
		extra=(); [ "$n" = fixture_test ] && extra=(--fixed-fps 60)
		s=$SECONDS
		run_godot "$n" "$TEST_TIMEOUT" "${extra[@]}" --path . "res://$t"
		rc=$?
		# Tests quit with 0 only when every check passed; the result line varies.
		last="$(grep -E 'ALL PASSED|FAIL \(|[0-9]+ failed' "$LOG/$n.log" | tail -1 | cut -c1-120)"
		errs="$(godot_errors "$LOG/$n.log" | grep -c .)"
		if [ "$rc" = 0 ]; then
			pass=$((pass + 1))
			[ "$errs" != 0 ] && warn "$n passed but printed $errs error lines (log: $LOG/$n.log)"
		else
			[ "$rc" = 124 ] && last="timed out after ${TEST_TIMEOUT}s"
			fail "$n exit $rc: ${last:-no result line} ($((SECONDS - s))s)"
			grep -E '\[FAIL\]|SCRIPT ERROR|^ERROR' "$LOG/$n.log" | head -8 | cut -c1-160 | sed 's/^/      /'
		fi
	done
	ok "$pass/$total test scenes passed"

	echo "== R4 fixture hashes (AC-07)"
	fixture_hashes "$LOG/fixture_test.log" > "$LOG/hashes_head.txt"
	if [ ! -s "$LOG/hashes_head.txt" ]; then
		fail "no '== hashes' section in fixture_test output"
	elif [ "${REVIEW_NO_BASELINE:-0}" = 1 ]; then
		info "baseline skipped; head hashes:"; sed 's/^/      /' "$LOG/hashes_head.txt"
	else
		# Hashes depend on the machine, so compare with BASE run here, not with docs.
		wt="$(mktemp -d)/base"
		if git worktree add -q --detach "$wt" "$BASE" > /dev/null 2>&1; then
			( cd "$wt" && timeout 600 "$GODOT" --headless --import --path . > "$LOG/base_import.log" 2>&1
			  timeout "$TEST_TIMEOUT" "$GODOT" --headless --fixed-fps 60 --path . res://tests/fixture_test.tscn > "$LOG/fixture_base.log" 2>&1 )
			git worktree remove --force "$wt" > /dev/null 2>&1
			fixture_hashes "$LOG/fixture_base.log" > "$LOG/hashes_base.txt"
			if [ ! -s "$LOG/hashes_base.txt" ]; then
				warn "baseline fixture run on $BASE produced no hashes"
			elif diff -q "$LOG/hashes_base.txt" "$LOG/hashes_head.txt" > /dev/null; then
				ok "hashes unchanged from $BASE"
			else
				warn "needs Kyrie (fixture hashes changed; the PR must explain why):"
				diff "$LOG/hashes_base.txt" "$LOG/hashes_head.txt" | grep -E '^[<>]' | sed 's/^/      /'
			fi
		else
			warn "could not create a worktree for $BASE; baseline skipped"
		fi
	fi
fi

echo "== summary: tier ${TIER_NAME[$TIER]}, $FAILS FAIL, $WARNS WARN, logs in $LOG"
[ "$FAILS" = 0 ]
