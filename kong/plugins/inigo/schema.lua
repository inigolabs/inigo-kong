local typedefs = require "kong.db.schema.typedefs"

local schema = {
  name = "inigo",
  fields = {
    -- this plugin cannot be configured on a consumer (typical for auth plugins)
    { consumer = typedefs.no_consumer },

    -- this plugin will only run within Nginx HTTP module
    { protocols = typedefs.protocols_http },

    -- plugin specific configuration
    { config = {
        type = "record",
        fields = {
          {
            token = {
              type = "string",
              description = "Inigo service token. Check out https://docs.inigo.io/ to setup a service and a token.",
              required = true
            }
          },
          {
            schema = {
              type = "string",
              description = "GraphQL schema of the endpoint. If not provided, Inigo Plugin will pull it from the cloud.",
              required = false
            }
          }
        },
        entity_checks = {},
      },
    },
  },
}

return schema
