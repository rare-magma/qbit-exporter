# qbit-exporter

Bash script that uploads qbittorrent Web UI API info to prometheus' pushgateway every minute.

## Dependencies

- [curl](https://curl.se/)
- [jq](https://stedolan.github.io/jq/)
- Optional: [make](https://www.gnu.org/software/make/) - for automatic installation support

## Relevant documentation

- [qBittorrent WebUI API](<https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)>)
- [Prometheus Pushgateway](https://github.com/prometheus/pushgateway/blob/master/README.md)
- [Systemd Timers](https://www.freedesktop.org/software/systemd/man/systemd.timer.html)

## Installation

### With the Makefile

For convenience, you can install this exporter with the following command or follow the manual process described in the next paragraph.

```
make install
$EDITOR $HOME/.config/qbit_exporter.conf
```

### Manually

1. Copy `qbit_exporter.sh` to `$HOME/.local/bin/` and make it executable.

2. Copy `qbit_exporter.conf` to `$HOME/.config/`, configure it (see the configuration section below) and make it read only.

3. Copy the systemd unit and timer to `$HOME/.config/systemd/user/`:

```
cp qbit-exporter.* $HOME/.config/systemd/user/
```

4. and run the following command to activate the timer:

```
systemctl --user enable --now qbit-exporter.timer
```

It's possible to trigger the execution by running manually:

```
systemctl --user start qbit-exporter.service
```

### Config file

The config file has a few options:

```
QBIT_URL='https://qbit.example.com'
PUSHGATEWAY_URL='https://pushgateway.example.com'
```

- `QBIT_URL` should be the same URL as used to access the qBittorrent web user interface
- `PUSHGATEWAY_URL` should be a valid URL for the [push gateway](https://github.com/prometheus/pushgateway).

### Troubleshooting

Check the systemd service logs and timer info with:

```
journalctl --user --unit qbit-exporter.service
systemctl --user list-timers
```

## Exported metrics

- dl_info_data: Data downloaded this session (bytes)
- dl_info_speed: Global download rate (bytes/s)
- up_info_data: Data uploaded this session (bytes)
- up_info_speed: Global upload rate (bytes/s)

## Exported metrics example

```
# HELP dl_info_data Data downloaded this session (bytes)
# TYPE dl_info_data counter
# HELP dl_info_speed Global download rate (bytes/s)
# TYPE dl_info_speed gauge
# HELP up_info_data Data uploaded this session (bytes)
# TYPE up_info_data counter
# HELP up_info_speed Global upload rate (bytes/s)
# TYPE up_info_speed gauge
dl_info_data {host="$HOSTNAME"} ${dl_info_data_value}
dl_info_speed {host="$HOSTNAME"} ${dl_info_speed_value}
up_info_data {host="$HOSTNAME"} ${up_info_data_value}
up_info_speed {host="$HOSTNAME"} ${up_info_speed_value}
```

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

This project takes inspiration from the following:

- [rare-magma/pbs-exporter](https://github.com/rare-magma/pbs-exporter)
