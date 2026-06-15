# App Store metadata via a private repo

Production submissions (`submit-release.yml` → `track: production`) can pull App
Store Connect and Google Play **listing metadata** from a separate **private**
git repository and upload it as part of the submission. This keeps store copy
(titles, descriptions, keywords, review notes, "What's new") versioned and
editable by people who don't have access to the app source.

Publishing is **driven by the metadata repo's own `v*` tags**, not a dispatch
checkbox. On a **production** submit (and only when `STORE_METADATA_REPO` is set),
CI inspects the **latest commit** of the private repo and:

- **HEAD has no `v*` tag** → there are listing changes that haven't shipped →
  **publish** the listing, then, on success, tag that exact commit with the
  release's `v<VERSION>` (the same tag the monorepo gets). So `v1.0.8` ends up in
  **both** repos.
- **HEAD already has a `v*` tag** → this listing was already published in an
  earlier release → **skip** it. The submit still ships the binary
  (attach/promote), it just doesn't touch the live listing.
- **Beta submit** → never publishes and never tags the metadata repo.

In other words, the private repo's `v*` tag means "this commit's listing has been
published." **To publish a listing edit, commit it to the private repo** — its
HEAD becomes untagged again, and the next production release publishes and
re-tags it. Unchanged metadata is never re-pushed.

When it does publish, **everything in the cloned repo is uploaded** — listing
text, "What's new" changelogs, screenshots, and images — so the repo is the
single source of truth for the store listing. When it doesn't, the fastlane lanes
behave exactly as before (iOS: attach build + submit; Android: promote
internal → production).

