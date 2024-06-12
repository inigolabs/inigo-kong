local ffi = require("ffi")
local cjson = require "cjson"

ffi.cdef[[
  typedef size_t GoUintptr;
  typedef long long GoInt64;
  typedef GoInt64 GoInt;
  typedef unsigned char GoUint8;

  typedef struct Config {
    int8_t debug; // depracate
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
  extern void disposeMemory(void* ptr);

  void *malloc(size_t);
  // void free(void *);
]]

local inigo = {
  PRIORITY = 1000, -- set the plugin priority, which determines plugin execution order
  VERSION = "0.1", -- version in X.Y.Z format. Check hybrid-mode compatibility requirements.
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

local token = os.getenv("INIGO_SERVICE_TOKEN")
local service_url = os.getenv("INIGO_SERVICE_URL")
local egress_url = os.getenv("INIGO_EGRESS_URL")

-- create Inigo instance (after the worker process has been forked)
function inigo:init_worker()
  kong.log.debug("init_worker : start")

  -- create config
  local cfg = ffi.typeof("Config")()
  cfg.token = ffi.cast("char*", token)
  cfg.service = ffi.cast("char*", service_url)
  cfg.egressUrl = ffi.cast("char*", egress_url)
  cfg.debug = ffi.cast("int8_t", 1)
  cfg.name = ffi.cast("char*", "kong ".. kong.version)
  cfg.runtime = ffi.cast("char*", string.lower(_VERSION))

  -- load lib
  self.libinigo = ffi.load(full_path)

  -- create Inigo instance
  self.handle_ptr = self.libinigo.create(cfg)
  if not self.handle_ptr then
    kong.log.err("init_worker : create failed:", ffi.string(self.libinigo.check_lasterror()))
  end

  kong.log.debug("init_worker : end")
end

-- process request
function inigo:access(plugin_conf)
  if not self.handle_ptr then
    return
  end

  kong.log.debug("process_request : start")

  -- headers
  local req_headers = kong.request.get_headers()
  local headers_str = cjson.encode(req_headers)
  local headers = ffi.cast("char *", headers_str)
  local header_len = ffi.cast("GoInt", #headers_str)

  -- body
  local req_body = kong.request.get_raw_body()
  local body = ffi.cast("char*", req_body)
  local body_len = ffi.cast("GoInt", #req_body)

  -- output and status
  local typechar_ptr = ffi.typeof("char**")
  local typechar_ptr_size = ffi.sizeof(typechar_ptr)

  local typeint_ptr = ffi.typeof("GoInt*")
  local typeint_ptr_size = ffi.sizeof(typeint_ptr)

  local output = ffi.cast(typechar_ptr, ffi.C.malloc(typechar_ptr_size))
  local output_len = ffi.cast(typeint_ptr, ffi.C.malloc(typeint_ptr_size))
  local status = ffi.cast(typechar_ptr, ffi.C.malloc(typechar_ptr_size))
  local status_len = ffi.cast(typeint_ptr, ffi.C.malloc(typeint_ptr_size))

  local output_size_before = tonumber(output_len[0])
  local status_size_before = tonumber(status_len[0])

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
  if status_size ~= status_size_before then
    local status_str = ffi.string(status[0], status_size)
    -- TODO: mutate request
  end

  -- block request : if response is provided by Inigo
  local output_size= tonumber(output_len[0])
  if output_size ~= output_size_before then
    local output_str = ffi.string(output[0], output_size)
    kong.response.exit(200, output_str)
  end

  self.libinigo.disposeMemory(output)
  self.libinigo.disposeMemory(status)

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
  local typechar_ptr = ffi.typeof("char**")
  local typechar_ptr_size = ffi.sizeof(typechar_ptr)
  local response = ffi.cast(typechar_ptr, ffi.C.malloc(typechar_ptr_size))

  -- output : response_len
  local typeint_ptr = ffi.typeof("GoInt*")
  local typeint_ptr_size = ffi.sizeof(typeint_ptr)
  local response_len = ffi.cast(typeint_ptr, ffi.C.malloc(typeint_ptr_size))

  local response_len_before = tonumber(response_len[0])

  self.libinigo.process_response(
    self.handle_ptr,
    kong.request.instance,
    body, body_len,
    response, response_len
  )

  local resp_size = tonumber(response_len[0])
  if response_len_before ~= resp_size then
    local raw_body = ffi.string(response[0], resp_size)
    kong.response.set_raw_body(raw_body)
  end

  self.libinigo.disposeMemory(response)
  self.libinigo.disposeMemory(response_len)

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
