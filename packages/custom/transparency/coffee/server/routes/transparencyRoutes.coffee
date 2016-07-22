'use strict'

# The Package is past automatically as first parameter
module.exports = (Transparency, app, auth, database) ->

  multipartMiddleware = require('connect-multiparty')()
  transparency = require('../controllers/transparencyServerCtrl')(Transparency)

  app.get '/transparency/example/anyone', (req, res, next) ->
    res.send 'Anyone can access this'

  app.get '/transparency/example/auth', auth.requiresLogin, (req, res, next) ->
    res.send 'Only authenticated users can access this'

  app.get '/transparency/example/admin', auth.requiresAdmin, (req, res, next) ->
    res.send 'Only users with Admin role can access this'


  app.get '/transparency/example/render', (req, res, next) ->
    Transparency.render 'index', package: 'transparency', (err, html) ->
      #Rendering a view from the Package server/views
      res.send html

  app.get '/api/transparency/overview', transparency.overview

  app.get '/api/transparency/flows', transparency.flows

  app.get '/api/transparency/search', transparency.search

  app.get '/api/transparency/years', transparency.years

  app.get '/api/transparency/top', transparency.topEntries

  app.get '/api/transparency/periods', transparency.periods

  app.get '/api/transparency/list', transparency.list

  app.get '/api/transparency/count', transparency.count

  app.post '/api/transparency/add', auth.requiresAdmin,multipartMiddleware,transparency.upload
  #Route for address-upload
  app.post '/api/transparency/addOrganisation', auth.requiresAdmin,multipartMiddleware,transparency.uploadOrganisation
  #Route for zip-upload
  app.post '/api/transparency/addZipCode', auth.requiresAdmin,multipartMiddleware,transparency.uploadZipCode

  app.get '/api/transparency/events', transparency.getEvents

  app.post '/api/transparency/events', auth.requiresEditor, transparency.createEvent

  app.put '/api/transparency/events', auth.requiresEditor, transparency.updateEvent

  app.delete '/api/transparency/events', auth.requiresEditor, transparency.deleteEvent

  app.get '/api/transparency/events/tags', transparency.getEventTags

  #Grouping - get selection
  app.get '/api/transparency/grouping/list', transparency.getPossibleGroupMembers
  #Grouping - save grouping
  app.post '/api/transparency/grouping', auth.requiresEditor, transparency.createGrouping
  #Grouping . get groupings
  app.get '/api/transparency/grouping', transparency.getGroupings

  #Grouping . get groupings
  app.put '/api/transparency/grouping', auth.requiresEditor, transparency.updateGrouping
  return
