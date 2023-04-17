use aiken/builtin
use aiken/list
use aiken/math
use aiken/transaction.{
  InlineDatum, Input, Output, OutputReference, ScriptContext, Spend,
  Transaction, TransactionId,
}
use aiken/transaction/credential.{Address, VerificationKeyCredential}
use aiken/transaction/value
use marketplace/constants.{marketplace_pct, marketplace_vkh, min_payout}
use marketplace/types.{Payout, TagDatum, VerificationKeyHash}

pub fn is_correct_split(
  payouts: List<Payout>,
  outputs: List<Output>,
  tag_datum: TagDatum,
  paid_acc: Int,
) {
  when payouts is {
    [] -> {
      True
    }
    [head, ..tail] -> {
      // Separate outputs that go to the head payout 
      // Note: If you duplicate the same payout, it will fail after
      let (head_outputs, other_outputs) =
        list.partition(
          outputs,
          fn(output: Output) {
            when output.address.payment_credential is {
              VerificationKeyCredential(vkh) ->
                vkh == head.vkh
              _ ->
                False
            }
          },
        )

      let amount_paid_to_head =
        list.reduce(
          head_outputs,
          fn(acc: Int, output: Output) { acc + value.lovelace_of(output.value) },
          0,
        )

      // TODO: Should we be exact here? This allows to pay more royalties than expected
      if !(amount_paid_to_head >= head.amount_lovelace) {
        False
      } else {
        is_correct_split(
          tail,
          other_outputs,
          tag_datum,
          paid_acc + amount_paid_to_head,
        )
      }
    }
  }
}

pub fn calculate_marketplace_payout(payouts: List<Payout>, owner: VerificationKeyHash) -> Int {
  let seller_payout = list.find(
    payouts,
    fn(payout: Payout) {
      payout.vkh == owner
    },
  ) 

  expect Some(payout) = seller_payout

  let price = payout.amount_lovelace

  math.max(price * marketplace_pct / 1000, min_payout)
}

pub fn is_signed_by(transaction: Transaction, vk: VerificationKeyHash) {
  list.has(transaction.extra_signatories, vk)
}

pub fn get_own_input(ctx: ScriptContext) -> Input {
  expect Spend(output_reference) =
    ctx.purpose
  expect Some(input) =
    list.find(
      ctx.transaction.inputs,
      fn(input) { input.output_reference == output_reference },
    )
  input
}

fn is_tagged_output(output: Output, tag_datum: TagDatum) -> Bool {
  when output.datum is {
    InlineDatum(datum) -> {
      builtin.serialise_data(tag_datum) == builtin.serialise_data(datum)
    }
    _ ->
      False
  }
}

test calculate_marketplace_payout_1(){
  let test_royalty_vkh =
    #"80f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"
  let test_seller_vkh =
    #"90f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"

  let test_payouts =
    [
      Payout {
        vkh: test_royalty_vkh,
        amount_lovelace: 2000000,
      },
      Payout { vkh: test_seller_vkh, amount_lovelace: 100000000 },
    ]

  let marketplace_payout = calculate_marketplace_payout(test_payouts, test_seller_vkh)

  marketplace_payout == 2000000

}

