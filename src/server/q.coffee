# curl -H 'content-type:application/json' -d '{"x":1, "y":3}' 192.168.7.2:7777

express = require 'express'
session = require 'express-session'
bodyParser = require 'body-parser'

app = express()

app.disable 'etag'
app.use bodyParser.json extended:true
app.use session secret: 'flattened', resave: true, saveUninitialized: true, store: new session.MemoryStore()

messages = []
clients = {}

app.get '/', (req, res) ->
  sess = req.session
  sess.nextMessage ||= 1
  message = messages[sess.nextMessage - 1]
  if message 
    sess.nextMessage += 1
    res.json message
  else
    res.json {}

app.post '/', (req, res) ->
  sess = req.session
  id = clients[req.sessionID] ||= 1 + Object.keys(clients).length
  req.body.sender = id
  req.body.serial = messages.length
  messages.push req.body
  res.json sent: req.body

app.listen 7777, ->
  console.log 'app started'

