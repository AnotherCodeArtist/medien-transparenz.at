'use strict'
app = angular.module 'mean.transparency'

app.controller 'UploadController',['$scope','Upload', ($scope,Upload) ->
  makeUpload = (file) ->
    $scope.feedback = null
    $scope.upload = Upload.upload(url: 'api/transparency/add', data: file: file)
    .then(
        (resp) -> $scope.feedback = resp.data
        (msg) -> $scope.error = msg
        (evt) -> $scope.percent = parseInt(100.0 * evt.loaded / evt.total)

    )
    return
  $scope.onFileSelect = ($files) -> makeUpload file for file in $files
  return

]