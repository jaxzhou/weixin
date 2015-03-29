express = require 'express'
router = express.Router()
wechatPay = require '../../lib/wechatPay'

router.get '/',(req,res,next)->
	userIp = req.connection.remoteAddress
	internalId = Math.floor(Math.random()*10000000) #用实际内部支付id替换
	totalFee = 100 #用实际金额替换,单位分
	body = '测试支付' #用实际描述替换
	order = 
		clientIp : userIp
		orderId : internalId
		total : totalFee
		body : body 
	wechatPay.generaterPay  order,(err,pacakge)->
		if err
			return res.send 400,err
		res.render 'wechat/pay',pacakge

router.post '/',(req,res,next)->
	postBody = req.body
	wechatPay.wxCallback  postBody,(err,orderId)->
		if err
			return res.send 400,err
		console.log "#{orderId} 已支付成功！"
		res.send ''


module.exports = router