# NutriCook

An AI-powered healthy recipe app: pick the ingredients you already have, choose
your preferences, and get structured recipes with exact measurements, macros and
step-by-step instructions.

```
Flutter  →  FastAPI  →  MongoDB
                     →  LangChain  →  OpenAI
```

## Layout

```
secret_chat/
├── nutricook-UI/   HTML designs — the source of truth for all UI
├── NutriCook/      Flutter app
└── backend/        FastAPI service
```

## Running it

Three pieces: MongoDB, the API, the app.

### 1. MongoDB

Nothing is hardcoded any more — the API serves only what is in the database, so
this has to be running first. Pick whichever suits you:

**Local server (Homebrew)**
```bash
brew tap mongodb/brew
brew install mongodb-community
brew services start mongodb-community
```

**Container**
```bash
colima start                      # or start Docker Desktop
docker run -d --name nutricook-mongo -p 27017:27017 mongo:8
```

**Atlas (cloud)** — put your connection string in `backend/.env`:
```
MONGODB_URI=mongodb+srv://user:pass@cluster.xxxxx.mongodb.net
```

Then seed the feed. Without this the home screen is legitimately empty:

```bash
cd backend
.venv/bin/python seed_db.py            # insert if the feed is empty
.venv/bin/python seed_db.py --reset    # replace the seeded recipes
```

### 2. Backend

```bash
cd backend
cp .env.example .env          # then add your OpenAI key
.venv/bin/uvicorn main:app --reload --port 8010
```

Check it: `curl http://127.0.0.1:8010/health` →
`{"status":"ok","database":"ok"}`. A `"database":"unreachable"` there means
MongoDB is not running.

Startup logs tell you what is configured: whether AI generation is on, how many
recipes are in the feed, and whether you need to seed.

If the venv is missing:
```bash
/opt/homebrew/bin/python3.12 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

### 3. App

```bash
cd NutriCook
flutter run
```

Point it elsewhere with `--dart-define`:
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8010
```

The default resolves per platform: `10.0.2.2` on the Android emulator,
`127.0.0.1` everywhere else. Port 8010 is used because 8000 was already taken.

**On a physical Android phone** neither default works — the device has to reach
your Mac over the network, so pass its LAN address and bind uvicorn to all
interfaces:

```bash
.venv/bin/uvicorn main:app --reload --host 0.0.0.0 --port 8010
flutter run --dart-define=API_BASE_URL=http://192.168.10.63:8010
```

(`192.168.10.63` is this machine's current LAN address — check with
`ipconfig getifaddr en0` if it changes.)

## Data model

Four collections, with `$jsonSchema` validators and indexes created on every
boot (idempotent, so there is no separate migration step).

| Collection | Holds | Notes |
|---|---|---|
| `recipes` | Feed and AI-generated recipes | Ingredients, instructions and nutrition are **embedded** — bounded, and always read with the recipe, so the detail screen is one document and one query |
| `users` | Account, credentials + preferences | Preferences are **embedded**: 1:1 and always loaded together. The bcrypt hash lives here and never leaves `user_repository` |
| `saved_recipes` | `user_id` ↔ `recipe_id` | A **separate collection**, not an array on the user: saves grow without bound. Resolved with a single `$in` on `_id`, so a renamed recipe can never go stale |
| `refresh_tokens` | One row per live session | Hashed, so a dump cannot be replayed. Expired rows are reaped by a TTL index rather than by anything anyone has to remember to run |

**Indexes** — deliberately few:
- `recipes.categories` and `recipes.sort_order` — the category filter and the
  curated ordering
- `recipes.random_key`, `{categories, random_key}` — the shuffled feed walk
- `recipes.input_fingerprint` (sparse) — the generation cache, on the hot path
  of every create
- `recipes.created_at`, `recipes.created_by` (sparse) — browse sorting, and
  "only my recipes"
- `saved_recipes {user_id, recipe_id}` unique — one index does two jobs: it
  makes a double save a no-op, and answers "what has this user saved" from its
  `user_id` prefix
- `users.email` unique, partial on `$type: string` — one account per address,
  partial so pre-auth rows with no email don't collide
- `refresh_tokens.expires_at` TTL — expired sessions delete themselves

## Authentication

Email and password, with a rotating token pair.

- **Passwords** are bcrypt hashed with a per-password salt. A login against an
  unknown address still runs a bcrypt comparison against a dummy hash, so
  response time alone cannot enumerate accounts — and both failures return the
  same message for the same reason.
- **Access tokens** are JWTs, good for an hour. They cannot be revoked, which
  is exactly why they are short.
- **Refresh tokens** are `<id>.<secret>`; only the id is stored in the clear,
  the secret as a SHA-256 hash. They last 30 days and **rotate on every use** —
  the row is deleted as part of the check, so replaying one always fails. That
  is what limits the damage when a token leaks.
