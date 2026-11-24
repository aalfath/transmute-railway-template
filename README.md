[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/transmute-1?utm_medium=integration&utm_source=button&utm_campaign=transmute)

# Transmute on Railway

One-click [Transmute](https://github.com/transmute-app/transmute) (self-hosted file converter and compressor) for [Railway](https://railway.com).

- **Version:** Transmute `v2.1.1`, official image `ghcr.io/transmute-app/transmute:2.1.1@sha256:87b669d835d9e68bdbc4082ab061cb361cd3ecee69c14ccfa9a3814d326b6707`, pinned by version and digest in the [`Dockerfile`](Dockerfile).
- **Services:** one service, `Transmute`, built from this repo, with a Railway volume on `/app/data` (SQLite database, uploads, converted files).
- **Health check:** `/api/health/ready` (checks the database and the volume).

## After deploy

Open the public URL and sign in as `admin` with the password in the service's **Variables** tab (`TRANSMUTE_ADMIN_PASSWORD`). Upstream lets the first visitor create the admin account; this template creates it on the first boot instead, so a stranger can't claim your instance. Changing the variable later doesn't change an existing account: change the password under My Account. API docs are at `/api/docs`.

## Variables

| Variable | Default | What it does |
|---|---|---|
| `TRANSMUTE_ADMIN_USERNAME` | `admin` | Username of the admin created on the first boot |
| `TRANSMUTE_ADMIN_PASSWORD` | generated, 24 characters | Password of that admin (first boot only) |
| `AUTH_SECRET_KEY` | generated, 64 characters | Signs login tokens; keep it so sessions survive restarts |
| `APP_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL, used for API docs links and OIDC redirects |
| `PORT` | `3313` | Port Transmute listens on |

Nothing to fill in at deploy time. Optional single sign-on: set `OIDC_ISSUER_URL`, `OIDC_CLIENT_ID` and `OIDC_CLIENT_SECRET` (see [Transmute's OIDC docs](https://transmute.sh/docs/oidc/)).

## Memory and CPU

The start script reads the service's CPU and memory limits from the cgroup (Railway shows the host's 32+ CPUs to processes) and sizes conversion workers, ffmpeg threads, OCR/BLAS threads and onnxruntime threads to them. On services under 1.5 GB it runs one conversion at a time and uses lean video-encoder settings.

- The app itself needs about 300 MB. On Railway's 0.5 GB Free/Trial limit, documents, images, audio, spreadsheets and video up to 720p convert fine.
- A 1080p or larger video conversion needs about **1 GB of RAM**. On a smaller service such a job runs out of memory and fails with a clear message; converter jobs are the kernel's first choice when memory runs out, so the web app stays up.
- Tested on Railway at 1 vCPU: at 0.5 GB a 15 s 1080p clip failed cleanly with the out-of-memory message; at 1 GB it converted to MKV in 29 s and to WebM (VP9, slow) in about 5 minutes.
- Railway ends HTTP requests after 5 minutes. The web UI queues conversions as background jobs, so long jobs are fine there; API scripts should use the jobs endpoints (`POST /api/jobs`, then poll `GET /api/jobs/{id}`) rather than the synchronous `POST /api/conversions` for long video jobs.
- If Transmute stops unexpectedly, the start script exits non-zero so Railway's restart policy brings it back.

## Updates

The template builds from this repo, so when the pinned Transmute version is bumped on `main`, Railway shows everyone who deployed it an "update available" notice; you choose when to apply it. Read [`CHANGELOG.md`](CHANGELOG.md) first: breaking changes are listed at the top of each entry. Your data stays on the volume.

## What's in this repo

- `Dockerfile`: the pinned official image plus the files below.
- `railway/start.sh`: sizes threads and workers, keeps a stable `AUTH_SECRET_KEY`, creates the first admin, runs Transmute and exits non-zero if it stops.
- `railway/bootstrap_admin.py`: creates the first admin from the variables when there are no users yet.
- `railway/ffmpeg`: wrapper that adds `-threads` and small-plan encoder limits to every ffmpeg call.
- `railway/sitecustomize.py` and `railway/oomwrap`: cap onnxruntime threads, and start converter jobs with a high OOM score.
- `OVERVIEW.md`: the Railway marketplace overview.

Transmute is MIT-licensed by its authors; this wrapper is not affiliated with the Transmute project.
