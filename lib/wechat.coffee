
WXCrypter = require './WXCrypter'
xml2js = require 'xml2js'
util = require 'util'
xmlHelper = require './xmlHelper'

class Wechat
	appId = 'appid'
	appsecret = 'secret'
	token = 'token'
	# 加密消息
	AESKey = 'aeskey' 

	validateRequest = (req)->
		signature = req.query.signature
		timestamp = req.query.timestamp
		nonce = req.query.nonce
		if not signature or not timestamp or not nonce
			return false
		signatureParamas = [timestamp,nonce,token]
		signatureParamas.sort()
		signatureString = signatureParamas.join ''
		hex = WXCrypter.signature signatureString
		return hex == signature

	handleMessage = (msg,callback)->
		type = msg.MsgType[0]
		handler = null
		if type == 'event'
			eventType = msg.Event[0]
			handler = eventHandler[eventType] if eventHandler[eventType]
		else
			handler = messageHandler[type] if messageHandler[type]
		return callback('not implement') if not handler
		handler msg,(err,returnMsg)->
			return callback err if err
			callback err,returnMsg

	eventHandler =
		subscribe : (evt,callback) ->
			#TODO: 
			evtKey = evt.EventKey[0]
			if evtKey && evtKey.length > 0
				# 扫码关注，带参数
				callback()
			else
				# 关注事件，无参数
				callback()
		SCAN : (evt,callback) ->
			#TODO: 已关注扫码
			callback()
		LOCATION : (evt,callback) ->
			#TODO: update user location
			callback()
		CLICK : (evt,callback) ->
			#TODO:  menu click
			callback()
		VIEW : (evt,callback) ->
			#TODO: menu link
			callback()

	messageHandler =
		text : (msg,callback) ->
			#TODO: deal with text message
			callback()
		image : (msg,callback) ->
			#TODO: deal with image message
			callback()
		video : (msg,callback) ->
			#TODO: deal with video message
			callback()
		voice : (msg,callback) ->
			#TODO: deal with voice message
			callback()
		location : (msg,callback) ->
			#TODO: deal with location
			callback()

	validate : (req,callback)->
		return callback null,'success' if validateRequest req
		callback null,'failed'

	message : (req,callback)->
		return callback 'failed' if not validateRequest req
		xml2js.parseString req.body,(err,result)->
			return callback 'failed' if err
			message = result.xml
			if req.query.encrypt_type == 'aes'
				encryptedMsg = message.Encrypt[0]
				decryptedMsg = WXCrypter.decryptMsg encryptedMsg
				xml2js.parseString decryptedMsg,(err,result)->
					message = result.xml
					handleMessage message,(err,message)->
						return callback err if err
						return callback(null,'') if not message or message.length==0
						encryptedMsg = WXCrypter.encryptedMsg message
						timestamp = Math.floor(new Date().getTime()/1000)
						nonce = Math.floor(Math.random()*10000000)+''
						signatureParamas = [timestamp,nonce,token,encryptedMsg]
						signatureParamas.sort()
						signatureString = signatureParamas.join ''
						hex = WXCrypter.signature signatureString
						msgObj = 
							xml :
								Encrypt : encryptedMsg
								MsgSignature : hex
								TimeStamp : timestamp
								Nonce : nonce
						callback null,xmlHelper.pacakgeXML(msgObj)
			else
				handleMessage message,callback



module.exports = new Wechat()

