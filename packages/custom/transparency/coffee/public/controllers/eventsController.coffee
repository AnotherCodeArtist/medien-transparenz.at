'use strict'
app = angular.module 'mean.transparency'

app.controller 'EventsController',['$scope', 'TPAService', ($scope, TPAService) ->

     updateTable = ->
          TPAService.getEvents({})
          .then((result) ->
               $scope.events = result.data
          )

     $scope.loadTags = (query) ->
          TPAService.getEventTags()
          .then (tags) ->
               tags.data.filter (tag) ->
                    tag.toLowerCase().indexOf(query.toLowerCase()) != -1
                    
     $scope.removeEvent = (id, name) ->
          if confirm("Sure to delete #{name}?")
               TPAService.removeEvent {id:id}
               .then () ->
                    updateTable()

     $scope.regions = [
          {name: "Austria"},
          {name: "Vorarlberg"},
          {name: "Tyrolia"},
          {name: "Salzburg"},
          {name: "Upper Austria"},
          {name: "Lower Austria"},
          {name: "Vienna"},
          {name: "Burgenland"},
          {name: "Styria"},
          {name: "Carenthia"}
     ]

     resetNewEvent = ->
          $scope.newEvent = {
               name: ''
               startDate: new Date()
               numericStartDate: 0
               endDate: ''
               numericEndDate: 0
               region: $scope.regions[0]
               tags: []
          }
          $scope.newEvent.startDate.setHours 0,0,0,0
          updateTable()

     resetNewEvent()

     $scope.createEvent = ->
          tags = []
          for tag in $scope.newEvent.tags
               tags.push tag.text
          $scope.newEvent.tags = tags
          $scope.newEvent.region = $scope.newEvent.region.name
          TPAService.createEvent $scope.newEvent
          .then((result) ->
               resetNewEvent()
          )

     return
]