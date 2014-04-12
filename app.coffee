
###
Module dependencies.
###

express = require 'express'
require 'shelljs/global'

app = express()
app.use(express.json())
app.use(express.urlencoded())

# all environments
app.set "port", process.env.PORT or 3000

# Default configurations
config =
	port: process.env.PORT or 1338
	env: process.env.NODE_ENV or 'development'

# Appilication
validateHookSource = (req, res, next) ->
	try
		repo = JSON.parse(req.body.payload).repository
		res.send 401, "Unauthorized" if repo.name not in ['vtexlab', 'docs', 'guide']
	catch
		res.send 401, "Unauthorized"

	next()

cloneRepository = (req, res, next) ->
	repo = JSON.parse(req.body.payload).repository
	if !test('-e', repo.name)
		exec "git clone https://github.com/vtex/#{repo.name}.git", (code, output) ->
			 res.send 500, output if code isnt 0
			 res.send 200, "Cloned."
	else
		res.send 200, "Cloned."

app.get '/', (req, res) ->
  res.send """
	<h1>Works!</h1>
    """

app.post "/hooks",
	validateHookSource,
	cloneRepository

http.createServer(app).listen app.get("port"), ->
	console.log "Express server listening on port " + app.get("port")
	return