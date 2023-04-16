use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{VerificationKey}

pub type VerificationKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type RoyaltyReceiver {
  owner: VerificationKeyHash,
  percentage_thousands: Int,
}
