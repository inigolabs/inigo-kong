local ffi = require("ffi")
local cjson = require "cjson"

ffi.cdef[[
  typedef size_t GoUintptr;
  typedef long long GoInt64;
  typedef GoInt64 GoInt;
  typedef unsigned char GoUint8;

  typedef struct Config {
    int8_t logLevel;
    char* name;
    char* service;
    char* token;
    char* schema;
    char* runtime;
    char* egressUrl;
    uintptr_t gateway;
    int8_t disableResponseData;
  } Config;

  GoUintptr create(Config* c);
  char* get_version();
  char* check_lasterror();
  GoUintptr process_service_request(GoUintptr handlePtr, char* subgraph_name, int subgraph_name_len, char* header, int header_len, char* input, int input_len, char** output, GoInt* output_len, char** status_output, GoInt* status_output_len);
  void process_response(GoUintptr handlePtr, GoUintptr reqHandle, char* input, GoInt input_len, char** output, GoInt* output_len);
  extern GoUint8 update_schema(GoUintptr handlePtr, char* input, GoInt input_len);

  extern void disposeHandle(GoUintptr handlePtr);
]]

local inigo = {
  -- priority determines plugin execution order, see https://docs.konghq.com/gateway/3.7.x/plugin-development/custom-logic/#plugins-execution-order
  PRIORITY = 1000,
  VERSION = "0.30.20",
}

local function getArch()
  local arch = ffi.arch

  if (arch == "x64") then
    return "amd64"
  end

  if (arch == "x32") then
    return "i386"
  end

  return string.lower(arch)
end

local function getOS()
  local os = ffi.os

  if (os == "win32") then
    return "windows"
  end

  return string.lower(os)
end

local function getExt()
  local os = getOS()

  if (os == "windows") then
    return ".dll"
  end

  if (os == "darwin") then
    return ".dylib"
  end

  return ".so" -- Linux
end

local lib_path = "inigo_" .. getOS() .. "_" .. getArch() .. "/libinigo" .. getExt()
local base_path = os.getenv("INIGO_LIB_BASE_PATH") or "/"
local full_path = base_path .. "kong/plugins/inigo/" .. lib_path
kong.log.debug("inigo : inigo lib path - ", full_path, ", os - ", ffi.os, ", arch - ", ffi.arch)

-- LOG_LEVELS mapping to indexes as they are defined in Inigo
local LOG_LEVELS = {
    ["debug"]   = 2,
    ["info"]    = 3,
    ["notice"]  = 4,
    ["warn"]    = 5,
    ["error"]   = 6,
    ["crit"]    = 8,
}

function inigo:configure(configs)
  -- to avoid nil-value error when Kong attempts to use local declarative configuration first and that one is not provided
  if configs == nil then
      return
  end

  kong.log.debug("configure : start")

  -- load Inigo lib
  self.libinigo = ffi.load(full_path)

  -- create a table that will be populated with Inigo handlers for different Inigo services (as configured per route)
  self.inigo_agents = {}

  -- iterate over all routes and create inigo instances for each unique token value
  for i = 1, #configs do
    local token_raw = configs[i].token
    local token;

    if kong.vault.is_reference(token_raw) then
      local value, err = kong.vault.get(token_raw)
      if err ~= nil then
        kong.log.err("configure : cannot read token from vault by path ", token_raw, ", err : ", err)
        return
      end

      kong.log.debug("configure : token is taken from vault by path ", token_raw)
      token = value
    else
      token = token_raw;
    end

    local instance = self.inigo_agents[token_raw]
    if not instance then
      kong.log.debug("configure : creating Inigo instance")

      -- create Inigo config (all Inigo services share the same env variables except the token)
      local cfg = ffi.typeof("Config")()
      cfg.logLevel = LOG_LEVELS[kong.configuration.log_level]
      cfg.name = ffi.cast("char*", "kong "..kong.version.."\0")
      cfg.runtime = ffi.cast("char*", string.lower(_VERSION).."\0")

      cfg.token = ffi.cast("char*", token)

      -- supply schema if provided
      local schema = configs[i].schema
      if schema ~= nil then
        cfg.schema = ffi.cast("char*", schema)
      end

      -- create Inigo instance
      self.inigo_agents[token_raw] = self.libinigo.create(cfg)
      local agent_create_err = ffi.string(self.libinigo.check_lasterror())
      if agent_create_err ~= "" then
        kong.log.err("configure : create failed - ", agent_create_err)
      end
    end
  end

  kong.log.debug("configure : end")
