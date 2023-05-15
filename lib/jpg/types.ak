use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{Address, VerificationKey}

pub type VerificationKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type Payout {
  address: Address,
  amount_lovelace: Int,
}
