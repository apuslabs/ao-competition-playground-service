import { connect, createDataItemSigner } from '@permaweb/aoconnect';
import { msgResultWrapper } from './ao/wallet';
import Arweave from 'arweave';
import * as fs from 'fs';
import * as path from 'path';
import { EMBEDDING_PROCESS, POOL_PROCESS } from '../scripts/ao/config';
import { expect } from 'chai';
import crypto from 'crypto';

const POOL_ID = 1002;

// 初始化 Arweave 实例
const arweave = Arweave.init({
  host: 'arweave.net', // Arweave 网关
  port: 443, // 默认端口
  protocol: 'https', // 使用 https
});

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// 批量生成钱包并保存到文件
async function generateWallets(count: number, outputDir: string) {
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  for (let i = 0; i < count; i++) {
    const wallet = await arweave.wallets.generate(); // 生成钱包密钥对
    const walletAddress = await arweave.wallets.jwkToAddress(wallet); // 获取钱包地址

    // 将钱包密钥保存到文件
    const walletFileName = path.join(
      outputDir,
      `wallet_${i + 1}_${walletAddress}.json`
    );
    fs.writeFileSync(walletFileName, JSON.stringify(wallet, null, 2));
  }
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
        const cleanedFileName = file
          .replace(/^wallet_\d+_/, '')
          .replace(/\.json$/, '');

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

  const hashOfData = crypto.hash(
    'sha1',
    testData.map((item) => item.content).join('')
  );

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
        hash: hashOfData,
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

    await delay(2000); // 等待 2 秒
    let createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: hashOfData,
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
        hash: hashOfData,
        list: testData,
        name: 'test',
      }
    );

    res = createDatasetResponse?.Messages?.[0];

    status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    message = res.Data ?? '';
    expect(status).to.equal(429);
    expect(message).to.equal(
      'The system is experiencing high traffic. Try again in five minutes.'
    );
  });

  it('Signer 4(in whitelist) upload twice will fail', async () => {
    let msgResult = msgResultWithTargetSignerWrapper(signers[3].signer);

    await delay(2000); // 等待 2 秒
    let createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: hashOfData,
        list: testData,
        name: 'test',
      }
    );

    let res = createDatasetResponse?.Messages?.[0];
    let status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    let message = res.Data ?? '';
    expect(status).to.equal('200');

    await delay(2000); // 等待 2 秒
    createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: hashOfData,
        list: testData,
        name: 'test',
      }
    );
    res = createDatasetResponse?.Messages?.[0];
    status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    message = res.Data ?? '';
    expect(status).to.equal('403');
    expect(message).to.equal('You have uploaded dataset before.');
  });

  it('Signer 5(in whitelist) upload large dataset 4000 records', async () => {
    const repeatedTestData = Array.from(
      { length: 1000 },
      () => testData
    ).flat();

    let msgResult = msgResultWithTargetSignerWrapper(signers[4].signer);

    await delay(2000); // 等待 2 秒
    let createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: hashOfData,
        list: repeatedTestData,
        name: 'test',
      }
    );

    let res = createDatasetResponse?.Messages?.[0];
    let status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    let message = res.Data ?? '';
    expect(status).to.equal('200');
  });

  it('Signer 6(in whitelist) upload large dataset 8000 records', async () => {
    await delay(2000); // 等待 2 秒
    const repeatedTestData = Array.from(
      { length: 2000 },
      () => testData
    ).flat();

    let msgResult = msgResultWithTargetSignerWrapper(signers[5].signer);

    await delay(2000); // 等待 2 秒
    let createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: hashOfData,
        list: repeatedTestData,
        name: 'test',
      }
    );

    let res = createDatasetResponse?.Messages?.[0];
    let status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    let message = res.Data ?? '';
    expect(status).to.equal('200');
  });

  it('Signer 7(in whitelist) upload large dataset 12000 records', async () => {
    await delay(2000); // 等待 2 秒
    const repeatedTestData = Array.from(
      { length: 3000 },
      () => testData
    ).flat();

    let msgResult = msgResultWithTargetSignerWrapper(signers[6].signer);

    await delay(2000); // 等待 2 秒
    let createDatasetResponse = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Create-Dataset',
        PoolID: POOL_ID.toString(),
      },
      {
        hash: hashOfData,
        list: repeatedTestData,
        name: 'test',
      }
    );

    let res = createDatasetResponse?.Messages?.[0];
    let status = (res.Tags ?? []).find((t: any) => t.name == 'Status').value;
    let message = res.Data ?? '';
    expect(status).to.equal('200');
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
        hash: hashOfData,
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
