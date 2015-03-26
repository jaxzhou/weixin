express = require 'express'
router = express.Router()

router.get '/',(req,res,next)->
	res.render 'wechat/index'

module.exports = router