end

-- process request
function inigo:access(plugin_conf)
  kong.log.debug("process_request : start")

  self.handle_ptr = self.inigo_agents[plugin_conf.token]
  if not self.handle_ptr then
    kong.log.err("process_request : inigo instance not found")
    return
  end

  -- headers
  local req_headers = kong.request.get_headers()
  local headers_str = cjson.encode(req_headers)
  local headers = ffi.cast("char *", headers_str)
  local header_len = ffi.cast("GoInt", #headers_str)

  -- body
  local req_body = kong.request.get_raw_body()
  local body = ffi.cast("char*", req_body)
  local body_len = ffi.cast("GoInt", #req_body)

  -- output
  local output = ffi.new("char*[1]")
  local output_len = ffi.new("GoInt[1]")
  -- status
  local status = ffi.new("char*[1]")
  local status_len = ffi.new("GoInt[1]")

  kong.request.instance = self.libinigo.process_service_request(
    self.handle_ptr,
    nil, 0,
    headers, header_len,
    body, body_len,
    output, output_len,
    status, status_len
  )

  -- mutate request : if request is mutated by Inigo
  local status_size = tonumber(status_len[0])
  if status_size ~= 0 then
    local status_str = ffi.string(status[0], status_size)
    kong.service.request.set_raw_body(status_str)
  end

  -- block request : if response is provided by Inigo
  local output_size = tonumber(output_len[0])
  if output_size ~= 0 then
    local output_str = ffi.string(output[0], output_size)

    self.libinigo.disposeHandle(kong.request.instance)
    kong.request.instance = nil -- avoid further processing by Inigo

    kong.response.exit(200, output_str)
  end

  kong.log.debug("process_request : end")
end

-- process response
function inigo:body_filter(plugin_conf)
  if not self.handle_ptr then
    return
  end

  if not kong.request.instance or tonumber(kong.request.instance) == 0 then
    -- request was either not processed by Inigo or blocked by Inigo
    return
  end

  local resp_body = kong.response.get_raw_body()
  if resp_body == "" or not resp_body then
    return
  end

  kong.log.debug("process_response : start : instance - ", tonumber(kong.request.instance))

  -- input : body
  local body = ffi.cast("char*", resp_body)
  local body_len = ffi.cast("GoInt", tostring(resp_body):len())

  -- output : response
  local response = ffi.new("char*[1]")
  local response_len = ffi.new("GoInt[1]")

  self.libinigo.process_response(
    self.handle_ptr,
    kong.request.instance,
    body, body_len,
    response, response_len
  )

  local resp_size = tonumber(response_len[0])
  if resp_size ~= 0 then
    local raw_body = ffi.string(response[0], resp_size)
    kong.response.set_raw_body(raw_body)
  end

  kong.log.debug("process_response : end")
end

function inigo:header_filter()
  if not self.handle_ptr then
    return
  end

  if not kong.request.instance or tonumber(kong.request.instance) == 0 then
    return
  end

  -- clear Content-Length in case body will be changed
  -- doc : https://docs.konghq.com/gateway/latest/plugin-development/pdk/kong.response/#kongresponseset_raw_bodybody
  kong.response.clear_header("Content-Length")
end

function inigo:log()
  if not self.handle_ptr then
    return
  end

  if kong.request.instance then
    self.libinigo.disposeHandle(kong.request.instance)
  end
end

-- return inigo plugin object
return inigo
