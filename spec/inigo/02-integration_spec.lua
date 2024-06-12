local helpers = require "spec.helpers"

local PLUGIN_NAME = "inigo"

for _, strategy in helpers.all_strategies() do if strategy ~= "cassandra" then
  describe(PLUGIN_NAME .. ": inigo plugin [#" .. strategy .. "]", function()
    local client
    helpers.setenv("LOG_LEVEL", "debug")
    -- a dummoy token
    helpers.setenv("INIGO_SERVICE_TOKEN", "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJNYXBDbGFpbXMiOm51bGwsInRva2VuVHlwZSI6InNlcnZpY2VfdG9rZW4iLCJ1c2VyX3Byb2ZpbGUiOiJzaWRlY2FyIiwidXNlcl9yb2xlcyI6WyJzaWRlY2FyIl0sInVzZXJfaWQiOjEsInVzZXJfbmFtZSI6IktvbmciLCJvcmdfaWQiOjEsIm9yZ19kZXNjIjoiS29uZyBQb25nbyIsInRva2VuIjoiMDEyMzQ1NjctODkxMC0xMTEyLTEzMTQtMTUxNjE3MTgxOTIwIiwiaWF0IjoxNzEwOTI0MDIyLCJzdWIiOiJ1bml0OnRlc3QifQ.U18pxtiU2UsdAZwv4_DPbDVU7xKwRsD94SsOPRSQdbeS1q2ZwP_6oNZCxdfmcyaAHTneUIdrm6XydDsHHV2hHw")
    helpers.setenv("INIGO_SERVICE_URL", "http://192.168.49.2:30018/query")
    helpers.setenv("INIGO_STORAGE_URL", "http://192.168.49.2:30020/query")
    helpers.setenv("INIGO_DEPLOYMENT_ENV", "mini")
    helpers.setenv("INIGO_EGRESS_URL", "http://192.168.49.2:30007/query")
    helpers.setenv("INIGO_LIB_BASE_PATH", "/kong-plugin/") -- path inside pongo container

    lazy_setup(function()
      local bp = helpers.get_db_utils(strategy == "off" and "postgres" or strategy, nil, { PLUGIN_NAME })
      -- Inject a test route. No need to create a service, there is a default
      -- service which will echo the request.
      local route1 = bp.routes:insert({
        hosts = { "local.host" },
      })
      -- add the plugin to test to the route we created
      bp.plugins:insert {
        name = PLUGIN_NAME,
        route = { id = route1.id },
        config = { },
      }

      -- start kong
      assert(helpers.start_kong({
        -- set the strategy
        database   = strategy,
        -- use the custom test template to create a local mock server
        nginx_conf = "spec/fixtures/custom_nginx.template",
        -- make sure our plugin gets loaded
        plugins = "bundled," .. PLUGIN_NAME,
        -- write & load declarative config, only if 'strategy=off'
        declarative_config = strategy == "off" and helpers.make_yaml_file() or nil,
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong(nil, true)
    end)

    before_each(function()
      client = helpers.proxy_client()
    end)

    after_each(function()
      if client then client:close() end
    end)


    describe("response", function()
      it("run inigo", function()
        local r = client:post("/request", {
          headers = {
            host = "local.host",
          },
          body = '{"query":"query films { films { episodeId title director } }","operationName":"films"}'
        })
        -- local header_value = assert.response(r).has.header("inigo")

        -- validate that the request succeeded, response status 200
        assert.response(r).has.status(200)
        assert.response(r).has.jsonbody()
        -- now check the response to have the header
        -- local header_value = assert.response(r).has.header("bye-world")
        -- validate the value of that header
        -- assert.equal("send response header", header_value)
      end)
    end)

  end)

end end
