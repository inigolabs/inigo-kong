local typedefs = require "kong.db.schema.typedefs"

local schema = {
  name = "inigo",
  fields = {
    -- this plugin cannot be configured on a consumer (typical for auth plugins)
    { consumer = typedefs.no_consumer },

    -- this plugin will only run within Nginx HTTP module
    { protocols = typedefs.protocols_http },

    -- plugin specific configuration (configuration description that will appear in the Kong Konnect UI)
    { config = {
        type = "record",
        fields = {},
        entity_checks = {},
      },
    },
  },
}

return schema
