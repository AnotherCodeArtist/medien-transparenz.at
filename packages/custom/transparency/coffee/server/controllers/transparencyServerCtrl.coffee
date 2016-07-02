'use strict'

qfs = require 'q-io/fs'
fs = require 'fs'
config = require('meanio').loadConfig()
mongoose = require 'mongoose'
iconv = require 'iconv-lite'
_ = require 'lodash'
#mongooseWhen = require 'mongoose-when'
Q = require 'q'
#Promise = mongoose.Promise

#iconv.extendNodeEncodings()

Transfer = mongoose.model 'Transfer'
Event = mongoose.model 'Event'
Organisation = mongoose.model 'Organisation'
ZipCode = mongoose.model 'Zipcode'

regex = /"?(.+?)"?;(\d{4})(\d);(\d{1,2});\d;"?(.+?)"?;(\d+(?:,\d{1,2})?).*/

#returns value for "others" / replaces promise
getTotalAmountOfTransfers = (entries) ->
    amounts = (entry.total for entry in entries)
    totalAmount = amounts.reduce(((total, num) ->
        total + num), 0)
    totalAmount

#matches media to federalState (due to lack of grouping)
mediaToFederalState = (mediaResult) ->
    uniqueMedia= []
    #console.log("Entries in result " +mediaResult.length)
    for media in mediaResult
        mediaNames = (name.organisation for name in uniqueMedia)

        if media.organisation not in mediaNames
           uniqueMedia.push(media)
        else
           # media is already there, add sum to media
           #console.log (media.organisation + ' in media names')
           for uniqueEntry in uniqueMedia
               if uniqueEntry.organisation is media.organisation
                   #console.log(uniqueEntry.organisation +  'has already ' +uniqueEntry.total)
                   #console.log("The transfer adds "+ media.total)
                   uniqueEntry.total += media.total
                   #console.log("Entry has now " +uniqueEntry.total)
                   break
    #console.log ("Entries after uniqueness: " + uniqueMedia.length)
    uniqueMedia

#function for populate
getPopulateInformation = (sourceForPopulate, path) ->
    #path: what to look for, select without id
    populatePromise = Organisation.populate(sourceForPopulate, {path: path, select: '-_id'})
    populatePromise

#Search for organisation entry in database
findOrganisationData = (organisation) ->
    #console.log "search for organisation with name " + organisation
    Organisation.findOne({ 'name': organisation }, 'name').exec()


#Transfer of line to ZipCode
lineToZipCode = (line, numberOfZipCodes) ->
    splittedLine = line.split(",")
    #Skip first line
    if splittedLine[0] != 'PLZ'
        entry = new ZipCode()
        entry.zipCode = splittedLine[0]
        entry.federalState = splittedLine[1]
        entry.save()
        numberOfZipCodes++
    numberOfZipCodes

#Transfer of line to Organisation
lineToOrganisation = (line, numberOfOrganisations) ->
    splittedLine = line.split(";")
    #Skip first and last lines
    if splittedLine[0] != 'Bezeichnung des Rechtsträgers' and splittedLine[0] != ''
        organisation = new Organisation()
        organisation.name = splittedLine[0]
        organisation.street = splittedLine[1]
        organisation.zipCode = splittedLine[2]
        organisation.city_de = splittedLine[3]
        organisation.country_de = splittedLine[4]
        findFederalState = ZipCode.findOne({'zipCode': splittedLine[2]}).exec()
        .then (results) ->
            if results
                organisation.federalState_en = results.federalState
            else
                organisation.federalState_en = "Unknown"
            organisation.save()
        .then (ok) ->
            numberOfOrganisations++
            numberOfOrganisations
        .catch (err) ->
            console.log "ERROR: Could not store organisation #{JSON.stringify organisation}: #{err}"
            numberOfOrganisations

