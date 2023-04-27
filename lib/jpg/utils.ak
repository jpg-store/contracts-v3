use aiken/builtin
use aiken/bytearray
use aiken/list
use aiken/string
use aiken/transaction.{
  InlineDatum, NoDatum, Output, OutputReference, ScriptContext, Spend,
  Transaction, TransactionId,
}
use aiken/transaction/credential.{Address, VerificationKeyCredential}
use aiken/transaction/value
use jpg/constants.{marketplace_vkh}
use jpg/types.{Payout, TagDatum, VerificationKeyHash}

pub fn is_correct_split(
  payouts: List<Payout>,
  outputs: List<Output>,
  tag_datum: TagDatum,
) {
  when payouts is {
    // The presence of a payout to the owner is validated in `calculate_marketplace_payout` 
    [] ->
      True
    [head, ..tail] -> {
      // Note: Payouts to the same vkh are not allowed,
      // meaning that the same vkh cannot be present in the list twice.
      // Just merge the payouts in that case.
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

      if !(amount_paid_to_head >= head.amount_lovelace) {
        False
      } else {
        is_correct_split(tail, other_outputs, tag_datum)
      }
    }
  }
}

pub fn is_signed_by(transaction: Transaction, vkh: VerificationKeyHash) {
  list.has(transaction.extra_signatories, vkh)
}

pub fn get_own_out_ref(ctx: ScriptContext) -> OutputReference {
  expect Spend(out_ref) =
    ctx.purpose

  out_ref
}

pub fn is_tagged_output(output: Output, tag_datum: TagDatum) -> Bool {
  when output.datum is {
    InlineDatum(datum) ->
      builtin.serialise_data(tag_datum) == builtin.serialise_data(datum)
    _ ->
      False
  }
}

test is_tagged_output_1() {
  let tag_datum =
    TagDatum {
      output_reference: OutputReference {
        transaction_id: TransactionId { hash: #"00" },
        output_index: 0,
      },
    }

  let serialised_td: Data =
    tag_datum

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

test is_tagged_output_2() {
  let tag_datum =
    TagDatum {
      output_reference: OutputReference {
        transaction_id: TransactionId { hash: #"00" },
        output_index: 0,
      },
    }

  let output =
    Output {
      address: Address {
        payment_credential: VerificationKeyCredential(marketplace_vkh),
        stake_credential: None,
      },
      value: value.from_lovelace(100000000),
      datum: NoDatum,
      reference_script: None,
    }

  is_tagged_output(output, tag_datum) == False
}

test is_correct_split_1() {
  let test_royalty_vkh =
    #"80f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"
  let test_seller_vkh =
    #"90f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"

  let test_royalty_payouts =
    [
      Payout { vkh: test_royalty_vkh, amount_lovelace: 3000000 },
      Payout { vkh: test_seller_vkh, amount_lovelace: 95000000 },
      Payout { vkh: marketplace_vkh, amount_lovelace: 2000000 },
    ]

  let tag_datum =
    TagDatum {
      output_reference: OutputReference {
        transaction_id: TransactionId { hash: #"00" },
        output_index: 0,
      },
    }

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
      value: value.from_lovelace(3000000),
      datum: InlineDatum(tag_datum),
      reference_script: None,
    }

  let out_2 =
    Output {
      address: marketplace_addr,
      value: value.from_lovelace(2000000),
      datum: InlineDatum(tag_datum),
      reference_script: None,
    }

  let out_3 =
    Output {
      address: seller_addr,
      value: value.from_lovelace(95000000),
      datum: InlineDatum(tag_datum),
      reference_script: None,
    }

  let outputs =
    [out_1, out_2, out_3]

  is_correct_split(test_royalty_payouts, outputs, tag_datum) == // calculate_marketplace_payout(test_royalty_payouts),
  // False,
  True
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
      Payout { vkh: test_seller_vkh, amount_lovelace: 93000000 },
    ]

  let marketplace_payout =
    Payout { vkh: marketplace_vkh, amount_lovelace: 2000000 }

  let tag_datum =
    TagDatum {
      output_reference: OutputReference {
        transaction_id: TransactionId { hash: #"00" },
        output_index: 0,
      },
    }

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
      datum: InlineDatum(tag_datum),
      reference_script: None,
    }

  let out_2 =
    Output {
      address: marketplace_addr,
      value: value.from_lovelace(2000000),
      datum: InlineDatum(tag_datum),
      reference_script: None,
    }

  let out_3 =
    Output {
      address: seller_addr,
      value: value.from_lovelace(93000000),
      datum: InlineDatum(tag_datum),
      reference_script: None,
    }

  let out_random =
    Output {
      address: random_addr,
      value: value.from_lovelace(1000000),
      datum: InlineDatum(tag_datum),
      reference_script: None,
    }

  let outputs =
    list.concat([out_1, out_2, out_3], list.repeat(out_random, 100))

  let all_payouts =
    list.push(payouts, marketplace_payout)

  is_correct_split(all_payouts, outputs, tag_datum) == True
}

// Debugging utilities

/// Encode a ByteArray as a hex String
pub fn hex_encode(bytes: ByteArray) -> String {
  bytearray.reduce(
    bytes,
    fn(acc, byte) {
      string.join(
        [acc, byte_hex_encode(byte / 16), byte_hex_encode(byte % 16)],
        @"",
      )
    },
    @"",
  )
}

fn byte_hex_encode(int: Int) -> String {
  if int < 10 {
    string.from_int(int)
  } else {
    when int is {
      10 ->
        @"a"
      11 ->
        @"b"
      12 ->
        @"c"
      13 ->
        @"d"
      14 ->
        @"e"
      15 ->
        @"f"
    }
  }
}

test hex_encode_1() {
  hex_encode("Hello world!") == @"48656c6c6f20776f726c6421"
}

pub fn bool_to_string(bool: Bool) -> String {
  when bool is {
    True ->
      @"True"
    False ->
      @"False"
  }
}
