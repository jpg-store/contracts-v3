use aiken/builtin.{blake2b_256, serialise_data}
use aiken/list
use aiken/transaction.{InlineDatum, NoDatum, ScriptContext, Spend, Transaction}
use jpg/types.{Payout, VerificationKeyHash}
use jpg/utils.{check_marketplace_payout, check_payouts, find_payout_outputs}

/// A listing requires a datum that has
/// the owner's payment key and a list of payouts.
/// The optional `reserver_for` allows for peer to peer
/// trading where the buyer must match the
/// private buyer payment key. Since the datum expects
/// a marketplace fee, we do not need to specify the
/// marketplace payout in `payouts` even though it will
/// be in one of the outputs.
type Datum {
  /// If set then only this key can buy the listing
  reserved_for: Option<VerificationKeyHash>,
  /// Does not contain the marketplace payout.
  /// This is usually royalty and seller payouts.
  payouts: List<Payout>,
  /// Flexible to allow discounts
  marketplace_fee: Int,
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
        let Datum { reserved_for, payouts, marketplace_fee, .. } = datum
        // Find the `outputs` that correspond to `payouts`.
        let payout_outputs = find_payout_outputs(outputs, payout_outputs_offset)
        let has_correct_payouts =
          // If `marketplace_fee` is `0` then we can
          // assume there is no output for it.
          if marketplace_fee == 0 {
            check_payouts(payout_outputs, payouts, datum_tag)
          } else {
            // When there is a marketplace fee we can assume
            // it is the first of the `payout_outputs`.
            expect [marketplace_output, ..rest_outputs] = payout_outputs
            // Make sure that the marketplace output
            // is correct.
            let has_correct_marketplace_payout =
              check_marketplace_payout(
                marketplace_output,
                marketplace_fee,
                datum_tag,
              )
            has_correct_marketplace_payout && check_payouts(
              rest_outputs,
              payouts,
              NoDatum,
            )
          }
        when reserved_for is {
          Some(buyer) ->
            // In addition to payouts, we need to check that
            // the current buyer matches the buyer that this listing
            // was reserved for.
            has_correct_payouts && list.has(extra_signatories, buyer)
          None -> has_correct_payouts
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
