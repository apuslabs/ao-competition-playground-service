import { connect, createDataItemSigner } from '@permaweb/aoconnect';
import Arweave from 'arweave';
import * as fs from 'fs';
import * as path from 'path';
import { EMBEDDING_PROCESS, POOL_PROCESS } from '../scripts/ao/config';
import { expect } from 'chai';
import crypto from 'crypto';

const POOL_ID = 1003;

const ao = connect();

function tostring(value: any) {
  if (typeof value === 'object') {
    return JSON.stringify(value);
  }
  return String(value);
}

function obj2tags(obj: Record<string, any>) {
  return Object.entries(obj).map(([key, value]) => ({
    name: key,
    value: tostring(value),
  }));
}

function generateUniqueRandomString(length: number): string {
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';

  // 加入时间戳，确保唯一性
  const timestamp = Date.now().toString(36); // 转换为36进制，缩短长度
  result += timestamp;

  // 生成剩余的随机字符串
  for (let i = 0; i < length - timestamp.length; i++) {
    const randomIndex = Math.floor(Math.random() * characters.length);
    result += characters[randomIndex];
  }

  return result;
}
const msgResultWrapper =
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

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function registerSigners(): Promise<{ signers: any; wallets: string }[]> {
  const res: any[] = [];
  const directory = 'wallets/';
  const files = fs.readdirSync(directory);
  // 遍历每个文件或文件夹
  files
    .filter((f) => f.startsWith('wallet_') && f.endsWith('.json'))
    .forEach((file) => {
      const fullPath = path.join(directory, file);
      const stat = fs.statSync(fullPath);

      if (stat.isDirectory()) {
        return true;
      } else {
        const walletJson = JSON.parse(fs.readFileSync(fullPath).toString());
        const signer = createDataItemSigner(walletJson);
        const cleanedFileName = file.replace(/^wallet_\d+_/, '').replace(/\.json$/, '');

        res.push({
          wallet: cleanedFileName,
          signer,
        });
      }
    });
  return res;
}

function msgResultWithTargetSignerWrapper(signer: any) {
  return msgResultWrapper(signer);
}

describe('Preparations', () => {
  let signers: any[];
  before(async function () {
    signers = await registerSigners();
  });
  it('Signer 1-9 should be in whitelist', async () => {
    // any one can check whitelist
    const msgResult = msgResultWithTargetSignerWrapper(signers[0].signer);

    const whitelistRes: boolean[] = [];
    for (const s of signers.slice(0, 9)) {
      const checkPermissionRes = await msgResult(EMBEDDING_PROCESS, {
        Action: 'Check-Permission',
        FromAddress: s.wallet,
      });
      const res = checkPermissionRes?.Messages?.[0] ?? {};
      whitelistRes.push(res.Data);
    }

    const errorMessage = `Run \n\n\`BatchAddWhiteList({${signers
      .filter((item, i) => whitelistRes[i] == false)
      .map((s) => `"${s.wallet}"`)
      .join(',')}})\`\n\n in aos console to resolve the problem`;

    expect(whitelistRes).to.deep.equal(Array(9).fill(true), errorMessage); // 串行等待每个结果
  });

  it('Signer 10 should not be in whitelist', async () => {
    const msgResult = msgResultWithTargetSignerWrapper(signers[0].signer);

    const checkPermissionRes = await msgResult(EMBEDDING_PROCESS, {
      Action: 'Check-Permission',
      FromAddress: signers[9].wallet,
    });
    const res = checkPermissionRes?.Messages?.[0] ?? {};

    const suggestion = `Run \n\n\`BatchRemoveWhiteList({"${signers[9].wallet}"})\`\n\n in aos console to resolve the problem`;
    expect(res.Data).to.deep.equal(false, suggestion);
  });
});