lineToTransfer = (line, feedback) ->
    if not feedback
        console.log "THIS SHOULD NOT HAPPEN: Supposed to parse line #{line} but got no feedback object!"
    m = line.match regex
    #console.log "Result: #{m} for line #{line}"
    if m
        transfer = new Transfer()
        transfer.organisation = m[1].replace '""','"'
        transfer.year = parseInt m[2]
        transfer.quarter = parseInt m[3]
        transfer.transferType = parseInt m[4]
        transfer.media = m[5].replace('""','"').replace(/http:\/\//i,'').replace('www.','').replace(/([\w\.-]+(?:\.at|\.com))/,(m)->m.toLowerCase())
        transfer.period = parseInt(m[2] + m[3])
        transfer.amount = parseFloat m[6].replace ',', '.'
        #Save reference
        Organisation.findOne({ 'name': transfer.organisation }, 'name')
        .then (results) ->
            if results
                transfer.organisationReference = results._id
                transfer.save()
            else
                console.log "WARNING: Could find reference for #{transfer.organisation}!!!!!!!"
                Organisation.findOne name: "Unknown"
                .then (unknown) ->
                    if unknown
                        console.log "Setting org-reference for #{transfer.organisation} to 'Unknown' (#{unknown._id})"
                        transfer.organisationReference = unknown._id
                        transfer.save()
                    else
                        feedback.errors+=1
                        throw new Error("'Unknown' as placeholder was not found in organisation collection")
        .then (ok) ->
            feedback.quarter = transfer.quarter
            feedback.year = transfer.year
            feedback.entries++
            feedback.paragraph2++ if transfer.transferType is 2
            feedback.paragraph4++ if transfer.transferType is 4
            feedback.paragraph31++ if transfer.transferType is 31
            feedback.sumParagraph2 += transfer.amount if transfer.transferType is 2
            feedback.sumParagraph4 += transfer.amount if transfer.transferType is 4
            feedback.sumParagraph31 += transfer.amount if transfer.transferType is 31
            feedback.sumTotal += transfer.amount
            feedback
        .catch (err) ->
            feedback.errors+=1
            console.log "Error while importing data: #{JSON.stringify err}"
            feedback
    else feedback



mapEvent = (event,req) ->
    event.name = req.body.name
    event.startDate = req.body.startDate
    event.numericStartDate = req.body.numericStartDate
    event.endDate = req.body.endDate
    if req.body.numericEndDate
        event.numericEndDate = req.body.numericEndDate
    event.tags = req.body.tags
    event.region = req.body.region
    event

module.exports = (Transparency) ->

    overview: (req, res) ->
        queryPromise = Transfer.aggregate({$match: {}})
        .group(
            _id:
                quarter: "$quarter"
                year: "$year"
                transferType: "$transferType"
            entries: {$sum: 1}
            total:
                $sum: "$amount")
        .project(quarter: "$_id.quarter", year: "$_id.year", transferType: "$_id.transferType", _id: 0, entries: 1, total: 1)
        #.sort('-year -quarter transferType')
        .group(
            _id:
                year: "$year"
            quarters:
                $addToSet: {quarter: "$quarter", transferType: "$transferType", entries: "$entries", total: "$total"}
            total:
                $sum: "$total")
        .project(year: "$_id.year", _id: 0, quarters: 1, total: 1)
        .sort("-year")
        .exec()
        queryPromise.then(
            (result) ->
                res.send result
            (err) ->
                res.status(500).send "Could not load overview from Database: #{err}"
        )

    years: (req, res) ->
        queryPromise = Transfer.aggregate($match: {})
        .group(_id:
            year: "$year")
        .project(year: "$_id.year", _id: 0)
        .sort("-year")
        .exec()
        queryPromise.then(
            (result) ->
                res.send years: result.map (e)->
                    e.year
            (err) ->
                res.status(500).send "Could not load overview from Database: #{err}"
        )

    upload: (req, res) ->
        file = req.files.file;
        feedback =
            quarter: 0
            year: 0
            entries: 0
            paragraph2: 0
            sumParagraph2: 0
            paragraph4: 0
            sumParagraph4: 0
            paragraph31: 0
            sumParagraph31: 0
            sumTotal: 0.0
            errors: 0
        #qfs.read(file.path).then(
        fs.readFile file.path, (err,data) ->
            if err
                res.send 500, "Error #{err.message}"
            else
                input = iconv.decode data,'latin1'
                input.split("\n").reduce ((p,line) -> p.then((f) -> lineToTransfer line, f)), Q.fcall(->feedback)
                .then (ok) ->
                    res.send feedback
                .catch (err) ->
                    res.send 500, "Error #{err.message}"
    #Function for the upload of organisation-address-data
    uploadOrganisation: (req, res) ->
        file = req.files.file;
        response =
            newOrganisationNumber: 0

        fs.readFile file.path, (err,data) ->
            if err
                res.status(500).send("Error #{err.message}")
            else
                input =  iconv.decode data, 'utf8'
                response.newOrganisationNumber = lineToOrganisation(line,response.newOrganisationNumber) for line in input.split('\n')
                res.status(200).send(response)

    #Function for the upload of organisation-address-data
    uploadZipCode: (req, res) ->
        file = req.files.file;
        response =
            newZipCodes: 0
        fs.readFile file.path, (err,data) ->
            if err
                res.status(500).send("Error #{err.message}")
            else
                input =  iconv.decode data, 'utf8'
                response.newZipCodes = lineToZipCode(line,response.newZipCodes) for line in input.split('\n')
                res.status(200).send(response)

    periods: (req, res) ->
        Transfer.aggregate(
            $match: {}
        )
        .group(
            _id:
                year: "$year", quarter: "$quarter", period: "$period"
        )
        .project(
            year: "$_id.year", quarter: "$_id.quarter", period: "$_id.period", _id: 0
        )
        .sort("-year -quarter")
        .exec()
        .then(
            (data) ->
                res.send data
            (err) -> res.status(500).send("Could not load periods (#{err})!")
        )


    flows: (req, res) ->
        try
            maxLength = parseInt req.query.maxLength or "750"
            federalState = req.query.federalState or ''
            period = {}
            period['$gte'] = parseInt(req.query.from) if req.query.from
            period['$lte'] = parseInt(req.query.to) if req.query.to
            paymentTypes = req.query.pType or []
            paymentTypes = [paymentTypes] if paymentTypes not instanceof Array
            orgType = req.query.orgType or 'org'
            name = req.query.name
            query = {}
            (query.transferType =
                $in: paymentTypes.map (e)->
                    parseInt(e)) if paymentTypes.length > 0
            query[if orgType is 'org' then 'organisation' else 'media'] = name if name
            if period.$gte? or period.$lte?
                query.period = period
            if req.query.filter
                filter = req.query.filter
                query.$or = [
                    {organisation: { $regex: ".*#{filter}.*", $options: "i"}}
                    {media: { $regex: ".*#{filter}.*", $options: "i"}}
                ]
            group =
                _id:
                    organisation: "$organisation"
                    organisationReference: "$organisationReference"
                    transferType: "$transferType"
                    media: "$media"
                amount:
                    $sum: "$amount"
            Transfer.aggregate($match: query)
            .group(group)
            .project(
                organisation: "$_id.organisation",
                organisationReference: "$_id.organisationReference",
                transferType: "$_id.transferType",
                media: "$_id.media"
                _id: 0
                amount: 1
            )
            .exec()
            .then (result) ->
                   populatedPromise = getPopulateInformation(result, 'organisationReference')
                   .then(
                     (isPopulated) ->
                         if federalState
                            #console.log "Federal State: " + transfer.organisationReference.federalState_en for transfer in result when transfer.organisationReference.federalState_en is federalState
                            #create new results based on the federalState selection
                            result = (transfer for transfer in result when transfer.organisationReference.federalState_en is federalState)
                            #console.log("Result with " +federalState+" has length of " + result.length)
                            #console.log(JSON.stringify(result))

                         if result.length > maxLength
                            res.status(413).send {
                             error: "You query returns more then the specified maximum of #{maxLength}"
                             length: result.length
                                }
                         else
                            res.json result
                   )

            .catch (err) ->
                res.status(500).send error: "Could not load money flow: #{err}"
        catch error
            res.status(500).send error: "Could not load money flow: #{error}"

    topEntries: (req, res) ->
        federalState = req.query.federalState or ''
        period = {}
        period['$gte'] = parseInt(req.query.from) if req.query.from
        period['$lte'] = parseInt(req.query.to) if req.query.to
        orgType = req.query.orgType or 'org'
        paymentTypes = req.query.pType or ['2']
        paymentTypes = [paymentTypes] if paymentTypes not instanceof Array
        results = parseInt(req.query.x or '10')
        query = {}
        project =
            organisation: '$_id.organisation'
            organisationReference: '$_id.organisationReference'
            _id: 0
            total: 1
        if period.$gte? or period.$lte?
            query.period = period
        query.transferType =
            $in: paymentTypes.map (e)->
                parseInt(e)
        group =
            _id:
                organisation: if orgType is 'org' then '$organisation' else '$media',
                organisationReference: '$organisationReference'
            total:
                $sum: '$amount'
        options = {}
        options.map = () ->
            emit this.year, this.amount
        options.reduce = (key, vals) ->
            Array.sum vals
        options.query = query
        #console.log "Query: "
        #console.log query
        #console.log "Group: "
        #console.log group
        #console.log "Project: "
        #console.log project
        topPromise = Transfer.aggregate($match: query)
        .group(group)
        .sort('-total')
        .project(project)
        .exec()
        Q.all([topPromise])
        .then (promiseResults) ->
            try
                populatedPromise = getPopulateInformation(promiseResults[0], 'organisationReference')
                .then (
                    (isPopulated) ->
                        try
                            populatedTransfers = promiseResults[0]
                            totalAmountOfTransfers = 0

                            if federalState.length
                                #create new results based on the federalState selection
                                populatedTransfers = (transfer for transfer in promiseResults[0] when transfer.organisationReference.federalState_en is federalState)
                                #console.log("Result with " +federalState+" has length of " + populatedTransfers.length)

                            if orgType is 'media'
                                populatedTransfers = mediaToFederalState populatedTransfers

                            totalAmountOfTransfers = getTotalAmountOfTransfers populatedTransfers
                            #console.log ("we have to cut the array to the limit of " + results)
                            topResult = populatedTransfers.splice(0,results);

                            result =
                                top: topResult
                                all: totalAmountOfTransfers

                            res.send result
                        catch error
                            console.log error
                            res.status(500).send("No Data was found!")
                )

            catch error
                console.log error
                res.status(500).send("No Data was found!")
        .catch (err) ->
            console.log "Error in Promise.when"
            console.log err
            res.status(500).send("Error #{err.message}")

    search: (req,res) ->
        name = req.query.name
        if not name
            res.status(400).send error: "'name' is required!"
            return
        types = if req.query.orgType then [req.query.orgType] else ['org','media']
        buildRegex = (name,value) ->
            q={}
            q[name]= { $regex: ".*#{value}.*", $options: "i"}
            q
        performQuery = (orgType) ->
            nameField = if orgType is 'org' then 'organisation' else 'media'
            $or = name.split(' ').reduce ((a,n)-> q={};a.push buildRegex(nameField,n);a) ,[]
            query = $or: $or
            group =
                _id:
                    name: "$#{nameField}"
                    type: orgType
                years:
                    $addToSet: "$year"
                total: $sum: "$amount"
                transferTypes: $addToSet: "$transferType"
            Transfer.aggregate($match: query)
            .group(group)
            .project(
                name: '$_id.name'
                _id: 0
                years: 1
                total: 1
                transferTypes: 1
            )
            .sort('name')
            .exec()
        all = Q.all types.map (t) ->
            performQuery t
        all.then (results) ->
            result = types.reduce ((r,t,index) -> r[t] = results[index];r),{}
            res.json result
        .catch (err) ->
            res.status(500).send error: "Could not perform search"

    list: (req,res) ->
        types = if req.query.orgType then [req.query.orgType] else ['org','media']
        page = parseInt req.query.page or "0"
        size = parseInt req.query.size or "50"
        performQuery = (orgType) ->
            nameField = if orgType is 'org' then 'organisation' else 'media'
            query = {}
            group =
                _id:
                    name: "$#{nameField}"
                    type: orgType
                years:
                    $addToSet: "$year"
                total: $sum: "$amount"
                transferTypes: $addToSet: "$transferType"
            Transfer.aggregate($match: query)
            .group(group)
            .project(
                name: '$_id.name'
                _id: 0
                years: 1
                total: 1
                transferTypes: 1
            )
            .sort('name').skip(page*size).limit(size)
            .exec()
        all = Q.all types.map (t) ->
            performQuery t
        all.then (results) ->
            result = types.reduce ((r,t,index) -> r[t] = results[index];r),{}
            res.json result
        .catch (err) ->
            res.status(500).send error: "Could not perform search #{err}"

    count: (req,res) ->
        type = req.query.orgType or 'org'
        performQuery = (orgType) ->
            nameField = if orgType is 'org' then 'organisation' else 'media'
            query = {}
            group =
                _id:
                    name: "$#{nameField}"
            Transfer.aggregate($match: query)
            .group(group)
            .exec()
        performQuery(type)
        .then (result) ->
            res.json result.length
        .catch (err) ->
            res.status(500).send error: "Could not determine number of items #{err}"

    getEvents: (req,res) ->

        handleEventResponse = (err, data) ->
            if err
                res.status(500).send error: "Could not get events #{err}"
            else if !data or data.length is 0
                res.status(404).send()
            else
                res.json data

        #todo: insert parameter checking
        if req.query.region
            Event.find {region: req.query.region}, handleEventResponse
        else if req.query.id
            Event.findById req.query.id, handleEventResponse
        else
            Event.find {}, handleEventResponse

    createEvent: (req,res) ->
        #todo: insert parameter checking
        event = new Event()
        event = mapEvent event, req
        event.save (err) ->
            if err
                res.status(500).send error: "Could not create event #{err}"
            else
                res.json event

    updateEvent: (req, res) ->

        #todo: insert parameter checking
        Event.findById req.body._id, (err, data) ->
            if err
                res.status(500).send error: "Could not update event #{err}"
            if !data or data.length is 0
                res.status(500).send error: "Could not find event #{req.body._id}"
            else
                event = mapEvent data, req
                event.save (err) ->
                    if err
                        res.status(500).send error: "Could not create event #{err}"
                    else
                        res.json event

    deleteEvent: (req, res) ->
        #todo: insert parameter checking
        Event.findById {_id: req.query.id}, (err, data) ->
            if err
                res.status(500).send error: "Could not find event #{err}"
            data.remove (removeErr) ->
                if removeErr
                    res.status(500).send error: "Could not delete event #{removeErr}"
            res.json data

    getEventTags: (req, res) ->
        Event.find {}, (err, events) ->
            if err
                res.status(500).send error "Could not load events #{err}"
            result = []
            for event in events
                if event.tags
                    Array.prototype.push.apply result, event.tags

            res.json Array.from(new Set(result))

    federalstates: (req, res) ->
        result =
            'AT-1': 0,
            'AT-2': 0,
            'AT-3': 0,
            'AT-4': 0,
            'AT-5': 0,
            'AT-6': 0,
            'AT-7': 0,
            'AT-8': 0,
            'AT-9': 0,
        period = {}
        period['$gte'] = parseInt(req.query.from) if req.query.from
        period['$lte'] = parseInt(req.query.to) if req.query.to
        orgType = req.query.orgType or 'org'
        paymentTypes = req.query.pType or ['2']
        paymentTypes = [paymentTypes] if paymentTypes not instanceof Array
        query = {}
        project =
            organisation: '$_id.organisation'
            organisationReference: '$_id.organisationReference'
            _id: 0
            total: 1
        if period.$gte? or period.$lte?
            query.period = period
        query.transferType =
            $in: paymentTypes.map (e)->
                parseInt(e)
        group =
            _id:
                organisation: if orgType is 'org' then '$organisation' else '$media',
                organisationReference: '$organisationReference'
            total:
                $sum: '$amount'
        #console.log "Query: "
        #console.log query
        #console.log "Group: "
        #console.log group
        #console.log "Project: "
        #console.log project
        totalPromise = Transfer.aggregate($match: query)
        .group(group)
        .sort('-total')
        .project(project)
        .exec()
        Q.all([totalPromise])
        .then (promiseResults) ->
            try
                populatedPromise = getPopulateInformation(promiseResults[0], 'organisationReference')
                .then (
                    (isPopulated) ->
                        try
                            populatedTransfers = promiseResults[0]

                            if orgType is 'media'
                                populatedTransfers = mediaToFederalState populatedTransfers

                            for transfer in populatedTransfers
                                #TODO ! WARNING ! needs to be refined after merging the ISO-branch (example see comment)
                                # after merging:
                                # result[transfer.organisationReference.federalState]+=transfer.total

                                switch transfer.organisationReference.federalState_en
                                    when 'Burgenland' then result['AT-1']+= transfer.total
                                    when 'Carinthia' then result['AT-2']+= transfer.total
                                    when 'Lower Austria' then result['AT-3']+= transfer.total
                                    when 'Salzburg' then result['AT-5']+= transfer.total
                                    when 'Styria' then result['AT-6']+= transfer.total
                                    when 'Tyrol' then result['AT-7']+= transfer.total
                                    when 'Upper Austria' then result['AT-4']+= transfer.total
                                    when 'Vienna' then result['AT-9']+= transfer.total
                                    when 'Vorarlberg' then result['AT-8']+= transfer.total
                            res.send(JSON.stringify(result))
                        catch error
                            console.log error
                            res.status(500).send("Error while calculate sum for federal states!")
                )
            catch error
                console.log error
                res.status(500).send("Error while calculate sum for federal states!")
        .catch (err) ->
            console.log "Error in Promise.when"
            console.log err
            res.status(500).send("Error #{err.message}")
