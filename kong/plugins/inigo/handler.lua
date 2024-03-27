-- If you're not sure your plugin is executing, uncomment the line below and restart Kong
-- then it will throw an error which indicates the plugin is being loaded at least.

--assert(ngx.get_phase() == "timer", "The world is coming to an end!")

---------------------------------------------------------------------------------------------
-- In the code below, just remove the opening brackets; `[[` to enable a specific handler
--
-- The handlers are based on the OpenResty handlers, see the OpenResty docs for details
-- on when exactly they are invoked and what limitations each handler has.
---------------------------------------------------------------------------------------------

local ffi = require("ffi")
local cjson = require "cjson"

print("====================== INIT START =======================")

local function getArch() 
  local arch = ffi.arch
  if (arch == "x64") then return "amd64" end
  if (arch == "x32") then return "i386" end
  return string.lower(arch)
end

local function getOS()
  local os = ffi.os
  if (os == "win32") then return "windows" end
  return string.lower(os)
end

local function getExt()
  local os = getOS()
  if (os == "windows") then return ".dll"
  elseif (os == "darwin") then return ".dylib"
  end

  return ".so" -- Linux
end

print("OS: ", ffi.os, " => ", getOS())
print("ARCH: ", ffi.arch, " => ", getArch())

local pf = "inigo_" .. getOS() .. "_" .. getArch()
local ext = getExt()

local libPath = pf .. "/libinigo" .. ext

print("load file: ", libPath)
-- @TODO - figure out better way to get path to lifffi .so file
local base_path = os.getenv("LIBFFI_BASE_PATH")
if not base_path then base_path = "/usr/local/bin/inigo/" end -- /kong-plugin/
print("load file path: ", base_path .. "kong/plugins/inigo/" .. libPath)
local libinigo = ffi.load(base_path .. "kong/plugins/inigo/" .. libPath)
print("====================== INIT END =======================")

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

local version_ptr = libinigo.get_version()
  
print("Inigo version: ", ffi.string(version_ptr))

local InigoPlugin = {
  PRIORITY = 1000, -- set the plugin priority, which determines plugin execution order
  VERSION = "0.1", -- version in X.Y.Z format. Check hybrid-mode compatibility requirements.
}

-- do initialization here, any module level code runs in the 'init_by_lua_block',
-- before worker processes are forked. So anything you add here will run once,
-- but be available in all workers.


print("====================== create START =======================")
local new_cfg = ffi.typeof("Config")
local cfg = new_cfg()
-- print("TOKEN: ",  os.getenv("INIGO_SERVICE_TOKEN"))
cfg.token = ffi.cast("char*", os.getenv("INIGO_SERVICE_TOKEN"))
cfg.service = ffi.cast("char*", os.getenv("INIGO_SERVICE_URL"))
cfg.egressUrl = ffi.cast("char*", os.getenv("INIGO_EGRESS_URL"))
cfg.debug = ffi.cast("int8_t", 1)
cfg.name = ffi.cast("char*", "unittest")
cfg.runtime = ffi.cast("char*", "kong-lua")

if not InigoPlugin.handle_ptr then InigoPlugin.handle_ptr = libinigo.create(cfg) end

if not InigoPlugin.handle_ptr then
  print("Inigo lib init failed:", ffi.string(libinigo.check_lasterror()))
else 
  print("Inigo lib initialized succesfully: ", tonumber(InigoPlugin.handle_ptr))
  end
print("====================== create END =======================")


local function modify_request(req, status)
  print("====================== modify_request START =======================")
  print("req: '", req, "' | status: '", status, "' ")
  local data = nil
  local status_code = 200
  if status ~= "" then status_code = tonumber(status, 10) end
  if req ~= "" then
    local st, err = pcall(function() data = cjson.decode(req) end)
    if err then
      print("error decoding req", err, " | ", st)
    end
    kong.log.inspect(data)
  end
  print("====================== modify_request END =======================")
  return data, status_code
end

-- @TODO - implement modify_response
local function modify_response(resp)
  print("====================== modify_response START =======================")
  print(resp)
  local data = {}
  if resp ~= "" then
    local status, err = pcall(function() data = cjson.decode(resp) end) 
    if err then
      print("error decoding resp", err, " | ", status)
    end
    kong.log.inspect(data)
  end
  print("====================== modify_response END =======================")
end


-- handles more initialization, but AFTER the worker process has been forked/created.
-- It runs in the 'init_worker_by_lua_block'
function InigoPlugin:init_worker()
  print("====================== init_worker START =======================")
  -- libinigo.create does not work inside forked() worker
  -- self.handle_ptr = libinigo.create(cfg)
  print("====================== init_worker END =======================")
end --]]

