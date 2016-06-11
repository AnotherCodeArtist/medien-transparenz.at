'use strict'
mongoose = require 'mongoose'
Schema = mongoose.Schema

###*
* Organisation Schema
###
OrganisationSchema = new Schema
    name:
        type: String
        required: true
        trim: true
    street:
        type: String
        required: true
        trim: true
    zipCode:
        type: String
        trim: true
        required: true
    city_de:
        type: String
        trim: true
        required: true
    federalState_en:
        type: String
        trim: true
        required: true
    country_de:
        type: String
        trim: true
        required: true



OrganisationSchema.index(
  {
      name: 1
      federalState_en: 1
  },{
      unique: true
  }
)

OrganisationSchema.indexes()

try
    m = mongoose.model 'Organisation'

catch err
    mongoose.model 'Organisation', OrganisationSchema