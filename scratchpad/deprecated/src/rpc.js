var Q=require('q')

module.exports = {
    RPC : Rpc
}

var XMLHttpRequest = require("xmlhttprequest").XMLHttpRequest;

/**
 * @param {string}
 *            options.url RPC server url (default: /rpc)
 * @param {string}
 *            options.user RPC server user
 * @param {string}
 *            options.password RPC server password
 */
function Rpc(options) {
    if (!options)
        options = {};

    this.rpcRequestId=1
    this.rpcUrl = options.url || '/rpc';
    if (options.user || options.password) {
        this.auth = "Basic "
                + new Buffer(options.user + ":" + options.password)
                        .toString("base64");
    }
}

Rpc.prototype.request = function(method, params) {
    var deferred = Q.defer();
    this.request_cb(method, params, function(response) {
        if(response.success){
            //console.log("Resolve: "+JSON.stringify(response))
            deferred.resolve(response.result ? response.result:response)
        }else{
            deferred.reject(
                new Error(JSON.stringify(response))
            ) 
        }
    })
    return deferred.promise
}

Rpc.prototype.request_cb = function(method, params, callback) {
    var client = new XMLHttpRequest();
    client.open("POST", this.rpcUrl, true);
    client.responseType = 'json';
    client.setRequestHeader("Content-Type", "application/json;charset=UTF-8");
    client.setRequestHeader('Cache-Control',
            'no-cache, no-store, must-revalidate');
    client.setRequestHeader('Pragma', 'no-cache');
    client.setRequestHeader('Expires', '0');

    if (this.auth)
        client.setRequestHeader('Authorization', this.auth);

    var response = {}
    var xhrcallback = function() {
        if (this.readyState == this.DONE) {

            var responseText = this.responseText || null;
            //var i = responseText.indexOf("{");
            //if (i != 0)
            //    // Bitshares error or node XML ??
            //    // https://github.com/driverdan/node-XMLHttpRequest/issues/76
            //    responseText = responseText.substring(i, responseText.length);
            
            response.status = this.status;

            try {
                response.result = JSON.parse(responseText);
            } catch (e) {
                response.error = responseText;
            }

            //console.log('http_response = ' + JSON.stringify(responseText));
            response.success = response.status == 200 && !response.error;
            callback(response);
            return;
        }
    }
    client.onreadystatechange = xhrcallback;
    try {
        var payload = JSON.stringify({
            method : method,
            params : params || [],
            id : this.rpcRequestId++
        });
        //console.log('http_request = '+JSON.stringify(payload));
        response.request=payload
        client.send(payload);
    } catch (e) {
        response.success = false;
        response.error = 'Error sending request: ' + e
        callback(response);
        return;
    }
}



