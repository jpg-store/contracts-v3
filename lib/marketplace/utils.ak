use aiken/list
use aiken/transaction.{NoDatum, Output, Transaction}
use aiken/transaction/credential.{VerificationKeyCredential, Address}
use aiken/transaction/value
use aiken/math

use marketplace/constants.{marketplace_pct, marketplace_vkh, min_payout}
use marketplace/types.{RoyaltyReceiver, VerificationKeyHash}

pub fn is_correct_split(
  amount_lovelace: Int,
  royalty_receivers: List<RoyaltyReceiver>,
  leftover_receiver: VerificationKeyHash,
  outputs: List<Output>,
  paid_acc: Int,
) {
  // Accumulator for the amount paid to the receivers
  when royalty_receivers is {
    [] -> {
      // Now we validate the leftover receiver
      let leftover =
        amount_lovelace - paid_acc

      let paid_to_leftover_receiver =
        list.reduce(
          outputs,
          fn(acc, output: Output) {
            when output.address.payment_credential is {
              VerificationKeyCredential(vkh) ->
                if vkh == leftover_receiver {
                  acc + value.lovelace_of(output.value)
                } else {
                  acc
                }
              _ ->
                acc
            }
          },
          0,
        )

      paid_to_leftover_receiver >= leftover
    }
    [head, ..tail] -> {
      // Separate outputs that go to the head receiver 
      // Note: If you duplicate the same receiver, it will fail after
      let (head_outputs, other_outputs) =
        list.partition(
          outputs,
          fn(output: Output) {
            when output.address.payment_credential is {
              VerificationKeyCredential(vkh) ->
                vkh == head.owner
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

      let due_fee = math.max(head.percentage_thousands * amount_lovelace / 1000, min_payout)

      if
      !(amount_paid_to_head == due_fee){
        // The head receiver has not been paid exactly the amount due 
        False
      } else {
        is_correct_split(
          amount_lovelace,
          tail,
          leftover_receiver,
          other_outputs,
          paid_acc + amount_paid_to_head,
        )
      }
    }
  }
}

pub fn must_be_signed_by(transaction: Transaction, vk: VerificationKeyHash) {
  list.has(transaction.extra_signatories, vk)
}

test is_correct_split_1() {
  let test_amount =
    100000000
  // 100 ADA
  let test_royalty_vkh =
    #"80f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"
  let test_seller_vkh =
    #"90f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"

  let test_royalty_receivers =
    [
      RoyaltyReceiver {
        owner: marketplace_vkh,
        percentage_thousands: marketplace_pct,
      },
      RoyaltyReceiver { owner: test_royalty_vkh, percentage_thousands: 50 },
    ]

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
      datum: NoDatum,
      reference_script: None,
    }

  let out_2 =
    Output {
      address: marketplace_addr,
      value: value.from_lovelace(2000000),
      datum: NoDatum,
      reference_script: None,
    }

  let out_3 =
    Output {
      address: seller_addr,
      value: value.from_lovelace(93000000),
      datum: NoDatum,
      reference_script: None,
    }


  let outputs =
    [out_1, out_2, out_3]

  is_correct_split(
    test_amount,
    test_royalty_receivers,
    test_seller_vkh,
    outputs,
    0,
  ) == True 
}

test is_correct_split_scaling() {
  let test_amount =
    100000000

  let test_royalty_vkh =
    #"80f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"
  let test_seller_vkh =
    #"90f60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"
  let test_random_vkh =
    #"fff60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a81"

  let test_royalty_receivers =
    [
      RoyaltyReceiver {
        owner: marketplace_vkh,
        percentage_thousands: marketplace_pct,
      },
      RoyaltyReceiver { owner: test_royalty_vkh, percentage_thousands: 50 },
    ]

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
      datum: NoDatum,
      reference_script: None,
    }

  let out_2 =
    Output {
      address: marketplace_addr,
      value: value.from_lovelace(2000000),
      datum: NoDatum,
      reference_script: None,
    }

  let out_3 =
    Output {
      address: seller_addr,
      value: value.from_lovelace(93000000), 
      datum: NoDatum,
      reference_script: None,
    }

  let out_random =
    Output {
      address: random_addr,
      value: value.from_lovelace(1000000),
      datum: NoDatum,
      reference_script: None,
    }

  
  let outputs =
    list.concat([out_1, out_2, out_3], list.repeat(out_random, 100))

  is_correct_split(
    test_amount,
    test_royalty_receivers,
    test_seller_vkh,
    outputs,
    0,
  ) == True 
}