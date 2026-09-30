# Operations guide: railway.tonikiuru.com

How the self-hosted demo runs, how to operate it, and how to recover it. The stack is
`docker-compose.demo.yml` running in VM 107 on Proxmox pve1; the public site is
[railway.tonikiuru.com](https://railway.tonikiuru.com). Setup steps and `.env` settings are
in [demo/README.md](../demo/README.md).

## Where everything lives

| What | Where |
| --- | --- |
| Code | [github.com/Tonzium/fintraffic_railway_data_pipeline](https://github.com/Tonzium/fintraffic_railway_data_pipeline), branch `main`. It started as a school project on gitlab.dclabra.fi (`data-alustat-2025/tonikiuru`) |
| Deployment files | `docker-compose.demo.yml`, `demo/`, `.env` (not in git) |
| Server | VM 107 `railway` (hostname `railway-vm`) on Proxmox pve1, 192.168.68.2. Ubuntu 24.04 LTS, 2 vCPU, 12 GB RAM, 32 GB disk |
| Code on the server | `/home/tonzium/tonikiuru`: a git checkout of `main`, owned by the user `tonzium`. Run git there as `tonzium` (as root, git stops with "detected dubious ownership"); `demo/deploy.sh` does that for you |
| Public site | railway.tonikiuru.com through a Cloudflare Tunnel to `web:80` |
| On the home network | `http://<VM IP>:3000` |
| Containers | `railway-pipeline`, `railway-web`, `railway-cloudflared` |
| Volumes | `railway_data` (raw files and warehouse), `railway_site` (published website) |
| Monitoring | Home Assistant: `binary_sensor.railway_sivusto_vanhentunut` and the automation `automation.railway_sivusto_vanhentunut` alert when the site is older than 26 h or down |

Find the folder on the VM that the stack runs from; run every `docker compose` command there:

```bash
docker inspect railway-pipeline --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}'
```

With `COMPOSE_FILE=docker-compose.demo.yml` in the server's `.env` (commented out in `.env.example`,
because it would also redirect `docker compose` on a development machine), plain `docker compose
ps/logs/up` use the demo stack. Without it, never run a plain `docker compose up` on the VM: `docker-compose.yml` in the same
folder is the local development stack, and its port 3000 clashes with `railway-web`.

## How the pipeline works

Every day at 07:00 Helsinki time the `railway-pipeline` container runs `demo/run_pipeline.sh`:

1. **Lock.** One run at a time (`flock` on `/tmp/pipeline.lock`). A second run prints
   `=== [<date>] Another pipeline run is already in progress; skipping. ===` and exits 75.
2. **Fetch.** `src/data_ingestion.py` downloads the station list and every train for each day from
   today minus `BACKFILL_DAYS` (default 7) to today from rata.digitraffic.fi. Each day is one gzipped
   JSON file, written to a temporary name and renamed, so a crash never leaves a half file. Requests
   time out and retry; a day that still fails is logged (`Error fetching trains`) and skipped.
3. **Tidy.** `src/staging_maintenance.py` compresses leftover plain files, moves unreadable ones to
   `staging/quarantine/`, deletes days older than `RETENTION_DAYS` (default 365) and removes temp files.
4. **Transform.** `dbt build` in `dbt_warehouse/`. Bronze re-reads the files of the fetch window and
   replaces those days, so a day first fetched at 07:00 (only the trains run so far) is completed by the
   following days' re-fetches. Silver and gold are rebuilt from bronze; the data tests run.
5. **Build the site.** The warehouse is copied into the Evidence project; `npm run sources` and
   `npm run build` render the static site, and `build-info.json` records when it was built and which
   days it covers.
6. **Publish.** `rsync` copies the build into the `railway_site` volume, which nginx serves.

When the container starts it runs the pipeline once straight away, then sleeps until 07:00 each day.
A failed run stops before step 6, so the previous site stays online, and the next try is the next
morning. A run that takes longer than `RUN_TIMEOUT` (default 3 h) is killed with all its child
processes. Container logs are rotated (3 × 10 MB per container).

## Data and storage

| What | Path inside `railway-pipeline` | Size |
| --- | --- | --- |
| Raw train data, one file per day | `/app/data/staging/train_departure_date/YYYY/MM/YYYY-MM-DD.json.gz` | 0.6–0.9 MB per day, about 0.3 GB for the full year kept |
| Station list | `/app/data/staging/stations/stations.json` | About 100 KB, rewritten every run |
| Unreadable files set aside | `/app/data/staging/quarantine/` | Normally empty |
| Warehouse | `/app/data/warehouse/warehouse.duckdb` | Grows with history, capped at 365 days |
| Published website | `/site` in `railway-pipeline`, `/usr/share/nginx/html` in `railway-web` | Tens of MB |

`/app/data` is the `railway_data` volume and `/site` is `railway_site`. Their location on the VM:

```bash
docker volume inspect railway_data --format '{{ .Mountpoint }}'
```

Everything else inside the container is rebuilt on every run, so recreating the container loses nothing.

## Everyday commands

Run these on the VM as root.

### Is the site up to date?

`build-info.json` says when the site was built and which days it covers:

```bash
curl -s https://railway.tonikiuru.com/build-info.json
```

The `last-modified` header works too: it should be today around 04:05 GMT in summer, or 05:05 GMT in
winter (Helsinki winter time runs from the last Sunday of October to the last Sunday of March).

```bash
curl -sI https://railway.tonikiuru.com/ | grep -i last-modified
```

On Windows PowerShell: `curl.exe -sI https://railway.tonikiuru.com/ | findstr /i last-modified`.

### Status and logs

```bash
docker ps -a --filter name=railway
```

```bash
docker logs -t --tail 50 railway-pipeline
```

Follow the log live (Ctrl+C stops following; the container keeps running):

```bash
docker logs -f railway-pipeline
```

The important lines from the last day:

```bash
docker logs -t --since 24h railway-pipeline 2>&1 | grep -aE '\[scheduler\]|=== |FATAL|Killed|No space|Traceback|ERROR'
```

What is running inside the container (the image has no `ps`). Between runs only tini (shown as
`/sbin/docker-init`), `entrypoint.sh` and `sleep` are there; `ELAPSED` like `2-03:14:05` means running for 2 days 3 hours:

```bash
docker top railway-pipeline -eo pid,etime,rss,args
```

### Refresh the site now

Runs the normal pipeline once (about 5 minutes). Output from `docker exec` goes to your terminal only,
not to `docker logs`, so keep a copy:

```bash
docker exec railway-pipeline bash /app/demo/run_pipeline.sh 2>&1 | tee /root/run-$(date +%F-%H%M).log
```

It ends with a line like `=== [Wed Sep 30 07:05:12 EEST 2026] Pipeline done ===`. If it prints
`already in progress; skipping`, another run is going: wait for it.

### Catch up after missed days

Re-fetches and reloads the last 35 days (set `BACKFILL_DAYS` to the days since the last good update,
plus a few). This one survives a dropped SSH session and shows up in `docker logs`:

```bash
docker exec -d -e BACKFILL_DAYS=35 railway-pipeline bash -c 'bash /app/demo/run_pipeline.sh > /proc/1/fd/1 2>&1'
```

```bash
docker logs -f railway-pipeline
```

### Reload every day from the raw files

Rebuilds bronze from all files on disk, for example after an upgrade or after restoring files. Run it
between scheduled runs (not near 07:00). It takes the pipeline lock, so while a run is going it
returns at once and prints the "Not run" message: wait for `[scheduler] Next run at` and try again.
It takes about a minute and up to 4 GB of memory for a full year of files.

```bash
docker exec -w /app/dbt_warehouse railway-pipeline flock -n -E 75 /tmp/pipeline.lock uv run dbt build --profiles-dir . --full-refresh || echo "Not run: a pipeline run holds the lock (exit 75), or it failed"
```

Then refresh the site (above) to publish the result.

### Deploy a code change from GitHub

Push the change to `main` on GitHub, then on the VM run the deploy script as root. It runs git as the
checkout's owner, refuses to deploy over local changes, waits while a pipeline run is going, pulls,
rebuilds only what changed (and recreates `railway-web` if `demo/nginx.conf` changed), prunes old
images, and follows the first pipeline run until the scheduler reports the result:

```bash
sudo /home/tonzium/tonikiuru/demo/deploy.sh
```

`--check` only lists the incoming commits and changed files; `--no-follow` skips waiting for the run.
It prints the previous commit and the command to go back if something goes wrong.

The same steps by hand, if the script is not available. Check that the checkout points at GitHub,
then pull as the owner and rebuild. The code is copied into the image, so a change needs `--build`,
and the rebuilt container runs the pipeline straight away:

```bash
runuser -u tonzium -- git -C /home/tonzium/tonikiuru remote -v
```

```bash
runuser -u tonzium -- git -C /home/tonzium/tonikiuru pull --ff-only
```

```bash
docker compose -f docker-compose.demo.yml up -d --build pipeline
```

If `demo/nginx.conf` changed, recreate the web container too:

```bash
docker compose -f docker-compose.demo.yml up -d --force-recreate web
```

Free the space the old image used:

```bash
docker image prune -f && docker builder prune -f
```

Make changes in the repo, not by editing tracked files on the VM: local edits make a later `git pull` fail.

### Change settings

All settings are in `.env` next to the compose file (see `.env.example` and demo/README.md):
`UPDATE_HOUR`, `BACKFILL_DAYS`, `RETENTION_DAYS`, `RUN_TIMEOUT`, `NODE_OPTIONS`, `DUCKDB_MEMORY_LIMIT`,
`DUCKDB_THREADS`, `TZ`. After editing,
recreate the container (this starts a run):

```bash
docker compose -f docker-compose.demo.yml up -d pipeline
```

### Disk and memory

```bash
df -h /
```

```bash
docker system df
```

```bash
du -sh "$(docker volume inspect railway_data --format '{{ .Mountpoint }}')"
```

```bash
free -m
```

### Start over from nothing (deletes all history)

Deletes every fetched day and the warehouse, and brings the stack back up. The old site stays online
until the first run publishes a site with only the last 8 days. Digitraffic still serves old dates, so
after `[scheduler] Next run at`, run a catch-up with a large `BACKFILL_DAYS` to refill history:

```bash
docker compose -f docker-compose.demo.yml down && docker volume rm railway_data && docker compose -f docker-compose.demo.yml up -d
```

## Restarts and reboots

- All three containers restart by themselves when Docker starts, except one you stopped by hand
  (`docker stop`); bring that back with `docker compose -f docker-compose.demo.yml up -d`.
- Every start of `railway-pipeline` (reboot, `docker restart`, `compose up`) begins a run at once.
  Wait for `[scheduler] Next run at` in `docker logs` before starting a catch-up.
- Does the VM start when pve1 boots? Check on pve1 with `qm config 107 | grep onboot`; turn it on with
  `qm set 107 --onboot 1`. In the VM, `systemctl is-enabled docker` should print `enabled`.

## Getting into the VM

The easiest way in is the Proxmox console: `https://192.168.68.2:8006` → **107 (railway)** →
**Console**, then log in as `root`. It is a VM, not a container: `pct enter` does not work and there is
no `qm enter`, so you need the VM's own password. Keep it in your password manager.

### SSH from your PC

Find the IP with `ip -4 addr` in the VM console, or look up MAC `BC:24:11:25:C9:6C` in the router's
client list. (`ip neigh | grep -i bc:24:11:25:c9:6c` on pve1 only finds it if pve1 has talked to the VM
recently.) Then, in the VM console as root:

```bash
systemctl status ssh
```

If it is missing: `apt install -y openssh-server`. Add your GitHub SSH keys (including this PC's) to
root's `authorized_keys`:

```bash
ssh-import-id gh:Tonzium
```

Then from Windows: `ssh root@<IP>`. Ubuntu does not allow root to log in over SSH with a password.

### Proxmox commands for the VM (run on pve1)

| Task | Command |
| --- | --- |
| List VMs | `qm list` |
| Is it running? | `qm status 107` |
| Settings (memory, disk, network) | `qm config 107` |
| Start | `qm start 107` |
| Clean shutdown | `qm shutdown 107` |
| Force off (last resort) | `qm stop 107` |
| Reboot | `qm reboot 107` |

### Change the memory

Check that pve1 has room: `free -g` should show the extra amount under `available` (pve1 has 15 GB in
total, and the Home Assistant VM runs there too).

```bash
qm set 107 --memory 12288
```

The new size applies only after a full shutdown and start; a reboot from inside the VM is not enough.
If the shutdown fails, `&&` skips the start: check `qm status 107`.

```bash
qm shutdown 107 && qm start 107
```

### Add disk space

The root filesystem uses the whole 32 GB disk. To go beyond that, enlarge the virtual disk on pve1:

```bash
qm resize 107 scsi0 +10G
```

Then grow the partition, the LVM volume and the filesystem inside the VM (`growpart` is in the
`cloud-guest-utils` package):

```bash
growpart /dev/sda 3 && pvresize /dev/sda3 && lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
```

### Forgotten password: reset it from pve1

No login needed. The VM must be off: editing a running VM's disk can corrupt it.

```bash
apt install -y libguestfs-tools
```

```bash
qm shutdown 107 --timeout 60 --forceStop 1
```

```bash
qm status 107
```

When it says `stopped`, set a new root password and start the VM:

```bash
virt-customize -a $(pvesm path local:107/vm-107-disk-0.qcow2) --root-password password:<new-password>
```

```bash
qm start 107
```

With the VM off, the same tools show its disk usage without logging in:

```bash
virt-df -h -a $(pvesm path local:107/vm-107-disk-0.qcow2)
```

Without pve1 shell access: in the console, click **Reset** and hold **Shift** for the GRUB menu, press
`e` on the Ubuntu entry, add ` init=/bin/bash` to the end of the line starting with `linux`, press
Ctrl+X, then run `mount -o remount,rw /`, `passwd root`, `sync`, `reboot -f`. (The menu's
**recovery mode → root** only works if you know the root password.)

### Make next time easier: the guest agent

With the QEMU guest agent, pve1 can run commands inside the VM without a login
(`qm guest exec 107 -- docker ps -a`). In the VM:

```bash
apt install -y qemu-guest-agent
```

Then on pve1, followed by a full shutdown and start:

```bash
qm set 107 --agent enabled=1
```

## Cloudflare Tunnel

- The token is `CLOUDFLARE_TUNNEL_TOKEN` in `.env` next to the compose file (`.env` is git-ignored).
  Don't copy it into notes.
- The route lives in Cloudflare, not on the VM: Zero Trust → Networks → Tunnels → the tunnel →
  Public hostname: `railway.tonikiuru.com` → `HTTP` → `web:80` (the compose service name).
- To see the token again: the tunnel → Overview → Add a replica (the `eyJ…` string in the command).
  To rotate it: Overview → Refresh token, put the new value in `.env`, then
  `docker compose -f docker-compose.demo.yml up -d cloudflared`.
- Never run two stacks with the same token (for example an old VM and a new one): Cloudflare splits
  the traffic between them.

## Monitoring

Home Assistant polls `https://railway.tonikiuru.com/_app/version.json` every 15 minutes (SvelteKit
writes the build time there). `binary_sensor.railway_sivusto_vanhentunut` turns on when the last
publish is older than 26 hours or the site has not answered for 45 minutes, and
`automation.railway_sivusto_vanhentunut` notifies the phones and creates a persistent notification.
The HA side is documented in the HA workbench (`HOME-ASSISTANT.md`, System 9).

## Troubleshooting

Start with `docker logs -t --tail 80 railway-pipeline` and `df -h /`: they answer most cases. A failed
run never takes the site down; the last good version stays online.

| What you see | Likely cause | Fix |
| --- | --- | --- |
| `No space left on device` | The VM's disk is full | `df -h /`, `docker image prune -f && docker builder prune -f`; add disk space if needed; then a catch-up |
| `Malformed JSON in file "…"` from dbt | A file in the fetch window is unreadable | Re-fetch that day (below). Plain files are checked and quarantined automatically; gzipped files are written atomically |
| `heap out of memory` or `FATAL ERROR` after `=== Evidence build ===` | Node's memory limit is too low | Raise `NODE_OPTIONS` in `.env` (e.g. `--max-old-space-size=6144`) and recreate the container |
| `Killed` or `SIGKILL` after `=== Evidence build ===` | The VM ran out of RAM | Give the VM more memory |
| `[scheduler] Pipeline TIMED OUT` | A step hung for `RUN_TIMEOUT` | Read the lines before it; the next run retries automatically |
| `[scheduler] Pipeline KILLED (SIGKILL…)` | Usually out of memory: the kernel killed a step | Check `free -m` and `journalctl -k \| grep -i oom` in the VM; give the VM more memory |
| `Pipeline FAILED` right after `=== dbt build ===`, with `Failure in test` or `ERROR` lines | A data test with error severity failed, or a model broke on new data | Read the failing test in the log, or `docker exec railway-pipeline tail -n 200 /app/dbt_warehouse/logs/dbt.log` (lost when the container is recreated). It fails every day until fixed |
| `Could not set lock on file "…warehouse.duckdb"` | Two processes opened the warehouse at once (a manual dbt run, a DuckDB CLI) | Close the other one; use the lock-wrapped commands in this guide |
| `Out of Memory Error` from DuckDB during `=== dbt build ===` | DuckDB hit `DUCKDB_MEMORY_LIMIT` | Raise `DUCKDB_MEMORY_LIMIT` in `.env` (default 4GB) and recreate the container |
| `Pipeline skipped: another run holds the lock` every day | A leftover process holds the lock | `docker restart railway-pipeline` (this starts a run) |
| A traceback right after `Fetching station metadata` | The VM cannot reach the Digitraffic API | Test from the container (below); check [status.digitraffic.fi](https://status.digitraffic.fi) |
| Cloudflare error 1033 (HTTP 530) | The tunnel is down: VM off, Docker not running, or a full disk after a reboot | `qm status 107` on pve1, then `docker ps -a` on the VM |

### Re-fetch one day

Rewrites the file for that date. If the day is inside the reload window (the last `BACKFILL_DAYS`
days), the next run reloads it; for an older day, follow with "Reload every day from the raw files".

```bash
docker exec -w /app/src railway-pipeline flock -n -E 75 /tmp/pipeline.lock uv run python data_ingestion.py --start 2026-08-29 --end 2026-08-29 --compress || echo "Not run: a pipeline run holds the lock (exit 75), or it failed"
```

### Test the API from inside the container

Expect `200`:

```bash
docker exec railway-pipeline curl -sS --compressed -o /dev/null -w '%{http_code}\n' https://rata.digitraffic.fi/api/v1/metadata/stations
```

## Backups

There are none, and nothing is irreplaceable: the code is on GitHub, the token is in the Cloudflare
dashboard, and Digitraffic still serves old dates. A backup only saves rebuild time. The raw files are
small now; to copy them off the VM:

```bash
docker run --rm -v railway_data:/d:ro -v /root:/b alpine tar czf /b/railway_data-$(date +%F).tgz -C /d staging
```

Then `scp root@<VM IP>:/root/railway_data-*.tgz .` from the PC, and delete the file on the VM.

## Upgrading to the 2026-09-30 version (one time)

This version stores raw files gzipped, reloads the fetch window, keeps one year and builds the site from
small aggregate tables. On the VM, in the compose folder:

Run the git commands as `tonzium` (`su - tonzium`, then `cd ~/tonikiuru`); the rest as root.

1. `git remote -v` must show github.com/Tonzium/fintraffic_railway_data_pipeline. If it shows the school
   GitLab: `git remote set-url origin https://github.com/Tonzium/fintraffic_railway_data_pipeline.git`.
   `git status` must be clean. Note the current commit with `git rev-parse HEAD`, then `git pull`.
2. Add `COMPOSE_FILE=docker-compose.demo.yml` to `.env`. The other new settings in `.env.example` all
   have defaults.
3. `docker compose -f docker-compose.demo.yml up -d --build`. The first run compresses the existing
   plain files (a few minutes, once; unreadable ones go to `staging/quarantine/`). Follow it with
   `docker logs -f railway-pipeline` until `[scheduler] Next run at`.
4. Repair the days that were stored as partial 07:00 snapshots: run "Reload every day from the raw
   files", then "Refresh the site now".
5. Check: `curl -s https://railway.tonikiuru.com/build-info.json` should show `data_from` 2026-08-05 and
   about 57 days or more.
6. `docker image prune -f && docker builder prune -f`.

Rolling back: after step 3 the raw files are gzipped, and the old code only reads plain `.json`. Before
running an older commit, decompress them:
`docker run --rm -v railway_data:/d alpine sh -c 'gunzip -r /d/staging/train_departure_date'`.

## Incident log

| Date | What happened |
| --- | --- |
| 2026-09-29 | The site had been frozen since Sep 3. Cause: the VM's root filesystem was only 15 GB of the 32 GB disk and 100% full. Grown to the whole disk from pve1 with guestfish; root password reset; memory raised to 12 GB; a 35-day catch-up re-fetched the cut-off 2026-08-29 file. Republished at 18:12 UTC with data for Aug 5 – Sep 29. Home Assistant stale-site alert added. |
| 2026-09-28 | Fintraffic API ruled out: every endpoint answered 200, the data format was unchanged around Sep 3, no incidents. |
| 2026-09-04 | Runs started failing with `No space left on device`; the 2026-08-29 file was left cut off. The Sep 3 site stayed online, frozen. |
| 2026-09-03 | Last successful run before the outage (published 07:05). |
| 2026-08-11 | Stack deployed; the first run fetched data back to 2026-08-05. |
