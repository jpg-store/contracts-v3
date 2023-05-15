use aiken/builtin.{blake2b_256, serialise_data}
use aiken/list
use aiken/transaction.{DatumHash, ScriptContext, Spend, Transaction}
use jpg/types.{Payout, VerificationKeyHash}
use jpg/utils.{check_payouts, find_payout_outputs}

/// A listing requires a datum that has
/// the owner's payment key and a list of payouts.
/// The optional `reserver_for` allows for peer to peer
/// trading where the buyer must match the
/// private buyer payment key.
type Datum {
  reserved_for: Option<VerificationKeyHash>,
  payouts: List<Payout>,
  owner: VerificationKeyHash,
}

/// A user can either buy a token
/// or cancel/update the listing.
type Redeemer {
  // `payout_outputs_offset` tells us where
  // the outputs containing the payouts start.
  Buy { payout_outputs_offset: Int }
  // Cancel or update a listing.
  CancelOrUpdate
}

validator {
  /// Validate that the signer is the owner or that payouts
  /// are present as outputs and that the tag is correct.
  fn spend(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } =
      ctx

    let Transaction { outputs, extra_signatories, .. } =
      transaction

    // Match on the action
    when redeemer is {
      Buy { payout_outputs_offset } -> {
        expect Spend(out_ref) =
          purpose

        // 
        let datum_tag =
          out_ref
            |> serialise_data
            |> blake2b_256
            |> DatumHash

        let Datum { reserved_for, payouts, .. } =
          datum

        let has_correct_payouts =
          outputs
            |> find_payout_outputs(payout_outputs_offset)
            |> check_payouts(payouts, datum_tag)

        when reserved_for is {
          Some(buyer) ->
            // In addition to payouts, we need to check that
            // the current buyer matches the buyer that this listing
            // was reserved for.
            has_correct_payouts && list.has(extra_signatories, buyer)

          None ->
            has_correct_payouts
        }
      }

      CancelOrUpdate ->
        // is signed by owner
        list.has(extra_signatories, datum.owner)
    }
  }
}
