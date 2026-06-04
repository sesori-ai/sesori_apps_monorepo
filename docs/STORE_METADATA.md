# App Store metadata via a private repo

Production submissions (`submit-release.yml` → `track: production`) can pull App
Store Connect and Google Play **listing metadata** from a separate **private**
git repository and upload it as part of the submission. This keeps store copy
(titles, descriptions, keywords, review notes, "What's new") versioned and
editable by people who don't have access to the app source.

The feature is **opt-in and non-breaking**. It activates only when a production
submission is dispatched with the **`upload_metadata`** input ticked (default
off) *and* the repository variable `STORE_METADATA_REPO` is set. Otherwise the
metadata checkout is skipped and the fastlane lanes behave exactly as before
(iOS: attach build + submit; Android: promote internal → production).

When activated, **everything in the cloned repo is uploaded** — listing text,
"What's new" changelogs, screenshots, and images — so the repo is the single
source of truth for the store listing.

## Two ways metadata reaches the stores

Both paths use the same tools (`deliver` for iOS, `supply` for Android) and the
same private repo; they differ only in *when* and *what*:

1. **With a release — `submit-release.yml`** in THIS repo (tick `upload_metadata`).
   Pushes the full listing **alongside** a production binary submit/promote. This
   is the only way to ship the per-release "What's new" changelog and the
   new-version iOS screenshots/copy that must ride with the version under review.
   Documented below.
2. **Standalone — `Sync Store Metadata` lives in the private metadata repo**
   (`app-stores-metadata`), not here. It pushes the listing (all languages +
   assets) **without** building or submitting a binary, runs on its own checkout
   with its own store secrets, and is manually dispatched. Use it to edit copy,
   add a language, or refresh screenshots between releases. See that repo's
   `README.md`. (Android updates the full listing immediately; iOS edits the
   editable version's text + screenshots, or the live listing's text with
   `ios_edit_live`.)

**Adding a language** = add its locale folder to the private repo (e.g.
`ios/metadata/de-DE/` + `ios/screenshots/de-DE/`, or `android/de-DE/`) and run the
private repo's sync. `deliver`/`supply` create the localization from the folders
present.

## How it works

1. `submit-release.yml` runs on `ubuntu-latest` (no rebuild — submission is pure
   App Store Connect / Play API work).
2. For a **production** run dispatched with `upload_metadata: true`, after
   checking out the monorepo it also checks out the private metadata repo into
   `$GITHUB_WORKSPACE/store-metadata` (`persist-credentials: false`, so the
   read-only token isn't left behind). With `upload_metadata: false` (the
   default) this step is skipped entirely.
3. It passes **absolute** paths to the fastlane lanes via env vars
   (`IOS_METADATA_PATH`, `IOS_SCREENSHOTS_PATH`, `ANDROID_METADATA_PATH`).
   Absolute because fastlane runs from `mobile/app/<platform>` while the clone
   lives at the workspace root.
4. The lanes (`submit_ios`, `submit_android`) upload each part of the metadata
   **only when its directory exists and is non-empty** (`metadata_dir_from_env`
   in each `Fastfile`). When the checkout was skipped the dirs are absent, so
   the lanes no-op. A text-only repo uploads only text; add screenshots/images
   to the repo and they upload too.

### iOS — two passes (`submit_ios`)

`deliver` uploads metadata and submits for review in **separate** API calls, so
the lane separates them too:

- **Pass 1** — metadata only (`submit_for_review: false`). A metadata error here
  fails *before* the build is attached/submitted, so it can never orphan a
  half-submitted version. The already-uploaded TestFlight binary is never
  touched (`skip_binary_upload: true`).
- **Pass 2** — attach the existing build (`build_number:`) and submit for review
  (`skip_metadata: true`, since pass 1 handled it). `automatic_release: false`,
  so a human approves the actual release after Apple's review.

### Android — one atomic edit (`submit_android`)

`supply` runs the internal → production promotion **and** the metadata upload
inside a single Play Edit, so a metadata error aborts the whole edit and the
promotion doesn't half-land. The lane just flips the relevant skip flags off
when a metadata dir is present.

- `skip_upload_metadata` gates **only** listing text (title/descriptions).
- Changelogs ("What's new") come from
  `<locale>/changelogs/<versionCode>.txt`, falling back to
  `<locale>/changelogs/default.txt`. **Keep a `default.txt`** — supply uploads
  blank release notes *silently* if neither file matches the promoted version
  code. The monorepo's `deploy_internal` lane writes a per-build
  `<versionCode>.txt` for the *internal* track; production "What's new" is the
  human-curated `default.txt` in the private repo.

### Screenshots & images

When `upload_metadata` is on, screenshots and images are uploaded too — but only
if you actually put them in the repo (an absent/empty `ios/screenshots` or
Android `<locale>/images` tree is skipped). If you keep the repo text-only,
nothing image-related is touched.

⚠️ Caveat if you do manage screenshots here: iOS `deliver` **hard-fails** on a
screen size fastlane doesn't yet recognize (happens with every new device), and
it overwrites the live set in the targeted locales. On iOS this failure lands in
**pass 1**, before the build is attached/submitted, so the binary is safe and
you can re-run after fixing the screenshot set. If you'd rather never risk it,
keep the repo text-only.

## Private repo layout

