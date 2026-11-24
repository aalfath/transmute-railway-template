# Deploy and Host Transmute on Railway

Transmute is an open-source, self-hosted file converter and compressor. It converts images, video, audio, documents, spreadsheets, e-books, subtitles, fonts, diagrams and data files through a web UI or a REST API, and keeps every file on your own server. It has user accounts, roles and API keys built in.

## About Hosting Transmute

This template runs Transmute 2.1.1 from the official image, pinned by version and digest, as one service with a volume on `/app/data` for its SQLite database, uploads and converted files. The admin account is created on the first boot, so nobody else can claim the setup page: the username is `admin` and the password is the generated `TRANSMUTE_ADMIN_PASSWORD` variable on the service. The login signing key is generated too, so sessions survive restarts. Worker counts, ffmpeg threads and OCR threads are sized from the service's CPU and memory limits, and the service restarts itself if it stops unexpectedly.

## Common Use Cases

* Convert documents, images, audio and video privately instead of uploading them to online converters
* Automate conversions from scripts or tools through the REST API with per-user API keys
* Shrink images, PDFs and videos before sharing or archiving them

## Dependencies for Transmute Hosting

* One Railway service built from the template's GitHub repo (official Transmute image plus a small start script)
* One Railway volume mounted at `/app/data`

### Deployment Dependencies

* Transmute: https://github.com/transmute-app/transmute
* Documentation: https://transmute.sh/docs/
* Template repo: https://github.com/aalfath/transmute-railway-template

### Implementation Details

After the deploy finishes, open the service's public URL and sign in as `admin` with the password from the service's **Variables** tab (`TRANSMUTE_ADMIN_PASSWORD`). Change it under My Account if you like; later edits to the variable don't change an existing account. Add more users from the admin settings. API docs are at `/api/docs`.

Memory: the app uses about 300 MB on its own. On a 0.5 GB service, documents, images, audio and video up to 720p convert fine; a 1080p or larger video job may run out of memory and fail with a clear message while the app stays up. Give the service about 1 GB of RAM for 1080p video. Long API conversions should use the background jobs endpoints (`/api/jobs`), because Railway ends HTTP requests after 5 minutes; the web UI already does. Uploaded and converted files are deleted after 60 minutes by default; change or turn this off in Settings.

Optional: single sign-on through any OIDC provider (`OIDC_ISSUER_URL`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, see the Transmute OIDC docs). Updates: the template builds from a GitHub repo, so Railway shows an "update available" notice when the pinned Transmute version is bumped; read the repo's CHANGELOG before applying it.

## Why Deploy Transmute on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Transmute on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