-- runs in the 'access_by_lua_block'
function InigoPlugin:access(plugin_conf)
  local schema_str = ""
  print("====================== InigoPlugin:access START =======================")
  if plugin_conf.schema then
    schema_str = tostring(plugin_conf.schema)
  end

  if not self.handle_ptr then return end

  local req_headers = kong.request.get_headers()
  local headers_str = cjson.encode(req_headers)

  -- @TODO - populate schema
  local schema = ffi.cast("char *", schema_str)
  local schema_len = ffi.cast("GoInt", #schema_str)

  local headers = ffi.cast("char *", headers_str)
  local header_len = ffi.cast("GoInt", #headers_str)
  --print("Request headers: ", ffi.string(headers), " | len: ", tonumber(header_len))

  local req_body = kong.request.get_raw_body()

  local body = ffi.cast("char*", req_body)
  local body_len = ffi.cast("GoInt", #req_body)
  --print('Request body: ', ffi.string(body), " | len: ", tonumber(body_len))
  
  local typechar_ptr = ffi.typeof("char**")
  local typechar_ptr_size = ffi.sizeof(typechar_ptr)

  local typeint_ptr = ffi.typeof("GoInt*")
  local typeint_ptr_size = ffi.sizeof(typeint_ptr)

  local output = ffi.cast(typechar_ptr, ffi.C.malloc(typechar_ptr_size))
  --print("PTR_output_STR: ", tostring(output), tonumber(output))

  local output_len = ffi.cast(typeint_ptr, ffi.C.malloc(typeint_ptr_size))
  --print("PTR_output_INT: ", tostring(output_len), tonumber(output_len))


  local status = ffi.cast(typechar_ptr, ffi.C.malloc(typechar_ptr_size))
  --print("PTR_status_STR: ", tostring(status), tonumber(status))

  local status_len = ffi.cast(typeint_ptr, ffi.C.malloc(typeint_ptr_size))
  --print("PTR_status_INT: ", tostring(status_len), tonumber(status_len))

  --print("headers: ", ffi.string(headers))
  local output_str = ""
  local status_str = ""
  local size_before = tonumber(output_len[0])
  local status_size_before = tonumber(status_len[0])

  kong.request.instance = libinigo.process_service_request(
    self.handle_ptr,
    schema,
    schema_len,
    headers,
    header_len,
    body,
    body_len,
    output,
    output_len,
    status,
    status_len
  )
  local size_after = tonumber(output_len[0])
  local status_size_after = tonumber(status_len[0])

  if size_after ~= size_before then
    output_str = ffi.string(output[0], size_after)
  end

  if status_size_after ~= status_size_before then
    status_str = ffi.string(status[0], status_size_after)
  end

  print("OUTPUT: ", output_str, " |")
  print("STATUS: ", status_str, " |")
  local req_body, req_status = modify_request(output_str, status_str)
  if kong.request.instance then
    print("Inigo process_request succesfully: ", tonumber(kong.request.instance))
  else 
    print("Inigo process_request failed:", ffi.string(libinigo.check_lasterror()))
    end
  print("output: ", tonumber(output_len), " | status: ", tonumber(status_len))
  libinigo.disposeMemory(output)
  libinigo.disposeMemory(status)

  if req_body ~= nil then kong.response.exit(req_status, req_body) end

  print("====================== InigoPlugin:access END =======================")
end --]]


-- runs in the 'body_filter_by_lua_block'
function InigoPlugin:body_filter(plugin_conf)
  if not self.handle_ptr then return end
  if not kong.request.instance or tonumber(kong.request.instance) == 0 then
    print("request handle was not found")
    return
  end

  print("====================== InigoPlugin:body_filter START =======================")

  print("running :body_filter with instance: ", tonumber(kong.request.instance))
  -- your custom code here
  local resp_body = kong.response.get_raw_body()
  -- print('RESP body: ', resp_body)
  local resp_len = 2

  local body = ffi.cast("char*", "")
  if resp_body then 
    body = ffi.cast("char*", resp_body)
    resp_len = tostring(resp_body):len()
  end
  local body_len = ffi.cast("GoInt", resp_len)

  print('Response body: ', ffi.string(body), " | len: ", tonumber(body_len))

  local typechar_ptr = ffi.typeof("char**")
  local typechar_ptr_size = ffi.sizeof(typechar_ptr)

  local typeint_ptr = ffi.typeof("GoInt*")
  local typeint_ptr_size = ffi.sizeof(typeint_ptr)

  local output = ffi.cast(typechar_ptr, ffi.C.malloc(typechar_ptr_size))

  local output_len = ffi.cast(typeint_ptr, ffi.C.malloc(typeint_ptr_size))

  local size_before = tonumber(output_len[0])

  libinigo.process_response(self.handle_ptr, kong.request.instance, body, body_len, output, output_len)
  local size_after = tonumber(output_len[0])
  print("RESPONSE: ", size_before, " => ", size_after, " |")

  print("output LEN: ", size_after, " | ")

  print("output STR: '", ffi.string(output[0], size_after), "' | ")
  if size_after ~= size_before then
    modify_response(ffi.string(output[0], size_after))
  end
  local last_error = ffi.string(libinigo.check_lasterror())
  if last_error == "" then
    print("Inigo process_response success:")
  else 
    print("Inigo process_response fail: ", tostring(last_error))
    end

    libinigo.disposeMemory(output)
    print("====================== InigoPlugin:body_filter END =======================")

end

function InigoPlugin:log()
  if not self.handle_ptr then return end
  if kong.request.instance then libinigo.disposeHandle(kong.request.instance) end
end

-- return inigo plugin object
return InigoPlugin
