# Kong datadog plugin with extended tags usage

This repository contains a slightly modified version of the datadog plugin from
Kong core. This version allows sending status codes in tags when datadog
configuration includes `status_in_tags` flag.

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
      tags        = {"T1:V1"},
      status_in_tags = true
    }
  }
```
