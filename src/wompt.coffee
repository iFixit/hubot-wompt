{Adapter, Robot} = require "hubot"
EventEmitter = require('events').EventEmitter
crypto = require('crypto')
http = require('http')
io = require('socket.io-client')

class WomptBot extends Adapter
   run: ->
      self = @
      
      options =
         host:   process.env.HUBOT_WOMPT_HOST or "wompt.com"
         room:   process.env.HUBOT_WOMPT_ROOM
         secret: process.env.HUBOT_WOMPT_SECRET
         nick:   process.env.HUBOT_WOMPT_NICK or @robot.name

      bot = new WomptConnector(options, @robot)

      @bot = bot

      self.emit "connected"

exports.use = (robot) ->
   new WomptBot robot

class WomptConnector extends EventEmitter
   constructor: (options, @robot) ->
      unless options.room
         throw new Error("HUBOT_WOMPT_ROOM is not defined.")
      unless options.secret
         throw new Error("HUBOT_WOMPT_SECRET is not defined.")
      
      @host   = options.host
      @room   = options.room
      @secret = options.secret
      @nick   = options.nick

      @connect()

   dispatch: (message) ->
      if message.action?
         if message.action == "message"
            # TODO: emit event?
            console.log "MESSAGE: #{message.msg}"

   generateURL: ->
      timestamp = Math.round(new Date().getTime() / 1000)
      baseURL = "/a/ifixit/"
      secureURL = "#{@room}?user_id=#{@nick}&user_name=#{@nick}&ts=#{timestamp}"
      shasum = crypto.createHash "sha1"
      shasum.update(secureURL + @secret)
      secureToken = shasum.digest "hex"
      chatURL = baseURL + secureURL + "&secure=#{secureToken}"

   join: (connectorID) ->
      @chat = io.connect("http://#{@host}")
      @chat.on "connect", =>
         console.log "Connected to Wompt."
         @chat.json.send {
            channel:      @room
            action:       "join"
            connector_id: connectorID
         }
      @chat.on "disconnect", ->
         console.log "Disconnected from Wompt."
         # TODO: reconnect?
      @chat.on "message", (data) =>
         if typeof(data) == "object"
            if data.length
               data.forEach @dispatch
            else
               @dispatch data

   connect: ->
      self = @

      options =
         host: @host
         port: 80
         path: @generateURL()

      getter = http.get options, (response) ->
         body = ""
         response.setEncoding "utf8"
         response.on "data", (chunk) ->
            body += chunk
         response.on "end", ->
            matches = body.match /connector_id\s+=\s+'([^']+)/
            connectorID = matches[1]
            self.join connectorID

      getter.on "error", (e) ->
         console.log("ERROR: " + e.message)