```
store-metadata/                         # the private repo
  ios/
    metadata/                           # → IOS_METADATA_PATH (deliver metadata_path)
      copyright.txt
      primary_category.txt
      secondary_category.txt
      review_information/
        first_name.txt  last_name.txt  phone_number.txt
        email_address.txt  demo_user.txt  demo_password.txt  notes.txt
      en-US/                            # App Store Connect locale code
        name.txt          subtitle.txt        description.txt
        keywords.txt      promotional_text.txt release_notes.txt
        support_url.txt   marketing_url.txt    privacy_url.txt
    screenshots/                        # → IOS_SCREENSHOTS_PATH (optional; omit to stay text-only)
      en-US/
        01_*.png  02_*.png  ...         # numeric prefixes control on-store order
  android/                              # → ANDROID_METADATA_PATH (supply metadata_path)
    en-US/                              # Play locale code
      title.txt  short_description.txt  full_description.txt
      changelogs/
        default.txt                     # safety net — always present
      images/                           # optional; omit to stay text-only
        featureGraphic.png  icon.png
        phoneScreenshots/  1.png  2.png  ...
```

Notes:
- `deliver` only uploads fields whose `.txt` file exists; missing files leave
  the store value unchanged. Once a field lives here, treat this repo as its
  source of truth and stop editing it in the consoles.
- iOS `name`/`subtitle`/`privacy_url` are app-level; `description`/`keywords`/
  `release_notes`/`promotional_text`/`support_url`/`marketing_url` are
  version-level.
- Files must be UTF-8 (supply hard-fails otherwise).

## One-time setup

### 1. Create + seed the private repo

Run locally with store credentials. iOS needs a **fastlane App Store Connect
API Key JSON** (`asc_api_key.json`) — NOT the raw `AuthKey_XXXX.p8`. Build it
from the values you already hold as monorepo secrets
([format](https://docs.fastlane.tools/app-store-connect-api/#using-fastlane-api-key-json-file)):
`{"key_id": "<APP_STORE_CONNECT_API_KEY_ID>", "issuer_id":
"<APP_STORE_CONNECT_API_ISSUER_ID>", "key": "<APP_STORE_CONNECT_API_KEY_CONTENT,
PEM with \n-escaped newlines>"}`. Android uses the
`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` content written to a file.

```bash
git init store-metadata && cd store-metadata
mkdir -p ios android

# iOS — download live text metadata (download_metadata does NOT fetch screenshots)
fastlane deliver download_metadata \
  --api_key_path "/abs/path/asc_api_key.json" \
  --app_identifier "com.sesori.app" \
  --metadata_path "./ios/metadata" \
  --use_live_version true

# Android — download live listing + changelogs (track defaults to production)
fastlane run download_from_play_store \
  package_name:"com.sesori.app" \
  json_key:"/abs/path/play-service-account.json" \
  metadata_path:"./android"

# Guarantee a non-empty production "What's new"
[ -f android/en-US/changelogs/default.txt ] || \
  printf 'Bug fixes and performance improvements.\n' > android/en-US/changelogs/default.txt

# Optional: keep it text-only
# rm -rf android/*/images ios/screenshots

# Optional: seed iOS screenshots (download_metadata does NOT fetch them).
# Only needed if you want screenshots managed here (uploaded when you run a
# production submit with upload_metadata=true).
# fastlane deliver download_screenshots \
#   --api_key_path "/abs/path/asc_api_key.json" \
#   --app_identifier "com.sesori.app" \
#   --screenshots_path "./ios/screenshots"

git add -A && git commit -m "Seed store listing metadata"
# create a PRIVATE remote, then push
```

### 2. Configure this repo

- **Repository variable** `STORE_METADATA_REPO` = `owner/store-metadata`
  (Settings → Secrets and variables → Actions → Variables). Optional:
  `STORE_METADATA_REF` (defaults to `main`).
- **Secret** `METADATA_REPO_TOKEN` — read-only access to the private repo. Use a
  fine-grained PAT scoped to just that repo with **Contents: Read**, or a
  read-only deploy key (switch the checkout to `ssh-key:`). Add it to the
  `store-production` environment.

That's it. To push the listing, run **Submit Release** with `track: production`
and tick **`upload_metadata`** — the run clones the private repo and uploads
everything in it. Leaving `upload_metadata` unticked promotes/submits the binary
only and never touches the listing. Edit copy by opening a PR against the private
repo; no app-source access required.

## Operational notes

- **When you run with `upload_metadata: true`, a working `METADATA_REPO_TOKEN`
  is required.** The metadata checkout runs before the submit step, so a
  missing/expired/under-scoped token (or a deleted repo/ref) fails the job
  *before* anything is promoted or submitted — a clean fail-fast with no
  half-published state, but it does block the binary for that run. If the token
  rotates, update the secret and re-run (the build is already on TestFlight /
  the internal track, so re-running the submission is safe). A run with
  `upload_metadata: false` never touches the private repo, so it's unaffected.
  To degrade instead of fail — promotion-only when metadata can't be fetched —
  add `continue-on-error: true` to the `Checkout store metadata` steps; note
  that this trades loud failures for *silently* not updating the listing.
- **Metadata tracks the latest `main` of the private repo, not the build's
  commit.** The app is checked out at the historical `build-<N>` commit, but
  metadata uses `STORE_METADATA_REF` (default `main`). This is intentional —
  you normally want current store copy. To reproduce a past submission exactly,
  set `STORE_METADATA_REF` to a tag/SHA in the private repo.
- **The private repo is the source of truth for any field it contains.**
  `deliver`/`supply` only push fields whose file exists, so missing files leave
  the console value untouched — but for fields you *do* manage here, stop
  editing them directly in App Store Connect / Play Console (every
  `upload_metadata: true` submission re-pushes them).
