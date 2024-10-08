import axios from 'axios';
import { HERDER_PROCESS, POOL_PROCESS } from './ao/config';
import { dryrun } from './ao/wallet';

const webhookUrl =
  'https://chat.googleapis.com/v1/spaces/AAAA-SmkxXU/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=l8qoqE2RZAfnzLObqr71cBUu0AnIC_TkBMRsMviC3H8';

async function getHerderStatistic() {
  const result = await dryrun(HERDER_PROCESS, { Action: 'Worker-Statistic' });
  const { FreeChat, FreeEvaluator, BusyEvaluator, QueueLength, BusyChat } = JSON.parse(
    result?.Messages?.[0]?.Data ?? '{}'
  );
  axios.post(webhookUrl, {
    text: `*Herder Statistic*:\n
FreeChat: \`${FreeChat}\`    FreeEvaluator: \`${FreeEvaluator}\`\n
BusyChat: \`${BusyChat}\`    BusyEvaluator: \`${BusyEvaluator}\`\n
QueueLength: \`${QueueLength}\``,
  });
}

async function getPoolStatistic() {
  const result = await dryrun(POOL_PROCESS, {
    Action: 'Participants-Statistic',
  });
  const { last_hour, last_day, total } = JSON.parse(result?.Messages?.[0]?.Data ?? '{}');
  const text = `*Pool Statistic*:\n
  Participants in last hour: \`${last_hour}\`\n
  Participants in last 24h: \`${last_day}\`\n
  Total participants: \`${total}\``;

  console.log(text);
  // axios.post(webhookUrl, {
  //   text,
  // });
}

async function getDatasetStatistic() {
  const result = await dryrun(POOL_PROCESS, { Action: 'Dataset-Statistic' });
  const datasetInfos = JSON.parse(result?.Messages?.[0]?.Data ?? '[]');

  const text = `*Dataset Statistics*:\n\n${datasetInfos
    .map((di: any) => {
      return `  Pool (${di.PoolId}): \n\n  Evaluated datasets count: ${di.evaluated} \n\n  UnEvaluated datasets count: ${di.unEvaluated}\n\n`;
    })
    .join('\n')}
  `;

  console.log(text);
}

async function runInterval() {
  getHerderStatistic();
  getPoolStatistic();
  getDatasetStatistic();
}

async function main() {
  runInterval();
  setInterval(
    () => {
      runInterval();
    },
    1000 * 60 * 60 * 1
  );
}

main();
