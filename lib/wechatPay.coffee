
WXCrypter = require './WXCrypter'
xml2js = require 'xml2js'
request = require 'request'
util = require 'util'
fs = require 'fs'
os = require 'os'
dateformat = require 'dateformat'
xmlHelper = require './xmlHelper'

class WechatPay
	appId = 'appid'
	payKey = '支付key'
	mchId = '商户号'

	unifiedorder = (userIp,body,totalFee,notifyUrl,outTradeNo,callback)->
		nonce = Math.floor(Math.random()*10000000) + ''
		pay =
			appid : appId
			mch_id : mchId
			nonce_str : nonce
			body : body
			out_trade_no : outTradeNo
			total_fee : totalFee
			notify_url : notifyUrl
			spbill_craete_ip : userIp
			trade_type : 'JSAPI'
		signString = WXCrypter.sortQuerys pay
		signString += "&key=#{payKey}"
		sign = WXCrypter.signature signString,'md5'
		pay.sign = sign.toUpperCase()
		payXML = xmlHelper.pacakgeXML pay

		request {url:"https://api.mch.weixin.qq.com/pay/unifiedorder",method:'POST',body:payxml},(err,res,data)->
			return callback err if err
			xml2js.parseString data,(err,result)->
				return callback err if err
				paypackage = result.xml
				if paypackage.return_code[0] == 'SUCCESS'
					if paypackage.result_code[0] == 'SUCCESS'
						prepay_id = paypackage.prepay_id[0]
						callback null,prepay_id
					else
						callback paypackage.err_code_des[0]
				else
					callback paypackage.return_msg[0]

	generatorPayPackage = (prepay_id)->
		nonce = Math.floor(Math.random()*10000000) + ''
		ts = Math.floor(new Date().getTime()/1000) + ''
		wxpay =
			appId : appId
			timeStamp : ts
			nonceStr : nonce
			package : "prepay_id=#{prepay_id}"
			signType : 'MD5'
		paysignstring = WXCrypter.sortQuery(wxpay,false)
		paysignstring += "&key=#{payKey}"
		paysign = WXCrypter.signature paysignstring,'md5'
		wxpay.paySign = paysign.toUpperCase()
		return wxpay

	checkOrder = (outTradeNo,callback)->
		nonce = Math.floor(Math.random()*10000000)
		queryOrder =
			appid : appId
			mch_id : mchId
			nonce_str : "#{nonce}"
			out_trade_no : outTradeNo
		paysignstring = WXCrypter.sortQuery(wxorder,false)
		paysignstring += "&key=#{payKey}"
		sign = WXCrypter.signature paysignstring,'md5'
		queryOrder.sign = sign.toUpperCase()
		queryXml = convertXML queryOrder
		request {url:"https://api.mch.weixin.qq.com/pay/orderquery",method:'POST',body:queryXml},(err,res,data)->
			return callback err if err
			xml2js.parseString data,(err,result)->
				return callback err if err
				result = result.xml || result
				returncode = result.return_code[0]
				if returncode != 'SUCCESS'
					return callback result.return_msg[0]
				if result.result_code[0] != 'SUCCESS'
					return callback result.err_code_des[0]
				if result.trade_state[0] != 'SUCCESS'
					return callback result.trade_state_desc[0]
				callback null,result

	cert = fs.readFileSync('./cert/apiclient_cert.p12') #读取证书，红包请求需要证书
	sendRedPack = (internalId,nickname,sendname,openid,total,wishing,remark,callback)->
		ip = null
		interfaces = os.networkInterfaces()
		for type,networks of interfaces
			for net in networks
				if net.family == 'IPv4' and not net.internal
					ip = net.address
		nonce = Math.floor(Math.random()*10000000)+''
		billNo = internalId + ''
		if billNo.length < 10
			count = 10 - billNo.length
			for [0...count]
				billNo = '0'+billNo
		billNo = mchId + dateformat(new Date(),'yyyyMMdd') + billNo
		redPack =
			mch_id : mchId
			nonce_str : nonce
			wxappid : appId
			mch_billno : billNo
			nickname : nickname
			send_name : sendname
			re_openid : openid
			total_amount : total
			min_value : total
			max_value : total
			total_num : 1
			wishing : wishing
			client_ip : ip
			act_name : '微信红包'
			remark : remark
		paysignstring = WXCrypter.sortQuery(redPack,false)
		paysignstring += "&key=#{payKey}"
		paysign = WXCrypter.signature paysignstring,'md5'
		redPack.sign = paysign.toUpperCase()
		redPackXML = xmlHelper.pacakgeXML redPack
		requestOptions =
			url:"https://api.mch.weixin.qq.com/mmpaymkttransfers/sendredpack"
			method:'POST'
			body:redPackXML
			agentOptions : 
				pfx : cert
				passphrase : mchId
				securityOptions : 'SSL_OP_NO_SSLv3'
		request requestOptions,(err,res,data)->
			return callback err if err
			xml2js.parseString data,(err,result)->
				return callback err if err
				result = result.xml || result
				returncode = result.return_code[0]
				if returncode != 'SUCCESS'
					return callback result.return_msg[0]
				if result.result_code[0] != 'SUCCESS'
					return callback result.err_code_des[0]
				callback null,result
		


module.exports = new WechatPay()