# weixin

微信相关API以及实现

client.coffee 实现了微信公众号JS API的调用

wechat.coffee 实现了微信公众号的消息接收流程

wechatPay.coffee 实现了微信支付的相关接口：JSAPI发起一个支付，发送微信红包

WXCrypter.coffee 主要实现了微信相关帮助方法，包括生成签名字符串，生成签名

xmlHelper.coffee 主要是实现了json对象转成xml字符串

## 其他注意

- 注释部分：使用redis来做缓存服务器保存 weixin的access_token以及js_api_ticket，可替换为其他服务