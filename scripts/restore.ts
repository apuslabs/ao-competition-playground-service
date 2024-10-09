import fs from 'fs';
import { msgResult } from './ao/wallet';

const POOL_PROCESS = 'mS9PN-9NMH0gk-nxFSA2JRZccmhR92BiRWp7VkoLoGE';
const DATA_COPY = '20241008230000.csv';
const BATCH_SIZE = 1;

function findLatestDataCopy(): string | null {
  const files = fs.readdirSync('backup/pool/participants').filter((f) => f != '.gitkeep');
  if (files.length == 0) {
    return null;
  }
  const targetFile = files.sort()[files.length - 1];
  return targetFile;
}

async function singleUpload(records: string[], headers: string[]) {
  const upload_datas: any[] = [];
  records.forEach((r: string) => {
    const columns = r.split(',').map((s) => s.trim());
    const obj = headers.reduce((acc, key, index) => {
      acc[key] = columns[index];
      return acc;
    }, {} as { [key: string]: any });

    upload_datas.push(obj);
  });

  const upload_json = JSON.stringify(upload_datas);
  const upload_param = `"${upload_json.replace(/"/g, '\\"')}"`;
  const eval_expression = `ImportParticipants(${upload_param})`;

  console.log(eval_expression);

  const result = await msgResult(
    POOL_PROCESS,
    {
      Action: 'Eval',
    },
    eval_expression
  );
}

function readRecordsAndUpload() {
  const targetCopy = findLatestDataCopy();
  if (!targetCopy) {
    console.log('No copy found.');
    return;
  }
  console.log(`Recovering data from copy ${targetCopy} ...`);

  const lines = fs
    .readFileSync('backup/pool/participants/' + targetCopy)
    .toString()
    .split('\n');
  const header_names = lines[0].split(',').map((s) => s.trim());

  let cur_page = 0;
  while (cur_page * BATCH_SIZE < lines.length - 1) {
    const upload_data = lines.slice(cur_page * BATCH_SIZE + 1, Math.min(lines.length, (cur_page + 1) * BATCH_SIZE + 1));
    singleUpload(upload_data, header_names);

    cur_page += 1;
  }
}

(async function main() {
  readRecordsAndUpload();
})();
