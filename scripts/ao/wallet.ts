import { readFileSync } from 'fs';
import { join } from 'path';
import { connect, createDataItemSigner } from '@permaweb/aoconnect';
import { obj2tags } from './utils';
const ao = connect();

const wallet = JSON.parse(
  readFileSync(join(__dirname, '../../wallets/lpJ5Edz_8DbNnVDL0XdbsY9vCOs45NACzfI4jvo4Ba8.json')).toString()
);
const moneyWallet = JSON.parse(
  readFileSync(join(__dirname, '../../wallets/s5M1xwcHIP9weXuL2HuWHHy4FrgPkJU4_4geptCo0os.json')).toString()
);

// const moneyWalletJason = JSON.parse(
//   readFileSync(join(__dirname, "../../wallets/3D0cVMRP69ExR9x03i-kv8eL2MJeQEY547c025UwIUM.json")).toString(),
// );

export const originSigner = createDataItemSigner(wallet);
export const moneySigner = createDataItemSigner(moneyWallet);

export const jasonSigner = createDataItemSigner(wallet);

export const msgResultWrapper =
  (signer: any, debug?: boolean) =>
  async (process: string, tags: Record<string, string>, data?: string | Record<string, any> | number) => {
    const action = tags.Action ?? 'Msg';
    debug && console.group(`${action} ${process}`);
    const msgId = await ao.message({
      process,
      tags: obj2tags(tags),
      data: typeof data === 'string' ? data : typeof data === 'number' ? data.toString() : JSON.stringify(data),
      signer: signer,
    });
    debug && console.log('Msg ID:', msgId);
    const result = await ao.result({
      process: process,
      message: msgId,
    });
    debug && console.log(result);
    debug && console.groupEnd();
    return result;
  };

export const msgResult = msgResultWrapper(originSigner);
export const msgResultDebug = msgResultWrapper(originSigner, true);

export const dryrunWrapper =
  (signer: any, debug?: boolean) =>
  async (process: string, tags: Record<string, string>, data?: string | Record<string, any> | number) => {
    const action = tags.Action ?? 'Dryrun';
    debug && console.group(`${action} ${process}`);
    const result = await ao.dryrun({
      process,
      tags: obj2tags(tags),
      data: typeof data === 'string' ? data : typeof data === 'number' ? data.toString() : JSON.stringify(data),
      signer: signer,
    });
    debug && console.log(result);
    debug && console.groupEnd();
    return result;
  };

export const dryrun = dryrunWrapper(originSigner);
export const dryrunDebug = dryrunWrapper(originSigner, true);
