# minecraft-server
scripts and helpers for minecraft server

 - `papermc-download-latest.sh` - Implements https://papermc.io APIv2 to download latest release of various tools like paper / velocity / waterfall / ... (only tested on paper, but should work for all tools where builds exist)
 - `update-minecraft.sh` - "internal" tool for daily updates and backups of minecraft servers running with plugin auto-updater
 - `minecraft.service` - systemd service unit for minecraft daemon
 - `mc-update.(service|timer)` - timer units to run daily backups and updates


## papermc-download-latest.sh

- Download latest relase of eg. `paper` from https://papermc.io
- checks sha256sums
- update `server.jar` symlink to downloaded release (if it exists)

(safe to call multiple times for the same version and it will not download everything a second time)

### Details

 1. Get the lates release of `MC_NAME` from https://papermc.io/api/v2
 2. Store the json locally in eg. `paper-1.20.6-148.jar.json`
 3. Write a sha256sum file with content from api eg. `paper-1.20.6-148.jar.sha256sum`
 4. Download `MC_NAME` release eg. `paper-1.20.6-148.jar`
 5. Check sha256sum of downloaded release
 6. If checksum matches update symlink `server.jar` (if it already exists) for usage in systemd unit file

### Usage

This script does not support any arguments but uses environment variables

 - `MC_NAME` - Tool to download from https://papermc.io, default=`paper`
 - `MC_VERSION` - Version to download default=`1.20`

### Example

`MC_VERSION=1.20 MC_NAME=paper papermc-download-latest.sh`

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
