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

## Ask

### Important/Breaking changes

- Output tagging is introduced to prevent double satisfaction. For every output
  corresponding to a payout or marketplace fee output, a datum hash made from
  `OutputReference` must be created:

```gleam
pub type OutputReference {
  transaction_id: TransactionId,
  output_index: Int,
}
```
