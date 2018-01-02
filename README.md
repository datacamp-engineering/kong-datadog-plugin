# Kong datadog plugin with extended tags usage

This repository contains a slightly modified version of the datadog plugin from
Kong core. This version sends API name, API URIs and status codes in tags
instead of interpolated in the metric name. Having variable information in the
tags is more convenient in datadog as it allows aggregating metrics from
multiple APIs.

Example plugin configuration:
```
config = {
  host    = "127.0.0.1",
  port    = 9999,
  metrics = {
    {
      name        = "status_count",
      stat_type   = "counter",
      sample_rate = 1,
      tags        = {"T1:V1"}
    }
  }
```

## Development

Follow the guidelines in [kong-vagrant][https://github.com/Kong/kong-vagrant].
Clone this repository into `kong-vagrant` directory with the name `kong-plugin`
and run `vagrant up`.

### Running tests

SSH into vagrant machine `vagrant ssh`.
Then
```bash
cd /kong-plugin
/kong/bin/busted
```

### Releasing

Update version in rockspec and rockspec filename. Execute `luarocks upload _plugin_and_version.rockspec`.
