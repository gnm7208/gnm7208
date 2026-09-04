# Profile README switcher — implementation log

## What this is

`github.com/gnm7208/gnm7208` serves whatever sits in `README.md` as the profile
page. This directory holds several complete READMEs; `scripts/readme-switch.sh`
copies one of them over `README.md` and records the choice in `active.txt`.
Nothing is generated or templated — each variant is a finished file you can
edit by hand.

```
README.md                   <- what GitHub actually serves (a copy)
readmes/
  active.txt                <- name of the variant currently copied out
  00-current.md             <- the README that was live before this existed
  a-quiet.md                <- prose-led, no badge wall, one greyscale stats card
  b-signal.md               <- full badge wall, per-project chips, both stats cards
  c-terminal.md             <- shell-session framing, code fences, dark stats cards
  d-showcase.md             <- two-column card grid built from an HTML table
scripts/readme-switch.sh    <- the switcher
```

## Using it

```sh
./scripts/readme-switch.sh                 # list variants, ● marks the live one
./scripts/readme-switch.sh use d-showcase  # put that one live
./scripts/readme-switch.sh next            # rotate to the next in order
./scripts/readme-switch.sh random          # pick a different one at random
./scripts/readme-switch.sh use a-quiet -p  # switch, commit and push in one go
```

Two guards worth knowing:

- if you hand-edit `README.md`, the switcher refuses to overwrite those edits.
  `./scripts/readme-switch.sh save` folds them back into the active variant,
  `diff` shows them, `--force` discards them.
- `active.txt` is committed alongside `README.md`, so the repo always records
  which variant is live.

Adding a fifth style is just dropping `readmes/e-whatever.md` in place — the
switcher picks up any `.md` file in this directory.

## Log

### 2026-09-04 — set up
- Kept the existing profile README as `00-current.md` and left it live, so the
  profile did not change on install.
- Repaired dead AgriLink links in the live README: `agrilink-sigma.vercel.app`
  -> `agrilink-self.vercel.app`, `agrilink-11rw.onrender.com` ->
  `agrilink-7uhu.onrender.com`. The old pair 404s; the new pair is what the
  AgriLink repo itself points at.
- Added four new variants. All four carry the same content: the six live
  full-stack apps (Kipato, Hesabu, Fundi Connect, Soko, AgriLink, Fiti
  Electronics) with stack lines and working demo links, a note that the Render
  APIs cold-start for ~50s on free tier, and GitHub stats + top-languages
  cards. Fint (3 commits) and Tubonge (build plan only, every phase marked
  planned) are named as in-progress rather than shipped.
- Extended `00-current.md` (and the live `README.md`) with the five newer apps
  in the existing emoji-bullet style, so the profile gained the projects
  without changing its look: Kipato, Hesabu, Fundi Connect, Soko and Tubonge,
  plus a cold-start note for the free-tier Render APIs. The README exactly as
  it stood before all of this is one `git show` away, in the commit before the
  switcher was added.
- Installed the switcher and this log.

### Next
- Pick a variant and put it live.
- Revisit when a project ships: each variant needs the new entry added
  separately, since they are independent files.
