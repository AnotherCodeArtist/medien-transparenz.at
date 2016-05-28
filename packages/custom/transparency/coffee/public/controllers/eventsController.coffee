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
          "Austria",
          "Vorarlberg",
          "Tyrolia",
          "Salzburg",
          "Upper Austria",
          "Lower Austria",
          "Vienna",
          "Burgenland",
          "Styria",
          "Carenthia"
     ]
     
     $scope.editEnabled = false

     $scope.cancelEdit = () ->
          $scope.editEnabled = false
          $scope.editId = -1
          resetNewEvent()

     $scope.updateEvent = ->
          tags = []
          for tag in $scope.event.tags
               tags.push tag.text
          $scope.event.tags = tags
          TPAService.updateEvent $scope.event
          .then ()->
               updateTable()
               resetNewEvent()
               $scope.editEnabled = false
               $scope.editId = -1

     $scope.editEvent = (id) ->
          TPAService.getEvents {id:id}
          .then (result) ->
               $scope.editEnabled = true
               $scope.editId = id
               $scope.event = result.data
               $scope.event.startDate = new Date(result.data.startDate)
               if result.data.endDate
                    $scope.event.endDate = new Date(result.data.endDate)
               $scope.event.region = result.data.region
               console.log $scope.event

     resetNewEvent = ->
          $scope.event = {
               name: ''
               startDate: new Date()
               numericStartDate: 0
               endDate: ''
               numericEndDate: 0
               region: $scope.regions[0]
               tags: []
          }
          $scope.event.startDate.setHours 0,0,0,0
          updateTable()

     resetNewEvent()

     $scope.createEvent = ->
          tags = []
          for tag in $scope.event.tags
               tags.push tag.text
          $scope.event.tags = tags
          TPAService.createEvent $scope.event
          .then((result) ->
               resetNewEvent()
          )

     return
]