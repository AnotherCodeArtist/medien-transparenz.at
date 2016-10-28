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
sorty = require 'sorty'

#iconv.extendNodeEncodings()

Transfer = mongoose.model 'Transfer'
Event = mongoose.model 'Event'
Organisation = mongoose.model 'Organisation'
ZipCode = mongoose.model 'Zipcode'
Grouping = mongoose.model 'Grouping'

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

# determines org type by name
determineOrganisationType = (organisationName) ->
    #public: state (Land), city (Stadt), municipality (Gemeinde)
    returnValue = 'undetermined'
    regexCompany = /(.* G?.m?.b?.H?.?$)|.* Ges?.*m?.b?.H?.|.*G?(es)?mbH|.*Gesellschaft?.*|.*AG$|.*OG$|.*KG$|(.* d.o.o?.)|.*s.r.o?.$|.*Sp.? z?.*|.*spol.r.s.o.|.*Sp.z.o.o..*|.* S.R.L.$|.* in Liq.*|.*ges.m.b.H.?.*|.*unternehmung|.*Limited.*|.*AD$|.*S.P.A.*|.*S.P.R.L.|.*Iberica SL/i
    regexIncorporatedCompany = /.* AG.*/
    regexAssociation = /.*(Verband).*|.*(Verein).*/i
    regexFoundation = /.*(Stiftung).*|.*(Holding)/i
    regexCity = /^Stadt .+/i
    regexMunicipality = /^(?:Markt)?gemeinde?.*|Stadtgemeinde .*|.*Sanitäts.*/i
    regexState = /^Land .+/ #Stadt Wien -- provincial
    regexMinistry = /^(?:Bundesministerium|Bundeskanzleramt)/
    regexAgency = /.*(Bundesamt|Patentamt|Parlamentsdirektion|Präsidentschaftskanzlei|Verfassungsgerichtshof|Volksanwaltschaft|.*Agency.*|Arbeitsmarktservice)/i #national - public agency
    regexFund = /.*Fonds?.*/i
    regexChamber = /.*?Kammer?.*/i
    regexPolicyRelevant = /^(Alternativregion).*|.*BIFIE|.*FMA|.*Sprengel?.*|^Kleinregion .*|Arbeitsmarktservice|Verwaltungsgerichtshof/i
    regexEducation = /.*(Alumni).*|.*(Universit).*|.*(Hochsch).*|.*Mittelschul.*|.*Schul.*|.*Päda.*/i

    if organisationName.match regexCompany
        returnValue = 'company'
    else if organisationName.match regexIncorporatedCompany
        returnValue = 'company'
    else if organisationName.match regexAssociation
        returnValue = 'association'
    else if organisationName.match regexChamber
        returnValue = 'chamber'
    else if organisationName.match regexEducation
        returnValue = 'education'
    else if organisationName.match regexFoundation
        returnValue = 'foundation'
    else if organisationName.match regexMunicipality
        returnValue = 'municipality'
    else if organisationName.match regexFund
        returnValue = 'fund'
    else if organisationName.match regexPolicyRelevant
        returnValue = 'policy-relevant'
    else if organisationName.match regexMinistry
        returnValue = 'ministry'
    else if organisationName.match regexCity
        returnValue = 'city'
    else if organisationName.match regexState
        returnValue = 'state'
    else if organisationName.match regexAgency
        returnValue = 'agency'

    console.log "Undetermined organisation type for: " + organisationName if returnValue is 'undetermined'
    returnValue
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
        # Setting the org type
        organisation.type = determineOrganisationType splittedLine[0]
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
            # Feedback for org type
            switch organisation.type
                when 'company' then feedback.organisationTypeCompany++
                when 'association' then feedback.organisationTypeAssociation++
                when 'chamber' then feedback.organisationTypeChamber++
                when 'education' then feedback.organisationTypeEducation++
                when 'foundation' then feedback.organisationTypeFoundation++
                when 'municipality' then feedback.organisationTypeMunicipality++
                when 'fund' then feedback.organisationTypeFund++
                when 'undetermined' then feedback.undeterminedOrganisationType++
                when 'policy-relevant' then feedback.organisationTypePolicyRelevant++
                when 'ministry' then feedback.organisationTypeMinistry++
                when 'city' then feedback.organisationTypeCity++
                when 'state' then feedback.organisationTypeState++
                when 'agency' then feedback.organisationTypeAgency++

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
    event.predictable = req.body.predictable
    if req.body.numericEndDate
        event.numericEndDate = req.body.numericEndDate
    event.tags = req.body.tags
    event.region = req.body.region
    event
