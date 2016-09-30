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
        trim: true
        index: true
    transferType: Number
    media:
        type: String
        trim: true
        required: true
    amount: Number
    year: Number
    quarter: Number
    period: Number
    organisationReference:
        type:Schema.Types.ObjectId
        ref: 'Organisation'

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
    },{
    unique: true
    #dropDups: true
    }
)

TransferSchema.indexes()

try
    m = mongoose.model 'Transfer'

catch err
    console.log "Transfer Model #{err}"
    mongoose.model 'Transfer', TransferSchema



