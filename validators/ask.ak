use aiken/list
use aiken/transaction.{ScriptContext}
use marketplace/types.{Payout, TagDatum, VerificationKeyHash}
use marketplace/utils.{
  get_own_out_ref, is_correct_split, is_signed_by, is_tagged_output,
}

type Datum {
  private_buyer: Option<VerificationKeyHash>,
  payouts: List<Payout>,
  owner: VerificationKeyHash,
}

type Redeemer {
  Buy
  CancelOrUpdate
}

validator {
  fn spend(datum: Datum, redeemer: Redeemer, ctx: ScriptContext) -> Bool {
    let tx =
      ctx.transaction
    let out_ref =
      get_own_out_ref(ctx)
    let tag_datum =
      TagDatum { output_reference: out_ref }

    when redeemer is {
      Buy -> {
        let is_correct_private_buyer =
          when datum.private_buyer is {
            Some(private_buyer) ->
              is_signed_by(tx, private_buyer)
            None ->
              True
          }

        let my_outputs =
          list.filter(
            tx.outputs,
            fn(output) { is_tagged_output(output, tag_datum) },
          )

        is_correct_split(datum.payouts, my_outputs, tag_datum) && is_correct_private_buyer
      }

      CancelOrUpdate ->
        is_signed_by(tx, datum.owner)
    }
  }
}
