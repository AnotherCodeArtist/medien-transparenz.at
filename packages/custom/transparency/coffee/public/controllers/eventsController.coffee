'use strict'
app = angular.module 'mean.transparency'

app.controller 'EventsController',['$scope', 'TPAService', 'gettextCatalog', ($scope, TPAService, gettextCatalog) ->

     updateTable = ->
          TPAService.getEvents({})
          .then((result) ->
               $scope.events = result.data

               for event in $scope.events
                    event.region = gettextCatalog.getString(event.region)
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

     setRegions = () ->
          if $scope.event and $scope.event.region
               reg = $scope.event.region
          $scope.regions = [
               {
                    value: "Austria"
                    name: gettextCatalog.getString("Austria")
               },
               {
                    value: "Vorarlberg"
                    name: gettextCatalog.getString("Vorarlberg")
               },
               {
                    value: "Tyrol"
                    name: gettextCatalog.getString("Tyrol")
               },
               {
                    value: "Salzburg"
                    name: gettextCatalog.getString("Salzburg")
               },
               {
                    value: "Upper Austria"
                    name: gettextCatalog.getString("Upper Austria")
               },
               {
                    value: "Lower Austria"
                    name: gettextCatalog.getString("Lower Austria")
               },
               {
                    value: "Vienna"
                    name: gettextCatalog.getString("Vienna")
               },
               {
                    value: "Burgenland"
                    name: gettextCatalog.getString("Burgenland")
               },
               {
                    value: "Styria"
                    name: gettextCatalog.getString("Styria")
               },
               {
                    value: "Carinthia"
                    name: gettextCatalog.getString("Carinthia")
               }
          ]
          if reg
               for region in $scope.regions
                    if region.value is reg.value
                         $scope.event.region = region

     setRegions()
     $scope.$on 'gettextLanguageChanged', setRegions
     $scope.$on 'gettextLanguageChanged', updateTable

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

          $scope.event.region = $scope.event.region.value
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

               for region in $scope.regions
                    if region.value is result.data.region
                         $scope.event.region = region

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
          $scope.event.region = $scope.event.region.value
          $scope.event.tags = tags
          TPAService.createEvent $scope.event
          .then((result) ->
               resetNewEvent()
          )

     return
]