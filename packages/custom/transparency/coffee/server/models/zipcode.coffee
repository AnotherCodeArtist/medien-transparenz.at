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

    federalState:
        type: String
        required: true


try
    m = mongoose.model 'Zipcode'

catch err
    console.log "Zipcode Model #{err}"
    mongoose.model 'Zipcode', ZipcodeSchema