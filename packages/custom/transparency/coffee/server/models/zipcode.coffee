'use strict'
mongoose = require 'mongoose'
Schema = mongoose.Schema

###*
* ZipCode Schema
###
ZipcodeSchema = new Schema

    zipCode:
        type: String
        required: true
        unique: true

    federalState:
        type: String
        required: true

ZipcodeSchema.index(
  {
      zipCode: 1
      unique: true
  }
)

try
    m = mongoose.model 'Zipcode'

catch err
    console.log "Zipcode Model #{err}"
    mongoose.model 'Zipcode', ZipcodeSchema