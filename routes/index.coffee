express = require 'express'
router = express.Router()
fs = require 'fs'
path = require 'path'

# GET home page.

router.get '/', (req, res) ->
  res.render 'index', { title: 'Express' }

Routers = (app)->
	routeFiles = (folderPath)->
		files = fs.readdirSync folderPath
		for file in files
			if file[0] != '.'
				filePath = path.resolve folderPath,file
				stat = fs.statSync(filePath)
				if stat.isDirectory()
					routeFiles(filePath)
				else
					module = require filePath
					relative = path.relative __dirname,filePath
					folder = path.dirname relative
					name = path.basename relative,'.coffee'
					routePath = "/#{folder}"
					if name != 'index'
						routePath += "/#{name}"
					app.use routePath,module

	app.use '/', router;
	files = fs.readdirSync('./routes')
	for file in files
		if file[0] != '.'
			filePath = "./routes/#{file}"
			stat = fs.statSync(filePath)
			if stat.isDirectory()
				routeFiles filePath



module.exports = Routers