test is_tagged_output_1() {
  let tag_datum =
    TagDatum {
      output_reference: OutputReference {
        transaction_id: TransactionId { hash: #"00" },
        output_index: 0,
      },
    }

  let serialised_td: Data = tag_datum

  let output =
    Output {
      address: Address {
        payment_credential: VerificationKeyCredential(marketplace_vkh),
        stake_credential: None,
      },
      value: value.from_lovelace(100000000),
      datum: InlineDatum(serialised_td),
      reference_script: None,
    }

  is_tagged_output(output, tag_datum) == True
}

test is_correct_split_1() {
  let test_royalty_vkh =
    #"80f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"
  let test_seller_vkh =
    #"90f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"

  let test_royalty_payouts =
    [
      Payout {
        vkh: marketplace_vkh,
        amount_lovelace: 2000000,
      },
      Payout { vkh: test_royalty_vkh, amount_lovelace: 5000000 },
    ]

  let tag_datum =
    TagDatum {
      output_reference: OutputReference {
        transaction_id: TransactionId { hash: #"00" },
        output_index: 0,
      },
    }
  let serialised_td =
    builtin.serialise_data(tag_datum)

  // 5% royalties 
  let marketplace_addr =
    Address {
      payment_credential: VerificationKeyCredential(marketplace_vkh),
      stake_credential: None,
    }

  let royalty_addr =
    Address {
      payment_credential: VerificationKeyCredential(test_royalty_vkh),
      stake_credential: None,
    }

  let seller_addr =
    Address {
      payment_credential: VerificationKeyCredential(test_seller_vkh),
      stake_credential: None,
    }

  let out_1 =
    Output {
      address: royalty_addr,
      value: value.from_lovelace(5000000),
      datum: InlineDatum(serialised_td),
      reference_script: None,
    }

  let out_2 =
    Output {
      address: marketplace_addr,
      value: value.from_lovelace(2000000),
      datum: InlineDatum(serialised_td),
      reference_script: None,
    }

  let out_3 =
    Output {
      address: seller_addr,
      value: value.from_lovelace(93000000),
      datum: InlineDatum(serialised_td),
      reference_script: None,
    }

  let outputs =
    [out_1, out_2, out_3]

  is_correct_split(
    test_royalty_payouts,
    outputs,
    tag_datum,
    0,
  ) == True
}

test is_correct_split_scaling() {
  let test_royalty_vkh =
    #"80f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"
  let test_seller_vkh =
    #"90f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"
  let test_random_vkh =
    #"fff60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"

  let payouts =
    [
      Payout { vkh: test_royalty_vkh, amount_lovelace: 5000000 },
      Payout { vkh: test_seller_vkh, amount_lovelace: 93000000},
    ]

  let marketplace_payout = Payout {
        vkh: marketplace_vkh,
        amount_lovelace: calculate_marketplace_payout(payouts, test_seller_vkh),
      }

  let tag_datum =
    TagDatum {
      output_reference: OutputReference {
        transaction_id: TransactionId { hash: #"00" },
        output_index: 0,
      },
    }
  let serialised_td: Data = tag_datum

  // 5% royalties 
  let marketplace_addr =
    Address {
      payment_credential: VerificationKeyCredential(marketplace_vkh),
      stake_credential: None,
    }

  let royalty_addr =
    Address {
      payment_credential: VerificationKeyCredential(test_royalty_vkh),
      stake_credential: None,
    }

  let seller_addr =
    Address {
      payment_credential: VerificationKeyCredential(test_seller_vkh),
      stake_credential: None,
    }

  let random_addr =
    Address {
      payment_credential: VerificationKeyCredential(test_random_vkh),
      stake_credential: None,
    }

  let out_1 =
    Output {
      address: royalty_addr,
      value: value.from_lovelace(5000000),
      datum: InlineDatum(serialised_td),
      reference_script: None,
    }

  let out_2 =
    Output {
      address: marketplace_addr,
      value: value.from_lovelace(2000000),
      datum: InlineDatum(serialised_td),
      reference_script: None,
    }

  let out_3 =
    Output {
      address: seller_addr,
      value: value.from_lovelace(93000000),
      datum: InlineDatum(serialised_td),
      reference_script: None,
    }

  let out_random =
    Output {
      address: random_addr,
      value: value.from_lovelace(1000000),
      datum: InlineDatum(serialised_td),
      reference_script: None,
    }

  let outputs =
    list.concat([out_1, out_2, out_3], list.repeat(out_random, 100))

  is_correct_split(
    list.push(payouts, marketplace_payout),
    outputs,
    tag_datum,
    0,
  ) == True
}