> **Token:** because CI now tags the private repo on publish, `METADATA_REPO_TOKEN`
> must have **Contents: Write** (it was previously read-only) and be a
> **repository** secret — the `tag` job that pushes the tag declares no
> environment, so an environment-scoped secret would be empty there. The
> production *submission* is still approval-gated; only the token's storage moves.
> See [One-time setup](#2-configure-this-repo).

## Two ways metadata reaches the stores

Both paths use the same tools (`deliver` for iOS, `supply` for Android) and the
same private repo; they differ only in *when* and *what*:

1. **With a release — `submit-release.yml`** in THIS repo (automatic when the
   private repo's HEAD is untagged). Pushes the full listing **alongside** a
   production binary submit/promote. This is the only way to ship the per-release
   "What's new" changelog and the new-version iOS screenshots/copy that must ride
   with the version under review. Documented below.
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
   App Store Connect / Play API work). The `resolve` job maps the dispatched
   `build_number` → commit → version.
2. Each submit job (`submit-ios`, `submit-android`) — on a **production** submit
   with `STORE_METADATA_REPO` set — checks out the private metadata repo at
   `STORE_METADATA_REF` (default `main`, `fetch-depth: 0` so its tags come too)
   into `$GITHUB_WORKSPACE/store-metadata` (`persist-credentials: false`, so the
   token isn't left in git config for the fastlane steps).
3. A **gate** step then runs `git tag --points-at HEAD`: if the latest commit has
   any `v*` tag the listing was already published, so the metadata env vars
   (`IOS_METADATA_PATH`, `IOS_SCREENSHOTS_PATH`, `ANDROID_METADATA_PATH`) are left
   **empty**; otherwise they point at the cloned tree. (Absolute paths, because
   fastlane runs from `mobile/app/<platform>` while the clone lives at the
   workspace root.)
4. The lanes (`submit_ios`, `submit_android`) upload each part of the metadata
   **only when its directory exists and is non-empty** (`metadata_dir_from_env`
   in each `Fastfile`). Empty paths → the lanes no-op (binary only). A text-only
   repo uploads only text; add screenshots/images to the repo and they upload too.
5. After the requested platforms submit successfully, the `tag` job stamps the
   release's **`v<VERSION>`** onto the private repo's published commit (the same
   value as the monorepo's release tag) using `METADATA_REPO_TOKEN` (write). This
   marks that commit "published" so step 3 skips it next time. Idempotent: an
   existing tag on the same commit is a no-op; on a different commit it fails loud.

### iOS — two passes (`submit_ios`)

`deliver` uploads metadata and submits for review in **separate** API calls, so
the lane separates them too:

- **Pass 1** — metadata only (`submit_for_review: false`). A metadata error here
  fails *before* the build is attached/submitted, so it can never orphan a
  half-submitted version. The already-uploaded TestFlight binary is never
  touched (`skip_binary_upload: true`). Runs only when the listing is being
  (re)published (HEAD untagged).
- **Pass 1b** — release notes only (`submit_for_review: false`). Runs when Pass 1
  is skipped (listing unchanged). "What's New" (`whatsNew`) is **version-scoped**:
  App Store Connect requires it on every new version before review, even when the
  store copy is identical to the last release. Pass 1 uploads it as part of the
  full listing, but when that's skipped this pass applies just the fixed
  `release_notes.txt` (from a temp tree containing only release notes, so nothing
  else in the unchanged listing is touched). Without it, Pass 2 fails with
  `appStoreVersions ... is not in valid state ... You must provide a value for
  the attribute 'whatsNew'`. The version's release notes path is exposed via
  `IOS_RELEASE_NOTES_PATH`, set independently of the publish gate.
- **Pass 2** — attach the existing build (`build_number:`) and submit for review
  (`skip_metadata: true`, since the earlier passes handled it).
  `automatic_release: false`, so a human approves the actual release after
  Apple's review.

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
  code. The monorepo's `deploy_internal` lane writes the build commit's message
  into `<versionCode>.txt` for the *internal* track; production "What's new" is
  the fixed `default.txt` in the private repo (see below).

### Release notes / "What's new"

Two distinct sources, by intent:

- **Production (App Store + Play): one fixed copy, identical on both stores.**
  iOS uploads `ios/metadata/<locale>/release_notes.txt`; Android falls back to
  `android/<locale>/changelogs/default.txt` (a production promotion never has a
  matching `<versionCode>.txt`). **Keep those two files identical** — that single
  copy is the production "What's new" every release. The *text* is not edited per
  release, but iOS **re-applies it to every new version** (App Store Connect
  requires `whatsNew` on each version before review, even when the listing is
  otherwise unchanged — see Pass 1b above). Keep a non-empty `release_notes.txt`
  for every iOS locale, or production submits will be rejected.
- **Test builds (TestFlight + Play internal): the build commit's message.**
  `deploy_testflight` / `deploy_internal` set the changelog to the message of the
  commit the build was made from, plus a `commit: <sha>` trailer, truncated to
  each store's limit (4000 chars iOS, 500 Play). Generated at build time —
  never read from the private repo.

### Screenshots & images

When metadata publishes, screenshots and images are uploaded too — but only
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
# Only needed if you want screenshots managed here (uploaded on the next
# production release after they're committed — i.e. while HEAD is untagged).
# fastlane deliver download_screenshots \
#   --api_key_path "/abs/path/asc_api_key.json" \
#   --app_identifier "com.sesori.app" \
#   --screenshots_path "./ios/screenshots"

git add -A && git commit -m "Seed store listing metadata"
# create a PRIVATE remote, then push.
# Leave this seed commit UNTAGGED — the first production release publishes it and
# stamps v<VERSION> on it.
```

### 2. Configure this repo

- **Repository variable** `STORE_METADATA_REPO` = `owner/store-metadata`
  (Settings → Secrets and variables → Actions → Variables). Optional:
  `STORE_METADATA_REF` (defaults to `main`).
- **Secret** `METADATA_REPO_TOKEN` — **write** access to the private repo
  (Contents: Write), because CI both clones the listing and pushes the
  `v<VERSION>` tag back on publish. Use a fine-grained PAT scoped to just that
  repo. Add it as a **repository** secret (Settings → Secrets and variables →
  Actions → *Repository secrets*), **not** an environment secret: the `tag` job
  that pushes the tag declares no environment, so an environment-scoped token
  would resolve to empty and the tag push would fail. The submit jobs keep their
  `store-production` approval gate on the actual submission regardless of where
  the token lives.

That's it. On a `track: production` **Submit Release**, the listing publishes
**automatically whenever the private repo's latest commit is untagged** — the run
clones the repo, uploads everything in it, ships the binary, and then stamps the
release's `v<VERSION>` onto that commit (so `v1.0.8` exists in both repos). If the
latest commit is already `v*`-tagged, the listing is left untouched and only the
binary is submitted.

**To publish a listing change**, commit it to the private repo (open a PR; no
app-source access required). That moves HEAD to a new, untagged commit, and the
next production release publishes and re-tags it. There's nothing to toggle at
submit time.

**Already-released, want to re-push the same commit?** Use the standalone **Sync
Store Metadata** workflow in the private repo — it pushes the listing without a
binary. (Deleting the `v<VERSION>` tag in the private repo and re-submitting would
also re-trigger publish, but the standalone sync is cleaner.)

**Split-platform releases:** the first platform to publish tags the private repo's
HEAD, so a *separate* later single-platform submit sees the tag and skips the
listing. Submit `platforms: both` in one run (both jobs see the untagged HEAD and
publish; the tag is stamped once afterward), or push the lagging platform's
listing via the standalone Sync workflow.

## Operational notes

- **A publishing production run needs a working write `METADATA_REPO_TOKEN`.**
  The metadata checkout runs *before* the submit step, so a missing/expired/
  under-scoped token (or a deleted repo/ref) fails the job *before* anything is
  promoted or submitted — a clean fail-fast with no half-published state, but it
  blocks the binary for that run. To degrade instead — promote/submit the binary
  even when metadata can't be fetched — add `continue-on-error: true` to the
  `Checkout store metadata` steps; that trades loud failure for *silently* not
  updating the listing. A beta run, or a production run where HEAD is already
  `v*`-tagged, never touches the private repo, so it's unaffected.
- **If the final tag-push to the private repo fails** (e.g. the token lacks
  write) *after* a successful submit, the listing is published but its commit
  stays untagged. This is self-healing: fix the token and re-run — HEAD is still
  untagged, so the gate republishes (idempotent) and re-attempts the tag. The
  build is already on TestFlight / the internal track, so re-running the submit
  is safe.
- **Metadata tracks the latest `STORE_METADATA_REF` of the private repo, not the
  build's commit.** The app is checked out at the historical `build-<N>` commit,
  but the listing comes from `STORE_METADATA_REF` (default `main`). This is
  intentional — you normally want current store copy. Note the gate keys off
  *that* commit's tags, so pinning `STORE_METADATA_REF` to an already-`v*`-tagged
  commit will skip publishing.
- **The private repo is the source of truth for any field it contains.**
  `deliver`/`supply` only push fields whose file exists, so missing files leave
  the console value untouched — but for fields you *do* manage here, stop
  editing them directly in App Store Connect / Play Console (every publishing
  submission — and every standalone Sync run — re-pushes them).
