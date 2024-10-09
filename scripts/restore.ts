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

async function singleUpload(records: any[]) {
  const upload_json = JSON.stringify(records);
  const upload_param = `"${upload_json.replace(/"/g, '\\"')}"`;
  const eval_expression = `SQL.ImportParticipants(${upload_param})`;

  const result = await msgResult(
    POOL_PROCESS,
    {
      Action: 'Eval',
    },
    eval_expression
  );
}

function recoverPoolParticipants() {
  const targetCopy = findLatestDataCopy();
  if (!targetCopy) {
    console.log('No copy found.');
    return;
  }
  console.log(`Recovering data from copy ${targetCopy} ...`);

  const records = JSON.parse(fs.readFileSync('backup/pool/participants/' + targetCopy).toString());

  let cur_page = 0;
  while (cur_page * BATCH_SIZE <= records.length - 1) {
    const upload_data = records.slice(cur_page * BATCH_SIZE, Math.min(records.length, (cur_page + 1) * BATCH_SIZE));
    singleUpload(upload_data);

    cur_page += 1;
  }
}

(async function main() {
  recoverPoolParticipants();
})();
