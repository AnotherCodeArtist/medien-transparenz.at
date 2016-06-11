'use strict'

should = require 'should'
mongoose = require 'mongoose'
Organisation = mongoose.model 'Organisation'
Transfer = mongoose.model 'Transfer'
controller = require('../controllers/transparencyServerCtrl')({})
request = require 'superagent'
Q = require 'q'


describe 'Transparency Controllers', ->
    createTestTransfer = (paragraph, id, quarter, year) ->
        transfer = new Transfer
            organisation: "Organisation#{id}"
            quarter: quarter
            year: year
            media: "Media#{id}"
            period: parseInt "#{year}#{quarter}"
            transferType: paragraph
            amount: paragraph * 100
        transfer.save()

    beforeEach (done) ->
        createTestTransfer 2, id, 4, 2013 for id in [1..10]
        createTestTransfer 4, id, 4, 2013 for id in [1..5]
        createTestTransfer 2, id, 1, 2014 for id in [1..5]  #5
        createTestTransfer 4, id, 1, 2014 for id in [1..8]      #8
        createTestTransfer 31, id, 1, 2014 for id in [1..2]         #2
        createTestTransfer 2, id, 2, 2014 for id in [2..10] #5
        createTestTransfer 4, id, 2, 2014 for id in [5..12]     #4
        createTestTransfer 31, id, 2, 2014 for id in [1..2]         #0
        done()

    describe 'Regex for parsing transparency report', ->
        it 'should match a valid line', ->
            line = "Ausgleichstaxfonds;20141;4;0;Plattform Arbeit und Behinderung http://www.arbeitundbehinderung.at/de/;10500\r"
            regex = /(.+?);(\d{4})(\d);(\d{1,2});\d;(.+?);(\d+(?:,\d{1,2})?).*/
            m = line.match regex
            m.should.have.lengthOf 7

    describe 'Saving Organisation', ->
        it 'should match and save an valid organisation line', (done)->
            line = "FH JOANNEUM Gesellschaft mbH;Alte Poststr. 149;8020;Graz;Österreich\r"
            splittedLine = line.split(";")
            splittedLine.should.have.lengthOf 5
            testOrganisation = new Organisation
            testOrganisation.name = splittedLine[0]
            testOrganisation.street = splittedLine[1]
            testOrganisation.zipCode = splittedLine[2]
            testOrganisation.city_de = splittedLine[3]
            testOrganisation.country_de = splittedLine[4]
            testOrganisation.save()
            done()

    describe 'controller overview', ->
        agent = request.agent()

        it 'should provide an overview of payments', (done)->
            req = {}
            res =
                send: (result) ->
                    #console.log r for r in result
                    result.should.have.lengthOf 2
                    result[0].year.should.be.exactly 2014
                    result[1].year.should.be.exactly 2013
                    done()
            controller.overview req, res

        it 'should provide a payment overview when called via REST', (done)->
            agent
            .get('http://localhost:3001/api/transparency/overview')
            .end (err, res) ->
                should.not.exist err
                res.status.should.be.exactly 200
                res.body.should.have.lengthOf 2
                res.body[0].year.should.be.exactly 2014
                res.body[1].year.should.be.exactly 2013
                done()


    describe 'controller years', ->
        agent = request.agent()

        it 'should return a list of years', (done)->
            agent.get('http://localhost:3001/api/transparency/years')
            .end (err, result) ->
                should.not.exist err
                result.body.years.should.have.lengthOf 2
                result.body.years[0].should.be.exactly 2014
                result.body.years[1].should.be.exactly 2013
                done()


    describe 'controller periods', ->
        agent = request.agent()

        it 'should load a list of available periods', (done) ->
            agent.get('http://localhost:3001/api/transparency/periods')
            .end (err, res) ->
                should.not.exist err
                res.body.should.have.lengthOf 3
                res.body[0].year.should.be.exactly 2014
                res.body[0].quarter.should.be.exactly 2
                res.body[0].period.should.be.exactly 20142
                done()

    describe 'controller topEntries', ->
        agent = request.agent()

        it 'should load top entries from database', (done) ->
            agent.get('http://localhost:3001/api/transparency/top?years=2013&years=2014&x=5')
            .end (err, res) ->
                should.not.exist err
                #console.log res.body
                #res.body.should.be.exactly "SUPI!"
                done()

    describe "flow controller", ->

        agent = request.agent()

        it "should load all transfers if no restrictions are present", (done) ->
            agent.get('http://localhost:3001/api/transparency/flows')
            .end (err,res) ->
                should.not.exist err
                res.status.should.be.equal 200
                result = res.body
                result.should.have.lengthOf 24
                should.exists result[0].organisation
                should.exists result[0].media
                should.exists result[0].transferType
                done()

        it "should only load those transfers for the given period 1", (done) ->
            agent.get('http://localhost:3001/api/transparency/flows?from=20142&to=20142&pType=2')
            .end (err,res) ->
                should.not.exist err
                res.status.should.be.equal 200
                result = res.body
                result.should.have.lengthOf 9
                should.exists result[0].organisation
                should.exists result[0].media
                should.exists result[0].transferType
                done()

        it "should only load those transfers for the given period 2", (done) ->
            agent.get('http://localhost:3001/api/transparency/flows?from=20134&to=20141')
            .end (err,res) ->
                should.not.exist err
                res.status.should.be.equal 200
                result = res.body
                result.should.have.lengthOf 20
                should.exists result[0].organisation
                should.exists result[0].media
                should.exists result[0].transferType
                done()

        it "should only load those transfers for the given transfer type", (done) ->
            agent.get('http://localhost:3001/api/transparency/flows?pType=2')
            .end (err,res) ->
                should.not.exist err
                res.status.should.be.equal 200
                result = res.body
                result.should.have.lengthOf 10
                should.exists result[0].organisation
                should.exists result[0].media
                should.exists result[0].transferType
                result[0].amount.should.be.above 0
                result[0].transferType.should.be.equal 2
                done()

        it "should only load those transfers for the given organisation", (done) ->
            agent.get('http://localhost:3001/api/transparency/flows?pType=2&name=Organisation5')
            .end (err,res) ->
                should.not.exist err
                res.status.should.be.equal 200
                result = res.body
                result.should.have.lengthOf 1
                should.exists result[0].organisation
                should.exists result[0].media
                should.exists result[0].transferType
                result[0].amount.should.be.above 0
                result[0].organisation.should.be.equal "Organisation5"
                done()

        it "should only load those transfers for the given media", (done) ->
            agent.get('http://localhost:3001/api/transparency/flows?orgType=media&name=Media7')
            .end (err,res) ->
                should.not.exist err
                res.status.should.be.equal 200
                result = res.body
                result.should.have.lengthOf 2
                should.exists result[0].organisation
                should.exists result[0].media
                should.exists result[0].transferType
                result[0].amount.should.be.above 0
                result[0].media.should.be.equal "Media7"
                done()


    afterEach (done) ->
        Transfer.remove({}).exec()
        Organisation.remove({}).exec()
        done()