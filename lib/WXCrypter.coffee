
crypto = require 'crypto'

class WXCrypter
	sortQuerys : (query,encoding)->
		allKeys = []
		for key of query
			allKeys.push key
		allKeys.sort()
		keypaires = []
		for key in allKeys
			value = query[key]
			if encoding
				value = encodeURIComponent value
			keypaire = "#{key}=#{value}"
			keypaires.push keypaire
		return keypaires.join '&'

	signature : (text,algorithm)->
		algorithm = algorithm || 'sha1'
		buffer =  new Buffer(1024)
		length = buffer.write text,0
		text = buffer.toString 'binary',0,length
		hash = crypto.createHash algorithm
		hash.update text
		hash.digest 'hex'

	decryptMsg : (text,AESKey)->
		IV = AESKey.slice 0,16
		decipher = crypto.createDecipheriv('aes-256-cbc', AESKey, IV)
		decipher.setAutoPadding(false)
		deciphered = Buffer.concat([decipher.update(text, 'base64'), decipher.final()])
		content = deciphered.slice(16)
		length = content.slice(0, 4).readUInt32BE(0)
		content.slice(4, length + 4).toString()

	encryptMsg : (text,AESKey,appid)->
		IV = AESKey.slice 0,16
		randomString = crypto.pseudoRandomBytes(16)
		msg = new Buffer(text)
		msgLength = new Buffer(4)
		msgLength.writeUInt32BE(msg.length, 0)
		id = new Buffer(appid)
		bufMsg = Buffer.concat([randomString, msgLength, msg, id])
		cipher = crypto.createCipheriv('aes-256-cbc', AESKey, IV)
		cipheredMsg = Buffer.concat([cipher.update(bufMsg), cipher.final()])
		cipheredMsg.toString('base64')

module.exports = new WXCrypter()