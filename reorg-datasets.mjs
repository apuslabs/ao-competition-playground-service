import fs from 'fs';
// read the online dataset list
const datalist = JSON.parse(fs.readFileSync('online-dataset-list.json', 'utf8'));

const dlist = datalist.map((v) => v.dataset_hash);
console.log(dlist.length);

// scan datasets folder
const files = fs.readdirSync('./datasets');

// read every file
const storedHash = [];
const data = files.reduce((list, file) => {
  // import each file as json
  const datalist = JSON.parse(fs.readFileSync(`./datasets/${file}`, 'utf8'));
  // filter the json with list, item.hash in list
  const filtered = datalist.filter((item) => dlist.includes(item.hash));
  for (const item of filtered) {
    if (!storedHash.includes(item.hash)) {
      storedHash.push(item.hash);
      list.push(item);
    }
  }
  return list;
}, []);

console.log(data.length);

fs.writeFileSync('final-dataset-list.json', JSON.stringify(data), 'utf8');
