'use strict'
app = angular.module 'mean.transparency'

#Controller for the upload of the zip-code list
app.controller 'UploadZipCodeController',['$scope','Upload', ($scope,Upload) ->
  makeUpload = (file) ->
    $scope.upload = Upload.upload(url: 'api/transparency/addZipCode', data: file: file)
    .then(
        (resp) -> $scope.feedbackZipCode = resp.data
        (msg) -> $scope.error = msg
        (evt) -> $scope.percent = parseInt(100.0 * evt.loaded / evt.total)

    )
    return
  $scope.onFileSelect = ($files) -> makeUpload file for file in $files
  return

]