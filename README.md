<br />
<div align="center">
  <img src="/assets/inigo.svg">
  <img height="25" src="/assets/lua.svg">
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

### @TODO

- [ ] create libinigo ffi instance for each worker, to be able to run goroutines
- [ ] figure out how to pass path to libffi file (currently done with the use of `BASE_PATH` env variable)
- [ ] implement `modify_response` function
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