import { connect, createDataItemSigner } from '@permaweb/aoconnect';
import { msgResultWrapper } from './ao/wallet';
import Arweave from 'arweave';
import * as fs from 'fs';
import * as path from 'path';
import { EMBEDDING_PROCESS, POOL_PROCESS } from '../scripts/ao/config';
import { expect } from 'chai';
import crypto from 'crypto';

// 初始化 Arweave 实例
const arweave = Arweave.init({
  host: 'arweave.net', // Arweave 网关
  port: 443, // 默认端口
  protocol: 'https', // 使用 https
});

// 批量生成钱包并保存到文件
async function generateWallets(count: number, outputDir: string) {
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  for (let i = 0; i < count; i++) {
    const wallet = await arweave.wallets.generate(); // 生成钱包密钥对
    const walletAddress = await arweave.wallets.jwkToAddress(wallet); // 获取钱包地址

    // 将钱包密钥保存到文件
    const walletFileName = path.join(outputDir, `wallet_${i + 1}_${walletAddress}.json`);
    fs.writeFileSync(walletFileName, JSON.stringify(wallet, null, 2));
  }
}

(async function main() {
  // clean wallets
  const files = await fs.readdirSync('wallets');
  files
    .filter((f) => f.startsWith('wallet_'))
    .forEach((f) => {
      fs.rmSync(path.join('wallets', f));
    });

  generateWallets(10, './wallets');
})();
