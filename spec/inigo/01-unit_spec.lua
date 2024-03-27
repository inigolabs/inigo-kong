local PLUGIN_NAME = "inigo"


-- helper function to validate data against a schema
local validate do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins."..PLUGIN_NAME..".schema")

  function validate(data)
    return validate_entity(data, plugin_schema)
  end
end


describe(PLUGIN_NAME .. ": (schema)", function()


  it("accepts schema", function()
    local ok, err = validate({
        schema = "schema { query }"
      })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)


  it("accepts path", function()
    local ok, err = validate({
      path = "/schema.graphql",
    })
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)


end)
