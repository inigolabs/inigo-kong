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

### Overview
Gain instant monitoring and protection into GraphQL APIs. Unblock platform teams and accelerate GraphQL adoption.
Inigo's platform integration offers GraphQL Security, Analytics, Rate-limiting, Access Control and more.

This package is the Inigo plugin for Ruby servers.

### Documentation
* [Docs](https://docs.inigo.io/)
* [Integration](https://docs.inigo.io/product/agent_installation/kong)
* [Example](https://github.com/inigolabs/inigo-rb/tree/master/kong)

### Docker image

1. Download inigo libs from https://github.com/inigolabs/artifacts/releases/latest and put them in the libs folder in the root of this repo. Example:

```
inigo-linux-amd64.so -> inigo-kong/libs/inigo_linux_amd64/libinigo.so
inigo-darwin-amd64.dylib -> inigo-kong/libs/inigo_darwin_amd64/libinigo.dylib
```

2. Build Docker image - ```docker build -t <put-your-tag> .```
3. Obtain installation script from Kong Konnect, substitute kong docker image with the newly built one
4. Add `INIGO_SERVICE_TOKEN` env var (get it from app.inigo.io)
5. Add 'inigo' plugin to Kong Konnect and enable it

### Contributing
Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

### License
Distributed under the MIT License.
