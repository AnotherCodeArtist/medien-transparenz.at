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
Organisation = mongoose.model 'Organisation'
ZipCode = mongoose.model 'Zipcode'

regex = /"?(.+?)"?;(\d{4})(\d);(\d{1,2});\d;"?(.+?)"?;(\d+(?:,\d{1,2})?).*/

#matches media to federalState (due to lack of grouping)
mediaToFederalState = (mediaResult, limit, federalState) ->
    #Show only media from organisations within the federalState
    if federalState.length
        mediaResult =  (media for media in mediaResult when media.organisationReference.federalState_en is federalState)

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
    uniqueMedia.splice(0,limit);

#function for populate
getPopulateInformation = (sourceForPopulate, path) ->
    #path: what to look for, select without id
    populatePromise = Organisation.populate(sourceForPopulate, {path: path, select: '-_id'})
    populatePromise

#Search for organisation entry in database
findOrganisationData = (organisation) ->
    #console.log "search for organisation with name " + organisation
    queryPromise = Organisation.findOne({ 'name': organisation }, 'name').exec()
    queryPromise.then(
        (result) ->
            #console.log "Organisation Data: " + result
            return
        (err) ->
            #console.log "Could not load organisation data from Database: #{err}"
            return
    )
    queryPromise

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
        Q.all(findFederalState)
        .then (results) ->
            try
                organisation.federalState_en = results.federalState
                organisation.save()
            catch error
                console.log error
        numberOfOrganisations++
    numberOfOrganisations

lineToTransfer = (line, feedback) ->
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
        transferReference = findOrganisationData transfer.organisation
        Q.all(transferReference)
        .then (results) ->
            try
                if results.name
                    transfer.organisationReference = results._id
                    #console.log transfer.organisationReference
                transfer.save()
            catch error
                console.log error
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
        #qfs.read(file.path).then(
        fs.readFile file.path, (err,data) ->
            if err
                res.send 500, "Error #{err.message}"
            else
                input = iconv.decode data,'latin1'
                feedback = lineToTransfer line, feedback for line in input.split('\n')
                res.send feedback
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
        allPromise = Transfer.mapReduce options
        allPromise.then (r) ->
        Q.all([topPromise, allPromise])
        .then (promiseResults) ->
            try
                populatedPromise = getPopulateInformation(promiseResults[0], 'organisationReference')
                .then (
                    (isPopulated) ->
                        try
                            if orgType is 'org'
                                if federalState.length
                                    #create new results based on the federalState selection
                                    promiseResults[0] = (transfer for transfer in promiseResults[0] when transfer.organisationReference.federalState_en is federalState)
                                    #console.log("Result with " +federalState+" has length of " + result.length)
                                    #console.log ("we have to cut the array to the limit of " + results)
                                topResult = promiseResults[0].splice(0,results);

                            else
                                topResult =  mediaToFederalState(promiseResults[0], results, federalState)
                            result =
                                top: topResult,
                                all: promiseResults[1].reduce(
                                    (sum, v)->
                                        sum + v.value
                                  0)
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