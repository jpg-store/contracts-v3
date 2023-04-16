use aiken/list
use aiken/transaction.{Transaction, ScriptContext, Output}
use aiken/transaction/credential.{VerificationKeyCredential}
use aiken/transaction/value.{lovelace_of}

use marketplace/types.{RoyaltyReceiver, VerificationKeyHash}

pub fn is_correct_split(
    amount_lovelace: Int,
    royalty_receivers: List<RoyaltyReceiver>,
    leftover_receiver: VerificationKeyHash,
    outputs: List<Output>,
    paid_acc: Int // Accumulator for the amount paid to the receivers
) {
    when royalty_receivers is {
        [] -> {
            // Now we validate the leftover receiver
            let leftover = amount_lovelace - paid_acc
            let paid_to_leftover_receiver = list.reduce(outputs, fn(acc: Int, output: Output) {
                when output.address.payment_credential is {
                    VerificationKeyCredential(vkh) -> {
                        if vkh == leftover_receiver {
                            acc + lovelace_of(output.value)
                        } else {
                            acc
                        }
                    }
                    _ -> acc
                }
            }, 0)

            paid_to_leftover_receiver >= leftover
        }
        [head, ..tail] -> {
            // Separate outputs that go to the head receiver 
            // Note: If you duplicate the same receiver, it will fail after
            let (head_outputs, other_outputs) = list.partition(
                outputs,
                fn (output: Output) {
                    when output.address.payment_credential is {
                        VerificationKeyCredential(vkh) -> vkh == head.owner
                        _ -> False
                    } 
                }
            )

            let amount_paid_to_head = list.reduce(head_outputs, fn (acc: Int, output: Output)  { acc + lovelace_of(output.value) }, 0)


            if !(amount_paid_to_head >= head.percentage_thousands * amount_lovelace / 1000) {
                // The head receiver has not been paid enough 
                False
            } else {
                is_correct_split(
                    amount_lovelace,
                    tail,
                    leftover_receiver,
                    other_outputs,
                    acc + amount_paid_to_head
                )
            }
        }
    }
}

pub fn must_be_signed_by(transaction: Transaction, vk: VerificationKeyHash) {
  list.has(transaction.extra_signatories, vk)
}