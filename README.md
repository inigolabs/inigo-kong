<br />
<div align="center">
  <img src="./assets/inigo.svg">
  <img height="40" src="./assets/lua.svg">
  <p align="center">
    GraphQL for Platform Teams
    <br />
    <a href="https://inigo.io">Home</a>
    ·
    <a href="https://docs.inigo.io/">Docs</a>
    ·
    <a href="https://github.com/inigolabs/inigo-kong/issues">Issues</a>
    ·
    <a href="https://slack.inigo.io/">Slack</a>
  </p>
</div>

#### Useful ingo
Install [pongo](https://github.com/Kong/kong-pongo)

`pongo run` - to run plugin unit tests

`pongo pack` - to pack plugin files into a `.rock` file

place inigo_ffi files into `kong.plugins/inigo` folder:
```
handler.lua
schema.lua
inigo_linux_native
inigo_linux_amd64       
inigo_linux_arm64
```

### @TODO

- [ ] figure out how to pass path to libffi file (currently done with the use of `BASE_PATH` env variable)
- [ ] implement schema update
- [ ] implement any other missing functionallity
- [ ] check for memory leaks
- [ ] implement plugin schema (config structure)
- [ ] set up CI and github tests
- [ ] set up plugin publishing via luarocks package manager
- [ ] write more tests :)

### Overview
Gain instant monitoring and protection into GraphQL APIs. Unblock platform teams and accelerate GraphQL adoption.
Inigo's platform integration offers GraphQL Security, Analytics, Rate-limiting, Access Control and more.  

This package is the Inigo plugin for Ruby servers.

### Documentation
* [Docs](https://docs.inigo.io/)
* [Integration](https://docs.inigo.io/product/agent_installation/kong)
* [Example](https://github.com/inigolabs/inigo-rb/tree/master/kong)

### Contributing
Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

### License
Distributed under the MIT License.