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

#Transfer of line to ZipCode
lineToZipCode = (line, numberOfZipCodes) ->
    splittedLine = line.split(",")
    if splittedLine.length != 2
        throw new Error('Upload expects another file format')
    #Skip first line
    if splittedLine[0] != 'PLZ'
        entry = new ZipCode()
        entry.zipCode = splittedLine[0]
        entry.federalState = splittedLine[1]
        entry.save()
        numberOfZipCodes++
    numberOfZipCodes

#Transfer of line to Organisation
lineToOrganisation = (line, feedback) ->
    if not feedback
        console.log "THIS SHOULD NOT HAPPEN: Supposed to parse line #{line} but got no feedback object!"
    splittedLine = line.split(";")
    #Skip first and last lines
    if splittedLine[0] != 'Bezeichnung des Rechtsträgers' and splittedLine[0] != ''
        organisation = new Organisation()
        organisation.name = splittedLine[0]
        organisation.street = splittedLine[1]
        organisation.zipCode = splittedLine[2]
        organisation.city_de = splittedLine[3]
        organisation.country_de = splittedLine[4]
        ZipCode.findOne({'zipCode': splittedLine[2]})
        .then (results) ->
            if results and organisation.country_de is 'Österreich'
                organisation.federalState = results.federalState
            else
                organisation.federalState = 'Unknown'
            organisation.save()
        .then (ok) ->
            feedback.entries++
            feedback.notAustria++ if organisation.country_de != 'Österreich'
            if organisation.federalState is 'Unknown' and organisation.country_de is 'Österreich'
                feedback.unknownFederalState++
                feedback.unknownFederalStateEntries.push organisation
            feedback
        .catch (err) ->
            feedback.errors+=1
            feedback.errorEntries.push {organisation: organisation, errorMessage: err.errmsg, errorCode: err.code}
            console.log "ERROR: Could not store organisation #{organisation.name}"
            feedback
    else
        feedback.ignoredEntries++;
        feedback

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
        Organisation.findOne({ 'name': transfer.organisation }, 'name federalState')
        .then (results) ->
            if results
                transfer.organisationReference = results._id
                transfer.federalState = results.federalState
                transfer.save()
            else
                console.log "WARNING: Could not find reference for #{transfer.organisation}!"
                Organisation.findOne name: "Unknown"
                .then (unknown) ->
                    if unknown
                        console.log "Setting org-reference for #{transfer.organisation} to 'Unknown' (#{unknown._id})"
                        transfer.federalState = 'Unknown'
                        transfer.organisationReference = unknown._id
                        unknownOrganisationNames = (org.organisation for org in feedback.unknownOrganisations)
                        feedback.unknownOrganisations.push {organisation: transfer.organisation} if transfer.organisation not in unknownOrganisationNames
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
            feedback.errorEntries.push {errorMessage: err.errmsg, errorCode: err.code}
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
            unknownOrganisations: []
            errors: 0
            errorEntries: []
        #qfs.read(file.path).then(
        fs.readFile file.path, (err,data) ->
            if err
                res.send 500, "Error #{err.message}"
            else
                input = iconv.decode data,'latin1'
                input.split("\n").reduce ((p,line) -> p.then((f) -> lineToTransfer line, f)), Q.fcall(->feedback)
                .then (ok) ->
                    Transfer.count()
                .then(
                    (transfersInDatabase) ->
                        feedback.savedInDatabase = transfersInDatabase
                        feedback.integrityCheck = true
                        res.status(200).send(feedback)
                )
                .catch (err) ->
                    res.send 500, "Error #{err.message}"
    #Function for the upload of organisation-address-data
    uploadOrganisation: (req, res) ->
        file = req.files.file;
        feedback =
            entries: 0
            ignoredEntries: 0
            unknownFederalState: 0,
            unknownFederalStateEntries: [],
            notAustria: 0,
            errors:0
            errorEntries: []

        fs.readFile file.path, (err,data) ->
            if err
                res.status(500).send("Error #{err.message}")
            else
                input =  iconv.decode data, 'utf8'
                input.split("\n").reduce ((p,line) -> p.then((f) -> lineToOrganisation line, f)), Q.fcall(->feedback)
                .then (ok) ->
                    Organisation.count()
                    .then(
                        (organisationsInDatabase) ->
                            feedback.savedInDatabase = organisationsInDatabase
                            feedback.integrityCheck = true
                            res.status(200).send(feedback)
                        )
                    .catch (err) ->
                        res.send 500, "Error #{err.message}"

    #Function for the upload of organisation-address-data
    uploadZipCode: (req, res) ->
        file = req.files.file;
        response =
            newZipCodes: 0
            integrityCheck: false
            savedInDatabase: 0

        fs.readFile file.path, (err,data) ->
            if err
                res.status(500).send("Error #{err.message}")
            else
                input =  iconv.decode data, 'utf8'
                response.newZipCodes = lineToZipCode(line,response.newZipCodes) for line in input.split('\n')
                ZipCode.count()
                .then(
                  (codesInDatabase) ->
                    response.savedInDatabase = codesInDatabase
                    response.integrityCheck = true
                    res.status(200).send(response)
                  (error) ->
                    res.send 500, "Error #{error}"
                )


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
            federalState = req.query.federalState if req.query.federalState
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
            if federalState?
                query.federalState = federalState
            group =
                _id:
                    organisation: "$organisation"
                    transferType: "$transferType"
                    media: "$media"
                amount:
                    $sum: "$amount"
            Transfer.aggregate($match: query)
            .group(group)
            .project(
                organisation: "$_id.organisation",
                transferType: "$_id.transferType",
                media: "$_id.media"
                _id: 0
                amount: 1
            )
            .exec()
            .then (result) ->
                if result.length > maxLength
                    res.status(413).send {
                        error: "You query returns more then the specified maximum of #{maxLength}"
                        length: result.length
                    }
                else
                    res.json result
            .catch (err) ->
                res.status(500).send error: "Could not load money flow: #{err}"
        catch error
            res.status(500).send error: "Could not load money flow: #{error}"

    topEntries: (req, res) ->
        federalState = req.query.federalState if req.query.federalState
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
            _id: 0
            total: 1
        if period.$gte? or period.$lte?
            query.period = period
        query.transferType =
            $in: paymentTypes.map (e)->
                parseInt(e)
        if federalState?
            query.federalState = federalState
        group =
            _id:
                organisation: if orgType is 'org' then '$organisation' else '$media',
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
        .limit(results)
        .project(project)
        .exec()
        allPromise = Transfer.mapReduce options
        allPromise.then (r) ->
        Q.all([topPromise, allPromise])
        .then (results) ->
            try
                result =
                    top: results[0]
                    all: results[1].reduce(
                        (sum, v)->
                            sum + v.value
                        0)
                res.send result
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
        console.log req.query.id
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