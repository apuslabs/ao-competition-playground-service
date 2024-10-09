import path from 'path';
import { EMBEDDING_PROCESS, POOL_PROCESS } from './ao/config';
import { msgResult } from './ao/wallet';
import fs from 'fs';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';

const COMPETITION_PROCESS = 'hrmEo_Hygd-QiawMdQcWH7-ZzWX7Q_c2Qqy4qNN0EYQ';

// 加载插件
dayjs.extend(utc);
dayjs.extend(timezone);

const PAGE_SIZE = 50;

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
  // 获取当前时间并调整到东八时区
  const now = dayjs().tz('Asia/Shanghai'); // Asia/Shanghai 代表东八时区

  // 获取当前的分钟
  const minutes = now.minute();
  let adjustedTime;

  // 取最近的半小时
  if (minutes >= 30) {
    adjustedTime = now.minute(30).second(0).millisecond(0);
  } else {
    adjustedTime = now.minute(0).second(0).millisecond(0);
  }

  // 格式化为 YYYYMMDDHHmm
  return adjustedTime.format('YYYYMMDDHHmm');
}

// Embedding stores variables in memory
async function getPoolBackup() {
  if (!fs.existsSync('backup/pool/participants/')) {
    fs.mkdirSync('backup/pool/participants/', { recursive: true });
  }
  const result = await msgResult(
    POOL_PROCESS,
    {
      Action: 'Eval',
    },
    'SQL.GetTotalAllParticipants()'
  );
  console.log(result);
  const totalRecordsCount = getCountFromResult(result);

  const target_file_name = 'backup/pool/participants/' + getNearestHalfHour() + '.json';

  if (fs.existsSync(target_file_name)) {
    console.log(`Target copy ${target_file_name} exists.`);
    return;
  }

  const dir = path.dirname(target_file_name);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true }); // 递归创建目录
    console.log('目录已创建:', dir);
  }

  let cur_page = 0;
  let records: any[] = [];
  while (cur_page * PAGE_SIZE < totalRecordsCount) {
    const getRecordsResult = await msgResult(
      POOL_PROCESS,
      {
        Action: 'Eval',
      },
      `Json.encode(SQL.GetAllParticipantsByPage(${cur_page * PAGE_SIZE}, ${PAGE_SIZE}))`
    );
    console.log(`json.encode(SQL.GetAllParticipantsByPage(${cur_page * PAGE_SIZE}, ${PAGE_SIZE}))`);
    console.log(getRecordsResult);
    const rows = getRecordsFromResult(getRecordsResult);

    records = records.concat(rows);
    console.log(records);

    cur_page += 1;
  }
  fs.writeFileSync(target_file_name, JSON.stringify(records, null, 2));
  console.log(`Data has been backed up to the file ${target_file_name}.`);
}

async function getCompetitionBackup() {
  async function getQuestions() {
    if (!fs.existsSync('backup/competition/questions/')) {
      fs.mkdirSync('backup/competition/questions/', { recursive: true });
    }
    const target_file_name = 'backup/competition/questions/' + getNearestHalfHour() + '.json';
    const getQuestionsResult = await msgResult(
      COMPETITION_PROCESS,
      {
        Action: 'Eval',
      },
      `Json.encode(SQL.GetQuestions())`
    );
    const questions = JSON.stringify(JSON.parse(getQuestionsResult.Output.data), null, 2);
    fs.writeFileSync(target_file_name, questions);

    console.log(`Question data has been backed up in ${target_file_name}`);
  }
  async function getEvaluations() {
    if (!fs.existsSync('backup/competition/evaluations/')) {
      fs.mkdirSync('backup/competition/evaluations/', { recursive: true });
    }
    const target_file_name = 'backup/competition/evaluations/' + getNearestHalfHour() + '.json';
    let continue_flag = true;
    let cur_page = 0;
    let records: any[] = [];

    while (continue_flag) {
      const getQuestionsResult = await msgResult(
        COMPETITION_PROCESS,
        {
          Action: 'Eval',
        },
        `Json.encode(SQL.GetEvaluations(${PAGE_SIZE}, ${cur_page * PAGE_SIZE}))`
      );
      const res = JSON.parse(JSON.parse(getQuestionsResult.Output.data));
      records = records.concat(res);
      if (res.length < PAGE_SIZE) {
        continue_flag = false;
      }
      cur_page += 1;
    }

    fs.writeFileSync(target_file_name, JSON.stringify(records, null, 2));
    console.log(`Evaluations data has been backed up in ${target_file_name}`);
  }

  getQuestions();
  getEvaluations();
}

(async function main() {
  // getPoolBackup();
  getCompetitionBackup();
})();
