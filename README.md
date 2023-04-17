# Marketplace | Jpg.store v3 contracts powered by Aiken

This repo contains the smart contracts powering jpg.store. 100% written in Aiken.

There are two main contracts: Bid and Ask. Bids are offerings in ADA in exchange for a given asset, asks are assets in exchange for ADA.

## Ask

### Important/Breaking changes

- The "Payout" struct is now the following:

```gleam
pub type Payout {
  vkh: VerificationKeyHash, // Before: A full address
  amount_lovelace: Int, // Before: A "Value" type
}
```

- A new field was added to the datum:

```gleam
private_buyer: Option<VerificationKeyHash>,
```

This can be ignored initially, so add a `Constr(idx, [])`

- Output tagging is introduced to prevent double satisfaction. For every output corresponding to a payout, an inline datum `PaymentDatum` must be created:

```gleam
pub type TagDatum {
  output_reference: OutputReference,
}
```

- Marketplace payout is now **implicit**, meaning that it should not be included in the payout list.
