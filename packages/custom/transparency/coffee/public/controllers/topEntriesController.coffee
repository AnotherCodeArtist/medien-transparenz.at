'use strict'
app = angular.module 'mean.transparency'

app.controller 'TopEntriesCtrl', ['$scope', 'TPAService', '$q', '$state','gettextCatalog','$rootScope', 'DTOptionsBuilder', 'DTColumnDefBuilder', 'DTColumnBuilder','$uibModal','$timeout'
($scope, TPAService, $q, $state, gettextCatalog, $rootScope, DTOptionsBuilder, DTColumnDefBuilder,DTColumnBuilder, $uibModal, $timeout) ->
    tc = this
    dataPromise = $q.defer()
    $scope.td = {}
    $scope.td.dtInstance = {}
    params = {}
    stateName = "topState"
    fieldsToStore = ['slider','periods','orgTypes','typesText','rank','orgType', 'selectedFederalState', 'includeGroupings', 'selectedOrgCategories']
    $scope.periods = []
    $scope.slider =
        from: 0
        to: 0
        options:
            step:5
            floor:0
            onEnd: -> change(1,2)
            translate: (value) -> $scope.periods.map((p) -> "#{p.year}/Q#{p.quarter}")[value/5]
    $scope.showSettings = false
    $scope.ranks = [3, 5, 10, 15, 20]
    $scope.rank = 10
    $scope.pieData = []
    window.scrollTo 0, 0

    $scope.getFrom = ->
        if $scope.periods && $scope.periods.length > 0
            "Q#{$scope.periods[$scope.slider.from/5].quarter}/#{$scope.periods[$scope.slider.from/5].year}"
        else ""
    $scope.getTo = ->
        if $scope.periods && $scope.periods.length > 0
            "Q#{$scope.periods[$scope.slider.to/5].quarter}/#{$scope.periods[$scope.slider.to/5].year}"
        else ""

    $scope.selectedTypes = -> $scope.typesText.filter((t) -> t.checked).map (t) -> t.type
    $scope.selectedOrgType = -> if $scope.orgType is "org" then "Payers" else "Beneficiaries"
    # register watches to update chart when changes occur
    registerWatches = ->
        $scope.$watch('typesText', change, true)
        $scope.$watch('orgType', change, true)
        $scope.$watch('rank', change, true)
        $scope.$watch('selectedFederalState', change, true)
        $scope.$watch('includeGroupings', change, true)
        $scope.$watch('selectedOrgCategories', change, true)


    #construct the query parameters
    parameters = ->
        params = {}
        params.from = $scope.periods[$scope.slider.from/5].period
        params.to =$scope.periods[$scope.slider.to/5].period
        params.federalState = $scope.selectedFederalState.iso if $scope.selectedFederalState
        params.groupings = $scope.includeGroupings if $scope.includeGroupings
        types = (v.type for v in $scope.typesText when v.checked)
        (params.pType = types) if types.length > 0
        params.x = $scope.rank
        params.orgType = $scope.orgType
        params.orgCategories = $scope.selectedOrgCategories
        params

    $scope.total = -> if $scope.top then $scope.top.all.toLocaleString() else "0"
    $scope.IntroOptions = null;
    $scope.selectedOrgCategories = [];

    $scope.goto = (l)-> $anchorScroll(l)

    $scope.showSettingsDialog = ->
        parent = $scope
        $uibModal.open(
            templateUrl: 'transparency/views/topSettingsDialog.html'
            scope: $scope
            size: 'lg'
            controller: ($scope, $uibModalInstance) ->
                $scope.close = ->
                    $scope.$parent.orgType = $scope.orgType
                    $scope.$parent.selectedOrgCategories = $scope.selectedOrgCategories
                    $uibModalInstance.close()
                current = $scope.slider.options.draggableRangeOnly
                $timeout (-> $scope.slider.options.draggableRangeOnly = !current), 100
                $timeout (-> $scope.slider.options.draggableRangeOnly = current), 120
        )

    buildPieModel = ->
        $scope.pieData = []
        $scope.pieData.push {key: entry.organisation, y: entry.total, isGrouping: entry.isGrouping} for entry in $scope.top.top
        topSum = $scope.top.top.reduce(
            (sum, entry) ->
                sum + entry.total
            0
        )
        $scope.pieData.push {key: gettextCatalog.getString("Others"), y: $scope.top.all - topSum}

    $scope.toolTipContentFunction = (e) ->
        link = if e.index < $scope.rank then '<br/><i class="fa fa-line-chart" aria-hidden="true"></i> '+gettextCatalog.getString("Click for Details") else ""
        numberOptions = {style:'currency',currency:'EUR'}
        """<div class='chartToolTip'>
                <h3>#{e.data.key}</h3>
                <p>#{e.data.y.toLocaleString(gettextCatalog.getCurrentLanguage(),numberOptions)} (#{(e.data.y/$scope.top.all *100).toFixed(2)}%)#{link}</p>
           </div>"""
    #fetch data from server and update the chart
    update = ->
        TPAService.top(parameters())
        .then((res) ->
            init = true
            $scope.top = res.data
            dataPromise.resolve()
            buildPieModel()
        )
    change = (oldValue, newValue) ->
        if (oldValue isnt newValue)
            dataPromise = $q.defer()
            $scope.td.dtInstance.reloadData()
            update()



    # Method for setting the intro-options (e.g. after translations)
    setIntroOptions = ->
        $scope.IntroOptions =
            steps: [
                {
                    element: document.querySelector('#topSettings')
                    intro: gettextCatalog.getString 'It is possible to customize the pie chart. To do so, use the settings.'
                }
                {
                    element: document.querySelector('#topSlider')
                    intro: gettextCatalog.getString 'Move the sliders to define a range.'
                }, {
                    element: document.querySelector('#fixSliderRange')
                    intro: gettextCatalog.getString 'Fix slider range. With that it is possible to keep the range constant.'
                }, {
                    element: document.querySelector('#grouping')
                    intro: gettextCatalog.getString 'With groupings enabled single transfers will be taken together (e.g. to show umbrella organisations)'
                },
                {
                    element: document.querySelector('#orgTypesSelection')
                    intro: gettextCatalog.getString 'It is possible to narrow down the results to specific organisation types'
                },
                {
                    element: document.querySelector('#spenderRecipient')
                    intro: gettextCatalog.getString 'Display top spender or top recipient'
                },
                {
                    element: document.querySelector('#paymentTypes')
                    intro: gettextCatalog.getString 'Transfers are divided in different payment types. Select the types to display.'
                },
                {
                    element: document.querySelector('#fedStateSelection')
                    intro: gettextCatalog.getString 'It is possible to show the chart for a specific federal state.'
                },
                {
                    element: document.querySelector('#rank')
                    intro: gettextCatalog.getString 'Select the numbers of elements in the pie chart'
                }

            ]
            showStepNumbers: false
            exitOnOverlayClick: true
            exitOnEsc: true
            nextLabel: gettextCatalog.getString 'Next info'
            prevLabel: gettextCatalog.getString 'Previous info'
            skipLabel: gettextCatalog.getString 'Skip info'
            doneLabel: gettextCatalog.getString 'End tour'

    initState = ->

        $scope.orgTypes = [
            {name: gettextCatalog.getString('Spender'), value: 'org'},
            {name: gettextCatalog.getString('Recipient'), value: 'media'}
        ]
        $scope.orgCategories = []
        orgTypePromise = TPAService.organisationTypes()
        .then (res) ->
            for orgTypeObject in res.data
                $scope.orgCategories.push(name: gettextCatalog.getString(orgTypeObject.type), value: orgTypeObject.type)
        setIntroOptions()
        #Federal states selection
        $scope.federalStates  =  (name: gettextCatalog.getString(state.value), value: state.value, iso: state.iso for state in TPAService.staticData 'federal')
        #remove Austria
        if $scope.federalStates.length is 10
            $scope.federalStates.pop()
        savedState = sessionStorage.getItem 'topState'
        if savedState
            TPAService.restoreState stateName, fieldsToStore, $scope
            orgTypePromise.then( => update())
            registerWatches()
        else
            pY = TPAService.years()
            pY.then (res) ->
                $scope.years = (year: year, checked: false for year in res.data.years)
                $scope.years[0].checked = true;
            pP = TPAService.periods()
            pP.then (res) ->
                $scope.periods = res.data.reverse()
                $scope.slider.options.ceil = ($scope.periods.length - 1)*5
                $scope.slider.from = $scope.slider.options.ceil
                $scope.slider.to = $scope.slider.options.ceil
            types = [2, 4, 31]
            $scope.typesText = (type: type, text: gettextCatalog.getString( TPAService.decodeType(type) ), checked: false for type in types)
            $scope.typesText[0].checked = true
            #Variables for the selection of federalState
            $scope.selectedFederalState = null
            $scope.orgType = $scope.orgTypes[0].value
            $scope.includeGroupings = false
            $q.all([pY, pP, orgTypePromise]).then (res) ->
                $scope.selectedOrgCategories.push(orgTypeObject.value) for orgTypeObject in $scope.orgCategories
                update()
                registerWatches()

    translate = ->
        $scope.orgTypes[0].name = gettextCatalog.getString('Spender')
        $scope.orgTypes[1].name = gettextCatalog.getString('Recipient')
        $scope.typesText.forEach (t) -> t.text = gettextCatalog.getString TPAService.decodeType t.type
        $scope.federalStates.forEach (state) -> state.name = gettextCatalog.getString state.value
        $scope.orgCategories.forEach (cat) -> cat.name = gettextCatalog.getString cat.value
        setIntroOptions()

    $scope.$on 'gettextLanguageChanged', translate

    initState()

    $scope.td.dtOptions = DTOptionsBuilder.fromFnPromise( ->
        defer = $q.defer()
        dataPromise.promise.then (result) ->
            defer.resolve($scope.top.top);
        defer.promise
    )
    .withPaginationType('full_numbers')
    .withButtons(['copy','csv','excel'])
    .withBootstrap()
    angular.extend $scope.td.dtOptions,
        language:
            paginate:
                previous: gettextCatalog.getString('previous')
                next: gettextCatalog.getString('next')
                first: gettextCatalog.getString('first')
                last: gettextCatalog.getString('last')
            search: gettextCatalog.getString('search')
            info: gettextCatalog.getString('Showing page _PAGE_ of _PAGES_')
            lengthMenu: gettextCatalog.getString "Display _MENU_ records"

    $scope.td.dtColumns = [
        DTColumnBuilder.newColumn('organisation').withTitle('Organisation'),
        DTColumnBuilder.newColumn('total').withTitle('Total')
        .renderWith((total,type) ->
            if type is 'display'
                total.toLocaleString($rootScope.language,{currency: "EUR", maximumFractionDigits:2,minimumFractionDigits:2})
            else
                total)
        .withClass('text-right')
    ];

    $scope.x = (d) ->
        d.key
    $scope.y = (d) ->
        d.y

    #prevents clicks on "Others" to trigger a navigation        
    $scope.preventClickForOthers = (d) -> d.data.key in ["Others","Andere"]

    $rootScope.$on '$stateChangeStart', (event,toState) ->
        if toState.name isnt "top"
            TPAService.saveState stateName,fieldsToStore, $scope

    $scope.selectedFederalStateName =  ->
        if $scope.selectedFederalState
          $scope.federalStates.filter( (v)->v.iso==$scope.selectedFederalState.iso)[0].name
        else gettextCatalog.getString('Austria')

    #navigate to some other page
    $scope.go = (d) ->
        window.scrollTo 0, 0
        if d.data.isGrouping
            groupName = d.data.key.slice(4) # removing the group prefix "(G) "
        $state.go 'showflow',
            {
                name: d.data.key if not d.data.isGrouping
                orgType: $scope.orgType
                mediaGrp: "S:#{groupName}" if $scope.orgType is 'media' and d.data.isGrouping
                orgGrp: "S:#{groupName}" if $scope.orgType is 'org' and d.data.isGrouping
                from: $scope.periods[$scope.slider.from/5].period
                to: $scope.periods[$scope.slider.to/5].period
                fedState: $scope.selectedFederalState.iso if $scope.selectedFederalState
                pTypes: $scope.typesText.filter((t) -> t.checked).map (t) -> t.type
            },
            location: true
            inherit: false
            reload: true
]