describe('Basic', () => {
  let signers: any[];
  const testData = [
    {
      content: 'This contains variable declarations',
      meta: { title: 'one' },
    },
    {
      content: 'This contains another sort of variable declarations',
      meta: { title: 'two' },
    },
    {
      content: 'This has nothing to do with variable declarations',
      meta: { title: 'three' },
    },
    { content: 'A random doc', meta: { title: 'four' } },
  ];

  before(async function () {
    signers = await registerSigners();
  });
  it('Signer 1 (in whitelist) can create dataset', async () => {
    const msgResult = msgResultWithTargetSignerWrapper(signers[0].signer);

    const createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: generateUniqueRandomString(32),
        list: testData,
        name: 'test',
      }
    );

    const res = createDatasetResponse?.Messages?.[0];
    const status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    const message = res.Data ?? '';
    expect(status).to.equal('200');
  });
  it('Signer 2 (in whitelist) create then signer 3 (in whitelist) meet throttle check', async () => {
    let msgResult = msgResultWithTargetSignerWrapper(signers[1].signer);

    await delay(2500); // 等待 2 秒
    let createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: generateUniqueRandomString(32),
        list: testData,
        name: 'test',
      }
    );

    let res = createDatasetResponse?.Messages?.[0];
    let status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    let message = res.Data ?? '';
    expect(status).to.equal('200');

    msgResult = msgResultWithTargetSignerWrapper(signers[2].signer);

    createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: generateUniqueRandomString(32),
        list: testData,
        name: 'test',
      }
    );

    res = createDatasetResponse?.Messages?.[0];

    status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    message = res.Data ?? '';
    expect(status).to.equal(429);
    expect(message).to.equal('The system is experiencing high traffic. Try again in five minutes.');
  });

  it('Signer 3 (in whitelist) create dataset with wrong format', async () => {
    let msgResult = msgResultWithTargetSignerWrapper(signers[2].signer);
    await delay(2500);

    let createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: generateUniqueRandomString(32),
        list: [{ a: 'bbb', c: 111, d: 223 }],
        name: 'test',
      }
    );

    expect(createDatasetResponse.Error).to.exist;
  });

  it('Signer 4 (in whitelist) upload twice will fail', async () => {
    let msgResult = msgResultWithTargetSignerWrapper(signers[3].signer);

    await delay(2500); // 等待 2 秒
    let createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: generateUniqueRandomString(32),
        list: testData,
        name: 'test',
      }
    );

    let res = createDatasetResponse?.Messages?.[0];
    let status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    let message = res.Data ?? '';
    expect(status).to.equal('200');

    await delay(2500); // 等待 2 秒
    createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: generateUniqueRandomString(32),
        list: testData,
        name: 'test',
      }
    );
    res = createDatasetResponse?.Messages?.[0];
    status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    message = res.Data ?? '';
    expect(status).to.equal('403');

    // May be  `You have pending creation, please wait for it`
    // expect(message).to.equal('You have uploaded dataset before.');
  });

  it('Signer 5 (in whitelist) upload large dataset 4000 records', async () => {
    const repeatedTestData = Array.from({ length: 1000 }, () => testData).flat();

    let msgResult = msgResultWithTargetSignerWrapper(signers[4].signer);

    await delay(2500); // 等待 2 秒
    let createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: generateUniqueRandomString(32),
        list: repeatedTestData,
        name: 'test',
      }
    );

    let res = createDatasetResponse?.Messages?.[0];
    let status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    let message = res.Data ?? '';
    expect(status).to.equal('200');
  });

  it('Signer 6 (in whitelist) upload large dataset 8000 records', async () => {
    await delay(2500); // 等待 2 秒
    const repeatedTestData = Array.from({ length: 2000 }, () => testData).flat();

    let msgResult = msgResultWithTargetSignerWrapper(signers[5].signer);

    await delay(2500); // 等待 2 秒
    let createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: generateUniqueRandomString(32),
        list: repeatedTestData,
        name: 'test',
      }
    );

    let res = createDatasetResponse?.Messages?.[0];
    let status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    let message = res.Data ?? '';
    expect(status).to.equal('200');
  });

  it('Signer 7 (in whitelist) upload large dataset 12000 records', async () => {
    await delay(2500); // 等待 2 秒
    const repeatedTestData = Array.from({ length: 3000 }, () => testData).flat();

    let msgResult = msgResultWithTargetSignerWrapper(signers[6].signer);

    await delay(2500); // 等待 2 秒
    let createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: generateUniqueRandomString(32),
        list: repeatedTestData,
        name: 'test',
      }
    );

    let res = createDatasetResponse?.Messages?.[0];
    let status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    let message = res.Data ?? '';
    expect(status).to.equal('200');
  });

  it('Signer 8 (in whitelist) upload and then signer 9 use same dataset-hash will fail', async () => {
    await delay(2500); // 等待 2 秒

    let msgResult = msgResultWithTargetSignerWrapper(signers[7].signer);

    const dataset_hash = generateUniqueRandomString(32);
    let createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: dataset_hash,
        list: testData,
        name: 'test',
      }
    );

    let res = createDatasetResponse?.Messages?.[0];
    let status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    let message = res.Data ?? '';
    expect(status).to.equal('200');
    await delay(15000); // 等待 5 秒

    msgResult = msgResultWithTargetSignerWrapper(signers[8].signer);

    createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: dataset_hash,
        list: testData,
        name: 'test',
      }
    );

    res = createDatasetResponse?.Messages?.[0];
    status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    message = res.Data ?? '';
    expect(status).to.equal('403');
    expect(message).to.equal('Your dataset hash has been taken.');
  });

  it('Signer 10 (not in whitelist) cannot create dataset', async () => {
    const msgResult = msgResultWithTargetSignerWrapper(signers[9].signer);

    const createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: generateUniqueRandomString(32),
        list: testData,
        name: 'test',
      }
    );

    const res = createDatasetResponse?.Messages?.[0];
    const status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    const message = res.Data ?? '';
    expect(status).to.equal('403');
    expect(message).to.equal('You are not allowed to join this event.');
  });
});
