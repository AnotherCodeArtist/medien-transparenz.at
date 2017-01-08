'use strict'
app = angular.module 'mean.transparency'

app.directive 'tpaSankey', ($rootScope, gettextCatalog) ->
    restrict: 'EA'
    scope:
        data: '='
        nodeClick: '&'
        linkClick: '&'
    link: ($scope,element,attrs) ->
        margin = top: 20, right: 1, bottom: 20, left: 1
        #width = (attrs.width or 960) - margin.left - margin.right
        width = Math.round element.width()*0.8;
        #console.log element.css()
        height = Math.max 500, $scope.data.nodes.length*20
        h = height + margin.top + margin.bottom
        formatNumber = (n) -> n.toLocaleString($scope.language,{minimumFractionDigits:2,maximumFractionDigits:2})
        format = (d) -> formatNumber(d) + " &euro;"
        color = d3.scale.category20()
        if not attrs.id
            element.attr 'id', 'tpaSankey'
        svg = d3.select('#' + element.attr 'id')
        .append('svg')

        #svg = d3.select("#")
        h = height + margin.top + margin.bottom
        #svg.attr("width", width + margin.left + margin.right)
        svg.attr("height", h)
        svg.attr("style", "height: " + h + "px;")
        #svg.append("g")
        #.attr("transform", "translate(" + margin.left + "," + margin.top + ")")

        sankey = d3.sankey()
        .nodeWidth(15)
        .nodePadding(10)
        .size([width, h])

        div = d3.select("body").append("div")
                .attr("class", "tooltip")
                .style("opacity", 0)

        path = sankey.link()



        updateDiagram = ()->
            svg.selectAll("g").remove()
            height = Math.max 500, $scope.data.nodes.length*20
            h = height + margin.top + margin.bottom
            svg.attr('height',h)
            svg.attr("style", "height: " + h + "px;")
            sankey
                .nodes($scope.data.nodes)
                .links($scope.data.links)
                .size([width, height])
                .layout(if $scope.data.nodes.length > 100 then 10 else 32)
            path = sankey.link()
            link = svg.append("g")
                    .attr("transform", "translate(#{margin.left},#{margin.top})")
                    .append("g")
                    .selectAll(".link")
                    .data($scope.data.links)
                    .enter().append("path")
                    .attr("class", (d) -> "link paragraph#{d.type}")
                    .attr("d", path)
                    .style("stroke-width", (d) -> Math.max(1, d.dy))
                    .sort( (a, b) -> b.dy - a.dy )

            #link.append("title")
            #    .text (d) -> d.source.name + " → " + d.target.name + "\n" + format(d.value)

            link.on "mouseover", (d) ->
                div.transition()
                .duration(200)
                .style("opacity", .9)
                .attr('class','tooltip link')
                if d.source.name is 'Other organisations' or
                    d.source.name = gettextCatalog.getString(d.source.name)
                else if d.target.name is 'Other media'
                    d.target.name = gettextCatalog.getString(d.target.name)
                if (d.source.type is "o" and d.target.type is "m" and d.source.name isnt gettextCatalog.getString("Other organisations") and d.target.name isnt gettextCatalog.getString("Other media"))
                    div.html("""#{d.source.name} (#{formatNumber((d.value/d.source.value)*100)}%) → #{d.target.name} (#{formatNumber((d.value/d.target.value)*100)}%)<br/>#{(formatNumber(d.value))} (§#{d.type})
                            <div><i class="fa fa-bar-chart" aria-hidden="true"></i> #{gettextCatalog.getString('Click for Details')}</div>
                         """)
                    .style("left", (d3.event.pageX) + "px")
                    .style("top", (d3.event.pageY - 28) + "px")
                else
                    div.html("""#{d.source.name} (#{formatNumber((d.value/d.source.value)*100)}%) → #{d.target.name} (#{formatNumber((d.value/d.target.value)*100)}%)<br/>#{(formatNumber(d.value))} (§#{d.type})""")
                    .style("left", (d3.event.pageX) + "px")
                    .style("top", (d3.event.pageY - 28) + "px")

            .on "mouseout", () ->
                div.transition()
                .duration(500)
                .style("opacity", 0)
            .on "click", (d) ->
                if d.source.name isnt gettextCatalog.getString("Other organisations") and d.target.name isnt gettextCatalog.getString("Other media")
                    $scope.linkClick()(d)


            #make sure that all labels are invisible once the page is left    
            $rootScope.$on '$stateChangeStart', () ->
                div.style("opacity",0)


            node = svg.append("g")
            .attr("transform", "translate(#{margin.left},#{margin.top})")
            .selectAll(".node")
            .data($scope.data.nodes)
            .enter().append("g")
            .attr("class", "node")
            .attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")
            #.call(d3.behavior.drag())
            #.origin( (d) -> d )
            #.on("dragstart", () -> this.parentNode.appendChild(this))
            #.on("drag", dragmove)

            node.append("rect")
            .attr("height", (d) -> d.dy)
            .attr("width", sankey.nodeWidth())
            .style("fill", (d) ->
                regex = new RegExp ' .*'
                d.color = color(d.name.replace regex ,''))
            .style("stroke", (d) -> d3.rgb(d.color).darker(2))
            #.append("title")
            #.text( (d) -> d.name + "\n" + format(d.value))

            #Append tooltip
            node.on "mouseover", (d) ->
                div.transition()
                .duration(200)
                .style("opacity", .9)
                .attr('class','tooltip node')
                if d.name is 'Other organisations' or d.name is 'Other media'
                    d.name = gettextCatalog.getString(d.name)
                div.html("""<i class="fa #{if d.type is 'o' then 'fa-credit-card' else 'fa-newspaper-o'}" aria-hidden="true"></i> #{d.name}<br/>#{format(d.value)}<br/>#{(formatNumber(d.value/$scope.data.sum*100))}%
                        <div><i class="fa fa-line-chart" aria-hidden="true"></i> #{gettextCatalog.getString('Click for Details')}</div>
                         """)
                .style("left", (d3.event.pageX) + "px")
                .style("top", (d3.event.pageY - 28) + "px")
            .on "mouseout", () ->
                div.transition()
                .duration(500)
                .style("opacity", 0)


            if $scope.nodeClick
                #$scope.nodeClick( name: "test", type: "o")
                node.on 'click', (d)->
                    if d.name isnt gettextCatalog.getString('Other media') and d.name isnt gettextCatalog.getString('Other organisations') and not d.name.includes('OG: ') and not d.name.includes('NG: ')
                        angular.element(".tooltip").css("opacity", 0)
                        $scope.nodeClick()(d)

            node.append("text")
            .attr("x", -6)
            .attr("y", (d) -> d.dy / 2)
            .attr("dy", ".35em")
            .attr("text-anchor", "end")
            .attr("transform", null)
            .text( (d) ->
                if d.name is 'Other organisations' or d.name is 'Other media'
                    gettextCatalog.getString(d.name)
                else
                    d.name
            )
            .filter((d) -> d.x < width / 2)
            .attr("x", 6 + sankey.nodeWidth())
            .attr("text-anchor", "start");

        $scope.$watch 'data', updateDiagram


