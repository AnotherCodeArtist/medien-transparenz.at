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
     endDate:
          type: Date
     region:
          type: String
          required: true
          default: 'Austria'
     tags:
          type: Array
          default: []

try
     m = mongoose.model 'Event'

catch err
     console.log "Event Model #{m}"
     mongoose.model 'Event', EventSchema



