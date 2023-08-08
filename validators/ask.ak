use aiken/builtin.{blake2b_256, serialise_data}
use aiken/list
use aiken/transaction.{InlineDatum, NoDatum, ScriptContext, Spend, Transaction}
use jpg/constants
use jpg/types.{Payout, VerificationKeyHash}
use jpg/utils.{check_marketplace_payout, check_payouts, find_payout_outputs}

/// A listing requires a datum that has
/// the owner's payment key and a list of payouts.
/// We do not need to specify the marketplace payout
/// in `payouts` even though it will be in
/// one of the outputs.
type Datum {
  /// Does not contain the marketplace payout.
  /// This is usually royalty and seller payouts.
  payouts: List<Payout>,
  /// Flexible to allow discounts
  /// The key that listed the NFT
  owner: VerificationKeyHash,
}

/// A user can either buy a token
/// or cancel/update the listing.
type Redeemer {
  /// `payout_outputs_offset` tells us where
  /// the outputs containing the payouts start.
  Buy { payout_outputs_offset: Int }
  /// Cancel or update a listing.
  WithdrawOrUpdate
}

validator {
  /// Validate that the signer is the owner or that payouts
  /// are present as outputs and that the tag is correct.
  fn spend(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } = ctx

    let Transaction { outputs, extra_signatories, .. } = transaction

    // Match on the action.
    when redeemer is {
      Buy { payout_outputs_offset } -> {
        expect Spend(out_ref) = purpose

        // for double satisfaction
        let datum_tag =
          out_ref
            |> serialise_data
            |> blake2b_256
            |> InlineDatum

        let Datum { payouts, .. } = datum

        // Find the `outputs` that correspond to `payouts`.
        let payout_outputs = find_payout_outputs(outputs, payout_outputs_offset)

        // We can ignore the fee check
        // if any of the authorizers have signed the tx.
        let can_have_discount =
          constants.authorizers()
            |> list.any(fn(authorizer) { list.has(extra_signatories, authorizer) })

        // If `can_have_discount` is `True` then we can
        // assume that jpg properly calculated the fee off chain.
        if can_have_discount {
          check_payouts(payout_outputs, payouts, datum_tag) > 0
        } else {
          // When there is a marketplace fee we can assume
          // it is the first of the `payout_outputs`.
          expect [marketplace_output, ..rest_outputs] = payout_outputs

          let payouts_sum = check_payouts(rest_outputs, payouts, NoDatum)

          // This approximates the marketplace fee given only the payouts to a very high degree.
          // For a payouts in excess of 100k ada the error is less than 40000 lovelace.
          let marketplace_fee = payouts_sum * 50 / 49 / 50

          // Make sure that the marketplace output
          // is correct.
          check_marketplace_payout(
            marketplace_output,
            marketplace_fee,
            datum_tag,
          )
        }
      }

      // There's not much to do here. An asset
      // owner can cancel or update their listing
      // at any time.
      WithdrawOrUpdate ->
        // is signed by owner
        list.has(extra_signatories, datum.owner)
    }
  }
}
