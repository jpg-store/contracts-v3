# Marketplace | Jpg.store v3 contracts powered by Aiken

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
