const crypto = require('crypto-js')

// generate the date
const created = (new Date()).toISOString();

// generate a nonce
const nonce = crypto.lib.WordArray.random(16).toString(crypto.enc.Hex);

// get the username and password
const username = pm.environment.get('wsse-username')
const password = pm.environment.get('wsse-password')

// encrypt the password (NxA doesn't seem to support this, though)
//<wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">${passwordDigest}</wsse:Password>
const passwordDigest = crypto.SHA1(nonce + created + password).toString(crypto.enc.Base64);

// generate the WSSE header
const wsseHeader = `
  <soap:Header>
    <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" soap:mustUnderstand="1">
      <wsu:Timestamp xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
        <wsu:Created>${created}</wsu:Created>
      </wsu:Timestamp>
      <wsse:UsernameToken>
        <wsse:Username>${username}</wsse:Username>
        <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#Password">${password}</wsse:Password>
        <wsse:Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">${nonce}</wsse:Nonce>
        <wsu:Created xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">${created}</wsu:Created>
      </wsse:UsernameToken>
    </wsse:Security>
  </soap:Header>
`

// refactor the body of the request
if (pm.request.body.raw !== undefined) {
    let insertPosition = pm.request.body.raw.search('\n.*<soap.*?:Body>')
    if (insertPosition != -1) {
        // remove the `string` placeholders
        pm.request.body.raw = pm.request.body.raw.replaceAll(/(?<=<soap:Body>.*)>string<(?=.*<\/soap:Body>)/gs, '><');
        // insert the security header
        pm.request.body.raw = pm.request.body.raw.slice(0, insertPosition) 
                            + wsseHeader
                            + pm.request.body.raw.slice(insertPosition);
    } else {
        console.warn("couldn insert WSSE header: but no soap body found", pm.request);
    }
} else {
    console.warn("couldn't insert WSSE header: raw request body missing");
}