handleGroupings = (groupings, transfers, limit) ->
    console.log ("found " + groupings.length + " gropings");
    console.log ("found " + transfers.length + " transfers");
    transfersWithGrouping = transfers
    for grouping in groupings
        groupingTransfersAmount = (transfer.total for transfer in transfersWithGrouping when transfer.organisation in grouping.members)
        groupingTransfersNames = (transfer.organisation  for transfer in transfersWithGrouping when transfer.organisation in grouping.members)
        groupingTotalAmount = groupingTransfersAmount.reduce (total, sum) -> total + sum
        #console.log("Grouping " + grouping.name + " with the member(s):"
        #JSON.stringify(grouping.members)+ " has the sum of " + groupingTotalAmount+ "("+ groupingTransfersAmount.length+" transfer(s))")
        #remove ALL transfers (filter) from results
        transfersWithGrouping = transfersWithGrouping.filter((transfer) ->
            transfer.organisation not in groupingTransfersNames
        )

        transfersWithGrouping.push({total: groupingTotalAmount, organisation: "(G) " + grouping.name, isGrouping: true})
        #console.log( "Group entry added: " + JSON.stringify(transfersWithGrouping[transfersWithGrouping.length-1]))
    #Sort array of transfers by total amount
    sorty([{name: 'total',  dir: 'desc', type: 'number'}], transfersWithGrouping)
    transfersWithGrouping.splice(0,limit)

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
        .sort("year")
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
            undeterminedOrganisationType: 0,
            organisationTypeCompany: 0,
            organisationTypeAssociation: 0,
            organisationTypeFoundation: 0,
            organisationTypeMunicipality: 0,
            organisationTypeState: 0,
            organisationTypeCity: 0,
            organisationTypeMinistry: 0,
            organisationTypeAgency: 0,
            organisationTypeFund: 0,
            organisationTypeChamber: 0,
            organisationTypePolicyRelevant: 0,
            organisationTypeEducation: 0,
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

    filteredflows: (req, res) ->
        getOtherMedia = (organisations, media, period, paymentTypes, federalState) ->
            result = []
            if (organisations and organisations.length > 0) and (media and media.length > 0)
                qry = {}
                (qry.transferType = $in: paymentTypes.map (e)->
                    parseInt(e)) if paymentTypes.length > 0
                (qry.organisation = $in: organisations) if organisations.length > 0
                (qry.media = $nin: media) if media.length > 0
                if period.$gte? or period.$lte?
                    qry.period = period

                grp =
                    _id:
                        organisation: "$organisation"
                        organisationReference: "$organisationReference"
                        transferType: "$transferType"
                    amount:
                        $sum: "$amount"

                Transfer.aggregate($match: qry)
                .group grp
                .exec()
                .then (rslt) ->
                    for data in rslt
                        result.push {
                            amount: data.amount,
                            organisation: data._id.organisation,
                            transferType: data._id.transferType,
                            media: "Other media"
                        }
                    result
            else
                new Promise (resolve, reject) ->
                    resolve result
        getOtherOrganisations = (organisations, media, period, paymentTypes, federalState) ->
            result = []
            if (media and media.length > 0) and (organisations and organisations.length > 0)
                qry = {}
                (qry.transferType = $in: paymentTypes.map (e)->
                    parseInt(e)) if paymentTypes.length > 0
                (qry.organisation = $nin: organisations) if organisations.length > 0
                (qry.media = $in: media) if media.length > 0
                if period.$gte? or period.$lte?
                    qry.period = period

                grp =
                    _id:
                        media: "$media"
                        transferType: "$transferType"
                    amount:
                        $sum: "$amount"

                Transfer.aggregate($match: qry)
                .group grp
                .exec()
                .then (rslt) ->
                    for data in rslt
                        result.push {
                            amount: data.amount,
                            media: data._id.media,
                            transferType: data._id.transferType,
                            organisation: "Other organisations"
                        }
                    result
            else
                new Promise (resolve, reject) ->
                    resolve result

        try
            maxLength = parseInt req.query.maxLength or "750"
            federalState = req.query.federalState or ''
            period = {}
            period['$gte'] = parseInt(req.query.from) if req.query.from
            period['$lte'] = parseInt(req.query.to) if req.query.to
            paymentTypes = req.query.pType or []
            paymentTypes = [paymentTypes] if paymentTypes not instanceof Array
            query = {}
            (query.transferType =
                $in: paymentTypes.map (e)->
                    parseInt(e)) if paymentTypes.length > 0
            organisations = req.query.organisations or []
            organisations = [organisations] if organisations not instanceof Array
            media = req.query.media or []
            media = [media] if media not instanceof Array
            (query.organisation = $in: organisations) if organisations.length > 0
            (query.media = $in: media) if media.length > 0
            if period.$gte? or period.$lte?
                query.period = period

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
                            result = (transfer for transfer in result when transfer.organisationReference.federalState_en is federalState)
                        getOtherMedia(organisations, media, period, paymentTypes, "").then (otherMedia) ->
                            result = result.concat otherMedia
                            getOtherOrganisations(organisations, media, period, paymentTypes, "").then (otherOrganisations) ->
                                result = result.concat otherOrganisations
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

    flowdetail: (req, res) ->
        try
            paymentTypes = req.query.pType or ['2']
            paymentTypes = [paymentTypes] if paymentTypes not instanceof Array
            source = req.query.source
            target = req.query.target
            query = {}
            query.organisation = source;
            query.media = target;


            (query.transferType =
                $in: paymentTypes.map (e)->
                    parseInt(e)) if paymentTypes.length > 0

            Transfer.find query, {}, {sort: {year: 1, quarter: 1}}, (err, transfers) ->
                result = {
                    data:
                         {
                             key: "Zahlungen"
                             values: []
                         }
                    tickvalues: []
                }

                i = 0

                tmpObj = {
                }

                #find all years
                Transfer.distinct 'year', (error, data) ->
                    if !error
                        years = data
                        years.sort()

                        tmpResult = {}
                        tickvalues = []
                        for year in years
                            for quarter in [0...4]
                                tmpObj[year + (quarter/4)] = 0
                                tickvalues.push (year + (quarter/4))

                        tickvalues.sort()

                        for transfer in transfers
                            tmpObj[""+ (transfer.year + (transfer.quarter-1)/4)] += transfer.amount

                        result.tickvalues = tickvalues

                        for tickvalue in tickvalues
                            result.data.values.push [tickvalue, tmpObj[tickvalue]]

                        res.json result
                    else
                        res.status 500
                        .send "Could not load years from database! #{error}"

        catch error
            res.status(500).send error: "Could not load money flow: #{error}"

    annualcomparison: (req, res) ->
        try
            source = req.query.source
            target = req.query.target

            query = {}
            query.organisation = source;
            query.media = target;

            years = []

            #find all years
            Transfer.distinct 'year', (error, data) ->
                if !error
                    years = data
                    years.sort()

                    tmpResult = {}
                    for year in years
                        tmpResult[""+year] = {
                            quarters: {
                                '1': 0
                                '2': 0
                                '3': 0
                                '4': 0
                            }
                        }
                else
                    res.status 500
                    .send "Could not load years from database! #{error}"


                Transfer.find query, {}, {sort: {year: 1, quarter: 1}, transferType: 1}, (err, transfers) ->
                    for transfer in transfers
                        tmpResult[""+transfer.year].quarters[""+transfer.quarter] += transfer.amount
                    result = []
                    for year, quarters of tmpResult
                        quarterArr = []
                        for quarter, amount of quarters.quarters
                            quarterArr.push {
                                x: (Number(quarter)-1)/4
                                y: amount
                            }
                        result.push {
                            key: year
                            color: '#'+(Math.random()*0xFFFFFF<<0).toString(16)
                            values: quarterArr
                        }
                    res.json result
        catch error
            res.status(500).send error: "Could not load money flow: #{error}"
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
        promiseToFullfill = []
        federalState = req.query.federalState if req.query.federalState
        includeGroupings = req.query.groupings if req.query.groupings
        period = {}
        period['$gte'] = parseInt(req.query.from) if req.query.from
        period['$lte'] = parseInt(req.query.to) if req.query.to
        orgType = req.query.orgType or 'org'
        paymentTypes = req.query.pType or ['2']
        paymentTypes = [paymentTypes] if paymentTypes not instanceof Array
        limitOfResults = parseInt(req.query.x or '10')
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
        if not includeGroupings
            topPromise = Transfer.aggregate($match: query)
            .group(group)
            .sort('-total')
            .limit(limitOfResults)
            .project(project)
            .exec()
        else
            topPromise = Transfer.aggregate($match: query)
            .group(group)
            .sort('-total')
            .project(project)
            .exec()
        promiseToFullfill.push(topPromise)


        allPromise = Transfer.mapReduce options
        promiseToFullfill.push allPromise
        if includeGroupings
            groupingQuery = {}
            groupingQuery.isActive = true
            groupingQuery.type = orgType
            groupingQuery.region = if federalState then federalState else 'AT'

            groupingsPromise = Grouping.find(groupingQuery)
            .select('name owner members -_id')
            .exec()
            promiseToFullfill.push(groupingsPromise)

        allPromise.then (r) ->
        Q.all(promiseToFullfill)
        .then (results) ->
            try
                result =
                    top: results[0]
                    all: results[1].reduce(
                        (sum, v)->
                            sum + v.value
                        0)
                    groupings: results[2] if results[2]

                if result.groupings?
                    result.top = handleGroupings(result.groupings, result.top, limitOfResults)

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
        federalState = req.query.federalState if req.query.federalState
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
            group =
                _id:
                    name: "$#{nameField}"
                    type: orgType
                years:
                    $addToSet: "$year"
                total: $sum: "$amount"
                transferTypes: $addToSet: "$transferType"
            project =
                name: '$_id.name'
                _id: 0
                years: 1
                total: 1
                transferTypes: 1

            $or = name.split(' ').reduce ((a,n)-> q={};a.push buildRegex(nameField,n);a) ,[]
            if not federalState
                    query = $or: $or
                else
                    query = $and: $or
                    query.$and.push {"federalState": federalState}
            Transfer.aggregate($match: query)
            .group(group)
            .project(project)
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
        federalState = req.query.federalState
        performQuery = (orgType) ->
            nameField = if orgType is 'org' then 'organisation' else 'media'
            query = {}
            if federalState?
                query.federalState = federalState
            project ={}
            project =
                name: '$_id.name'
                _id: 0
                years: 1
                total: 1
                transferTypes: 1
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
            .project(project)
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
        federalState = req.query.federalState if req.query.federalState
        performQuery = (orgType) ->
            nameField = if orgType is 'org' then 'organisation' else 'media'
            query = {}
            group =
                _id:
                    name: "$#{nameField}"
            if federalState
                query.federalState = federalState
                group._id.federalState = federalState
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
                                result[transfer.organisationReference.federalState]+=transfer.total
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


    #Grouping
    getPossibleGroupMembers: (req, res) ->
        type = req.query.orgType or 'org'
        nameField = if type is 'org' then 'organisation' else 'media'
        query = {}
        project =
            name: '$_id.name'
            _id: 0
        group =
            _id:
                name: "$#{nameField}"
        if type is 'org'
            group._id.federalState = '$federalState'
            project.federalState = '$_id.federalState'

        #console.log 'Query:'
        #console.log query
        #console.log 'Group'
        #console.log group
        #console.log 'Project'
        #console.log project
        Transfer.aggregate($match: query)
        .group(group)
        .project(project)
        .sort('name')
        .exec()
        .then (result) ->
            res.status(200).send result
        .catch (error) ->
            console.log "Error query possible group members: #{error}"
            res.status(500).send error: "Could not get group members #{error}"

    createGrouping: (req, res) ->
        grouping  = new Grouping()
        grouping.name = req.body.params.name
        grouping.type = req.body.params.type
        grouping.region = req.body.params.region
        grouping.members = req.body.params.members
        grouping.isActive = req.body.params.isActive
        if  req.body.params.owner?
            grouping.owner = req.body.params.owner
        grouping.save (err) ->
            if err
                res.status(500).send error: "Could not create grouping #{err}"
            else
                res.status(200).send grouping
    getGroupings: (req, res) ->
        query = {}
        if req.query.id?
            query._id = req.query.id
            page =  parseInt "0"
            size = parseInt "1"
        else
            page = parseInt req.query.page or "0"
            size = parseInt req.query.size or "50"

        Grouping
        .find(query)
        .sort('name')
        .skip(page*size)
        .limit(parseInt(size))
        .exec()
        .then(
            (result) ->
                res.status(200).send result
        )
        .catch (
            (err) ->
                res.status(500).send error: "Could not read grouping(s) #{err}"
        )
    updateGrouping: (req, res) ->
        if req.body.params._id?
            Grouping.findById(_id: req.body.params._id).exec()
            .then(
                (result) ->
                    grouping = result
                    grouping.name = req.body.params.name
                    grouping.type = req.body.params.type
                    grouping.region = req.body.params.region
                    grouping.isActive = req.body.params.isActive
                    grouping.members = req.body.params.members
                    if req.body.params.owner?
                        grouping.owner = req.body.params.owner
                    else
                        grouping.owner = ''
                    grouping.save()
                    .then (
                      (updated) ->
                          res.status(200).send updated
                        )
                    )
            .catch (
                (err) ->
                    res.status(500).send error: "Could not update grouping #{err}"
                )
    deleteGroupings: (req, res) ->
        if req.query.id?
            Grouping.findByIdAndRemove(req.query.id).exec()
            .then(
              (removed) ->
                  res.status(200).send removed
            )
            .catch (
                (err) ->
                    res.status(500).send error: "Could not delete grouping #{err}"
            )
        else
            res.status(500).send error: "Could not delete grouping #{err}"

    countGroupings: (req, res) ->
            Grouping.count().exec()
            .then(
                (counted) ->
                    res.status(200).send({count :counted})
            )
            .catch (
                (err) ->
                    res.status(500).send error: "Could not count groupings #{err}"
            )
    getGroupingMembers: (req, res) ->
        query = {}
        query.isActive = true
        query.name = req.query.name

        Grouping.find(query)
        .select('members type -_id')
        .then(
            (members) ->
                res.status(200).send(members)
        )
        .catch (
            (err) ->
                res.status(500).send error: "Could not load grouping's member #{err}"
        )
