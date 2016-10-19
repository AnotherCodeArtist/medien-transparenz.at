'use strict'
app = angular.module 'mean.transparency'

#Controller for the upload of the organisation-address-data
app.controller 'UploadOrganisationController',['$scope','Upload', ($scope,Upload) ->
  makeUpload = (file) ->
    $scope.upload = Upload.upload(url: 'api/transparency/addOrganisation', data: file: file)
    .then(
        (resp) -> $scope.feedback = resp.data
        (msg) -> $scope.error = msg
        (evt) -> $scope.percent = parseInt(100.0 * evt.loaded / evt.total)

    )
    return
  $scope.onFileSelect = ($files) -> makeUpload file for file in $files
  return

]