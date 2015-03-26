express = require 'express'
router = express.Router()

router.get '/',(req,res,next)->
	res.render 'wechat/pay'

module.exports = router