# medien-transparenz.at

This is the repository of the web-site [www.medien-transparenz.at](www.medien-transparenz.at). The goal of this platform is to 
interactively visualize publicly available data records that are quarterly published by [KommAustria](https://www.rtr.at/en/rtr/OrganeKommAustria).
Therefore this project is one example of Open Government Data Applications in Austria

## Technology Stack
The whole application is based on the so called MEAN stack (MongoDB, Express, Angular and NodeJS). 
Instead of building the application from scratch we have decided to use a really nice framework called
 [Mean.io](http://mean.io). So if you want to checkout this application and run it locally you can
 follow the [Mean.io instructions](http://learn.mean.io) for setting up the necessary pre-requisites.
 
A Main.io application is structured in so called [packages](http://learn.mean.io/#mean-stack-packages). 
Therefore our application comes also bundled as a package and can be found in the folder [packages/custom/transparency](https://github.com/AnotherCodeArtist/medien-transparenz.at/tree/master/packages/custom/transparency).
  
The actual logic is written in [CoffeeScript](http://coffeescript.org). Thus the folder layout is 
a bit different compared to other packages. The source can be found at [packages/custom/transparency/coffee](https://github.com/AnotherCodeArtist/medien-transparenz.at/tree/master/packages/custom/transparency/coffee) that 
actually rebuilds the file structure of one level above. The goal `gulp coffee_transparency` compiles the 
CoffeeScript code to JavaScript and places all files in the correct folders.

