'use strict'
mongoose = require 'mongoose'
Schema = mongoose.Schema

###*
* Grouping Schema
###
GroupingSchema = new Schema
    name:
        type: String
        required: true
        trim: true
        unique: true
    type: String
    region:
        type: String
        required: true
        trim: true
    owner:
        type: String
        trim: true
    members:
        type: [String]
        required: true
    isActive:
        type: Boolean
        required: true


GroupingSchema.path('type').validate(
    (type) -> type in ['org','media']
    'Type must be either org or media')

try
    m = mongoose.model 'Grouping'

catch err
    console.log "Grouping Model #{m}"
    mongoose.model 'Grouping', GroupingSchema