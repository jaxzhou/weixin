wechat_host = 'api.weixin.qq.com'
wechat_file_host = 'file.api.weixin.qq.com'
https = require 'https'
url = require 'url'
request = require 'request'
fs = require 'fs'
async = require 'async'

class WechatClient

	service_access_token = null
	js_api_ticket = null

	appID = null
	appSecret = null
	constructor:(options)->
		appID = options.appID
		appSecret = options.appsecret
		requestToken()

	sendMessage : (message,cb)->
		return cb('token failed') if not service_access_token
		# 如果不传touser则自动转换文章为群发
		return sendGroupMessage message,cb if not message.touser

		requestPathObject =
			protocol : 'https'
			hostname : wechat_host
			pathname : 'cgi-bin/message/custom/send'
			query :
				access_token : service_access_token

		request_path = url.format(requestPathObject)
		request {url:request_path,method:'POST',json:message},(err,res,data)->
			return cb(packageWeixinError(data)) if data.errcode > 0
			cb(null,data)

	sendGroupMessage = (message,callback)->
		articles = message.news.articles
		async.map articles
			,(article,cb)->
				return cb() if not article.picurl
				pic = article.picurl
				tempfilename = Math.floor(Math.random()*10000000)+'.jpg'
				request.get {url:pic,encoding:null},(err,res,body)->
					uploadOption =
						protocol : 'http'
						hostname : wechat_file_host
						pathname : 'cgi-bin/media/upload'
						query :
							access_token : service_access_token
							type : 'image'
					request_path = url.format(uploadOption)
					req = request.post request_path,(er,resp,wxreturn)->
						return cb(er) if er
						wxreturn = JSON.parse wxreturn
						return cb(wxreturn) if not wxreturn['media_id']
						article.media = wxreturn['media_id']
						cb()
					form = req.form()
					form.append 'media',body,{filename:tempfilename,contentType:'image/jpeg'}
					form.append 'hack','none'

			,(err,result)->
				return callback err if err
				packedMessages = []
				for a in articles
					pacMedia =
						thumb_media_id : a.media
						title : a.title
						digest : a.description
						content : a.description || ''
						content_source_url : a.url
					pacMedia.content += "<p>完整内容点击<b>查看原文</b></p>"
					pacMedia.thumb_media_id = a.media if a.media
					packedMessages.push pacMedia
				medidOption =
					protocol : 'https'
					hostname : wechat_host
					pathname : 'cgi-bin/media/uploadnews'
					query :
						access_token : service_access_token
				request_path = url.format(medidOption)
				request {url:request_path,method:'POST',json: {articles : packedMessages}},(er,resp,body)->
					return callback(body) if not body.media_id
					msgId = body.media_id
					sendOption =
						protocol : 'https'
						hostname : wechat_host
						pathname : 'cgi-bin/message/mass/sendall'
						query :
							access_token : service_access_token
					send_path = url.format(sendOption)
					msg =
						filter :
							is_to_all : true
						msgtype : 'mpnews'
						mpnews :
							media_id : msgId
					request {url:send_path,method:'POST',json: msg},(er,res,wx)->
						return callback(wx) if not wx.msg_id
						logger.info "send group message #{wx.msg_id}"
						callback(null,wx)

	getUserInfo : (openid,cb)->
		return cb('token failed') if not service_access_token
		requestUserInfo(openid,cb)

	getUserList : (cb)->
		return cb('token failed') if not service_access_token
		requestPathObject =
			protocol : 'https'
			hostname : wechat_host
			pathname : 'cgi-bin/user/get'
			query :
				access_token : service_access_token
		request_path = url.format(requestPathObject)
		request request_path,(err,res,body)->
			return cb(err) if err
			result = JSON.parse(body)
			return cb(packageWeixinError(result)) if result.errcode
			return cb(null,result.data) if result.data
			cb('data error')


	getUserInfoByCode : (code,cb)->
		return cb('token failed') if not service_access_token
		requestTempToken code,(tk)->
			return cb(packageWeixinError(tk)) if tk.errcode
			openid = tk.openid
			requestUserInfo openid,cb

	getApiTicket : (cb)->
		cb(null,js_api_ticket)

	createQRCode : (scene,cb)->
		type = scene.scene
		qrRequest = null
		if type == 0
			qrRequest = 
				'action_name' : 'QR_SCENE'
				'expire_seconds' : 1800
				'action_info' :
					'scene' :
						'scene_id' : scene.id
		else if type == 1
			qrRequest = 
				'action_name' : 'QR_LIMIT_SCENE'
				'action_info' :
					'scene' :
						'scene_str' : scene.id
		else
			return cb('code error')

		requestPathObject =
			protocol : 'https'
			hostname : wechat_host
			pathname : 'cgi-bin/qrcode/create'
			query :
				access_token : service_access_token

		request_path = url.format(requestPathObject)
		
		request {url:request_path,method:'POST',json:qrRequest},(err,res,data)->
			return cb(packageWeixinError(data)) if data.errcode > 0
			cb(null,data)

	retry = 0
	refreshTokenTimer = null
	requestToken = () ->
		refreshTokenTimer = null if refreshTokenTimer
		requestPathObject =
			protocol : 'https'
			hostname : wechat_host
			pathname : 'cgi-bin/token'
			query :
				grant_type : 'client_credential'
				appid : appID
				secret : appSecret

		request_path = url.format(requestPathObject)

		request request_path,(err,res,body)->
			result = JSON.parse(body)
			if !err && !result.errcode
				service_access_token = result.access_token
				expirein = result.expires_in
				# cache token
				# redisClient.set tokenkey,service_access_token
				# redisClient.expire tokenkey,expirein
				refreshTokenTimer = setTimeout requestToken,(expirein-60)*1000
				logger.info 'token upated :'+service_access_token
				retry = 0
			else
				refreshTokenTimer = setTimeout requestToken,1000*retry
				logger.warn 'refrsh weixin token failed, retry times:',retry
				retry++

	ticketTry = 0
	ticketTimer = null
	requstJsApiTicket = (cb)->
		if not service_access_token
			ticketTry = 5
			refreshTokenTimer = setTimeout requstJsApiTicket,1000*ticketTry

		requestPathObject =
			protocol : 'https'
			hostname : wechat_host
			pathname : 'cgi-bin/ticket/getticket'
			query :
				access_token : service_access_token
				type : 'jsapi'
		request_path = url.format(requestPathObject)

		request request_path,(err,res,body)->
			result = JSON.parse(body)
			if not err and result.ticket
				js_api_ticket = result.ticket
				expirein = result.expires_in
				# cache ticket
				# redisClient.set ticketKey,js_api_ticket
				# redisClient.expire ticketKey,expirein
				ticketTimer = setTimeout requstJsApiTicket,(expirein-60)*1000
				logger.info 'api ticket update :' +js_api_ticket
				ticketTry = 0
			else
				refreshTokenTimer = setTimeout requstJsApiTicket,1000*ticketTry
				logger.warn 'get api ticket failed, retry times:',ticketTry
				ticketTry++


	requestTempToken = (usercode,cb)->
		requestPathObject =
			protocol : 'https'
			hostname : wechat_host
			pathname : 'sns/oauth2/access_token'
			query :
				grant_type : 'authorization_code'
				appid : appID
				secret : appSecret
				code : usercode

		request_path = url.format(requestPathObject)

		request request_path,(err,res,body)->
			result = JSON.parse(body)
			cb(result)

	requestUserInfo = (uid,cb)->
		return cb('token failed') if not service_access_token
		return cb('need user openid') if not uid

		requestPathObject =
			protocol : 'https'
			hostname : wechat_host
			pathname : 'cgi-bin/user/info'
			query :
				access_token : service_access_token
				openid : uid

		request_path = url.format(requestPathObject)

		request request_path,(err,res,body)->
			return cb(err) if err
			result = JSON.parse(body)
			return cb(result) if result.errcode
			return cb(null,result)

	packageWeixinError = (err)->
		requestToken() if err.errcode==42001
		errOption = 
			message : err.errcode+':'+err.errmsg
			statusCode : 400
			errCode : 'WeixinApi'
		return errors.create errOption

module.exports = WechatClient