app.directive 'tpaMultiBarChart',[ '$compile', ($compile) ->
    restrict: 'E'
    scope:
        data: '='
        showXAxis: '='
        showYAxis: '='
        tooltips: '='
        showLegend: '='
        showControls: '='
    link: ($scope,element,attrs) ->
        setAttribute = (attributeName,defaultValue) ->
            if angular.isDefined($scope[attributeName]) then $scope[attributeName] else defaultValue
        if not attrs.id
            attrs.id = 'tpaMultiBar'
            element.attr 'id', 'tpaMultiBar'
        svg = angular.element "svg"
        svg.attr 'id', attrs.id+'svg'
        element.attr 'id',attrs.id
        $compile(svg)($scope)
        element.append(svg)
        svg = d3.select('#'+attrs.id+'svg')
        updateDiagram = ()->
            svg.selectAll("g").remove()
            dummy =
                [
                    key: "Stream A"
                    values: [{x:1,y:4},{x:2,y:8},{x:"Q3",y:2}]
                ]
            nv.addGraph ->
                chart = nv.models.multiBarChart()
                .transitionDuration(setAttribute 'transitionDuration',350)
                .reduceXTicks(setAttribute 'reduceXTicks',true)
                .rotateLabels(setAttribute 'rotateLabels',0)
                .showControls(setAttribute 'showControls',false)
                .groupSpacing(0.1)
                svg.datum(dummy)
                .call(chart)
                chart
        $scope.$watch 'data', updateDiagram, true

]

app.directive 'tpaPieChart', [ ->
    restrict: 'E'
    scope:
        data: '='
        x: '&'
        y: '&'
        showLegend: '=?'
        tooltipFn: '&?'
        goFn: '&?'
        preventClickFn: '='
    link: ($scope,element,attrs) ->
        if not attrs.id
            element.attr 'id', 'tpaSankey'
        svg = d3.select('#' + element.attr 'id')
        .append('svg')
        updateDiagram = ()->
            svg.selectAll("g").remove()
            nv.addGraph ->
                chart = nv.models.pieChart()
                .x($scope.x())
                .y($scope.y())
                .showLabels(true)
                .labelsOutside(false)
                .labelSunbeamLayout(true)
                .showLegend(if angular.isDefined($scope.showLegend) then $scope.showLegend else true)
                chart.tooltip.contentGenerator $scope.tooltipFn() if angular.isDefined $scope.tooltipFn
                svg.datum($scope.data)
                .transition().duration(350)
                .call(chart)
                d3.selectAll('.nv-slice')
                .on 'click', (e) ->
                    return if angular.isDefined($scope.preventClickFn) and $scope.preventClickFn(e)
                    d3.selectAll('div.nvtooltip').remove()
                    $scope.goFn()(e)
                chart
        $scope.$watch 'data', updateDiagram, true

]