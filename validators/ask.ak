use aiken/builtin.{blake2b_256, serialise_data}
use aiken/transaction.{DatumHash, ScriptContext, Spend, Transaction}
use jpg/types.{Payout, VerificationKeyHash}
use jpg/utils.{find_leading_output, is_signed_by, reduce_over_tagged_outputs}

type Datum {
  private_buyer: Option<VerificationKeyHash>,
  payouts: List<Payout>,
  owner: VerificationKeyHash,
}

type Redeemer {
  Buy { leading_output_index: Int }
  CancelOrUpdate
}

validator {
  fn spend(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } =
      ctx

    let Transaction { outputs, extra_signatories, .. } =
      transaction

    when redeemer is {
      Buy { leading_output_index } -> {
        expect Spend(out_ref) =
          purpose

        let tag_datum =
          out_ref |> serialise_data |> blake2b_256 |> DatumHash

        let Datum { private_buyer, payouts, .. } =
          datum

        let is_correct_private_buyer =
          when private_buyer is {
            Some(private_buyer) ->
              is_signed_by(extra_signatories, private_buyer)
            None ->
              True
          }

        let leading_outputs =
          find_leading_output(leading_output_index, outputs)

        reduce_over_tagged_outputs(leading_outputs, payouts, tag_datum) && is_correct_private_buyer
      }

      CancelOrUpdate ->
        is_signed_by(extra_signatories, datum.owner)
    }
  }
}
