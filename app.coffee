
###
Module dependencies.
###

express = require 'express'

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

	res.send 200, "Authorized."

app.get '/', (req, res) ->
  res.send """
	<h1>Works!</h1>
    """

app.post "/hooks",
	validateHookSource

http.createServer(app).listen app.get("port"), ->
	console.log "Express server listening on port " + app.get("port")
	return