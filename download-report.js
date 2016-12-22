/**
 * Created by salho on 16.12.16.
 */

import * as http from 'https';
import * as fs from 'fs';
import * as iconv from 'iconv-lite';

const quarter = 20163;

const previousQuarter = (quarter) => {
  let pq = quarter-1;
  if (parseInt(pq.toString()[4])===0){
   pq = pq-6
  }
  return pq;
};


const download = () => http.get(
    "https://data.rtr.at/api/v1/tables/MedKFTGBekanntgabe.json?quartal=" + quarter + "&size=0",
    res => {
        let rawData = "";
        res.on('data', (chunk) => {rawData += chunk});
        res.on('end', () => {
            try {
                let transfers = JSON.parse(rawData).data;
                let csv = "";
                //console.log(transfers[2]);
                transfers.filter(s=>s.rechtstraeger.includes('UNESCO')).forEach(console.log);
                transfers.forEach(transfer =>
                csv+=transfer.rechtstraeger.replace(';',',')+";"+transfer.quartal+";"+
                    transfer.bekanntgabe+";"+transfer.leermeldung+";"+transfer.mediumMedieninhaber+";"+
                    transfer.euro+"\n");
                fs.appendFile(`./data/20123-${quarter}-raw.csv`,iconv.encode(csv,'win1252'),e=>
                    console.log("File written")
                )
            } catch (e) {
                console.log(e.message);
            }
        });
    }).on('error', (e) => {
    console.log(`Got error: ${e.message}`);
});

const pQuarter = previousQuarter(quarter);
console.log(pQuarter);
const inFile = fs.createReadStream(`./data/20123-${pQuarter}-refine-latin1.csv`);
const outFile = fs.createWriteStream(`./data/20123-${quarter}-raw.csv`);
inFile
    .pipe(iconv.decodeStream('win1251'))
    .pipe(iconv.encodeStream('win1251'))
    .pipe(outFile);
outFile.on('close',download);
