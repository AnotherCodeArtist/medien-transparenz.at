fs = require 'fs'
iconv = require 'iconv-lite'
fs.readFile '/Users/salho/Downloads/Veroeffentlichung_3Abs3MedKFTG_2015_Q1.csv', (err,data)->
    console.log iconv.decode data,'latin1'