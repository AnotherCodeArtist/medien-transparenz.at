'use strict'
mongoose = require 'mongoose'
Schema = mongoose.Schema

###*
* Transfer Schema
###
TransferSchema = new Schema
    organisation:
        type: String
        required: true
        trim: true,
        index: 'hashed'
    transferType:
        type: Number
        index: 'hashed'
    media:
        type: String
        trim: true
        required: true,
        index: 'hashed'
    amount:
      type: Number
      index: true
    year:
        type: Number
        index: true
    quarter:
      type: Number
      index: true
    period:
      type: Number
      index: true
    organisationReference:
        type:Schema.Types.ObjectId
        ref: 'Organisation'
    federalState:
        type: String
        trim: true
        index: 'hashed'

TransferSchema.path('transferType').validate(
    (transferType) -> transferType in [2,4,31]
    'Transfer type must be either 2(cooperation),4(funding) or 31(?)')

TransferSchema.index(
    {
    organisation: 1
    transferType: 1
    quarter: 1
    year: 1
    media: 1
    amount: 1
    federalState : 1
    },{
    unique: true
    #dropDups: true
    }
)

TransferSchema.indexes()

try
    m = mongoose.model 'Transfer'

catch err
    console.log "Transfer Model #{m}"
    mongoose.model 'Transfer', TransferSchema



