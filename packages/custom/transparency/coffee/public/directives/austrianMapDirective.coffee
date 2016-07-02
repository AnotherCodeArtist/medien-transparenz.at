'use strict'
app = angular.module 'mean.transparency'

app.directive 'austrianMap', ($rootScope) ->
     restrict: 'EA'
     link: ($scope,element,attrs) ->
          json = {}
          #Store downloaded JSON in variable
          defaults = {
               color:
                    'function(d) {\n' +
                    '  return Math.random() * 16777216;\n' +
                    '}'
               height:
                    'function(d) {\n' +
                    '  return Math.random()*50\n' +
                    '}'
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
                         side: THREE.DoubleSide
                    #phong : new THREE.MeshPhongMaterial({ color: 0xffffff, specular: 0x000000, shininess: 60, shading: THREE.SmoothShading, transparent:true  }),
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
               camera.position.z = Math.min(container.clientWidth, container.clientHeight);
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
               renderer.shadowMapEnabled = true;
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

          clearGroups = () ->
               if (json)
                    if json.type is 'FeatureCollection'
                         json.features.forEach (feature) ->
                              scene.remove(feature._group)
                    else if (json.type is 'Topology')
                         Object.keys(json.objects).forEach (key) ->
                              json.objects[key].geometries.forEach (object) ->
                                   scene.remove(object._group)
                    render()
          update = () ->
               clearGroups();
               width = container.clientWidth;
               height = container.clientHeight;
               #Read url from url textarea
               url = "/transparency/assets/data/oesterreich.json"
               d3.json(url, (data) ->
                    console.log(data)
                    json = data;
                    functions = {};
                    functions.color = eval('(' + defaults.color + ')');
                    functions.height = eval('(' + defaults.height + ')');
                    if (json.type is 'FeatureCollection')
                         projection = getProjection(json, width, height)
                         json.features.forEach (feature) ->
                              group = addFeature(feature, projection, functions)
                              feature._group = group
                    else if (json.type is 'Topology')
                         geojson = topojson.merge(json, json.objects[Object.keys(json.objects)[0]].geometries)
                         projection = getProjection(geojson, width, height)
                         Object.keys(json.objects).forEach (key) ->
                              json.objects[key].geometries.forEach (object) ->
                                   feature = topojson.feature(json, object)
                                   group = addFeature(feature, projection, functions)
                                   object._group = group
                    else
                         console.log('This tutorial only renders TopoJSON and GeoJSON FeatureCollections'))
               render()
          addShape = (group, shape, extrudeSettings, material, color, x, y, z, rx, ry, rz, s) ->
               geometry = new THREE.ExtrudeGeometry(shape, extrudeSettings);
               mesh = new THREE.Mesh(geometry, materials[material](color));
               #Add shadows
               mesh.castShadow = true;
               mesh.receiveShadow = true;
               mesh.position.set(x, y, z);
               mesh.rotation.set(rx, ry, rz);
               mesh.scale.set(s, s, s);
               group.add(mesh);
          addFeature = (feature, projection, functions) ->
               group = new THREE.Group();
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
               if (feature.geometry.type is 'Polygon')
                    shape = createPolygonShape(feature.geometry.coordinates, projection)
                    addShape(group, shape, extrudeSettings, material, color, 0, 0, amount, Math.PI, 0, 0, 1)
               else if (feature.geometry.type is 'MultiPolygon')
                    feature.geometry.coordinates.forEach (polygon) ->
                         shape = createPolygonShape(polygon, projection)
                         addShape(group, shape, extrudeSettings, material, color, 0, 0, amount, Math.PI, 0, 0, 1)
               else
                    console.log('This tutorial only renders Polygons and MultiPolygons')
               group
          #Initalize WebGL!
          init()
          animate()