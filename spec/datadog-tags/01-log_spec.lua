local helpers = require "spec.helpers"
local threads = require "llthreads2.ex"
local pl_file = require "pl.file"

describe("Plugin: datadog (log)", function()
  local client
  setup(function()
    helpers.run_migrations()

    local consumer1 = assert(helpers.dao.consumers:insert {
      username = "foo",
      custom_id = "bar"
    })
    assert(helpers.dao.keyauth_credentials:insert {
      key = "kong",
      consumer_id = consumer1.id
    })

    local api1 = assert(helpers.dao.apis:insert {
      name         = "dd1",
      hosts        = { "datadog1.com" },
      upstream_url = helpers.mock_upstream_url,
    })
    assert(helpers.dao.plugins:insert {
      name   = "key-auth",
      api_id = api1.id
    })
    local api2     = assert(helpers.dao.apis:insert {
      name         = "dd2",
      hosts        = { "datadog2.com" },
      upstream_url = helpers.mock_upstream_url,
    })
    local api3     = assert(helpers.dao.apis:insert {
      name         = "dd3",
      hosts        = { "datadog3.com" },
      upstream_url = helpers.mock_upstream_url,
    })
    local api4     = assert(helpers.dao.apis:insert {
      name         = "dd4",
      hosts        = { "datadog4.com" },
      upstream_url = helpers.mock_upstream_url,
    })
    assert(helpers.dao.plugins:insert {
      name   = "key-auth",
      api_id = api4.id
    })
    assert(helpers.dao.plugins:insert {
      name   = "datadog-tags",
      api_id = api1.id,
      config = {
        host = "127.0.0.1",
        port = 9999,
      },
    })
    assert(helpers.dao.plugins:insert {
      name   = "datadog-tags",
      api_id = api2.id,
      config = {
        host    = "127.0.0.1",
        port    = 9999,
        metrics = {
          {
            name        = "status_count",
            stat_type   = "counter",
            sample_rate = 1,
          },
          {
            name        = "request_count",
            stat_type   = "counter",
            sample_rate = 1,
          },
        },
      },
    })
    assert(helpers.dao.plugins:insert {
      name   = "datadog-tags",
      api_id = api3.id,
      config = {
        host    = "127.0.0.1",
        port    = 9999,
        metrics = {
          {
            name        = "status_count",
            stat_type   = "counter",
            sample_rate = 1,
            tags        = {"T1:V1"},
          },
          {
            name        = "request_count",
            stat_type   = "counter",
            sample_rate = 1,
            tags        = {"T2:V2,T3:V3,T4"},
          },
          {
            name        = "latency",
            stat_type   = "gauge",
            sample_rate = 1,
            tags        = {"T2:V2:V3,T4"},
          },
        },
      },
    })
    assert(helpers.dao.plugins:insert {
      name   = "datadog-tags",
      api_id = api4.id,
      config = {
        host   = "127.0.0.1",
        port   = 9999,
        prefix = "prefix",
      },
    })

    assert(helpers.start_kong({
      nginx_conf = "spec/fixtures/custom_nginx.template",
    }))
    client = helpers.proxy_client()
  end)
  teardown(function()
    if client then client:close() end
    helpers.stop_kong()
  end)

  it("logs metrics over UDP", function()
    local thread = threads.new({
      function()
        local socket = require "socket"
        local server = assert(socket.udp())
        server:settimeout(1)
        server:setoption("reuseaddr", true)
        server:setsockname("127.0.0.1", 9999)
        local gauges = {}
        for _ = 1, 12 do
          gauges[#gauges+1] = server:receive()
        end
        server:close()
        return gauges
      end
    })
    thread:start()
    ngx.sleep(0.1)

    local res = assert(client:send {
      method = "GET",
      path = "/status/200?apikey=kong",
      headers = {
        ["Host"] = "datadog1.com"
      }
    })
    assert.res_status(200, res)

    local ok, gauges = thread:join()
    assert.True(ok)
    assert.equal(12, #gauges)
    assert.contains("kong.request.count:1|c|#app:kong,api_name:dd1", gauges)
    assert.contains("kong.latency:%d+|ms|#app:kong,api_name:dd1", gauges, true)
    assert.contains("kong.request.size:%d+|ms|#app:kong,api_name:dd1", gauges, true)
    assert.contains("kong.request.status:1|c|#app:kong,api_name:dd1,status:200", gauges)
    assert.contains("kong.request.status.total:1|c|#app:kong,api_name:dd1", gauges)
    assert.contains("kong.response.size:%d+|ms|#app:kong,api_name:dd1", gauges, true)
    assert.contains("kong.upstream_latency:%d+|ms|#app:kong,api_name:dd1", gauges, true)
    assert.contains("kong.kong_latency:%d*|ms|#app:kong,api_name:dd1", gauges, true)
    assert.contains("kong.user.uniques:.*|s|#app:kong,api_name:dd1", gauges, true)
    assert.contains("kong.user.*.request.count:1|c|#app:kong,api_name:dd1", gauges, true)
    assert.contains("kong.user.*.request.status.total:1|c|#app:kong,api_name:dd1",
                    gauges, true)
    assert.contains("kong.user.*.request.status:1|c|#app:kong,api_name:dd1,status:200",
                    gauges, true)
  end)

  it("logs metrics over UDP with custom prefix", function()
    local thread = threads.new({
      function()
        local socket = require "socket"
        local server = assert(socket.udp())
        server:settimeout(1)
        server:setoption("reuseaddr", true)
        server:setsockname("127.0.0.1", 9999)
        local gauges = {}
        for _ = 1, 12 do
          gauges[#gauges+1] = server:receive()
        end
        server:close()
        return gauges
      end
    })
    thread:start()
    ngx.sleep(0.1)

    local res = assert(client:send {
      method = "GET",
      path = "/status/200?apikey=kong",
      headers = {
        ["Host"] = "datadog4.com"
      }
    })
    assert.res_status(200, res)

    local ok, gauges = thread:join()
    assert.True(ok)
    assert.equal(12, #gauges)
    assert.contains("prefix.request.count:1|c|#app:kong,api_name:dd4",gauges)
    assert.contains("prefix.latency:%d+|ms|#app:kong,api_name:dd4", gauges, true)
    assert.contains("prefix.request.size:%d+|ms|#app:kong,api_name:dd4", gauges, true)
    assert.contains("prefix.request.status:1|c|#app:kong,api_name:dd4,status:200", gauges)
    assert.contains("prefix.request.status.total:1|c|#app:kong,api_name:dd4", gauges)
    assert.contains("prefix.response.size:%d+|ms|#app:kong,api_name:dd4", gauges, true)
    assert.contains("prefix.upstream_latency:%d+|ms|#app:kong,api_name:dd4", gauges, true)
    assert.contains("prefix.kong_latency:%d*|ms|#app:kong,api_name:dd4", gauges, true)
    assert.contains("prefix.user.uniques:.*|s|#app:kong,api_name:dd4", gauges, true)
    assert.contains("prefix.user.*.request.count:1|c|#app:kong,api_name:dd4",
                    gauges, true)
    assert.contains("prefix.user.*.request.status.total:1|c|#app:kong,api_name:dd4",
                    gauges, true)
    assert.contains("prefix.user.*.request.status:1|c|#app:kong,api_name:dd4,status:200",
                    gauges, true)
  end)

  it("logs only given metrics", function()
    local thread = threads.new({
      function()
        local socket = require "socket"
        local server = assert(socket.udp())
        server:settimeout(1)
        server:setoption("reuseaddr", true)
        server:setsockname("127.0.0.1", 9999)
        local gauges = {}
        for _ = 1, 3 do
          gauges[#gauges+1] = server:receive()
        end
        server:close()
        return gauges
      end
    })
    thread:start()
    ngx.sleep(0.1)

    local res = assert(client:send {
      method = "GET",
      path = "/status/200",
      headers = {
        ["Host"] = "datadog2.com"
      }
    })
    assert.res_status(200, res)

    local ok, gauges = thread:join()
    assert.True(ok)
    assert.equal(3, #gauges)
    assert.contains("kong.request.count:1|c|#api_name:dd2", gauges)
    assert.contains("kong.request.status:1|c|#api_name:dd2,status:200", gauges)
    assert.contains("kong.request.status.total:1|c|#api_name:dd2", gauges)
  end)

  it("logs metrics with tags", function()
    local thread = threads.new({
      function()
        local socket = require "socket"
        local server = assert(socket.udp())
        server:settimeout(1)
        server:setoption("reuseaddr", true)
        server:setsockname("127.0.0.1", 9999)
        local gauges = {}
        for _ = 1, 4 do
          gauges[#gauges+1] = server:receive()
        end
        server:close()
        return gauges
      end
    })
    thread:start()
    ngx.sleep(0.1)

    local res = assert(client:send {
      method = "GET",
      path = "/status/200",
      headers = {
        ["Host"] = "datadog3.com"
      }
    })
    assert.res_status(200, res)

    local ok, gauges = thread:join()
    assert.True(ok)
    assert.contains("kong.request.count:1|c|#T2:V2,T3:V3,T4,api_name:dd3", gauges)
    assert.contains("kong.request.status:1|c|#T1:V1,api_name:dd3,status:200", gauges)
    assert.contains("kong.request.status.total:1|c|#T1:V1,api_name:dd3", gauges)
    assert.contains("kong.latency:%d+|g|#T2:V2:V3,T4,api_name:dd3", gauges, true)
  end)

  it("should not return a runtime error (regression)", function()
    local thread = threads.new({
      function()
        local socket = require "socket"
        local server = assert(socket.udp())
        server:settimeout(1)
        server:setoption("reuseaddr", true)
        server:setsockname("127.0.0.1", 9999)
        local gauge = server:receive()
        server:close()
        return gauge
      end
    })
    thread:start()
    ngx.sleep(0.1)

    local res = assert(client:send {
      method = "GET",
      path = "/NonMatch",
      headers = {
        ["Host"] = "fakedns.com"
      }
    })

    assert.res_status(404, res)

    local err_log = pl_file.read(helpers.test_conf.nginx_err_logs)
    assert.not_matches("attempt to index field 'api' (a nil value)", err_log, nil, true)
  end)
end)
