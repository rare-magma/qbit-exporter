# qbit-exporter

# I no longer use prometheus for this purpose so development of this tool has ceased. Feel free to fork it

If using telegraf + influxdb the same can be achieved via `input.http` [plugin](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/http) + `json_v2` [parser](https://github.com/influxdata/telegraf/tree/master/plugins/parsers/json_v2) with the following config:

```ini
[[inputs.http]]
  interval = "1m"
  tags = {host = "host.example.com"}
  urls = ["https://host.example.com/api/v2/sync/maindata"]
  cookie_auth_url = "https://host.example.com/api/v2/auth/login"
  cookie_auth_method = "POST"
  cookie_auth_headers = { Content-Type = "application/x-www-form-urlencoded; charset=UTF-8" }
  cookie_auth_body = 'username=QBIT_USER&password=QBIT_PASSWORD'
  data_format = "json_v2"
  [[inputs.http.json_v2]]
        [[inputs.http.json_v2.object]]
            path = "server_state"
            disable_prepend_keys = true

[[inputs.http]]
  interval = "1m"
  tags = {host = "host.example.com"}
  urls = ["https://host.example.com/api/v2/transfer/info"]
  cookie_auth_url = "https://host.example.com/api/v2/auth/login"
  cookie_auth_method = "POST"
  cookie_auth_headers = { Content-Type = "application/x-www-form-urlencoded; charset=UTF-8" }
  cookie_auth_body = 'username=QBIT_USER&password=QBIT_PASSWORD'
  data_format = "json_v2"
  [[inputs.http.json_v2]]
        [[inputs.http.json_v2.object]]
            path = "@this"
            included_keys = ["dl_info_data", "dl_info_speed", "up_info_data", "up_info_speed"]
            disable_prepend_keys = true
```

Bash script that uploads qBittorrent Web UI API info to prometheus' pushgateway every minute.

## Dependencies

- [awk](https://www.gnu.org/software/gawk/manual/gawk.html)
- [curl](https://curl.se/)
- [jq](https://stedolan.github.io/jq/)
- Optional:
  - [make](https://www.gnu.org/software/make/) - for automatic installation support
  - [docker](https://docs.docker.com/)

## Relevant documentation

- [qBittorrent WebUI API](<https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)>)
- [Prometheus Pushgateway](https://github.com/prometheus/pushgateway/blob/master/README.md)
- [Systemd Timers](https://www.freedesktop.org/software/systemd/man/systemd.timer.html)

## Installation

### With Docker

#### docker-compose

1. Configure `qbit_exporter.conf` (see the configuration section below).
1. Run it.

   ```bash
   docker compose up --detach
   ```

#### docker build & run

1. Build the docker image.

   ```bash
   docker build . --tag qbit-exporter
   ```

1. Configure `qbit_exporter.conf` (see the configuration section below).
1. Run it.

   ```bash
    docker run --rm --init --tty --interactive --read-only --cap-drop ALL --security-opt no-new-privileges:true --cpus 2 -m 64m --pids-limit 16 --volume ./qbit_exporter.conf:/app/qbit_exporter.conf:ro ghcr.io/rare-magma/qbit-exporter:latest
    ```

### With the Makefile

For convenience, you can install this exporter with the following command or follow the manual process described in the next paragraph.

```bash
make install
$EDITOR $HOME/.config/qbit_exporter.conf
```

### Manually

1. Copy `qbit_exporter.sh` to `$HOME/.local/bin/` and make it executable.

2. Copy `qbit_exporter.conf` to `$HOME/.config/`, configure it (see the configuration section below) and make it read only.

3. Copy the systemd unit and timer to `$HOME/.config/systemd/user/`:

   ```bash
   cp qbit-exporter.* $HOME/.config/systemd/user/
   ```

4. and run the following command to activate the timer:

   ```bash
   systemctl --user enable --now qbit-exporter.timer
   ```

It's possible to trigger the execution by running manually:

```bash
systemctl --user start qbit-exporter.service
```

### Config file

The config file has a few options:

```bash
QBIT_URL='https://qbittorrent.example.com'
QBIT_USER='username'
QBIT_PASS='password'
PUSHGATEWAY_URL='https://pushgateway.example.com'
```

- `QBIT_URL` should be the same URL as used to access the qBittorrent web user interface
- `PUSHGATEWAY_URL` should be a valid URL for the [push gateway](https://github.com/prometheus/pushgateway).

  Optional:

  - `QBIT_USER` should be the username configured to access the qBittorrent web user interface
  - `QBIT_PASS` should be the password corresponding to the user above

### Troubleshooting

Run the script manually with bash set to trace:

```bash
bash -x $HOME/.local/bin/qbit_exporter.sh
```

Check the systemd service logs and timer info with:

```bash
journalctl --user --unit qbit-exporter.service
systemctl --user list-timers
```

## Exported metrics

- dl_info_data_alltime: All-time download (bytes)
- dl_info_data: Data downloaded this session (bytes)
- dl_info_speed: Global download rate (bytes/s)
- up_info_data_alltime: All-time upload (bytes)
- up_info_data: Data uploaded this session (bytes)
- up_info_speed: Global upload rate (bytes/s)

## Exported metrics example

```
# HELP dl_info_data_alltime All-time download (bytes)
# TYPE dl_info_data_alltime counter
# HELP dl_info_data Data downloaded this session (bytes)
# TYPE dl_info_data counter
# HELP dl_info_speed Global download rate (bytes/s)
# TYPE dl_info_speed gauge
# HELP up_info_data Data uploaded this session (bytes)
# TYPE up_info_data counter
# HELP up_info_data_alltime All-time upload (bytes)
# TYPE up_info_data_alltime counter
# HELP up_info_speed Global upload rate (bytes/s)
# TYPE up_info_speed gauge
dl_info_data_alltime{host="qbittorrent.example.com"} 1.9616861272791e+13
dl_info_data {host="qbittorrent.example.com"} 81434357739
dl_info_speed {host="qbittorrent.example.com"} 0
up_info_data {host="qbittorrent.example.com"} 1375554433715
up_info_data_alltime{host="qbittorrent.example.com"} 1.62631111452758e+14
up_info_speed {host="qbittorrent.example.com"} 7569367
```

## Example grafana dashboard

In `grafana-dashboard.json` there is an example of the kind of dashboard that can be built with `qbit-exporter` data:

<img src="dashboard-screenshot.png" title="Example grafana dashboard" width="100%">

Import it by doing the following:

1. Create a dashboard
2. Click the dashboard's settings button on the top right.
3. Go to JSON Model and then paste there the content of the `grafana-dashboard.json` file.

## Uninstallation

### With the Makefile

For convenience, you can uninstall this exporter with the following command or follow the process described in the next paragraph.

```
make uninstall
```

### Manually

Run the following command to deactivate the timer:

```
systemctl --user disable --now qbit-exporter.timer
```

Delete the following files:

```
$HOME/.local/bin/qbit_exporter.sh
$HOME/.config/qbit_exporter.conf
$HOME/.config/systemd/user/qbit-exporter.timer
$HOME/.config/systemd/user/qbit-exporter.service
```

## Credits

- [reddec/compose-scheduler](https://github.com/reddec/compose-scheduler)
