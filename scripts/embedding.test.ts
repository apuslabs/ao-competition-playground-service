import { EMBEDDING_PROCESS } from './ao/config';
import { msgResult } from './ao/wallet';
import crypto from 'crypto';

function executeWithRetryUntilSucceed(
  asyncFunc: () => Promise<void>,
  intervalMs: number
) {
  async function wrapper() {
    try {
      await asyncFunc();
    } catch (e) {
      setTimeout(wrapper, intervalMs);
    }
  }
  // Initial call to start the process
  setTimeout(wrapper, intervalMs);
}

function createDataset() {
  const testData = [
    { content: 'This contains variable declarations', meta: { title: 'one' } },
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

  const result = msgResult(
    EMBEDDING_PROCESS,
    {
      Action: 'Create-Dataset',
      PoolID: '1002',
    },
    {
      hash: hashOfData,
      list: testData,
      name: 'test',
    }
  );
  result
    .then((response) => {
      console.log('Dataset created successfully:', response);
    })
    .catch((error) => {
      console.error('Failed to create dataset:', error);
      throw new Error('Dataset creation failed');
    });
}

function searchPrompt() {
  const result = msgResult(
    EMBEDDING_PROCESS,
    {
      Action: 'Search-Prompt',
    },
    {
      dataset_hash: '673322f20121f3dc36538578295819386f1ef2b8',
      prompt: 'variable declarations',
    }
  );
}

async function createDatasetJoinPool() {
  const testData = [
    { content: 'This contains variable declarations', meta: { title: 'one' } },
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

  const result = await msgResult(
    EMBEDDING_PROCESS,
    {
      Action: 'Create-Dataset',
      PoolID: '1002',
    },
    {
      hash: hashOfData,
      list: testData,
      name: 'test',
    }
  );

  if (result.Error) {
    // error occured
    console.log(result.Error);
    return;
  } else {
    // console.log(result?.Messages?.[0].Tags);
    const statusCode = result?.Messages?.[0].Tags.find(
      (t: any) => t.name == 'Status'
    ).value;

    if (statusCode != '200' && statusCode != 200) {
      console.log(result?.Messages?.[0].Data);
      return;
    }
  }

  executeWithRetryUntilSucceed(async () => {
    const fetchCreationRes = await msgResult(
      EMBEDDING_PROCESS,
      {
        Action: 'Get-Creation-Status',
      },
      'hgTuOFm4YpILHI3XScCuRuaKGJCdeF5FuFyyigNt-Gk'
    );

    const res = fetchCreationRes.Messages?.[0]?.Data ?? {};

    console.log(res);
    if (res.status == 'WAIT_FOR_SYNC') {
      // WAIT_FOR_SYNC CANCELED JOIN_POOL_FAILED JOIN_SUCCEED
      throw new Error();
    }
  }, 100);
}

function main() {
  createDatasetJoinPool();
  // searchPrompt();
}

main();