- The app refreshes **silently on a 401** and replays the request once.
  Concurrent 401s share a single refresh, because two of them would rotate each
  other out and sign the user out for nothing.

Tokens are kept in `SharedPreferences` behind `TokenStore`. That is a real
trade-off — on a rooted device they are readable — and the reason it is its own
class: moving to `flutter_secure_storage` means reimplementing four methods and
touching nothing else.

### The feed is shuffled, not sorted

Every recipe gets a fixed `random_key` in `[0, 1)`. The feed walks that space
in order from a **random starting point**, wrapping past the end back to zero.
Each reader gets a different order because the start differs, and no recipe
repeats or goes missing inside one walk — which paging over `$sample` could
never promise. The cursor is opaque and encodes where the walk has got to;
pull-to-refresh drops it, which is what reshuffles the feed.

Recipes written before this existed have no `random_key` and would sit outside
the walk entirely, so they are backfilled at startup.

### Recipe photos are files, not documents

The Images API hands back base64. Inlining that as a `data:` URI put a **2.4 MB
string inside the recipe document**, which then shipped in full with every feed
page that happened to contain it — a ten-card page would have been roughly
24 MB. So images are written to `backend/media/` and served from `/media`;
the document holds a short path, and the same recipe's JSON went from
2,389,892 bytes to 2,121.

The stored path is **relative** (`/media/gen-abc123.png`). The backend is
reached at a different host from the simulator (`127.0.0.1`), the Android
emulator (`10.0.2.2`) and a phone on the LAN, so it cannot know its own public
address; the client already knows which base URL it used and resolves the path
at render time. Seeded recipes keep their absolute `https://` URLs and pass
through untouched.

`ImageService._persist_bytes` is the seam for real object storage — upload
there and return the public URL instead. Nothing else changes.

**Generated recipes reach the feed without a photo.** Generation returns text
immediately so results render straight away, and the client then requests each
image separately — so anything created outside the create flow, a script
included, never gets one. To fill those in:

```bash
cd backend
.venv/bin/python backfill_images.py             # migrate inline images, free
.venv/bin/python backfill_images.py --generate  # also generate what is missing
```

`--generate` is one image-model call per recipe and costs real money, which is
why it is opt-in. `--limit N` caps a run.

### Generation is cached by its inputs

Every generate request is fingerprinted: ingredients lowercased, trimmed,
de-duplicated and sorted, plus goal, meal, time, servings, diet, allergies and
cuisines. Identical inputs — from anyone — return the stored recipes with
`cached: true` instead of calling the model.

The normalisation is the whole substance of it: too strict and nothing ever
matches, too loose and people get recipes that ignore what they asked for.
Servings and cooking time are part of the fingerprint deliberately — the same
ingredients for two in fifteen minutes is a different dish from the same
ingredients for six in an hour.

The results screen says plainly that the recipes were reused and offers to
generate fresh ones; that button re-sends the same request with `force_new`,
which skips the cache.

## API

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/health` | — | Liveness + database reachability |
| POST | `/api/auth/register` | — | Create an account, returns tokens + user |
| POST | `/api/auth/login` | — | Sign in |
| POST | `/api/auth/refresh` | — | Rotate the token pair |
| POST | `/api/auth/logout` | — | Revoke a refresh token |
| GET | `/api/recipes` | optional | Shuffled public feed, 10 at a time (`?category=`, `?cursor=`, `?limit=`) |
| GET | `/api/recipes/browse` | optional | Community recipes, filtered and sorted |
| GET | `/api/recipes/{id}` | optional | One recipe |
| POST | `/api/recipes/generate` | **required** | Generate from ingredients + preferences |
| POST | `/api/recipes/{id}/generate-image` | **required** | Generate and attach the photo |
| GET | `/api/users/me` | **required** | The signed-in account |
| PUT | `/api/users/me/preferences` | **required** | Save preferences |
| GET | `/api/users/me/saved` | **required** | Saved recipes, newest first |
| POST | `/api/users/me/saved` | **required** | Save one |
| DELETE | `/api/users/me/saved/{id}` | **required** | Unsave |

`/api/recipes/browse` takes `q`, `category`, `difficulty`, `max_cooking_time`,
`max_calories`, `min_protein`, `mine`, `sort` (`recent`, `quick`, `protein`,
`calories`), `page` and `page_size`. Search is escaped before it reaches the
regex, so a stray bracket in the search box is a character to match rather than
a pattern the user has accidentally authored.

Generated recipes are **public**: they join the feed and the browse library for
everyone. `is_public` on the document is the seam for ever making one private.

Generation returns recipes **without** images so results render immediately; the
app then requests each photo separately and fills the cards in as they arrive.

Saved recipes and preferences live on the account, so they follow the user to
any device. Both are still written locally first, so the app stays responsive
and keeps working offline; a failed sync never loses the action.

## Configuration

All in `backend/.env` — see `.env.example`.

| Variable | Default | Notes |
|---|---|---|
| `OPENAI_API_KEY` | — | Without it, the create flow reports generation is unavailable |
| `OPENAI_TEXT_MODEL` | `gpt-5.6-terra` | Change without touching code |
| `OPENAI_IMAGE_MODEL` | `gpt-image-2` | Change without touching code |
| `OPENAI_TEMPERATURE` | `0.7` | |
| `RECIPES_PER_REQUEST` | `3` | |
| `MONGODB_URI` | `mongodb://localhost:27017` | |
| `MONGODB_DB` | `nutricook` | |
| `MEDIA_DIR` | `media` | Where generated photos are written; relative to `backend/` |
| `JWT_SECRET` | random per process | **Set this anywhere that matters** — otherwise a restart signs everyone out |
| `ACCESS_TOKEN_MINUTES` | `60` | |
| `REFRESH_TOKEN_DAYS` | `30` | |
| `SECRET_CHAT_CODE` | empty | Unlocks the secret chat; empty turns the feature off |

