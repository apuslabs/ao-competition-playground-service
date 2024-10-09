import path from 'path';
import { EMBEDDING_PROCESS, POOL_PROCESS } from './ao/config';
import { msgResult } from './ao/wallet';
import fs from 'fs';

const PAGE_SIZE = 1;

function getCountFromResult(result: any): number {
  const raw_str = result.Output.data as string;
  const totalRecordsCount = parseInt(raw_str.replace(/^\x1B\[.*\n?/gm, ''));

  return totalRecordsCount;
}

function getRecordsFromResult(result: any): any[] {
  const raw_str = result.Output.data as string;
  const rows = JSON.parse(raw_str);
  return rows as any[];
}

function getNearestHalfHour(): string {
  const now = new Date();

  // 调整时间到东八时区
  const utcTime = now.getTime() + now.getTimezoneOffset() * 60000; // 当前 UTC 时间
  const eightHoursAhead = new Date(utcTime + 8 * 60 * 60 * 1000); // 转换为东八区时间

  // 获取当前的小时和分钟
  let minutes = eightHoursAhead.getMinutes();
  let hours = eightHoursAhead.getHours();

  // 取最近的半小时
  if (minutes >= 30) {
    minutes = 30;
  } else {
    minutes = 0;
  }

  eightHoursAhead.setHours(hours);
  eightHoursAhead.setMinutes(minutes);
  eightHoursAhead.setSeconds(0);
  eightHoursAhead.setMilliseconds(0);

  // 格式化为 YYYYMMDDHHmmss
  const year = eightHoursAhead.getFullYear();
  const month = String(eightHoursAhead.getMonth() + 1).padStart(2, '0'); // 月份是从 0 开始的
  const day = String(eightHoursAhead.getDate()).padStart(2, '0');
  const hour = String(eightHoursAhead.getHours()).padStart(2, '0');
  const minute = String(eightHoursAhead.getMinutes()).padStart(2, '0');

  return `${year}${month}${day}${hour}${minute}`;
}

// Embedding stores variables in memory
async function getPoolBackup() {
  const result = await msgResult(
    POOL_PROCESS,
    {
      Action: 'Eval',
    },
    'GetTotalAllParticipants()'
  );
  const totalRecordsCount = getCountFromResult(result);

  const target_file_name = 'backup/pool/participants/' + getNearestHalfHour() + '.csv';

  if (fs.existsSync(target_file_name)) {
    console.log(`Target copy ${target_file_name} exists.`);
    return;
  }

  const headers = [
    'dataset_hash',
    'pool_id',
    'author',
    'dataset_name',
    'created_at',
    'progress',
    'score',
    'rank',
    'reward',
  ];

  const dir = path.dirname(target_file_name);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true }); // 递归创建目录
    console.log('目录已创建:', dir);
  }

  if (!fs.existsSync(target_file_name)) {
    fs.writeFileSync(target_file_name, headers.join(',') + '\n', 'utf8');
  }

  let cur_page = 0;
  while (cur_page * PAGE_SIZE < totalRecordsCount) {
    const getRecordsResult = await msgResult(
      POOL_PROCESS,
      {
        Action: 'Eval',
      },
      `GetAllParticipantsByPage(${cur_page * PAGE_SIZE}, ${PAGE_SIZE})`
    );
    const rows = getRecordsFromResult(getRecordsResult);

    const content = rows
      .map((r: any) => {
        return headers.map((header) => (r[header] !== undefined ? r[header] : '')).join(',');
      })
      .join('\n');
    fs.appendFileSync(target_file_name, content, 'utf8');

    if ((cur_page + 1) * PAGE_SIZE < totalRecordsCount) {
      fs.appendFileSync(target_file_name, '\n', 'utf8');
    }
    cur_page += 1;
  }
  console.log(`Data has been backed up to the file ${target_file_name}.`);
}

(async function main() {
  getPoolBackup();
})();
