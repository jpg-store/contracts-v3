import * as colors from "https://deno.land/std@0.184.0/fmt/colors.ts";
import {
  Assets,
  C,
  Constr,
  Credential,
  Data,
  Emulator,
  generatePrivateKey,
  getAddressDetails,
  Lucid,
  PROTOCOL_PARAMETERS_DEFAULT,
  TxSigned,
} from "https://deno.land/x/lucid@0.10.1/mod.ts";

import {
  printExecutionDetails,
  randomAssetId,
  readValidator,
} from "./utils.ts";

export type TestContext = {
  contractAddress: string;
  lucid: Lucid;
  emulator: Emulator;
  sellerPaymentCredential?: Credential;
  royaltyPaymentCredential?: Credential;
  sellerAddr: string;
  sellerPk: string;
  buyerAddr: string;
  buyerPk: string;
  royaltyAddr: string;
  royaltyPk: string;
  refAddr: string;
};

const marketplacePkh =
  "70e60f3b5ea7153e0acc7a803e4401d44b8ed1bae1c7baaad1a62a72";

const marketplaceStakePkh =
  "81728e7ed4cf324e1323135e7e6d931f01e30792d9cdf17129cb806d";

export const BULK_PURCHASE_SIZE = 54;

const validator = readValidator();

export const singleAsset = {
  ["627c22b8a13e0f7dad08ea3cc25ac6f254822acf9ded1b52b8578b413d0acfbf35c28c6346d8de3e27b7ebeab19022a24d9cedb87e08078b03a6dd13"]:
    1n,
};

export const bulkPurchaseAssets: Assets = new Array(BULK_PURCHASE_SIZE)
  .fill(0)
  .reduce((acc) => {
    acc[randomAssetId()] = 1n;
    return acc;
  }, {});

export const marketplaceAddr = C.BaseAddress.new(
  0,
  C.StakeCredential.from_keyhash(C.Ed25519KeyHash.from_hex(marketplacePkh)),
  C.StakeCredential.from_keyhash(
    C.Ed25519KeyHash.from_hex(marketplaceStakePkh),
  ),
).to_address().to_bech32("addr_test");

export async function test(
  name: string,
  fn: (ctx: TestContext) => Promise<TxSigned>,
) {
  const sellerPk = generatePrivateKey();
  const refPk = generatePrivateKey();
  const buyerPk = generatePrivateKey();
  const royaltyPk = generatePrivateKey();

  const l = await Lucid.new(undefined, "Preprod");

  const sellerAddr = await l
    .selectWalletFromPrivateKey(sellerPk)
    .wallet.address();

  const refAddr = await l
    .selectWalletFromPrivateKey(refPk)
    .wallet.address();

  const royaltyAddr = await l
    .selectWalletFromPrivateKey(royaltyPk)
    .wallet.address();

  const buyerAddr = await l
    .selectWalletFromPrivateKey(buyerPk)
    .wallet.address();

  const { paymentCredential: sellerPaymentCredential } = getAddressDetails(
    sellerAddr,
  );
  const { paymentCredential: royaltyPaymentCredential } = getAddressDetails(
    royaltyAddr,
  );

  const emulator = new Emulator(
    [
      {
        address: sellerAddr,
        assets: {
          lovelace: BigInt(1e14),
          ...singleAsset,
          ...bulkPurchaseAssets,
        },
      },
      {
        address: buyerAddr,
        assets: { lovelace: BigInt(1e14) },
      },
      {
        address: refAddr,
        assets: { lovelace: BigInt(1e14) },
      },
    ],
    {
      ...PROTOCOL_PARAMETERS_DEFAULT,
    },
  );

  const lucid = await Lucid.new(emulator);

  const contractAddress = lucid.utils.validatorToAddress(validator);

  lucid.selectWalletFromPrivateKey(sellerPk);

  const txRef = await lucid
    .newTx()
    .payToAddressWithData(refAddr, { scriptRef: validator }, {
      lovelace: 100000000n,
    })
    .complete();

  const signedRef = await txRef.sign().complete();

  await signedRef.submit();

  emulator.awaitBlock(16);

  const txSigned = await fn({
    contractAddress,
    lucid,
    emulator,
    sellerPaymentCredential,
    royaltyPaymentCredential,
    sellerAddr,
    sellerPk,
    buyerAddr,
    buyerPk,
    royaltyAddr,
    royaltyPk,
    refAddr,
  });

  printExecutionDetails(txSigned, name);
}

export async function testFail(
  name: string,
  fn: (ctx: TestContext) => Promise<TxSigned>,
) {
  try {
    await test(name, fn);

    const err = `
  ${colors.bold(colors.brightMagenta(name))} - ${colors.red("failed")}`;

    console.log(err);
  } catch (e) {
    const error = e.split("\n").map((l: string) => `\n    ${l}`).join("");

    const message = `
  ${colors.bold(colors.brightMagenta(name))} - ${
      colors.green("passed")
    }\n${error}`;

    console.log(message);
  }
}

export function makePayout(cred: string, amount: bigint) {
  const address = new Constr(0, [new Constr(0, [cred]), new Constr(1, [])]);

  return new Constr(0, [address, amount]);
}

export function buyRedeemer(payoutOutputsOffset: number): string {
  return Data.to(new Constr(0, [BigInt(payoutOutputsOffset)]));
}
