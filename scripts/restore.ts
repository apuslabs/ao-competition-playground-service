import fs from 'fs';
import { msgResult } from './ao/wallet';
import path from 'path';

const POOL_PROCESS = 'mS9PN-9NMH0gk-nxFSA2JRZccmhR92BiRWp7VkoLoGE';
const COMPETITION_PROCESS = 'hrmEo_Hygd-QiawMdQcWH7-ZzWX7Q_c2Qqy4qNN0EYQ';
const DATA_COPY = '20241008230000.csv';
const BATCH_SIZE = 20;

function findLatestDataCopy(base_dir: string): string | null {
  const files = fs.readdirSync(base_dir).filter((f) => f != '.gitkeep');
  if (files.length == 0) {
    return null;
  }
  const targetFile = files.sort()[files.length - 1];
  return path.join(base_dir, targetFile);
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
  const targetCopy = findLatestDataCopy('backup/pool/participants/');
  if (!targetCopy) {
    console.log('No copy found.');
    return;
  }
  console.log(`Recovering data from copy ${targetCopy} ...`);

  const records = JSON.parse(fs.readFileSync(targetCopy).toString());

  let cur_page = 0;
  while (cur_page * BATCH_SIZE <= records.length - 1) {
    const upload_data = records.slice(cur_page * BATCH_SIZE, Math.min(records.length, (cur_page + 1) * BATCH_SIZE));
    singleUpload(upload_data);

    cur_page += 1;
  }
}

async function recoverCompetition() {
  async function recoverCompetitionQuestions() {
    const targetCopy = findLatestDataCopy('backup/competition/questions/');
    if (!targetCopy) {
      console.log('No copy found.');
      return;
    }
    console.log(`Recovering competition questions from copy ${targetCopy} ...`);

    const records = JSON.parse(fs.readFileSync(targetCopy).toString());
    const result = await msgResult(
      COMPETITION_PROCESS,
      {
        Action: 'Eval',
      },
      `SQL.BatchCreateQuestion("${JSON.stringify(records).replace(/"/g, '\\"')}", {json_input=true, contain_id=true})`
    );
  }

  async function recoverCompetitionEvaluations() {
    const targetCopy = findLatestDataCopy('backup/competition/evaluations/');
    if (!targetCopy) {
      console.log('No copy found.');
      return;
    }
    console.log(`Recovering competition questions from copy ${targetCopy} ...`);

    const records = JSON.parse(fs.readFileSync(targetCopy).toString());

    let cur_page = 0;
    while (cur_page * BATCH_SIZE < records.length) {
      const result = await msgResult(
        COMPETITION_PROCESS,
        {
          Action: 'Eval',
        },
        `SQL.BatchCreateEvaluation("${JSON.stringify(
          records.slice(cur_page * BATCH_SIZE, Math.min(records.length, (cur_page + 1) * BATCH_SIZE))
        ).replace(/"/g, '\\"')}", {json_input=true, contain_id=true})`
      );

      cur_page += 1;
    }
  }
  recoverCompetitionQuestions();
  recoverCompetitionEvaluations();
}

(async function main() {
  // recoverPoolParticipants();
  recoverCompetition();
})();
