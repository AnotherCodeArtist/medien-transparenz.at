'use strict'
app = angular.module 'mean.transparency'

app.directive 'austrianMap', ($rootScope, TPAService) ->
     restrict: 'EA'
     scope:
          data: '='
     link: ($scope,element,attrs) ->
          $rootScope.showTooltip = true;
          initialized = false
          transferSums = {}
          json = {}

          mouse = new THREE.Vector2();
          objects = [];

          onDocumentMouseDown = (e) ->
               debugMode = false;
               if debugMode
                    console.log e
               event = e.originalEvent
               if debugMode
                    console.log event
               event.preventDefault();

               mouse3D = new THREE.Vector3(event.offsetX / event.srcElement.width * 2 - 1,
                    -(event.offsetY ) / event.srcElement.height * 2 + 1,
                    1.0 );

               mouse3D.unproject(camera);
               mouse3D.sub(camera.position);
               mouse3D.normalize();
               raycaster = new THREE.Raycaster(camera.position, mouse3D );

               if debugMode
                    console.log 'camera'
                    console.log camera.position
                    console.log 'mouse'
                    console.log mouse3D

                    geometry = new THREE.Geometry();
                    geometry.vertices.push(raycaster.ray.origin);
                    newV = new THREE.Vector3(raycaster.ray.direction.x, raycaster.ray.direction.y, raycaster.ray.direction.z);
                    newV = newV.multiplyScalar(10000);
                    newV = newV.add(raycaster.ray.origin);
                    geometry.vertices.push(newV);
                    line = new THREE.Line(geometry, materials.phong (new THREE.Color("rgb(241, 176, 0)")));

                    scene.add line

               intersects = raycaster.intersectObjects(objects);
               if ( intersects.length > 0 )
                    $rootScope.$broadcast 'federalStateClicked', intersects[0].object.userData.bundesland
                    
          onDocumentMouseOver = (event) ->
               debugMode = false
               mouse3D = new THREE.Vector3(event.offsetX / event.srcElement.width * 2 - 1,
                    -(event.offsetY ) / event.srcElement.height * 2 + 1,
                    1.0 );

               mouse3D.unproject(camera);
               mouse3D.sub(camera.position);
               mouse3D.normalize();
               raycaster = new THREE.Raycaster(camera.position, mouse3D );

               if debugMode
                    console.log 'camera'
                    console.log camera.position
                    console.log 'mouse'
                    console.log mouse3D

                    geometry = new THREE.Geometry();
                    geometry.vertices.push(raycaster.ray.origin);
                    newV = new THREE.Vector3(raycaster.ray.direction.x, raycaster.ray.direction.y, raycaster.ray.direction.z);
                    newV = newV.multiplyScalar(10000);
                    newV = newV.add(raycaster.ray.origin);
                    geometry.vertices.push(newV);
                    line = new THREE.Line(geometry, materials.phong (new THREE.Color("rgb(241, 176, 0)")));

                    scene.add line

               intersects = raycaster.intersectObjects(objects);

               toolTipDiv = document.getElementById 'toolTip'
               if ( intersects.length > 0 )
                    for object in objects
                         if object.userData.bundesland isnt intersects[0].object.userData.bundesland
                              object.material = materials.phong(defaults.color({iso: object.userData.bundesland}));
                         else
                              object.material = materials.phongNotTransparent(defaults.color({iso: object.userData.bundesland}))
                    render()
                    $rootScope.$broadcast 'isoChanged', transferSums[intersects[0].object.userData.bundesland]
                    toolTipDiv.style.display = 'block';

                    left  = event.clientX  + "px";
                    top  = event.clientY  + "px";
                    toolTipDiv.style.left = left;
                    toolTipDiv.style.top = top;
                    if debugMode
                         console.log intersects[0].object.userData.bundesland
               else
                    toolTipDiv.style.display = 'none';

          element.bind 'click', onDocumentMouseDown
          element[0].addEventListener 'mousemove', onDocumentMouseOver, false
          element.on('mouseleave', () ->
               document.getElementById 'toolTip'
               .style.display = 'none';
               for object in objects
                    object.material = materials.phong(defaults.color({iso: object.userData.bundesland}));
               render()
          )

          #Store downloaded JSON in variable
          defaults = {
               color: (d) ->
                    color = switch (d.iso)
                              when "AT-1" then new THREE.Color("rgb(241, 176, 0)")
                              when "AT-2" then new THREE.Color("rgb(255, 204, 0)")
                              when "AT-3" then new THREE.Color("rgb(0, 102, 255)")
                              when "AT-4" then new THREE.Color("rgb(255, 0, 0)")
                              when "AT-5" then new THREE.Color("rgb(245, 190, 21)")
                              when "AT-6" then new THREE.Color("rgb(0, 102, 0)")
                              when "AT-7" then new THREE.Color("rgb(255, 0, 0)")
                              when "AT-8" then new THREE.Color("rgb(255, 0, 0)")
                              when "AT-9" then new THREE.Color("rgb(255, 0, 0)")
               height:
                    (d) ->
                         transferSums[d.iso].height*250
          }
          latest = {
               url: null
               color: null
               height: null
          }
          materials = {
               phong: (color) ->
                    new THREE.MeshPhongMaterial({
                         color: color,
                         side: THREE.DoubleSide,
                         opacity: 0.5,
                         transparent: true
                    #phong : new THREE.MeshPhongMaterial({ color: 0xffffff, specular: 0x000000, shininess: 60, shading: THREE.SmoothShading, transparent:true  }),
                    })
               phongNotTransparent: (color) ->
                    new THREE.MeshPhongMaterial({
                         color: color,
                         side: THREE.DoubleSide
                    })
               meshLambert: (color) ->
                    new THREE.MeshLambertMaterial({
                         color: color,
                         specular: 0x009900,
                         shininess: 30,
                         shading: THREE.SmoothShading,
                         transparent:true
                    })
               meshWireFrame: (color) ->
                    new THREE.MeshBasicMaterial({
                         color: color,
                         specular: 0x009900,
                         shininess: 30,
                         shading: THREE.SmoothShading,
                         wireframe:true,
                         transparent:true
                    })
               meshBasic: (color) ->
                    new THREE.MeshBasicMaterial({
                         color: color,
                         specular: 0x009900,
                         shininess: 30,
                         shading: THREE.SmoothShading,
                         transparent: true
                    });
          }
          if (!Detector.webgl)
               Detector.addGetWebGLMessage()
          container = {}
          camera = {}
          controls = {}
          scene = {}
          renderer = {}
          light = {}
          spotLight = {}
          ambientLight = {}
          cross = {}
          onWindowResize = () ->
               camera.aspect = container.clientWidth / container.clientHeight;
               camera.updateProjectionMatrix();
               renderer.setSize(container.clientWidth, container.clientHeight);
               controls.handleResize();
               render()
          animate = () ->
               requestAnimationFrame(animate)
               controls.update()

          render = () ->
               renderer.render(scene, camera)
          init = () ->
               container = document.getElementById('webgl');
               camera = new THREE.PerspectiveCamera( 80, container.clientWidth / container.clientHeight, 0.1, 10000);
               camera.position.set(0,-370,380)
               #camera.position.z = Math.min(container.clientWidth, container.clientHeight);
               camera.zoom = 0.7;
               controls = new THREE.TrackballControls(camera, container);
               controls.rotateSpeed = 1.0;
               controls.zoomSpeed = 1.2;
               controls.panSpeed = 0.8;
               controls.noZoom = false;
               controls.noPan = false;
               controls.staticMoving = true;
               controls.dynamicDampingFactor = 0.3;
               controls.keys = [65, 83, 68];
               controls.addEventListener('change', render);
               #World
               scene = new THREE.Scene();
               #Lights
               light = new THREE.DirectionalLight(0xffffff);
               light.position.set(1, 1, 1);
               scene.add(light);
               spotLight = new THREE.SpotLight(0xffffff);
               spotLight.position.set(-1000, -1000, 1000);
               spotLight.castShadow = true;
               scene.add(spotLight);
               ambientLight = new THREE.AmbientLight(0x333333);
               scene.add(ambientLight);
               #Renderer
               renderer = new THREE.WebGLRenderer({antialias: true});
               renderer.setPixelRatio(window.devicePixelRatio);
               renderer.setSize(container.clientWidth, container.clientHeight);
               container.appendChild(renderer.domElement);
               #Shadows
               renderer.shadowMap.enabled = true;
               renderer.shadowMapSoft = true;
               renderer.shadowCameraNear = 1;
               renderer.shadowCameraFar = camera.far;
               renderer.shadowCameraFov = 60;
               renderer.shadowMapBias = 0.0025;
               renderer.shadowMapDarkness = 0.5;
               renderer.shadowMapWidth = 1024;
               renderer.shadowMapHeight = 1024;
               renderer.setClearColor(0xffffff, 1);
               window.addEventListener('resize', onWindowResize, false);
               onWindowResize();
               render();
               update();
               animate();

          clearGroups = () ->
               if (json)
                    if json.type is 'FeatureCollection'
                         json.features.forEach (feature) ->
                              scene.remove(scene.getObjectByName(feature.properties.iso))
                    else if (json.type is 'Topology')
                         Object.keys(json.objects).forEach (key) ->
                              json.objects[key].geometries.forEach (object) ->
                                   scene.remove(object._group)
                    render()
          update = () ->
               width = container.clientWidth;
               height = container.clientHeight;
               #Read url from url textarea
               url = "/transparency/assets/data/oesterreich.json"
               d3.json(url, (data) ->
                    json = data;
                    clearGroups();
                    functions = {};
                    functions.color = defaults.color
                    functions.height = defaults.height
                    if (json.type is 'FeatureCollection')
                         projection = getProjection(json, width, height)
                         json.features.forEach (feature) ->
                              group = addFeature(feature, projection, functions)
                              feature._group = group
                         render()
                    else if (json.type is 'Topology')
                         geojson = topojson.merge(json, json.objects[Object.keys(json.objects)[0]].geometries)
                         projection = getProjection(geojson, width, height)
                         Object.keys(json.objects).forEach (key) ->
                              json.objects[key].geometries.forEach (object) ->
                                   feature = topojson.feature(json, object)
                                   group = addFeature(feature, projection, functions)
                                   object._group = group
                         render()
                    else
                         console.log('This tutorial only renders TopoJSON and GeoJSON FeatureCollections'))
          addShape = (group, shape, extrudeSettings, material, color, x, y, z, rx, ry, rz, s, iso) ->
               geometry = new THREE.ExtrudeGeometry(shape, extrudeSettings);
               mesh = new THREE.Mesh(geometry, materials[material](color));
               #Add shadows
               mesh.castShadow = true;
               mesh.receiveShadow = true;
               mesh.position.set(x, y, z);
               mesh.rotation.set(rx, ry, rz);
               mesh.scale.set(s, s, s);
               mesh.userData.bundesland = iso
               objects.push mesh
               group.add(mesh);
          addFeature = (feature, projection, functions) ->
               group = new THREE.Group();
               group.name = feature.properties.iso
               scene.add(group);
               color;
               amount;
               try
                    color = functions.color(feature.properties);
               catch err
                    console.log(err)
               try
                    amount = functions.height(feature.properties);
               catch err
                    console.log(err)
               extrudeSettings = {
                    amount: amount,
                    bevelEnabled: false
               };
               material = 'phong';
               iso = feature.properties.iso
               if (feature.geometry.type is 'Polygon')
                    shape = createPolygonShape(feature.geometry.coordinates, projection)
                    addShape(group, shape, extrudeSettings, material, color, 0, 0, amount, Math.PI, 0, 0, 1, iso)
               else if (feature.geometry.type is 'MultiPolygon')
                    feature.geometry.coordinates.forEach (polygon) ->
                         shape = createPolygonShape(polygon, projection)
                         addShape(group, shape, extrudeSettings, material, color, 0, 0, amount, Math.PI, 0, 0, 1, iso)
               else
                    console.log('This tutorial only renders Polygons and MultiPolygons')
               group



          dataUpdated = () ->
               if $scope.data and Object.keys($scope.data).length isnt 0
                    #transferSums = $scope.data
                    maximum = Number.NEGATIVE_INFINITY
                    sum = 0
                    for k,v of $scope.data
                         sum += v
                         if v > maximum
                              maximum = v
                    for k,v of $scope.data
                         transferSums[k] = {}
                         transferSums[k].height = v/parseFloat(maximum)
                         transferSums[k].sum = v
                         transferSums[k].percent = (v/sum)*100
                         transferSums[k].iso = k

                    if !initialized
                         init()
                         render()
                         initialized = true
                    if initialized
                         update()
          $scope.$watch 'data', dataUpdated