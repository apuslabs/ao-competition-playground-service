import { readFileSync } from 'fs';
import { join } from 'path';
import { connect, createDataItemSigner } from '@permaweb/aoconnect';
import { obj2tags } from './utils';
const ao = connect();

const devWallet = JSON.parse(readFileSync(join(__dirname, '../../wallets/devops.json')).toString());

export const devSigner = createDataItemSigner(devWallet);

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

export const msgResult = msgResultWrapper(devSigner);
export const msgResultDebug = msgResultWrapper(devSigner, true);

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

export const dryrun = dryrunWrapper(devSigner);
export const dryrunDebug = dryrunWrapper(devSigner, true);
