'use strict'
mongoose = require 'mongoose'
Schema = mongoose.Schema

###*
* Event Schema
###
EventSchema = new Schema
     name:
          type: String
          required: true
          trim: true
     startDate:
          type: Date
          required: true
     numericStartDate:
          type: Number
     endDate:
          type: Date
     numericEndDate:
          type: Number
     region:
          type: String
          required: true
          default: 'Austria'
     tags:
          type: [String]
          default: []

try
     m = mongoose.model 'Event'

catch err
     console.log "Event Model #{m}"
     mongoose.model 'Event', EventSchema