## Secret chat

A hidden, anonymous chat room shared by the NutriCook and Luna apps. It is off
unless `SECRET_CHAT_CODE` is set in `backend/.env`.

1. `POST /api/secret-chat/unlock` with `{"code": "..."}` returns
   `{"token", "expires_in"}` — a chat token valid for 12 hours
   (`CHAT_TOKEN_HOURS`). A wrong code is `401`; five wrong codes from one
   address within ten minutes lock it out with `429`; with no code configured
   the endpoint is a `404`. Chat tokens and account access tokens are signed
   with different types and never work in place of each other.
2. Connect with Socket.IO (default namespace, same host and port as the API)
   passing `auth = {"token": ..., "name": "<nickname, 1-24 chars>"}`. A bad
   token is refused with `unauthorized`, a bad nickname with `invalid_name`.

| Direction | Event | Payload |
|---|---|---|
| server → joiner | `history` | the last 50 messages, oldest first |
| server → all | `presence` | `{"online": n}` — on every join and leave |
| client → server | `send_message` | `{"text": "..."}` — trimmed, 1–1000 chars |
| server → all | `message` | one message, sender included |
| server → sender | `error` | `{"message": "..."}` — empty, too long, or over ~5 messages / 5 s |

A message is `{"id", "name", "text", "sent_at"}`, with `sent_at` an ISO-8601
UTC timestamp. Messages are kept in the `secret_messages` collection.

## Screens

```
Welcome hero ─┬─ Sign Up ──► 4 preference steps ──► app
              └─ Log In  ─────────────────────────► app

app = [ Home  Explore  Create  Saved  Profile ]
```

**Explore** is the new one: everything the community has generated, with
search, category chips and a filter sheet (meal and goal, cooking time,
difficulty, calorie ceiling, protein floor, "only my recipes") over four sort
orders. It pages as you scroll.

## Notes on the design

The HTML in `nutricook-UI/` is authoritative — colours, type, spacing and
layout are transcribed from it rather than reinterpreted. Deliberate
departures:

- **A fifth nav tab.** Every HTML file shows four. Explore is a destination in
  its own right — a library of everything the community has generated — and a
  link buried on Home would have hidden the larger half of the app. The
  treatment of each tab is unchanged.
- **The home feed lists recipes.** The design shows one featured card and the
  AI card; the feed now arrives ten at a time and keeps going as you scroll,
  and a screen that fetched ten recipes to display one would be a strange
  thing to build.
- **No search field on Home** — removed by request. It could only ever filter
  the page already loaded, whereas Explore searches the whole library
  server-side, so the two would have behaved differently under the same
  gesture.
- **Onboarding is four steps, not five.** The HTML files disagree on the
  progress indicator, so it is normalised to one segment per step —
  onboarding1's welcome hero is now the sign-in front door rather than a step
  in the flow.
- **The greeting** on Home follows the clock instead of always saying
  "Good evening".
- **Recipe of the Day** is the first card of the shuffle rather than a fixed
  pick, so it actually changes between visits.
- **The Muscle Gain icon** on the preferences screen uses a fitness glyph; the
  HTML has `qr_code_2`, which reads as a slip.
- **No Start Cooking button** on the recipe detail screen — removed by request.
  There is no cooking mode.

## Tests

```bash
cd NutriCook && flutter test && flutter analyze    # 111 tests
cd backend && .venv/bin/pytest -q                  # 92 tests
```

Backend tests run against a real MongoDB on a throwaway `nutricook_test`
database, so schema validators, unique indexes and password hashing are all
genuinely exercised. With no server reachable the suite skips rather than
failing misleadingly.

No test reaches OpenAI: the fixtures clear the API key, so a cache miss is a
clean 503 rather than a slow, billable, non-deterministic call.
