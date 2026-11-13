# minecraft-server
scripts and helpers for minecraft server

 - `papermc-download-latest.sh` - Implements the PaperMC Fill API v3 (https://fill.papermc.io/v3) to download the latest stable build of various tools like paper / velocity / folia / ... (only tested on paper, but should work for all tools where builds exist)
 - `update-minecraft.sh` - "internal" tool for daily updates and backups of minecraft servers running with plugin auto-updater
 - `minecraft.service` - systemd service unit for minecraft daemon
 - `mc-update.(service|timer)` - timer units to run daily backups and updates


## papermc-download-latest.sh

- Download latest stable build of eg. `paper` from https://papermc.io
- checks sha256sums
- checks that the installed java satisfies the minimum java version of the build
- update `server.jar` symlink to downloaded release (if it is a symlink or does not exist yet)

(safe to call multiple times for the same version and it will not download everything a second time)

The old PaperMC API v2 (https://api.papermc.io/v2) was sunset in 2026 and only returns HTTP 410.

### Details

 1. Resolve `MC_VERSION`: a version group (eg. `1.21`) selects the newest version in that group which has a build in `MC_CHANNEL`, otherwise it is used as exact version (eg. `1.21.11`). Version groups take precedence, so `1.21` never selects the release `1.21` itself.
 2. Get the latest build of that version in `MC_CHANNEL` from https://fill.papermc.io/v3
 3. Store the json locally in eg. `paper-1.21.11-132.jar.json`
 4. Write a sha256sum file with content from api eg. `paper-1.21.11-132.jar.sha256sum`
 5. Download `MC_NAME` release eg. `paper-1.21.11-132.jar`
 6. Check sha256sum of downloaded release
 7. Check the installed java version against the minimum java version required by that version; abort without activating if it is too old
 8. If everything matches update symlink `server.jar` for usage in systemd unit file

### Usage

This script does not support any arguments but uses environment variables

 - `MC_NAME` - Tool to download from https://papermc.io, default=`paper`
 - `MC_VERSION` - Version group or exact version to download, default=`1.21`
 - `MC_CHANNEL` - Build channel (`STABLE` / `BETA` / `ALPHA`), default=`STABLE`
 - `MC_JAVA` - java binary used for the java version check, default=`java`

### Example

`MC_VERSION=1.21 MC_NAME=paper papermc-download-latest.sh`

on first run:

```
% time MC_VERSION=1.20 MC_NAME=paper papermc-download-latest.sh
2024-07-10 19:20:30 URL:https://papermc.io/api/v2/projects/paper/versions/1.20.6/builds/148/downloads/paper-1.20.6-148.jar [45824674/45824674] -> "paper-1.20.6-148.jar" [1]
MC_VERSION=1.20 MC_NAME=paper ../papermc-download-latest.sh  0,24s user 0,10s system 20% cpu 1,680 total
% ls -lah
-rw-rw-r-- 1 user user  44M  2. Jul 17:39 paper-1.20.6-148.jar
-rw-rw-r-- 1 user user  544 10. Jul 19:20 paper-1.20.6-148.jar.json
-rw-rw-r-- 1 user user   87 10. Jul 19:20 paper-1.20.6-148.jar.sha256sum
lrwxrwxrwx 1 user user   20 10. Jul 19:20 server.jar -> paper-1.20.6-148.jar
```

on second run:

```
% time MC_VERSION=1.20 MC_NAME=paper ../papermc-download-latest.sh
## paper-1.20.6-148.jar already successfully downloaded
MC_VERSION=1.20 MC_NAME=paper ../papermc-download-latest.sh  0,19s user 0,02s system 69% cpu 0,302 total
% ls -lah
-rw-rw-r-- 1 user user  44M  2. Jul 17:39 paper-1.20.6-148.jar
-rw-rw-r-- 1 user user  544 10. Jul 19:20 paper-1.20.6-148.jar.json
-rw-rw-r-- 1 user user   87 10. Jul 19:20 paper-1.20.6-148.jar.sha256sum
lrwxrwxrwx 1 user user   20 10. Jul 19:22 server.jar -> paper-1.20.6-148.jar
```
