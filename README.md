# Electron Notifications ProofOfConcept (ENP)
> A bare minimum project structure based on [`electron-webpack`](https://github.com/electron-userland/electron-webpack) to exemplify problems found during development of windows notifications with electron.

### Development Scripts

```bash
# run application in development mode
yarn dev

# compile source code and create webpack output
yarn compile

# `yarn compile` & create build with electron-builder
yarn dist

# `yarn compile` & create unpacked build with electron-builder
yarn dist:dir
```

### to build an MSI

on windows, you'll need choco installed and the build-tools

run on a powershell:

`.\scripts\Makefile.ps1`
