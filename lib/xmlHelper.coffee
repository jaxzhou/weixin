
class XMLHelper

	pacakgeXML : (object)->
		xmlString = ""
		for key,value of object
			xmlString += "<#{key}>"
			valueType = typeof value 
			switch valueType
				when 'number'
					xmlString += "#{value}"
				when 'string'
					xmlString += "<![CDATA[#{value}]]>"
				when 'object'
					if util.isArray value
						for obj in value
							xmlString += pacakgeXML obj
					else
						xmlString += pacakgeXML value
			xmlString += "</#{key}>"
		return xmlString

module.exports = new XMLHelper()