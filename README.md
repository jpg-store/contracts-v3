<div align="center">
  <img src="https://github.com/jpg-store/contracts-v3/blob/main/img/icon.png?raw=true" alt="Jpg Store" height="150" />

  <hr />
    <h2 align="center" style="border-bottom: none">
      <a href="https://jpg.store">jpg.store</a> v3 contracts powered by <a href="https://aiken-lang.org">Aiken</a>
    </h2>

[![Licence](https://img.shields.io/github/license/jpg-store/contracts-v3)](https://github.com/jpg-store/contracts-v3/blob/main/LICENSE)
[![Tests](https://github.com/jpg-store/contracts-v3/actions/workflows/tests.yaml/badge.svg?branch=main)](https://github.com/jpg-store/contracts-v3/actions/workflows/tests.yaml)

  <hr />
</div>

This repo contains the smart contracts powering jpg.store. 100% written in
Aiken.

There are two main contracts: Bid and Ask. Bids are offerings in ADA in exchange
for a given asset, asks are assets in exchange for ADA.

Ask bulk-purchase currently maxes out at **54** assets in a single transaction when running
the e2e tests.

## Ask

### Important/Breaking changes

Check out our [medium post](https://medium.com/@jpgstorenft/unveiling-the-next-gen-smart-contract-update-for-jpg-store-2f883c913979)

## Development

- install [Aiken](https://aiken-lang.org/installation-instructions)
- `aiken check`
- `cd e2e && deno task e2e`

> If you change any Aiken code please run `aiken build` and commit the `plutus.json` file.
